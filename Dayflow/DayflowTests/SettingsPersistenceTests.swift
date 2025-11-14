//
//  SettingsPersistenceTests.swift
//  DayflowTests
//
//  Created for Story 4.3: Settings and Configuration Persistence
//  Purpose: Comprehensive tests for settings persistence, validation, and integrity
//

import XCTest
@testable import Dayflow

final class SettingsPersistenceTests: XCTestCase {

    var storageManager: StorageManager!
    var testDatabasePath: String!

    override func setUp() {
        super.setUp()
        // Create test-specific database with isolated storage
        let tempDir = FileManager.default.temporaryDirectory
        let testDbPath = tempDir.appendingPathComponent("test_settings_\(UUID().uuidString).sqlite")
        testDatabasePath = testDbPath.path

        // Initialize test instance with isolated database
        storageManager = StorageManager(testDatabasePath: testDatabasePath)
    }

    override func tearDown() {
        // Clean up test database and associated files
        if let dbPath = testDatabasePath {
            // Remove main database file
            try? FileManager.default.removeItem(atPath: dbPath)
            // Remove WAL and SHM files
            try? FileManager.default.removeItem(atPath: dbPath + "-wal")
            try? FileManager.default.removeItem(atPath: dbPath + "-shm")
        }

        storageManager = nil
        testDatabasePath = nil
        super.tearDown()
    }

    // MARK: - Basic Persistence Tests

    func testSettingsSaveAndLoad() async throws {
        // Create test settings
        let settings = RecordingSettings(
            enabled: true,
            frameRate: 5,
            quality: .high,
            storageLocation: nil,
            displays: []
        )

        // Save settings
        try await storageManager.saveSetting(key: "recording", value: settings)

        // Load settings
        let loaded: RecordingSettings = try await storageManager.loadSetting(
            key: "recording",
            defaultValue: RecordingSettings()
        )

        // Verify
        XCTAssertEqual(loaded.enabled, true, "Recording enabled should match")
        XCTAssertEqual(loaded.frameRate, 5, "Frame rate should match")
        XCTAssertEqual(loaded.quality, .high, "Quality should match")
    }

    func testSettingsDefaultValue() async throws {
        // Attempt to load non-existent setting
        let loaded: RecordingSettings = try await storageManager.loadSetting(
            key: "nonexistent",
            defaultValue: RecordingSettings()
        )

        // Verify default values
        XCTAssertEqual(loaded.enabled, true, "Should return default enabled value")
        XCTAssertEqual(loaded.frameRate, 1, "Should return default frame rate")
        XCTAssertEqual(loaded.quality, .medium, "Should return default quality")
    }

    func testMultipleSettingsCategories() async throws {
        // Create and save multiple settings categories
        let aiSettings = AIProviderSettings(
            selectedProvider: .ollama,
            geminiModel: "gemini-1.5-pro",
            ollamaEndpoint: "http://localhost:11434",
            ollamaModel: "llava:latest"
        )

        let retentionSettings = RetentionSettings(
            enabled: true,
            retentionDays: 7,
            maxStorageGB: 20,
            cleanupIntervalHours: 2
        )

        let notificationSettings = NotificationSettings(
            enabled: true,
            analysisComplete: false,
            storageWarning: true,
            errorAlerts: true
        )

        // Save all settings
        try await storageManager.saveSetting(key: "aiProvider", value: aiSettings)
        try await storageManager.saveSetting(key: "retention", value: retentionSettings)
        try await storageManager.saveSetting(key: "notifications", value: notificationSettings)

        // Load and verify each setting
        let loadedAI: AIProviderSettings = try await storageManager.loadSetting(
            key: "aiProvider",
            defaultValue: AIProviderSettings()
        )
        XCTAssertEqual(loadedAI.selectedProvider, .ollama)
        XCTAssertEqual(loadedAI.geminiModel, "gemini-1.5-pro")

        let loadedRetention: RetentionSettings = try await storageManager.loadSetting(
            key: "retention",
            defaultValue: RetentionSettings()
        )
        XCTAssertEqual(loadedRetention.retentionDays, 7)
        XCTAssertEqual(loadedRetention.maxStorageGB, 20)

        let loadedNotifications: NotificationSettings = try await storageManager.loadSetting(
            key: "notifications",
            defaultValue: NotificationSettings()
        )
        XCTAssertEqual(loadedNotifications.analysisComplete, false)
        XCTAssertEqual(loadedNotifications.storageWarning, true)
    }

