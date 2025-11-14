//
//  SettingsManager.swift
//  Dayflow
//
//  Created for Story 4.3: Settings and Configuration Persistence
//  Purpose: Central settings manager with @Published properties for SwiftUI
//

import Foundation
import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Published Settings

    @Published var aiProvider: AIProviderSettings
    @Published var recording: RecordingSettings
    @Published var retention: RetentionSettings
    @Published var notifications: NotificationSettings
    @Published var analytics: AnalyticsSettings
    @Published var focusLock: FocusLockSettings

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let autoSaveDebounceInterval: TimeInterval = 1.0
    private var isLoading = false

    // MARK: - Initialization

    private init() {
        // Initialize with default values
        self.aiProvider = AIProviderSettings()
        self.recording = RecordingSettings()
        self.retention = RetentionSettings()
        self.notifications = NotificationSettings()
        self.analytics = AnalyticsSettings()
        self.focusLock = FocusLockSettings()

        // Load settings asynchronously
        Task {
            await loadAllSettings()
            setupAutoSave()
        }
    }

    // MARK: - Loading Settings

    /// Loads all settings from the database
    func loadAllSettings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load each settings category with default fallback
            aiProvider = try await StorageManager.shared.loadSetting(
                key: "aiProvider",
                defaultValue: AIProviderSettings()
            )

            recording = try await StorageManager.shared.loadSetting(
                key: "recording",
                defaultValue: RecordingSettings()
            )

            retention = try await StorageManager.shared.loadSetting(
                key: "retention",
                defaultValue: RetentionSettings()
            )

            notifications = try await StorageManager.shared.loadSetting(
                key: "notifications",
                defaultValue: NotificationSettings()
            )

            analytics = try await StorageManager.shared.loadSetting(
                key: "analytics",
                defaultValue: AnalyticsSettings()
            )

            focusLock = try await StorageManager.shared.loadSetting(
                key: "focusLock",
                defaultValue: FocusLockSettings()
            )

            print("✅ Settings loaded successfully")
        } catch {
            print("⚠️ Failed to load settings: \(error). Using defaults.")
            // Settings remain at default values
        }
    }

    // MARK: - Saving Settings

    /// Saves all settings to the database with validation
    func save() async {
        guard !isLoading else { return }  // Don't save during initial load

        do {
            // Validate all settings before saving
            try validateAll()

            // Save each settings category
            try await StorageManager.shared.saveSetting(key: "aiProvider", value: aiProvider)
            try await StorageManager.shared.saveSetting(key: "recording", value: recording)
            try await StorageManager.shared.saveSetting(key: "retention", value: retention)
            try await StorageManager.shared.saveSetting(key: "notifications", value: notifications)
            try await StorageManager.shared.saveSetting(key: "analytics", value: analytics)
            try await StorageManager.shared.saveSetting(key: "focusLock", value: focusLock)

            print("✅ Settings saved successfully")
        } catch let error as SettingsError {
            print("❌ Settings validation failed: \(error)")
            // TODO: Notify user of validation error
        } catch {
            print("❌ Failed to save settings: \(error)")
        }
    }

    /// Saves a specific settings category
    func saveSetting<T: Codable>(_ key: String, value: T) async {
        guard !isLoading else { return }

        do {
            try await StorageManager.shared.saveSetting(key: key, value: value)
            print("✅ Setting '\(key)' saved successfully")
        } catch {
            print("❌ Failed to save setting '\(key)': \(error)")
        }
    }

    // MARK: - Validation

    /// Validates all settings
    private func validateAll() throws {
        try aiProvider.validate()
        try recording.validate()
        try retention.validate()
        try notifications.validate()
        try analytics.validate()
        try focusLock.validate()
    }

    // MARK: - Auto-Save

    /// Sets up automatic saving when settings change
    private func setupAutoSave() {
        // Debounce saves to avoid excessive database writes
        Publishers.CombineLatest3(
            $aiProvider.dropFirst(),
            $recording.dropFirst(),
            $retention.dropFirst()
        )
        .debounce(for: .seconds(autoSaveDebounceInterval), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            guard let self = self else { return }
            Task {
                await self.save()
            }
        }
        .store(in: &cancellables)

        Publishers.CombineLatest3(
            $notifications.dropFirst(),
            $analytics.dropFirst(),
            $focusLock.dropFirst()
        )
        .debounce(for: .seconds(autoSaveDebounceInterval), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            guard let self = self else { return }
            Task {
                await self.save()
            }
        }
        .store(in: &cancellables)
    }

    // MARK: - Reset

    /// Resets all settings to defaults
    func resetToDefaults() async {
        aiProvider = AIProviderSettings()
        recording = RecordingSettings()
        retention = RetentionSettings()
        notifications = NotificationSettings()
        analytics = AnalyticsSettings()
        focusLock = FocusLockSettings()

        await save()
        print("✅ Settings reset to defaults")
    }

    // MARK: - Backup & Restore

    /// Creates a backup of all settings
    func createBackup() async throws -> SettingsBackup {
        return try await SettingsBackup.create(from: StorageManager.shared)
    }

    /// Restores settings from a backup
    func restoreFromBackup(_ backup: SettingsBackup) async throws {
        try await backup.restore(to: StorageManager.shared)
        await loadAllSettings()
        print("✅ Settings restored from backup")
    }

    /// Exports settings to a file
    func exportSettings(to url: URL) async throws {
        let backup = try await createBackup()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        try data.write(to: url)
        print("✅ Settings exported to: \(url.path)")
    }

    /// Imports settings from a file
    func importSettings(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(SettingsBackup.self, from: data)
        try await restoreFromBackup(backup)
        print("✅ Settings imported from: \(url.path)")
    }

    // MARK: - API Key Management

    /// Saves an API key to the Keychain (not database)
    func saveAPIKey(_ key: String, for provider: String) -> Bool {
        return KeychainManager.shared.store(key, for: provider)
    }

    /// Retrieves an API key from the Keychain
    func getAPIKey(for provider: String) -> String? {
        return KeychainManager.shared.retrieve(for: provider)
    }

    /// Deletes an API key from the Keychain
    func deleteAPIKey(for provider: String) -> Bool {
        return KeychainManager.shared.delete(for: provider)
    }

    /// Checks if an API key exists in the Keychain
    func hasAPIKey(for provider: String) -> Bool {
        return KeychainManager.shared.exists(for: provider)
    }
}
