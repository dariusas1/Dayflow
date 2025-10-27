//
//  SessionManager.swift
//  FocusLock
//
//  Manages focus session lifecycle and state
//

import Foundation
import SwiftUI
import Combine
import UserNotifications
import os.log

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    // MARK: - Published Properties
    @Published var currentSession: FocusSession?
    @Published var currentState: FocusSessionState = .idle
    @Published var lastSessionSummary: SessionSummary?
    @Published var emergencyBreakTimeRemaining: TimeInterval = 0.0
    @Published var isEmergencyBreakActive: Bool = false

    // Performance monitoring properties
    @Published var currentPerformanceMetrics: SessionPerformanceMetrics?
    @Published var sessionHealthScore: Double = 1.0
    @Published var resourceUsage: ResourceUsage?

    // MARK: - Private Properties
    private var sessionTimer: Timer?
    private let settingsManager = SettingsManager.shared
    private let lockController = LockController.shared
    private let emergencyBreakManager = EmergencyBreakManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Performance monitoring
    private var performanceMonitor: PerformanceMonitor?
    private var resourceMonitor: ResourceMonitor?
    private var performanceMetricsTimer: Timer?
    private let logger = Logger(subsystem: "FocusLock", category: "SessionManager")

    // MARK: - Computed Properties
    var isActive: Bool {
        return currentState.isActive
    }

    var sessionDurationFormatted: String {
        guard let session = currentSession else { return "0m 0s" }
        return session.durationFormatted
    }

    var canStartSession: Bool {
        return currentState.canStart
    }

    var canEndSession: Bool {
        return currentState.canEnd
    }

    // MARK: - Initialization
    private init() {
        setupObservers()
        setupEmergencyBreakObservation()
        setupPerformanceMonitoring()
        loadLastSessionSummary()
    }

    // MARK: - Session Management
    func startSession(taskName: String, allowedApps: [String]? = nil) {
        guard canStartSession else {
            print("[SessionManager] Cannot start session in current state: \(currentState)")
            return
        }

        print("[SessionManager] Starting focus session for task: \(taskName)")

        // Reset emergency break manager for new session
        emergencyBreakManager.resetForNewSession()

        let apps = allowedApps ?? settingsManager.currentSettings.globalAllowedApps
        let session = FocusSession(taskName: taskName, allowedApps: apps)

        currentSession = session
        currentState = .arming

        // Start performance monitoring
        startPerformanceMonitoring(for: session)

        // Apply app blocking after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.applyAppBlocking(for: session)
            self.currentState = .active
            self.startSessionTimer()
        }

        // Log session start
        if settingsManager.currentSettings.logSessions {
            SessionLogger.shared.logSessionEvent(.sessionStarted, session: session)
        }

        sendNotification(title: "Focus Session Started", body: "Focusing on: \(taskName)")
    }

    func endSession() {
        guard let session = currentSession, canEndSession else {
            print("[SessionManager] Cannot end session in current state: \(currentState)")
            return
        }

        print("[SessionManager] Ending focus session")

        // Stop timers
        sessionTimer?.invalidate()
        sessionTimer = nil
      // End the emergency break
        if let currentBreak = emergencyBreakManager.currentBreak {
            if var updatedSession = currentSession {
                if let index = updatedSession.emergencyBreaks.firstIndex(where: { $0.id == currentBreak.id }) {
                    updatedSession.emergencyBreaks[index].endTime = Date()
                    currentSession = updatedSession
                }
            }
        }
        emergencyBreakManager.forceEndEmergencyBreak(session: session)

        // Finalize performance monitoring
        finalizePerformanceMonitoring()

        // Update session
        if var session = currentSession {
            session.endTime = Date()
            session.state = .ended
            currentSession = session
        }
        currentState = .ended

        // Remove app blocking
        lockController.removeBlocking()

        // Create summary
        let summary = SessionSummary(session: session)
        lastSessionSummary = summary

        // Save session data
        if settingsManager.currentSettings.logSessions {
            SessionLogger.shared.saveSession(session)
            SessionLogger.shared.logSessionEvent(.sessionEnded, session: session)
        }

        sendNotification(title: "Focus Session Completed", body: "Duration: \(summary.durationFormatted)")

        // Clear current session
        currentSession = nil
        currentState = .idle
    }

    func requestEmergencyBreak() {
        guard let session = currentSession, currentState == .active else {
            print("[SessionManager] Cannot request emergency break in current state: \(currentState)")
            return
        }

        print("[SessionManager] Starting emergency break")

        // Temporarily remove blocking for emergency break
        lockController.removeBlocking()
        currentState = .break

        // Add the break to session before starting manager
        let emergencyBreak = EmergencyBreak(reason: .userRequested)
        var updatedSession = session
        updatedSession.emergencyBreaks.append(emergencyBreak)
        currentSession = updatedSession

        // Use EmergencyBreakManager
        emergencyBreakManager.startEmergencyBreak(session: updatedSession)
    }

    private func endEmergencyBreak() {
        guard let session = currentSession else { return }

        print("[SessionManager] Ending emergency break")

        // Re-apply blocking
        currentState = .active
        applyAppBlocking(for: session)
    }

    // MARK: - Private Methods
    private func applyAppBlocking(for session: FocusSession) {
        // Create app policy based on session settings
        let appPolicy = AppPolicy(
            bundleID: "com.focuslock.session",
            appName: "Focus Session",
            isAllowed: false,
            taskSpecificRules: [:]
        )

        // Allow specified apps and block everything else
        let allowedBundleIDs = Set(session.allowedApps)
        let blockedApps = Array(allowedBundleIDs) // Will be filtered in LockController

        lockController.applyBlocking(allowedApps: Array(allowedBundleIDs))

        if settingsManager.currentSettings.logSessions {
            SessionLogger.shared.logSessionEvent(.appBlockingApplied, session: session)
        }
    }

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.objectWillChange.send()
        }
    }

    private func setupObservers() {
        // Observe settings changes
        settingsManager.$settings
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }

    private func setupEmergencyBreakObservation() {
        // Observe EmergencyBreakManager state
        emergencyBreakManager.$isActive
            .sink { [weak self] isActive in
                self?.isEmergencyBreakActive = isActive
            }
            .store(in: &cancellables)

        emergencyBreakManager.$timeRemaining
            .sink { [weak self] timeRemaining in
                self?.emergencyBreakTimeRemaining = timeRemaining
            }
            .store(in: &cancellables)

        // Monitor when break ends naturally to resume focus
        emergencyBreakManager.$isActive
            .sink { [weak self] isActive in
                guard let self = self, let session = self.currentSession else { return }

                // When break ends, if we're still in break state, resume focus
                if !isActive && self.currentState == .break {
                    DispatchQueue.main.async {
                        self.endEmergencyBreak()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handleSettingsChange() {
        // React to settings changes if needed
        // For example, update notification preferences
    }

    private func loadLastSessionSummary() {
        lastSessionSummary = SessionLogger.shared.getLastSessionSummary()
    }

    // MARK: - Performance Monitoring

    private func setupPerformanceMonitoring() {
        // Initialize performance monitors
        performanceMonitor = PerformanceMonitor()
        resourceMonitor = ResourceMonitor()
    }

    private func startPerformanceMonitoring(for session: FocusSession) {
        guard let monitor = performanceMonitor, let resourceMon = resourceMonitor else { return }

        // Start monitoring
        monitor.startMonitoring(session: session)
        resourceMon.startMonitoring()

        // Start periodic metrics collection
        performanceMetricsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }

        logger.info("Started performance monitoring for session: \(session.taskName)")
    }

    private func updatePerformanceMetrics() {
        guard let session = currentSession else { return }

        // Collect current metrics
        let resourceUsage = resourceMonitor?.getCurrentUsage()
        let performanceData = performanceMonitor?.getCurrentMetrics()

        // Update published properties
        self.resourceUsage = resourceUsage

        if let perfData = performanceData {
            let metrics = SessionPerformanceMetrics(
                sessionID: session.id,
                cpuUsage: perfData.cpuUsage,
                memoryUsage: perfData.memoryUsage,
                taskDetectionLatency: perfData.taskDetectionLatency,
                blockingEfficiency: perfData.blockingEfficiency,
                timestamp: Date()
            )
            self.currentPerformanceMetrics = metrics

            // Calculate health score
            calculateSessionHealthScore(metrics: metrics)
        }
    }

    private func calculateSessionHealthScore(metrics: SessionPerformanceMetrics) {
        // Health score based on multiple factors
        var score: Double = 1.0

        // CPU usage (lower is better)
        if metrics.cpuUsage > 0.8 {
            score *= 0.7
        } else if metrics.cpuUsage > 0.5 {
            score *= 0.85
        }

        // Memory usage (lower is better)
        if metrics.memoryUsage > 0.8 {
            score *= 0.7
        } else if metrics.memoryUsage > 0.6 {
            score *= 0.85
        }

        // Task detection latency (lower is better)
        if metrics.taskDetectionLatency > 3.0 {
            score *= 0.8
        } else if metrics.taskDetectionLatency > 1.5 {
            score *= 0.9
        }

        // Blocking efficiency (higher is better)
        if metrics.blockingEfficiency < 0.7 {
            score *= 0.8
        }

        sessionHealthScore = max(score, 0.0)
    }

    private func finalizePerformanceMonitoring() {
        // Stop timers
        performanceMetricsTimer?.invalidate()
        performanceMetricsTimer = nil

        // Finalize monitoring
        performanceMonitor?.finalizeMonitoring()
        resourceMonitor?.stopMonitoring()

        logger.info("Finalized performance monitoring")
    }

    // MARK: - Notifications
    private func sendNotification(title: String, body: String) {
        guard settingsManager.currentSettings.enableNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SessionManager] Failed to send notification: \(error)")
            }
        }
    }
}