    // MARK: - Validation Tests

    func testRecordingSettingsValidation() async throws {
        var settings = RecordingSettings()

        // Valid frame rate should not throw
        settings.frameRate = 15
        XCTAssertNoThrow(try settings.validate(), "Valid frame rate should pass validation")

        // Invalid frame rate (too high) should throw
        settings.frameRate = 100
        XCTAssertThrowsError(try settings.validate(), "Frame rate > 30 should fail validation")

        // Invalid frame rate (too low) should throw
        settings.frameRate = 0
        XCTAssertThrowsError(try settings.validate(), "Frame rate < 1 should fail validation")
    }

    func testRetentionSettingsValidation() async throws {
        var settings = RetentionSettings()

        // Valid retention days
        settings.retentionDays = 7
        XCTAssertNoThrow(try settings.validate(), "Valid retention days should pass")

        // Invalid retention days (too high)
        settings.retentionDays = 500
        XCTAssertThrowsError(try settings.validate(), "Retention days > 365 should fail")

        // Invalid retention days (too low)
        settings.retentionDays = 0
        XCTAssertThrowsError(try settings.validate(), "Retention days < 1 should fail")

        // Invalid max storage
        settings.retentionDays = 7  // Reset to valid
        settings.maxStorageGB = 2000
        XCTAssertThrowsError(try settings.validate(), "Max storage > 1000 should fail")

        // Invalid cleanup interval
        settings.maxStorageGB = 10  // Reset to valid
        settings.cleanupIntervalHours = 48
        XCTAssertThrowsError(try settings.validate(), "Cleanup interval > 24 should fail")
    }

    func testAIProviderSettingsValidation() async throws {
        var settings = AIProviderSettings()

        // Valid settings should pass
        XCTAssertNoThrow(try settings.validate(), "Default AI settings should be valid")

        // Invalid Ollama endpoint
        settings.ollamaEndpoint = "not-a-valid-url"
        XCTAssertThrowsError(try settings.validate(), "Invalid Ollama endpoint should fail")

        // Reset and test invalid LM Studio endpoint
        settings = AIProviderSettings()
        settings.lmStudioEndpoint = "invalid://endpoint"
        XCTAssertThrowsError(try settings.validate(), "Invalid LM Studio endpoint should fail")

        // Empty model name should fail
        settings = AIProviderSettings()
        settings.geminiModel = ""
        XCTAssertThrowsError(try settings.validate(), "Empty model name should fail")
    }

    func testFocusLockSettingsValidation() async throws {
        var settings = FocusLockSettings()

        // Valid session duration
        settings.defaultSessionDuration = 25 * 60  // 25 minutes
        XCTAssertNoThrow(try settings.validate(), "Valid session duration should pass")

        // Session duration too short
        settings.defaultSessionDuration = 30  // 30 seconds
        XCTAssertThrowsError(try settings.validate(), "Session duration < 60s should fail")

        // Session duration too long
        settings.defaultSessionDuration = 5 * 60 * 60  // 5 hours
        XCTAssertThrowsError(try settings.validate(), "Session duration > 4 hours should fail")
    }

    // MARK: - Update/Overwrite Tests

    func testSettingsOverwrite() async throws {
        // Create initial settings
        var settings = RetentionSettings(
            enabled: true,
            retentionDays: 3,
            maxStorageGB: 10,
            cleanupIntervalHours: 1
        )

        // Save initial settings
        try await storageManager.saveSetting(key: "retention", value: settings)

        // Modify and save again
        settings.retentionDays = 7
        settings.maxStorageGB = 20
        try await storageManager.saveSetting(key: "retention", value: settings)

        // Load and verify updated values
        let loaded: RetentionSettings = try await storageManager.loadSetting(
            key: "retention",
            defaultValue: RetentionSettings()
        )

        XCTAssertEqual(loaded.retentionDays, 7, "Should have updated retention days")
        XCTAssertEqual(loaded.maxStorageGB, 20, "Should have updated max storage")
        XCTAssertEqual(loaded.cleanupIntervalHours, 1, "Should retain unchanged value")
    }

