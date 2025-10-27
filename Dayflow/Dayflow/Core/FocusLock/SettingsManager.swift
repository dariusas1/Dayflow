//
//  SettingsManager.swift
//  FocusLock
//
//  Manages FocusLock settings and preferences
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Published Properties
    @Published var settings: FocusLockSettings = .default

    // MARK: - Computed Properties
    var currentSettings: FocusLockSettings {
        return settings
    }

    // MARK: - Private Properties
    private let settingsKey = "FocusLockSettings"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init() {
        loadSettings()
        setupAutoSave()
    }

    // MARK: - Settings Management
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(FocusLockSettings.self, from: data) {
            settings = decoded
        } else {
            settings = FocusLockSettings.default
        }
    }

    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    private func setupAutoSave() {
        $settings
            .debounce(for: 1.0, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }

    // MARK: - Convenience Methods
    func updateGlobalAllowedApps(_ apps: [String]) {
        settings.globalAllowedApps = apps
    }

    func updateEmergencyBreakDuration(_ duration: TimeInterval) {
        settings.emergencyBreakDuration = duration
    }

    func enableAutoStartDetection(_ enabled: Bool) {
        settings.autoStartDetection = enabled
    }

    func enableNotifications(_ enabled: Bool) {
        settings.enableNotifications = enabled
    }

    func enableSessionLogging(_ enabled: Bool) {
        settings.logSessions = enabled
    }
}