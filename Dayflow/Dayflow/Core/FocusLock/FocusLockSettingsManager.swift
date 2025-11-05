//
//  FocusLockSettingsManager.swift
//  FocusLock
//
//  Settings management for FocusLock functionality
//  Consolidated from SettingsManager and FocusLockSettingsManager
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FocusLockSettingsManager: ObservableObject {
    static let shared = FocusLockSettingsManager()

    // MARK: - Published Properties (struct-based)
    @Published var settings: FocusLockSettings = .default
    
    // MARK: - Legacy Published Properties (for backward compatibility)
    @Published var isAutostartEnabled: Bool = false
    @Published var emergencyBreakDuration: TimeInterval = 20.0
    @Published var enableBackgroundMonitoring: Bool = true
    @Published var enableTaskDetection: Bool = true
    @Published var enableNotifications: Bool = true

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "FocusLockSettings"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UserDefaults Keys (legacy, for migration)
    private enum Keys {
        static let autostartEnabled = "FocusLockAutostartEnabled"
        static let emergencyBreakDuration = "FocusLockEmergencyBreakDuration"
        static let backgroundMonitoringEnabled = "FocusLockBackgroundMonitoringEnabled"
        static let taskDetectionEnabled = "FocusLockTaskDetectionEnabled"
        static let notificationsEnabled = "FocusLockNotificationsEnabled"
    }

    private init() {
        loadSettings()
        setupAutoSave()
        syncPublishedProperties()
    }

    // MARK: - Settings Management

    func loadSettings() {
        // Try to load from new struct-based storage
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(FocusLockSettings.self, from: data) {
            settings = decoded
            migrateLegacySettingsIfNeeded()
        } else {
            // Try to load from legacy individual property storage
            loadLegacySettings()
            migrateToStructStorage()
        }
    }
    
    private func loadLegacySettings() {
        isAutostartEnabled = userDefaults.bool(forKey: Keys.autostartEnabled)
        emergencyBreakDuration = userDefaults.double(forKey: Keys.emergencyBreakDuration)
        if emergencyBreakDuration == 0 {
            emergencyBreakDuration = 20.0 // Default value
        }
        enableBackgroundMonitoring = userDefaults.bool(forKey: Keys.backgroundMonitoringEnabled)
        enableTaskDetection = userDefaults.bool(forKey: Keys.taskDetectionEnabled)
        enableNotifications = userDefaults.bool(forKey: Keys.notificationsEnabled)

        // Enable features by default if not set
        if !userDefaults.bool(forKey: Keys.backgroundMonitoringEnabled) && !userDefaults.bool(forKey: Keys.taskDetectionEnabled) && !userDefaults.bool(forKey: Keys.notificationsEnabled) {
            enableBackgroundMonitoring = true
            enableTaskDetection = true
            enableNotifications = true
        }
    }
    
    private func migrateToStructStorage() {
        // Create settings struct from legacy properties
        settings = FocusLockSettings(
            globalAllowedApps: settings.globalAllowedApps, // Keep existing if available
            emergencyBreakDuration: emergencyBreakDuration,
            minimumSessionDuration: settings.minimumSessionDuration,
            autoStartDetection: isAutostartEnabled,
            enableNotifications: enableNotifications,
            logSessions: settings.logSessions,
            enableBackgroundMonitoring: enableBackgroundMonitoring,
            enableTaskDetection: enableTaskDetection
        )
        saveSettings()
    }
    
    private func migrateLegacySettingsIfNeeded() {
        // Sync legacy properties from struct if they're different
        if isAutostartEnabled != settings.autoStartDetection {
            isAutostartEnabled = settings.autoStartDetection
        }
        if emergencyBreakDuration != settings.emergencyBreakDuration {
            emergencyBreakDuration = settings.emergencyBreakDuration
        }
        if enableBackgroundMonitoring != settings.enableBackgroundMonitoring {
            enableBackgroundMonitoring = settings.enableBackgroundMonitoring
        }
        if enableTaskDetection != settings.enableTaskDetection {
            enableTaskDetection = settings.enableTaskDetection
        }
        if enableNotifications != settings.enableNotifications {
            enableNotifications = settings.enableNotifications
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
        syncPublishedProperties()
    }
    
    private func setupAutoSave() {
        $settings
            .debounce(for: 1.0, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    private func syncPublishedProperties() {
        // Sync individual properties with struct
        isAutostartEnabled = settings.autoStartDetection
        emergencyBreakDuration = settings.emergencyBreakDuration
        enableBackgroundMonitoring = settings.enableBackgroundMonitoring
        enableTaskDetection = settings.enableTaskDetection
        enableNotifications = settings.enableNotifications
    }
    
    // MARK: - Convenience Properties (backward compatibility)
    
    var currentSettings: FocusLockSettings {
        return settings
    }

    // MARK: - Convenience Methods (backward compatibility with SettingsManager)
    
    func updateGlobalAllowedApps(_ apps: [String]) {
        settings.globalAllowedApps = apps
        saveSettings()
    }

    func updateEmergencyBreakDuration(_ duration: TimeInterval) {
        settings.emergencyBreakDuration = duration
        emergencyBreakDuration = duration
        saveSettings()
    }

    func enableAutoStartDetection(_ enabled: Bool) {
        settings.autoStartDetection = enabled
        isAutostartEnabled = enabled
        saveSettings()
    }

    func enableNotifications(_ enabled: Bool) {
        settings.enableNotifications = enabled
        saveSettings()
        syncPublishedProperties()
    }

    func enableSessionLogging(_ enabled: Bool) {
        settings.logSessions = enabled
        saveSettings()
    }
    
    func enableBackgroundMonitoring(_ enabled: Bool) {
        settings.enableBackgroundMonitoring = enabled
        saveSettings()
        syncPublishedProperties()
    }
    
    func enableTaskDetection(_ enabled: Bool) {
        settings.enableTaskDetection = enabled
        saveSettings()
        syncPublishedProperties()
    }

    // MARK: - Autostart Management

    func toggleAutostart() -> Bool {
        let launchAgentManager = LaunchAgentManager.shared

        if isAutostartEnabled {
            // Disable autostart
            let success = launchAgentManager.uninstallLaunchAgent()
            if success {
                isAutostartEnabled = false
                settings.autoStartDetection = false
                saveSettings()
            }
            return success
        } else {
            // Enable autostart
            let success = launchAgentManager.installLaunchAgent()
            if success {
                isAutostartEnabled = true
                settings.autoStartDetection = true
                saveSettings()
            }
            return success
        }
    }

    func refreshAutostartStatus() {
        LaunchAgentManager.shared.checkAgentStatus()
        let status = LaunchAgentManager.shared.isEnabled
        isAutostartEnabled = status
        settings.autoStartDetection = status
        saveSettings()
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
        settings = FocusLockSettings.default
        syncPublishedProperties()
        saveSettings()

        // Uninstall LaunchAgent if it was installed
        if LaunchAgentManager.shared.isInstalled {
            _ = LaunchAgentManager.shared.uninstallLaunchAgent()
        }
    }
}