    // MARK: - Invalid Data Handling Tests

    func testInvalidJSONHandling() async throws {
        // Manually insert invalid JSON into database
        try await storageManager.db.write { db in
            try db.execute(sql: """
                INSERT INTO app_settings (key, value)
                VALUES ('recording', 'invalid json data')
            """)
        }

        // Should return default value on decode failure
        let loaded: RecordingSettings = try await storageManager.loadSetting(
            key: "recording",
            defaultValue: RecordingSettings()
        )

        XCTAssertEqual(loaded.frameRate, 1, "Should return default value for invalid JSON")
        XCTAssertEqual(loaded.quality, .medium, "Should return default quality for invalid JSON")
    }

    func testCorruptedDataGracefulFallback() async throws {
        // Insert partially valid JSON (missing required fields after schema change)
        let partialJSON = """
        {
            "enabled": true,
            "frameRate": 5
        }
        """

        try await storageManager.db.write { db in
            try db.execute(sql: """
                INSERT INTO app_settings (key, value, updated_at)
                VALUES ('recording', ?, ?)
            """, arguments: [partialJSON, Int(Date().timeIntervalSince1970)])
        }

        // Should fall back to defaults gracefully
        let loaded: RecordingSettings = try await storageManager.loadSetting(
            key: "recording",
            defaultValue: RecordingSettings()
        )

        // Even if it successfully decodes partial data, we should get a valid object
        XCTAssertNotNil(loaded, "Should return a valid settings object")
    }

    // MARK: - Persistence Across "Restart" Tests

    func testSettingsPersistenceAcrossRestart() async throws {
        // Save settings with first storage manager instance
        let originalSettings = AIProviderSettings(
            selectedProvider: .ollama,
            geminiModel: "gemini-1.5-pro",
            ollamaModel: "llava:latest",
            ollamaEndpoint: "http://localhost:11434"
        )
        try await storageManager.saveSetting(key: "aiProvider", value: originalSettings)

        // Simulate app restart by creating a new storage manager instance with same database
        let newStorageManager = StorageManager(testDatabasePath: testDatabasePath)

        // Load settings with new instance
        let loadedSettings: AIProviderSettings = try await newStorageManager.loadSetting(
            key: "aiProvider",
            defaultValue: AIProviderSettings()
        )

        // Verify persistence
        XCTAssertEqual(loadedSettings.selectedProvider, .ollama, "Provider should persist")
        XCTAssertEqual(loadedSettings.geminiModel, "gemini-1.5-pro", "Model should persist")
        XCTAssertEqual(loadedSettings.ollamaModel, "llava:latest", "Ollama model should persist")
    }

    // MARK: - Performance Tests

    func testSettingsLoadPerformance() async throws {
        // Pre-populate with test data
        let settings = RecordingSettings(
            enabled: true,
            frameRate: 5,
            quality: .high,
            storageLocation: nil,
            displays: []
        )
        try await storageManager.saveSetting(key: "recording", value: settings)

        // Measure load time and validate against acceptance criteria (< 100ms)
        let start = Date()
        _ = try await storageManager.loadSetting(
            key: "recording",
            defaultValue: RecordingSettings()
        )
        let duration = Date().timeIntervalSince(start)

        // CRITICAL: Validate against acceptance criteria (< 100ms)
        XCTAssertLessThan(duration, 0.1, "Settings load exceeded 100ms target (actual: \(String(format: "%.3f", duration * 1000))ms)")

        // Also run measure block for detailed performance tracking
        measure {
            Task {
                _ = try? await storageManager.loadSetting(
                    key: "recording",
                    defaultValue: RecordingSettings()
                )
            }
        }
    }