// MARK: - Session Event Types
enum SessionEventType: String {
    case sessionStarted = "session_started"
    case sessionEnded = "session_ended"
    case emergencyBreakStarted = "emergency_break_started"
    case emergencyBreakEnded = "emergency_break_ended"
    case appBlockingApplied = "app_blocking_applied"
    case appBlockingRemoved = "app_blocking_removed"
    case interruptionDetected = "interruption_detected"
}

// MARK: - Performance Monitoring Data Models

struct SessionPerformanceMetrics {
    let sessionID: UUID
    let cpuUsage: Double
    let memoryUsage: Double
    let taskDetectionLatency: TimeInterval
    let blockingEfficiency: Double
    let timestamp: Date

    var isHealthy: Bool {
        return cpuUsage < 0.8 && memoryUsage < 0.8 && taskDetectionLatency < 3.0 && blockingEfficiency > 0.7
    }

    var summary: String {
        var issues: [String] = []
        if cpuUsage > 0.8 { issues.append("High CPU usage: \(Int(cpuUsage * 100))%") }
        if memoryUsage > 0.8 { issues.append("High memory usage: \(Int(memoryUsage * 100))%") }
        if taskDetectionLatency > 3.0 { issues.append("High detection latency: \(String(format: "%.1f", taskDetectionLatency))s") }
        if blockingEfficiency < 0.7 { issues.append("Low blocking efficiency: \(Int(blockingEfficiency * 100))%") }

        return issues.isEmpty ? "All systems healthy" : "\(issues.count) issues detected"
    }
}

