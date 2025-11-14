//
//  RecordingStatusPersistence.swift
//  Dayflow
//
//  Created for Story 2.3: Real-Time Recording Status
//

import Foundation

/// Manages persistence of recording status across app restarts
/// Uses UserDefaults for lightweight state storage (transitional until Epic 1 DatabaseManager ready)
final class RecordingStatusPersistence {

    // MARK: - Singleton

    static let shared = RecordingStatusPersistence()

    private init() {}

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let recordingState = "com.dayflow.recording.state"
        static let displayCount = "com.dayflow.recording.displayCount"
        static let startTimestamp = "com.dayflow.recording.startTimestamp"
        static let lastErrorCode = "com.dayflow.recording.lastErrorCode"
    }

    // MARK: - Saved State Model

    struct SavedState: Codable {
        let stateDescription: String  // idle, recording, paused, etc.
        let displayCount: Int
        let startTimestamp: Date?
        let lastErrorCode: String?

        var isValid: Bool {
            // State is valid if it was saved recently (within 24 hours)
            // This prevents resuming stale recording states after app crashes
            guard let start = startTimestamp else {
                return stateDescription == "idle"
            }

            let elapsed = Date().timeIntervalSince(start)
            return elapsed < 24 * 60 * 60 // 24 hours
        }
    }

    // MARK: - Save State

    func saveState(_ state: RecordingState, startTime: Date? = nil) {
        let stateDesc: String
        var displayCount = 0

        switch state {
        case .idle:
            stateDesc = "idle"
        case .initializing:
            stateDesc = "initializing"
        case .recording(let count):
            stateDesc = "recording"
            displayCount = count
        case .paused:
            stateDesc = "paused"
        case .error(let error):
            stateDesc = "error"
            UserDefaults.standard.set(error.code.rawValue, forKey: Keys.lastErrorCode)
        case .stopping:
            stateDesc = "stopping"
        }

        let savedState = SavedState(
            stateDescription: stateDesc,
            displayCount: displayCount,
            startTimestamp: startTime,
            lastErrorCode: UserDefaults.standard.string(forKey: Keys.lastErrorCode)
        )

        if let encoded = try? JSONEncoder().encode(savedState) {
            UserDefaults.standard.set(encoded, forKey: Keys.recordingState)
        }
    }

    // MARK: - Restore State

    func restoreState() -> SavedState? {
        guard let data = UserDefaults.standard.data(forKey: Keys.recordingState),
              let savedState = try? JSONDecoder().decode(SavedState.self, from: data) else {
            return nil
        }

        // Validate that the state is still valid
        guard savedState.isValid else {
            // Clear invalid state
            clearState()
            return nil
        }

        return savedState
    }

    // MARK: - Clear State

    func clearState() {
        UserDefaults.standard.removeObject(forKey: Keys.recordingState)
        UserDefaults.standard.removeObject(forKey: Keys.displayCount)
        UserDefaults.standard.removeObject(forKey: Keys.startTimestamp)
        UserDefaults.standard.removeObject(forKey: Keys.lastErrorCode)
    }

    // MARK: - Recording Duration Calculation

    func calculateDuration(from startTime: Date?) -> TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Validate Restored State

    func validateRestoredState(_ savedState: SavedState) -> Bool {
        // Check if recording state is still valid
        // For example, verify displays are still connected
        switch savedState.stateDescription {
        case "recording", "paused":
            // In a full implementation, we would verify:
            // - Displays are still connected
            // - Permissions are still granted
            // - Storage is still available
            // For now, just check if it's recent
            return savedState.isValid

        case "idle", "stopping", "initializing":
            // These states are transient - don't restore
            return false

        case "error":
            // Don't restore error states
            return false

        default:
            return false
        }
    }
}

// MARK: - RecordingStatusViewModel Extension for Persistence

extension RecordingStatusViewModel {

    /// Save current state to persistent storage
    func saveCurrentState() {
        RecordingStatusPersistence.shared.saveState(
            currentState,
            startTime: recordingStartTime
        )
    }

    /// Restore state from persistent storage on app launch
    func restoreSavedState() {
        guard let savedState = RecordingStatusPersistence.shared.restoreState() else {
            return
        }

        // Validate state is still valid before restoring
        guard RecordingStatusPersistence.shared.validateRestoredState(savedState) else {
            RecordingStatusPersistence.shared.clearState()
            return
        }

        // Restore duration tracking if recording was active
        if savedState.stateDescription == "recording" || savedState.stateDescription == "paused" {
            if let startTime = savedState.startTimestamp {
                recordingStartTime = startTime
                recordingDuration = RecordingStatusPersistence.shared.calculateDuration(from: startTime)

                // Resume duration timer if recording
                if savedState.stateDescription == "recording" {
                    startDurationTracking()
                }
            }
        }
    }
}
