//
//  SettingsModels.swift
//  Dayflow
//
//  Created for Story 4.3: Settings and Configuration Persistence
//  Purpose: Settings data models with validation and Codable support
//

import Foundation

// MARK: - Settings Validation Protocol

protocol SettingsValidatable {
    func validate() throws
}

// MARK: - AI Provider Settings

enum AIProviderType: String, Codable {
    case gemini
    case ollama
    case lmStudio
}

struct AIProviderSettings: Codable, Equatable {
    var selectedProvider: AIProviderType = .gemini
    // Note: API keys are stored in Keychain, not in this struct
    var geminiModel: String = "gemini-1.5-flash"
    var ollamaEndpoint: String = "http://localhost:11434"
    var ollamaModel: String = "llava:latest"
    var lmStudioEndpoint: String = "http://localhost:1234"
    var lmStudioModel: String = "gpt-4-vision-preview"
}

extension AIProviderSettings: SettingsValidatable {
    func validate() throws {
        // Validate endpoint URLs
        if !ollamaEndpoint.isEmpty {
            guard URL(string: ollamaEndpoint) != nil else {
                throw SettingsError.invalidValue("Ollama endpoint must be a valid URL")
            }
        }

        if !lmStudioEndpoint.isEmpty {
            guard URL(string: lmStudioEndpoint) != nil else {
                throw SettingsError.invalidValue("LM Studio endpoint must be a valid URL")
            }
        }

        // Validate model names are not empty
        guard !geminiModel.isEmpty else {
            throw SettingsError.invalidValue("Gemini model name cannot be empty")
        }

        guard !ollamaModel.isEmpty else {
            throw SettingsError.invalidValue("Ollama model name cannot be empty")
        }

        guard !lmStudioModel.isEmpty else {
            throw SettingsError.invalidValue("LM Studio model name cannot be empty")
        }
    }
}

// MARK: - Recording Settings

enum VideoQuality: String, Codable {
    case low
    case medium
    case high
}

struct RecordingSettings: Codable, Equatable {
    var enabled: Bool = true
    var frameRate: Int = 1  // Frames per second (1-30)
    var quality: VideoQuality = .medium
    var storageLocation: String? = nil  // File path as string for Codable compatibility
    var displays: [String] = []  // Empty = all displays
}

extension RecordingSettings: SettingsValidatable {
    func validate() throws {
        // Validate frame rate
        guard frameRate >= 1 && frameRate <= 30 else {
            throw SettingsError.invalidValue("Frame rate must be between 1 and 30 FPS (got: \(frameRate))")
        }

        // Validate storage location if specified
        if let location = storageLocation, !location.isEmpty {
            let url = URL(fileURLWithPath: location)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SettingsError.invalidPath("Storage location does not exist: \(location)")
            }
        }
    }
}

// MARK: - Retention Settings

struct RetentionSettings: Codable, Equatable {
    var enabled: Bool = true
    var retentionDays: Int = 3  // 1-365 days
    var maxStorageGB: Int = 10  // 1-1000 GB
    var cleanupIntervalHours: Int = 1  // 1-24 hours
}

extension RetentionSettings: SettingsValidatable {
    func validate() throws {
        // Validate retention days
        guard retentionDays >= 1 && retentionDays <= 365 else {
            throw SettingsError.invalidValue("Retention days must be between 1 and 365 (got: \(retentionDays))")
        }

        // Validate max storage
        guard maxStorageGB >= 1 && maxStorageGB <= 1000 else {
            throw SettingsError.invalidValue("Max storage must be between 1 and 1000 GB (got: \(maxStorageGB))")
        }

        // Validate cleanup interval
        guard cleanupIntervalHours >= 1 && cleanupIntervalHours <= 24 else {
            throw SettingsError.invalidValue("Cleanup interval must be between 1 and 24 hours (got: \(cleanupIntervalHours))")
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettings: Codable, Equatable {
    var enabled: Bool = true
    var analysisComplete: Bool = true
    var storageWarning: Bool = true
    var errorAlerts: Bool = true
}

extension NotificationSettings: SettingsValidatable {
    func validate() throws {
        // No specific validation needed for boolean flags
    }
}

// MARK: - Analytics Settings

struct AnalyticsSettings: Codable, Equatable {
    var sentryEnabled: Bool = false
    var postHogEnabled: Bool = false
    var crashReporting: Bool = false
}

extension AnalyticsSettings: SettingsValidatable {
    func validate() throws {
        // No specific validation needed for boolean flags
    }
}

// MARK: - Focus Lock Settings

enum BlockingMode: String, Codable {
    case soft       // Warnings only
    case hard       // Block access
    case adaptive   // Learn from user behavior
}

struct FocusLockSettings: Codable, Equatable {
    var globalAllowedApps: [String] = ["Finder", "System Preferences"]
    var defaultSessionDuration: TimeInterval = 25 * 60  // 25 minutes (Pomodoro)
    var breakReminders: Bool = true
    var blockingMode: BlockingMode = .soft
}

extension FocusLockSettings: SettingsValidatable {
    func validate() throws {
        // Validate session duration (should be reasonable)
        guard defaultSessionDuration >= 60 && defaultSessionDuration <= 14400 else {
            throw SettingsError.invalidValue("Session duration must be between 1 minute and 4 hours (got: \(defaultSessionDuration) seconds)")
        }
    }
}

// MARK: - Settings Backup/Restore

struct SettingsBackup: Codable {
    let version: Int
    let timestamp: Date
    let settings: [String: String]  // All settings as JSON strings

    static func create(from storageManager: StorageManager) async throws -> SettingsBackup {
        let settingKeys = try await storageManager.listSettingKeys()
        var settingsDict: [String: String] = [:]

        // Read all settings as raw JSON strings
        for key in settingKeys {
            if let jsonString = try? await storageManager.db.read({ db in
                try String.fetchOne(db, sql: "SELECT value FROM app_settings WHERE key = ?", arguments: [key])
            }) {
                settingsDict[key] = jsonString
            }
        }

        return SettingsBackup(
            version: 1,
            timestamp: Date(),
            settings: settingsDict
        )
    }

    func restore(to storageManager: StorageManager) async throws {
        for (key, jsonValue) in settings {
            try await storageManager.db.write { db in
                try db.execute(sql: """
                    INSERT OR REPLACE INTO app_settings (key, value, updated_at)
                    VALUES (?, ?, ?)
                """, arguments: [key, jsonValue, Int(Date().timeIntervalSince1970)])
            }
        }
    }
}