struct ResourceUsage {
    let timestamp: Date
    let cpuPercent: Double
    let memoryMB: Double
    let diskUsageMB: Double
    let networkActivity: NetworkActivity

    var isOptimal: Bool {
        return cpuPercent < 50 && memoryMB < 200 && diskUsageMB < 100 && networkActivity.totalBytesPerSecond < 1024 * 1024 // 1MB/s
    }
}

struct NetworkActivity {
    let incomingBytesPerSecond: Double
    let outgoingBytesPerSecond: Double
    let totalBytesPerSecond: Double
}

// MARK: - Performance Monitoring Classes

class PerformanceMonitor {
    private var session: FocusSession?
    private var startTime: Date?
    private var detectionLatencies: [TimeInterval] = []
    private var blockingEvents: [Date] = []
    private let logger = Logger(subsystem: "FocusLock", category: "PerformanceMonitor")

    func startMonitoring(session: FocusSession) {
        self.session = session
        self.startTime = Date()
        logger.info("Started performance monitoring for session: \(session.taskName)")
    }

    func getCurrentMetrics() -> (cpuUsage: Double, memoryUsage: Double, taskDetectionLatency: TimeInterval, blockingEfficiency: Double) {
        // Mock implementation - in real app, would measure actual metrics
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()
        let avgLatency = detectionLatencies.isEmpty ? 0.5 : detectionLatencies.reduce(0, +) / Double(detectionLatencies.count)
        let blockingEfficiency = calculateBlockingEfficiency()

        return (cpuUsage, memoryUsage, avgLatency, blockingEfficiency)
    }

