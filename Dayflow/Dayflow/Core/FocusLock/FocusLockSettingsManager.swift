//
//  FocusLockSettingsManager.swift
//  FocusLock
//
//  Settings management for FocusLock functionality
//

import Foundation
import Combine

@MainActor
class FocusLockSettingsManager: ObservableObject {
    static let shared = FocusLockSettingsManager()

    // MARK: - Published Properties
    @Published var isAutostartEnabled: Bool = false
    @Published var emergencyBreakDuration: TimeInterval = 20.0
    @Published var enableBackgroundMonitoring: Bool = true
    @Published var enableTaskDetection: Bool = true
    @Published var enableNotifications: Bool = true

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let autostartEnabled = "FocusLockAutostartEnabled"
        static let emergencyBreakDuration = "FocusLockEmergencyBreakDuration"
        static let backgroundMonitoringEnabled = "FocusLockBackgroundMonitoringEnabled"
        static let taskDetectionEnabled = "FocusLockTaskDetectionEnabled"
        static let notificationsEnabled = "FocusLockNotificationsEnabled"
    }

    private init() {
        loadSettings()
    }

    // MARK: - Settings Management

    func loadSettings() {
        isAutostartEnabled = userDefaults.bool(forKey: Keys.autostartEnabled)
        emergencyBreakDuration = userDefaults.double(forKey: Keys.emergencyBreakDuration)
        if emergencyBreakDuration == 0 {
            emergencyBreakDuration = 20.0 // Default value
        }
        enableBackgroundMonitoring = userDefaults.bool(forKey: Keys.backgroundMonitoringEnabled)
        enableTaskDetection = userDefaults.bool(forKey: Keys.taskDetectionEnabled)
        enableNotifications = userDefaults.bool(forKey: Keys.notificationsEnabled)

        // Enable features by default if not set
        if !userDefaults.bool(forKey: Keys.backgroundMonitoringEnabled) {
            enableBackgroundMonitoring = true
            saveSettings()
        }
    }

    func saveSettings() {
        userDefaults.set(isAutostartEnabled, forKey: Keys.autostartEnabled)
        userDefaults.set(emergencyBreakDuration, forKey: Keys.emergencyBreakDuration)
        userDefaults.set(enableBackgroundMonitoring, forKey: Keys.backgroundMonitoringEnabled)
        userDefaults.set(enableTaskDetection, forKey: Keys.taskDetectionEnabled)
        userDefaults.set(enableNotifications, forKey: Keys.notificationsEnabled)
    }

    // MARK: - Autostart Management

    func toggleAutostart() -> Bool {
        let launchAgentManager = LaunchAgentManager.shared

        if isAutostartEnabled {
            // Disable autostart
            let success = launchAgentManager.uninstallLaunchAgent()
            if success {
                isAutostartEnabled = false
                saveSettings()
            }
            return success
        } else {
            // Enable autostart
            let success = launchAgentManager.installLaunchAgent()
            if success {
                isAutostartEnabled = true
                saveSettings()
            }
            return success
        }
    }

    func refreshAutostartStatus() {
        LaunchAgentManager.shared.checkAgentStatus()
        isAutostartEnabled = LaunchAgentManager.shared.isEnabled
    }

    // MARK: - Convenience Properties

    var emergencyBreakDurationFormatted: String {
        let minutes = Int(emergencyBreakDuration) / 60
        let seconds = Int(emergencyBreakDuration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var autostartStatusDescription: String {
        let launchAgentManager = LaunchAgentManager.shared
        if launchAgentManager.isInstalled && launchAgentManager.isEnabled {
            return "Enabled and active"
        } else {
            return "Disabled"
        }
    }
}

// MARK: - Settings Validation

extension FocusLockSettingsManager {
    func validateSettings() -> [String] {
        var issues: [String] = []

        // Validate emergency break duration
        if emergencyBreakDuration < 5.0 || emergencyBreakDuration > 300.0 {
            issues.append("Emergency break duration should be between 5 seconds and 5 minutes")
        }

        return issues
    }

    func resetToDefaults() {
        isAutostartEnabled = false
        emergencyBreakDuration = 20.0
        enableBackgroundMonitoring = true
        enableTaskDetection = true
        enableNotifications = true
        saveSettings()

        // Uninstall LaunchAgent if it was installed
        if LaunchAgentManager.shared.isInstalled {
            _ = LaunchAgentManager.shared.uninstallLaunchAgent()
        }
    }
}