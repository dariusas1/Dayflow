//
//  ProactiveCoachEngine.swift
//  FocusLock
//
//  Background monitoring engine for proactive coaching alerts
//  Detects context switches, dropped balls, patterns, and energy mismatches
//

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class ProactiveCoachEngine: ObservableObject {
    static let shared = ProactiveCoachEngine()
    
    // MARK: - Published Properties
    @Published var activeAlerts: [ProactiveAlert] = []
    @Published var isMonitoring = false
    
    // MARK: - Dependencies
    private let storageManager = StorageManager.shared
    private let todoEngine = TodoExtractionEngine.shared
    private let memoryStore = HybridMemoryStore.shared
    private let logger = Logger(subsystem: "FocusLock", category: "ProactiveCoachEngine")
    
    // MARK: - Monitoring State
    private var monitoringTimer: Timer?
    private var contextSwitchHistory: [ContextSwitch] = []
    private var mentionedTasks: [String: Int] = [:] // Task mention count
    private var lastActivityApp: String = ""
    private var lastActivityTime: Date = Date()
    private var currentFocusSession: LegacyFocusSession?
    
    // MARK: - Configuration
    private let contextSwitchThreshold = 3 // Alert after N switches in window
    private let contextSwitchWindow: TimeInterval = 7200 // 2 hours
    private let p0CheckTime = 14 // 2pm PT
    private let droppedBallMentionThreshold = 3
    
    private init() {
        // Don't load data synchronously in init - defer to loadDataAsync()
    }
    
    // MARK: - Public Interface
    
    /// Load data asynchronously after initialization
    /// Must be called once before using the engine
    func loadDataAsync() async {
        await loadAlertHistoryAsync()
    }
    
    /// Start background monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("🎯 Proactive coach monitoring started")
        
        // Run checks every 5 minutes
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runMonitoringCycle()
            }
        }
        
        // Run initial check
        Task {
            await runMonitoringCycle()
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        logger.info("Proactive coach monitoring stopped")
    }
    
    /// Dismiss an alert
    func dismissAlert(_ alertId: UUID) {
        guard let index = activeAlerts.firstIndex(where: { $0.id == alertId }) else { return }
        
        var alert = activeAlerts[index]
        alert.isDismissed = true
        alert.dismissedAt = Date()
        activeAlerts.remove(at: index)
        
        // Persist to database
        do {
            try storageManager.dismissAlert(id: alertId)
        } catch {
            logger.error("Failed to dismiss alert in database: \(error.localizedDescription)")
        }
    }
    
    /// Get alerts by type
    func getAlerts(ofType type: AlertType? = nil, severity: AlertSeverity? = nil) -> [ProactiveAlert] {
        var filtered = activeAlerts.filter { !$0.isDismissed }
        
        if let type = type {
            filtered = filtered.filter { $0.alertType == type }
        }
        
        if let severity = severity {
            filtered = filtered.filter { $0.severity == severity }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Record a context switch
    func recordContextSwitch(from fromActivity: String?, to toActivity: String?, fromApp: String?, toApp: String?) {
        let duration = Int(Date().timeIntervalSince(lastActivityTime))
        
        let contextSwitch = ContextSwitch(
            fromActivity: fromActivity,
            toActivity: toActivity,
            fromApp: fromApp,
            toApp: toApp,
            durationSeconds: duration
        )
        
        contextSwitchHistory.append(contextSwitch)
        
        // Keep only last 24 hours
        let dayAgo = Date().addingTimeInterval(-86400)
        contextSwitchHistory = contextSwitchHistory.filter { $0.createdAt > dayAgo }
        
        lastActivityApp = toApp ?? ""
        lastActivityTime = Date()
        
        // Check if this violates an anchor block
        if let session = currentFocusSession, session.mode == .anchor {
            checkAnchorBlockViolation(session: session)
        }
        
        // Check overall context switching
        checkContextSwitching()
    }
    
    /// Track a task mention in conversation or notes
    func trackTaskMention(_ taskDescription: String) {
        mentionedTasks[taskDescription, default: 0] += 1
        
        // Check for dropped balls
        if mentionedTasks[taskDescription]! >= droppedBallMentionThreshold {
            checkDroppedBalls()
        }
    }
    
    /// Start a focus session
    func startFocusSession(mode: FocusMode, taskId: UUID? = nil) {
        currentFocusSession = LegacyFocusSession(mode: mode, taskId: taskId)
        logger.info("Started \(mode.displayName) session")
    }
    
    /// Start a legacy focus session (used by FocusSessionManager)
    func startLegacyFocusSession(mode: FocusMode, taskId: UUID? = nil) {
        currentFocusSession = LegacyFocusSession(mode: mode, taskId: taskId)
        logger.info("Started \(mode.displayName) session")
    }
    
    /// End current focus session
    func endFocusSession() {
        guard let session = currentFocusSession else { return }
        var updatedSession = session
        updatedSession.endTime = Date()
        
        // Analyze session quality
        analyzeSessionQuality(updatedSession)
        
        currentFocusSession = nil
    }
    
    /// End legacy focus session (used by FocusSessionManager)
    func endLegacyFocusSession() {
        guard let session = currentFocusSession else { return }
        var updatedSession = session
        updatedSession.endTime = Date()
        
        // Analyze session quality
        analyzeSessionQuality(updatedSession)
        
        currentFocusSession = nil
    }
    
    // MARK: - Private Monitoring Methods
    
    private func runMonitoringCycle() async {
        logger.debug("Running monitoring cycle...")
        
        // 1. Check P0 task neglect
        await checkP0TaskNeglect()
        
        // 2. Check energy/task mismatch
        await checkEnergyMismatch()
        
        // 3. Check for pattern recognition opportunities
        await checkPatterns()
        
        // 4. Check approaching deadlines
        await checkDeadlines()
        
        // 5. Clean up old alerts (older than 24h)
        cleanUpOldAlerts()
    }
    
    // MARK: - Alert Generators
    
    private func checkContextSwitching() {
        let recentSwitches = contextSwitchHistory.filter {
            $0.createdAt > Date().addingTimeInterval(-contextSwitchWindow)
        }
        
        if recentSwitches.count >= contextSwitchThreshold {
            // Check if we already have an active alert for this
            let hasActiveAlert = activeAlerts.contains { 
                $0.alertType == .contextSwitch && !$0.isDismissed
            }
            
            guard !hasActiveAlert else { return }
            
            let alert = ProactiveAlert(
                alertType: .contextSwitch,
                message: "You've switched contexts \(recentSwitches.count) times in 2 hours. Consider entering an Anchor Block to maintain focus.",
                severity: .warning,
                context: "Recent switches: \(recentSwitches.count)"
            )
            
            saveAlert(alert)
            logger.warning("🚨 Context switch alert generated")
        }
    }
    
    private func checkP0TaskNeglect() async {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Only check after 2pm PT
        guard hour >= p0CheckTime else { return }
        
        let p0Tasks = todoEngine.getTodos(status: .pending, priority: .p0)
        
        guard !p0Tasks.isEmpty else { return }
        
        // Check if any P0s haven't been started today
        let today = Calendar.current.startOfDay(for: Date())
        let untouchedP0s = p0Tasks.filter { task in
            guard let scheduled = task.scheduledTime else { return true }
            return scheduled < Date() && task.status == .pending
        }
        
        if !untouchedP0s.isEmpty {
            let hasActiveAlert = activeAlerts.contains { 
                $0.alertType == .p0Neglect && !$0.isDismissed
            }
            
            guard !hasActiveAlert else { return }
            
            let taskTitles = untouchedP0s.prefix(3).map { $0.title }.joined(separator: ", ")
            
            let alert = ProactiveAlert(
                alertType: .p0Neglect,
                message: "You have \(untouchedP0s.count) P0 task(s) that haven't been started: \(taskTitles). These should be your top priority.",
                severity: .critical,
                context: "\(untouchedP0s.count) P0 tasks pending"
            )
            
            saveAlert(alert)
            logger.warning("🚨 P0 neglect alert generated")
        }
    }
    
    private func checkEnergyMismatch() async {
        guard let session = currentFocusSession else { return }

        // If in Anchor Block but energy is low
        if session.mode == .anchor && JarvisCoachPersona.shared.coachingContext.userEnergyLevel < 5 {
            let hasActiveAlert = activeAlerts.contains { 
                $0.alertType == .energyMismatch && !$0.isDismissed
            }
            
            guard !hasActiveAlert else { return }
            
            let alert = ProactiveAlert(
                alertType: .energyMismatch,
                message: "You're in an Anchor Block but your energy is low (\(String(format: "%.1f", JarvisCoachPersona.shared.coachingContext.userEnergyLevel))/10). Consider switching to Triage Block or taking a break.",
                severity: .warning,
                context: "Energy: \(JarvisCoachPersona.shared.coachingContext.userEnergyLevel)/10, Mode: Anchor"
            )
            
            saveAlert(alert)
        }
    }
    
    private func checkDroppedBalls() {
        let droppedBalls = mentionedTasks.filter { $0.value >= droppedBallMentionThreshold }
        
        for (task, count) in droppedBalls {
            // Check if this task is already a todo
            let existsAsTodo = todoEngine.extractedTodos.contains { $0.title.lowercased().contains(task.lowercased()) }
            
            guard !existsAsTodo else { continue }
            
            let hasActiveAlert = activeAlerts.contains { alert in
                alert.alertType == .droppedBall && alert.context?.contains(task) == true && !alert.isDismissed
            }
            
            guard !hasActiveAlert else { continue }
            
            let alert = ProactiveAlert(
                alertType: .droppedBall,
                message: "You've mentioned '\(task)' \(count) times but haven't created a todo or taken action. Should this be scheduled?",
                severity: .warning,
                context: task
            )
            
            saveAlert(alert)
            logger.info("🎯 Dropped ball detected: \(task)")
        }
    }
    
    private func checkPatterns() async {
        // Look for patterns in timeline cards
        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayString = dateFormatter.string(from: today)
        let timelineCards = storageManager.fetchTimelineCards(forDay: dayString)
        
        // Pattern: Same low-ROI activity multiple times
        var activityCounts: [String: Int] = [:]
        for card in timelineCards {
            let category = card.category
            activityCounts[category, default: 0] += 1
        }
        
        // If spending too much time on one category
        let dominantCategory = activityCounts.max(by: { $0.value < $1.value })
        if let (category, count) = dominantCategory, count > timelineCards.count / 2 {
            let lowROICategories = ["Social Media", "Entertainment", "Communication"]
            
            if lowROICategories.contains(category) {
                let hasActiveAlert = activeAlerts.contains { 
                    $0.alertType == .patternRecognition && $0.context?.contains(category) == true && !$0.isDismissed
                }
                
                guard !hasActiveAlert else { return }
                
                let alert = ProactiveAlert(
                    alertType: .patternRecognition,
                    message: "Pattern detected: You've spent \(count) sessions on \(category) today. Is this aligned with your P0 goals?",
                    severity: .info,
                    context: category
                )
                
                saveAlert(alert)
            }
        }
    }
    
    private func checkDeadlines() async {
        let allTodos = todoEngine.extractedTodos
        
        // Find todos with deadlines in next 24 hours
        let tomorrow = Date().addingTimeInterval(86400)
        let approachingDeadlines = allTodos.filter { todo in
            guard let scheduled = todo.scheduledTime else { return false }
            return scheduled < tomorrow && scheduled > Date() && todo.status != .completed
        }
        
        for todo in approachingDeadlines {
            let hasActiveAlert = activeAlerts.contains { alert in
                alert.alertType == .deadlineApproaching && alert.context?.contains(todo.id.uuidString) == true && !alert.isDismissed
            }
            
            guard !hasActiveAlert else { continue }
            
            let alert = ProactiveAlert(
                alertType: .deadlineApproaching,
                message: "Deadline approaching: '\(todo.title)' is due soon (\(todo.priority.rawValue)). Time to prioritize this?",
                severity: todo.priority == .p0 ? .critical : .warning,
                context: todo.id.uuidString
            )
            
            saveAlert(alert)
        }
    }
    
    private func checkAnchorBlockViolation(session: LegacyFocusSession) {
        var updatedSession = session
        updatedSession.interruptionCount += 1
        currentFocusSession = updatedSession
        
        if updatedSession.interruptionCount >= 2 {
            let hasActiveAlert = activeAlerts.contains { 
                $0.alertType == .anchorBlockViolation && !$0.isDismissed
            }
            
            guard !hasActiveAlert else { return }
            
            let alert = ProactiveAlert(
                alertType: .anchorBlockViolation,
                message: "Anchor Block violation: \(updatedSession.interruptionCount) interruptions detected. Anchor Blocks should be focused on ONE task with no interruptions.",
                severity: .warning,
                context: "Session ID: \(session.id.uuidString)"
            )
            
            saveAlert(alert)
            logger.warning("⚠️ Anchor block violated")
        }
    }
    
    private func analyzeSessionQuality(_ session: LegacyFocusSession) {
        let duration = session.actualDuration / 60 // in minutes
        
        switch session.mode {
        case .anchor:
            // Anchor blocks should be 60-120min
            if duration < 60 {
                logger.info("Anchor block ended early (\(Int(duration))m). Quality may be compromised.")
            } else if duration > 120 {
                logger.info("Extended anchor block (\(Int(duration))m). Great focus!")
            }
            
            if session.interruptionCount == 0 {
                logger.info("✅ Perfect anchor block - zero interruptions")
            }
            
        case .triage:
            // Triage should be 30-90min
            if duration < 30 {
                logger.info("Short triage block (\(Int(duration))m)")
            }
            
        case .break_:
            logger.info("Break completed (\(Int(duration))m)")
        }
    }
    
    private func saveAlert(_ alert: ProactiveAlert) {
        activeAlerts.append(alert)
        
        // Persist to database
        do {
            _ = try storageManager.saveProactiveAlert(alert)
        } catch {
            logger.error("Failed to save alert to database: \(error.localizedDescription)")
        }
    }
    
    private func cleanUpOldAlerts() {
        let dayAgo = Date().addingTimeInterval(-86400)
        activeAlerts = activeAlerts.filter { $0.createdAt > dayAgo }
    }
    
    private func loadAlertHistoryAsync() async {
        // Load active (non-dismissed) alerts from database asynchronously
        do {
            // Perform database read off main actor to avoid blocking UI
            let alerts = try await Task.detached(priority: .userInitiated) {
                try StorageManager.shared.fetchActiveAlerts()
            }.value
            
            // Update published property on main actor
            await MainActor.run {
                self.activeAlerts = alerts
                self.logger.info("Loaded \(alerts.count) active alerts from database")
            }
        } catch {
            logger.error("Failed to load alert history: \(error.localizedDescription)")
            activeAlerts = []
        }
    }
}