    func recordDetectionLatency(_ latency: TimeInterval) {
        detectionLatencies.append(latency)
        // Keep only last 20 measurements
        if detectionLatencies.count > 20 {
            detectionLatencies.removeFirst(detectionLatencies.count - 20)
        }
    }

    func recordBlockingEvent() {
        blockingEvents.append(Date())
        // Keep only last 50 events
        if blockingEvents.count > 50 {
            blockingEvents.removeFirst(blockingEvents.count - 50)
        }
    }

    func finalizeMonitoring() {
        session = nil
        startTime = nil
        detectionLatencies.removeAll()
        blockingEvents.removeAll()
        logger.info("Finalized performance monitoring")
    }

    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(0)
        let result = task_info(mach_task_self_, MACH_TASK_BASIC_INFO, &info, &count)

        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }

        return 0.0
    }

    private func getCurrentMemoryUsage() -> Double {
        // Simplified memory usage calculation
        return Double(arc4random_uniform(UInt32.max)) * 0.3 + 0.1 // 10-40% mock
    }

    private func calculateBlockingEfficiency() -> Double {
        guard let session = session else { return 0.0 }
        let expectedBlocks = Double(session.allowedApps.count) * 10 // Assume 10 blocks per minute per app
        let actualBlocks = Double(blockingEvents.count)
        let duration = session.duration

        if duration > 0 {
            let blocksPerMinute = actualBlocks / (duration / 60.0)
            return min(blocksPerMinute / expectedBlocks, 1.0)
        }

        return 1.0
    }
}

class ResourceMonitor {
    private var isMonitoring = false
    private let logger = Logger(subsystem: "FocusLock", category: "ResourceMonitor")

    func startMonitoring() {
        isMonitoring = true
        logger.debug("Started resource monitoring")
    }

    func stopMonitoring() {
        isMonitoring = false
        logger.debug("Stopped resource monitoring")
    }

    func getCurrentUsage() -> ResourceUsage {
        let timestamp = Date()
        let cpuPercent = getCurrentCPUUsage()
        let memoryMB = getCurrentMemoryMB()
        let diskUsageMB = getCurrentDiskUsageMB()
        let networkActivity = getCurrentNetworkActivity()

        return ResourceUsage(
            timestamp: timestamp,
            cpuPercent: cpuPercent,
            memoryMB: memoryMB,
            diskUsageMB: diskUsageMB,
            networkActivity: networkActivity
        )
    }

    private func getCurrentCPUUsage() -> Double {
        // Mock implementation
        return Double(arc4random_uniform(UInt32.max)) * 0.6 + 0.1 // 10-70% mock
    }

    private func getCurrentMemoryMB() -> Double {
        // Mock implementation
        return Double(arc4random_uniform(UInt32.max)) * 150 + 50 // 50-200MB mock
    }

    private func getCurrentDiskUsageMB() -> Double {
        // Mock implementation
        return Double(arc4random_uniform(UInt32.max)) * 50 + 10 // 10-60MB mock
    }

    private func getCurrentNetworkActivity() -> NetworkActivity {
        // Mock implementation
        return NetworkActivity(
            incomingBytesPerSecond: Double(arc4random_uniform(UInt32.max)) * 1000,
            outgoingBytesPerSecond: Double(arc4random_uniform(UInt32.max)) * 500,
            totalBytesPerSecond: Double(arc4random_uniform(UInt32.max)) * 1500
        )
    }
}