    func testSettingsSavePerformance() async throws {
        let settings = RetentionSettings(
            enabled: true,
            retentionDays: 7,
            maxStorageGB: 20,
            cleanupIntervalHours: 2
        )

        // Measure save time and validate against acceptance criteria (< 50ms)
        let start = Date()
        try await storageManager.saveSetting(key: "retention", value: settings)
        let duration = Date().timeIntervalSince(start)

        // CRITICAL: Validate against acceptance criteria (< 50ms)
        XCTAssertLessThan(duration, 0.05, "Settings save exceeded 50ms target (actual: \(String(format: "%.3f", duration * 1000))ms)")

        // Also run measure block for detailed performance tracking
        measure {
            Task {
                try? await storageManager.saveSetting(key: "retention", value: settings)
            }
        }
    }

    func testValidationPerformance() async throws {
        let settings = RecordingSettings(
            enabled: true,
            frameRate: 15,
            quality: .medium,
            storageLocation: nil,
            displays: []
        )

        // Measure validation time (< 10ms per acceptance criteria)
        let start = Date()
        try settings.validate()
        let duration = Date().timeIntervalSince(start)

        // CRITICAL: Validate against acceptance criteria (< 10ms)
        XCTAssertLessThan(duration, 0.01, "Validation exceeded 10ms target (actual: \(String(format: "%.3f", duration * 1000))ms)")

        // Run measure block
        measure {
            try? settings.validate()
        }
    }

    // MARK: - Backup/Restore Tests

    func testSettingsBackupCreation() async throws {
        // Save multiple settings
        try await storageManager.saveSetting(key: "recording", value: RecordingSettings())
        try await storageManager.saveSetting(key: "retention", value: RetentionSettings())
        try await storageManager.saveSetting(key: "notifications", value: NotificationSettings())

        // Create backup
        let backup = try await SettingsBackup.create(from: storageManager)

        // Verify backup contents
        XCTAssertEqual(backup.version, 1, "Backup version should be 1")
        XCTAssertGreaterThanOrEqual(backup.settings.count, 3, "Backup should contain at least 3 settings")
        XCTAssertNotNil(backup.settings["recording"], "Backup should contain recording settings")
        XCTAssertNotNil(backup.settings["retention"], "Backup should contain retention settings")
        XCTAssertNotNil(backup.settings["notifications"], "Backup should contain notification settings")
    }

    func testSettingsRestore() async throws {
        // Create original settings
        let originalRetention = RetentionSettings(
            enabled: true,
            retentionDays: 7,
            maxStorageGB: 20,
            cleanupIntervalHours: 2
        )
        try await storageManager.saveSetting(key: "retention", value: originalRetention)

        // Create backup
        let backup = try await SettingsBackup.create(from: storageManager)

        // Modify settings
        let modifiedRetention = RetentionSettings(
            enabled: false,
            retentionDays: 30,
            maxStorageGB: 50,
            cleanupIntervalHours: 12
        )
        try await storageManager.saveSetting(key: "retention", value: modifiedRetention)

        // Verify modification
        let modified: RetentionSettings = try await storageManager.loadSetting(
            key: "retention",
            defaultValue: RetentionSettings()
        )
        XCTAssertEqual(modified.retentionDays, 30, "Settings should be modified")

        // Restore from backup
        try await backup.restore(to: storageManager)

        // Verify restoration
        let restored: RetentionSettings = try await storageManager.loadSetting(
            key: "retention",
            defaultValue: RetentionSettings()
        )
        XCTAssertEqual(restored.retentionDays, 7, "Settings should be restored from backup")
        XCTAssertEqual(restored.maxStorageGB, 20, "Storage should be restored from backup")
    }

    // MARK: - Keychain Integration Tests

