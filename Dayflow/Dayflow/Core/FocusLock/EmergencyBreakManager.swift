//
//  EmergencyBreakManager.swift
//  FocusLock
//
//  Manages emergency break functionality with countdown notifications
//

import Foundation
import SwiftUI
import Combine
import UserNotifications
import os.log

@MainActor
class EmergencyBreakManager: ObservableObject {
    static let shared = EmergencyBreakManager()

    private let logger = Logger(subsystem: "FocusLock", category: "EmergencyBreak")
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Published state
    @Published var isActive: Bool = false
    @Published var timeRemaining: TimeInterval = 0.0
    @Published var totalDuration: TimeInterval = 0.0
    @Published var breakCount: Int = 0

    // Timer
    private var countdownTimer: Timer?
    private var warningTimer: Timer?

    // Emergency break tracking
    var currentBreak: EmergencyBreak?
    private var breaksTakenInSession: Int = 0

    init() {
        setupObservation()
    }

    // MARK: - Public Interface

    func startEmergencyBreak(session: FocusSession) {
        guard !isActive else {
            logger.warning("Emergency break already active")
            return
        }

        let emergencyBreak = EmergencyBreak(reason: .userRequested)
        currentBreak = emergencyBreak
        // Note: SessionManager will handle adding this break to the session

        totalDuration = settingsManager.currentSettings.emergencyBreakDuration
        timeRemaining = totalDuration
        isActive = true
        breaksTakenInSession += 1
        breakCount = breaksTakenInSession

        logger.info("Emergency break started for \(self.totalDuration) seconds")

        // Send initial notification
        sendNotification(
            title: "Emergency Break Started",
            body: "You have \(Int(totalDuration)) seconds. Focus will resume automatically."
        )

        // Start countdown
        startCountdown()
        startWarningNotifications()

        // Log event
        if settingsManager.currentSettings.logSessions {
            SessionLogger.shared.logSessionEvent(.emergencyBreakStarted, session: session)
        }
    }

    func endEmergencyBreak(session: FocusSession) {
        guard isActive, let currentBreak = currentBreak else {
            logger.warning("No active emergency break to end")
            return
        }

        // End the break
        // Note: SessionManager will handle updating the session break endTime

        stopAllTimers()
        isActive = false
        timeRemaining = 0.0
        self.currentBreak = nil

        logger.info("Emergency break ended after \(self.totalDuration - self.timeRemaining) seconds")

        // Send completion notification
        sendNotification(
            title: "Emergency Break Ended",
            body: "Focus session resumed. Stay on task!"
        )

        // Log event
        if settingsManager.currentSettings.logSessions {
            SessionLogger.shared.logSessionEvent(.emergencyBreakEnded, session: session)
        }
    }

    func forceEndEmergencyBreak(session: FocusSession) {
        if isActive {
            logger.info("Force ending emergency break")
            endEmergencyBreak(session: session)
        }
    }

    // MARK: - Private Methods

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1.0
            } else {
                self.breakExpired()
            }
        }
    }

    private func startWarningNotifications() {
        let warningIntervals = [10.0, 5.0, 3.0, 1.0]

        for interval in warningIntervals {
            guard interval < totalDuration else { continue }

            let delay = totalDuration - interval
            warningTimer?.invalidate()
            warningTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                if self.isActive {
                    self.sendNotification(
                        title: "Emergency Break Warning",
                        body: "Returning to focus in \(Int(interval)) seconds"
                    )
                }
            }
        }
    }

    private func breakExpired() {
        // This will be handled by the SessionManager when it detects timeRemaining == 0
        logger.info("Emergency break timer expired")
    }

    private func stopAllTimers() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        warningTimer?.invalidate()
        warningTimer = nil
    }

    private func setupObservation() {
        // Observe settings changes
        settingsManager.$settings
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }

    private func handleSettingsChange() {
        // Update duration if settings change during an active break
        if isActive {
            let newDuration = settingsManager.currentSettings.emergencyBreakDuration
            if newDuration != totalDuration {
                totalDuration = newDuration
                logger.info("Emergency break duration updated to \(newDuration) seconds")
            }
        }
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        guard settingsManager.currentSettings.enableNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Add urgency for break notifications
        if title.contains("Warning") {
            content.categoryIdentifier = "URGENT_ALERT"
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to send notification: \(error)")
            }
        }
    }

    // MARK: - Reset for New Session

    func resetForNewSession() {
        stopAllTimers()
        isActive = false
        timeRemaining = 0.0
        totalDuration = 0.0
        currentBreak = nil
        breaksTakenInSession = 0
        breakCount = 0

        logger.info("Emergency break manager reset for new session")
    }

    // MARK: - Analytics

    func getBreakStatistics() -> EmergencyBreakStats {
        return EmergencyBreakStats(
            totalBreaks: breakCount,
            averageBreakDuration: totalDuration,
            isCurrentlyActive: isActive
        )
    }
}

// MARK: - Supporting Types

struct EmergencyBreakStats {
    let totalBreaks: Int
    let averageBreakDuration: TimeInterval
    let isCurrentlyActive: Bool

    var averageDurationFormatted: String {
        let duration = Int(averageBreakDuration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%dm %ds", minutes, seconds)
    }
}

// MARK: - Extensions

extension EmergencyBreakManager {
    var timeRemainingFormatted: String {
        let seconds = Int(timeRemaining)
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return String(format: "%dm %ds", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    var totalDurationFormatted: String {
        let seconds = Int(totalDuration)
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return String(format: "%dm %ds", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0.0 }
        return (totalDuration - timeRemaining) / totalDuration
    }
}