//
//  FocusSessionManager.swift
//  FocusLock
//
//  LEGACY SESSION MANAGER - Deprecated
//
//  ⚠️ DEPRECATION NOTICE:
//  This is a legacy session manager that uses simplified LegacyFocusSession models.
//  It provides lightweight Anchor/Triage/Break tracking for the FocusSessionWidget.
//
//  CURRENT USAGE:
//  - FocusSessionWidget (dashboard widget)
//  - SmartTodoView (minimal reference)
//
//  MODERN ALTERNATIVE:
//  Use SessionManager for full-featured sessions with:
//  - App blocking via LockController
//  - Emergency break support
//  - Performance monitoring
//  - Resource tracking
//  - Full FocusSession model with persistence
//
//  POST-BETA MIGRATION PLAN:
//  1. Migrate FocusSessionWidget to use SessionManager
//  2. Add Anchor/Triage/Break modes to SessionManager if needed
//  3. Remove this file and LegacyFocusSession model
//  4. Consolidate all session management under SessionManager
//
//  For now, this manager provides simple session tracking without the overhead
//  of full blocking enforcement. It uses UserDefaults for persistence (temporary).
//

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class FocusSessionManager: ObservableObject {
    static let shared = FocusSessionManager()
    
    // MARK: - Published Properties
    @Published var currentSession: LegacyFocusSession?
    @Published var isInSession = false
    @Published var sessionProgress: Double = 0.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var remainingTime: TimeInterval = 0
    
    // MARK: - Dependencies
    private let proactiveEngine = ProactiveCoachEngine.shared
    private let logger = Logger(subsystem: "FocusLock", category: "FocusSessionManager")
    
    // MARK: - Session State
    private var sessionTimer: Timer?
    private var progressTimer: Timer?
    private var sessionHistory: [LegacyFocusSession] = []
    
    // MARK: - Configuration
    private let anchorMinDuration: TimeInterval = 3600 // 60 minutes
    private let anchorMaxDuration: TimeInterval = 7200 // 120 minutes
    private let triageMinDuration: TimeInterval = 1800 // 30 minutes
    private let triageMaxDuration: TimeInterval = 5400 // 90 minutes
    private let breakDuration: TimeInterval = 900 // 15 minutes
    
    private init() {
        loadSessionHistory()
    }
    
    // MARK: - Public Interface
    
    /// Start an Anchor Block (60-120min deep work on single task)
    func startAnchorBlock(taskId: UUID?, duration: TimeInterval = 3600) {
        guard !isInSession else {
            logger.warning("Cannot start Anchor Block - session already in progress")
            return
        }
        
        let session = LegacyFocusSession(
            mode: .anchor,
            taskId: taskId,
            startTime: Date()
        )
        
        currentSession = session
        isInSession = true
        remainingTime = duration
        
        // Notify proactive engine
        proactiveEngine.startLegacyFocusSession(mode: .anchor, taskId: taskId)
        
        // Start timers
        startProgressTracking(duration: duration)
        
        logger.info("🎯 Started Anchor Block (\(Int(duration/60))min)")
    }
    
    /// Start a Triage Block (30-90min batched small tasks)
    func startTriageBlock(duration: TimeInterval = 1800) {
        guard !isInSession else {
            logger.warning("Cannot start Triage Block - session already in progress")
            return
        }
        
        let session = LegacyFocusSession(
            mode: .triage,
            taskId: nil,
            startTime: Date()
        )
        
        currentSession = session
        isInSession = true
        remainingTime = duration
        
        proactiveEngine.startLegacyFocusSession(mode: .triage)
        startProgressTracking(duration: duration)
        
        logger.info("📋 Started Triage Block (\(Int(duration/60))min)")
    }
    
    /// Start a Break
    func startBreak(duration: TimeInterval = 900) {
        guard !isInSession else {
            logger.warning("Cannot start break - session already in progress")
            return
        }
        
        let session = LegacyFocusSession(
            mode: .break_,
            taskId: nil,
            startTime: Date()
        )
        
        currentSession = session
        isInSession = true
        remainingTime = duration
        
        proactiveEngine.startLegacyFocusSession(mode: .break_)
        startProgressTracking(duration: duration)
        
        logger.info("☕️ Started Break (\(Int(duration/60))min)")
    }
    
    /// End current session
    func endSession() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        
        // Stop timers
        stopProgressTracking()
        
        // Record in history
        sessionHistory.append(session)

        // Keep only last 100 sessions
        if sessionHistory.count > 100 {
            sessionHistory = Array(sessionHistory.suffix(100))
        }

        // Save to persistent storage
        saveSessionHistory()

        // Notify proactive engine
        proactiveEngine.endLegacyFocusSession()
        
        // Log session quality
        logSessionQuality(session)
        
        // Reset state
        currentSession = nil
        isInSession = false
        sessionProgress = 0.0
        elapsedTime = 0
        remainingTime = 0
        
        logger.info("Session ended: \(session.mode.displayName) (\(Int(session.actualDuration/60))min)")
    }
    
    /// Pause current session
    func pauseSession() {
        guard isInSession else { return }
        stopProgressTracking()
        logger.info("Session paused")
    }
    
    /// Resume paused session
    func resumeSession() {
        guard let session = currentSession, !isInSession else { return }
        
        isInSession = true
        let elapsed = Date().timeIntervalSince(session.startTime)
        
        // Calculate remaining time based on mode
        let plannedDuration: TimeInterval
        switch session.mode {
        case .anchor:
            plannedDuration = anchorMinDuration
        case .triage:
            plannedDuration = triageMinDuration
        case .break_:
            plannedDuration = breakDuration
        }
        
        remainingTime = max(0, plannedDuration - elapsed)
        startProgressTracking(duration: plannedDuration)
        
        logger.info("Session resumed")
    }
    
    /// Record an interruption in the current session
    func recordInterruption(reason: String? = nil) {
        guard var session = currentSession else { return }
        
        session.interruptionCount += 1
        currentSession = session
        
        logger.warning("⚠️ Interruption recorded (\(session.interruptionCount) total)")
        
        // Anchor blocks should have zero interruptions
        if session.mode == .anchor && session.interruptionCount > 0 {
            // Proactive engine will generate an alert
            logger.warning("Anchor Block integrity compromised")
        }
    }
    
    /// Get session statistics for today
    func getTodayStats() -> SessionStats {
        let today = Calendar.current.startOfDay(for: Date())
        let todaySessions = sessionHistory.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: today)
        }
        
        let anchorMinutes = todaySessions
            .filter { $0.mode == .anchor }
            .reduce(0) { $0 + Int($1.actualDuration / 60) }
        
        let triageMinutes = todaySessions
            .filter { $0.mode == .triage }
            .reduce(0) { $0 + Int($1.actualDuration / 60) }
        
        let breakMinutes = todaySessions
            .filter { $0.mode == .break_ }
            .reduce(0) { $0 + Int($1.actualDuration / 60) }
        
        let totalInterruptions = todaySessions.reduce(0) { $0 + $1.interruptionCount }
        
        let averageFocusQuality = calculateAverageFocusQuality(sessions: todaySessions)
        
        return SessionStats(
            anchorMinutes: anchorMinutes,
            triageMinutes: triageMinutes,
            breakMinutes: breakMinutes,
            totalInterruptions: totalInterruptions,
            focusQuality: averageFocusQuality,
            sessionsCount: todaySessions.count
        )
    }
    
    /// Get recommended next session based on patterns
    func getRecommendedNextSession(energyLevel: Double, p0TaskCount: Int) -> FocusMode {
        let stats = getTodayStats()
        
        // If high energy and P0s pending → Anchor
        if energyLevel >= 7 && p0TaskCount > 0 && stats.anchorMinutes < 120 {
            return .anchor
        }
        
        // If low energy → Break or Triage
        if energyLevel < 5 {
            return stats.breakMinutes < 60 ? .break_ : .triage
        }
        
        // If already did lots of anchor → Triage
        if stats.anchorMinutes > 180 {
            return .triage
        }
        
        // If many interruptions → Take a break
        if stats.totalInterruptions > 5 {
            return .break_
        }
        
        // Default to Anchor if energy permits
        return energyLevel >= 6 ? .anchor : .triage
    }
    
    // MARK: - Private Methods
    
    private func startProgressTracking(duration: TimeInterval) {
        // Update progress every second
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.currentSession else { return }
            
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(session.startTime)
                self.elapsedTime = elapsed
                self.remainingTime = max(0, duration - elapsed)
                self.sessionProgress = min(1.0, elapsed / duration)
                
                // Auto-end when time is up
                if self.remainingTime <= 0 {
                    self.endSession()
                }
            }
        }
    }
    
    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func logSessionQuality(_ session: LegacyFocusSession) {
        let duration = session.actualDuration / 60 // in minutes
        let interruptions = session.interruptionCount
        
        var quality = "Good"
        if interruptions == 0 && duration >= (session.mode == .anchor ? 60 : 30) {
            quality = "Excellent"
        } else if interruptions > 3 || duration < 15 {
            quality = "Poor"
        }
        
        logger.info("Session quality: \(quality) (\(Int(duration))min, \(interruptions) interruptions)")
    }
    
    private func calculateAverageFocusQuality(sessions: [LegacyFocusSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        
        let scores = sessions.map { session -> Double in
            var score = 1.0
            
            // Penalty for interruptions
            score -= Double(session.interruptionCount) * 0.2
            
            // Penalty for short sessions
            let minDuration = session.mode == .anchor ? 60.0 : 30.0
            if session.actualDuration / 60 < minDuration {
                score -= 0.3
            }
            
            return max(0, score)
        }
        
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func loadSessionHistory() {
        // Load from UserDefaults
        // Note: This uses UserDefaults as a temporary solution until SessionManager reconciliation
        if let data = UserDefaults.standard.data(forKey: "focus_session_history"),
           let decoded = try? JSONDecoder().decode([LegacyFocusSession].self, from: data) {
            sessionHistory = decoded
            logger.info("Loaded \(sessionHistory.count) sessions from history")
        } else {
            sessionHistory = []
            logger.info("No session history found, starting fresh")
        }
    }

    private func saveSessionHistory() {
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(encoded, forKey: "focus_session_history")
            logger.debug("Saved \(sessionHistory.count) sessions to history")
        } else {
            logger.error("Failed to encode session history")
        }
    }
}

// MARK: - Supporting Types

struct SessionStats {
    let anchorMinutes: Int
    let triageMinutes: Int
    let breakMinutes: Int
    let totalInterruptions: Int
    let focusQuality: Double
    let sessionsCount: Int
    
    var totalFocusMinutes: Int {
        anchorMinutes + triageMinutes
    }
    
    var deepWorkPercentage: Double {
        let total = totalFocusMinutes
        guard total > 0 else { return 0 }
        return Double(anchorMinutes) / Double(total)
    }
}