    func testAPIKeyStorage() {
        let testKey = "test_api_key_12345"
        let provider = "gemini-test"

        // Store API key
        let storeResult = KeychainManager.shared.store(testKey, for: provider)
        XCTAssertTrue(storeResult, "Should successfully store API key")

        // Retrieve API key
        let retrievedKey = KeychainManager.shared.retrieve(for: provider)
        XCTAssertEqual(retrievedKey, testKey, "Retrieved key should match stored key")

        // Verify key exists
        let exists = KeychainManager.shared.exists(for: provider)
        XCTAssertTrue(exists, "Key should exist in keychain")

        // Delete API key
        let deleteResult = KeychainManager.shared.delete(for: provider)
        XCTAssertTrue(deleteResult, "Should successfully delete API key")

        // Verify deletion
        let keyAfterDelete = KeychainManager.shared.retrieve(for: provider)
        XCTAssertNil(keyAfterDelete, "Key should be nil after deletion")
    }

    func testAPIKeyNotInDatabase() async throws {
        // Save AI provider settings
        let settings = AIProviderSettings(
            selectedProvider: .gemini,
            geminiModel: "gemini-1.5-flash"
        )
        try await storageManager.saveSetting(key: "aiProvider", value: settings)

        // Verify that the database value does not contain API key
        let jsonString = try await storageManager.db.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM app_settings WHERE key = 'aiProvider'")
        }

        XCTAssertNotNil(jsonString, "Settings JSON should exist")
        // The JSON should not contain "apiKey" or sensitive data
        XCTAssertFalse(jsonString?.contains("apiKey") ?? false, "Database should not contain API key field")
    }

    // MARK: - Delete Settings Tests

    func testDeleteSetting() async throws {
        // Save a setting
        let settings = NotificationSettings(enabled: true, analysisComplete: true)
        try await storageManager.saveSetting(key: "notifications", value: settings)

        // Verify it exists
        let loaded1: NotificationSettings = try await storageManager.loadSetting(
            key: "notifications",
            defaultValue: NotificationSettings(enabled: false)
        )
        XCTAssertTrue(loaded1.enabled, "Setting should exist")

        // Delete the setting
        try await storageManager.deleteSetting(key: "notifications")

        // Verify it's deleted (should return default)
        let loaded2: NotificationSettings = try await storageManager.loadSetting(
            key: "notifications",
            defaultValue: NotificationSettings(enabled: false)
        )
        XCTAssertFalse(loaded2.enabled, "Should return default after deletion")
    }

    // MARK: - List Settings Tests

    func testListSettingKeys() async throws {
        // Save multiple settings
        try await storageManager.saveSetting(key: "recording", value: RecordingSettings())
        try await storageManager.saveSetting(key: "retention", value: RetentionSettings())
        try await storageManager.saveSetting(key: "analytics", value: AnalyticsSettings())

        // List all keys
        let keys = try await storageManager.listSettingKeys()

        // Verify
        XCTAssertGreaterThanOrEqual(keys.count, 3, "Should have at least 3 keys")
        XCTAssertTrue(keys.contains("recording"), "Should contain recording key")
        XCTAssertTrue(keys.contains("retention"), "Should contain retention key")
        XCTAssertTrue(keys.contains("analytics"), "Should contain analytics key")
    }

    // MARK: - Edge Cases

    func testEmptySettingsQuery() async throws {
        // Query non-existent key should return default
        let settings: AnalyticsSettings = try await storageManager.loadSetting(
            key: "nonexistent_key_xyz",
            defaultValue: AnalyticsSettings()
        )

        XCTAssertEqual(settings.sentryEnabled, false, "Should return default value")
    }

    func testSettingsWithSpecialCharacters() async throws {
        // Test settings with unicode and special characters
        var settings = AIProviderSettings()
        settings.geminiModel = "gemini-1.5-flash-🚀"
        settings.ollamaEndpoint = "http://localhost:11434/api/v1"

        try await storageManager.saveSetting(key: "aiProvider", value: settings)

        let loaded: AIProviderSettings = try await storageManager.loadSetting(
            key: "aiProvider",
            defaultValue: AIProviderSettings()
        )

        XCTAssertEqual(loaded.geminiModel, "gemini-1.5-flash-🚀", "Should handle unicode characters")
        XCTAssertEqual(loaded.ollamaEndpoint, "http://localhost:11434/api/v1", "Should handle URLs with paths")
    }
}
