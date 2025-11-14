//
//  SettingsMigration.swift
//  Dayflow
//
//  Created for Story 4.3: Settings and Configuration Persistence
//  Purpose: Settings migration system with version tracking
//

import Foundation
import GRDB

// MARK: - Migration Definition

struct SettingsMigration {
    let fromVersion: Int
    let toVersion: Int
    let migration: (Database) throws -> Void
    let description: String
}

// MARK: - Migration Manager

class SettingsMigrationManager {
    private static let settingsVersionKey = "settingsVersion"
    private static let userDefaults = UserDefaults.standard

    /// All registered migrations (ordered by version)
    static let migrations: [SettingsMigration] = [
        // Migration from version 0 (no settings) to version 1 (initial settings)
        SettingsMigration(
            fromVersion: 0,
            toVersion: 1,
            description: "Initialize default settings structure"
        ) { db in
            // No-op: Initial version, settings table already created
            print("📦 Migration 0→1: Initial settings structure")
        },

        // Migration from version 1 to 2: Add LM Studio support
        SettingsMigration(
            fromVersion: 1,
            toVersion: 2,
            description: "Add LM Studio endpoint to AI provider settings"
        ) { db in
            // Update AIProviderSettings schema to include lmStudioEndpoint
            if let settingsJSON = try String.fetchOne(db, sql: """
                SELECT value FROM app_settings WHERE key = 'aiProvider'
            """) {
                var json = try JSONSerialization.jsonObject(with: settingsJSON.data(using: .utf8)!) as? [String: Any] ?? [:]

                // Add new field with default value if not present
                if json["lmStudioEndpoint"] == nil {
                    json["lmStudioEndpoint"] = "http://localhost:1234"
                }
                if json["lmStudioModel"] == nil {
                    json["lmStudioModel"] = "gpt-4-vision-preview"
                }

                let newData = try JSONSerialization.data(withJSONObject: json)
                let newJSON = String(data: newData, encoding: .utf8)!

                try db.execute(sql: """
                    UPDATE app_settings SET value = ? WHERE key = 'aiProvider'
                """, arguments: [newJSON])

                print("✅ Migration 1→2: Added LM Studio fields to AI provider settings")
            }
        },

        // Example: Migration from version 2 to 3 (for future use)
        SettingsMigration(
            fromVersion: 2,
            toVersion: 3,
            description: "Add new retention policy options"
        ) { db in
            // This is a placeholder for future migrations
            print("📦 Migration 2→3: Reserved for future use")
        }
    ]

    /// Current settings schema version
    static var currentVersion: Int {
        get {
            return userDefaults.integer(forKey: settingsVersionKey)
        }
        set {
            userDefaults.set(newValue, forKey: settingsVersionKey)
        }
    }

    /// Target version (highest migration version)
    static var targetVersion: Int {
        return migrations.map { $0.toVersion }.max() ?? 0
    }

    /// Performs all necessary migrations to bring settings to the latest version
    /// - Parameter db: Database pool for migration operations
    /// - Throws: Migration errors
    static func performMigrations(db: DatabasePool) throws {
        let startVersion = currentVersion
        let target = targetVersion

        guard startVersion < target else {
            print("✅ Settings schema is up to date (version \(startVersion))")
            return
        }

        print("🔄 Starting settings migration from version \(startVersion) to \(target)")

        // Run migrations in order
        for migration in migrations where startVersion < migration.toVersion && migration.toVersion <= target {
            print("  Running migration \(migration.fromVersion)→\(migration.toVersion): \(migration.description)")

            do {
                try db.write { db in
                    try migration.migration(db)
                }

                // Update version after successful migration
                currentVersion = migration.toVersion
                print("  ✅ Migration \(migration.fromVersion)→\(migration.toVersion) completed")
            } catch {
                print("  ❌ Migration \(migration.fromVersion)→\(migration.toVersion) failed: \(error)")
                throw SettingsError.migrationFailed("Migration \(migration.fromVersion)→\(migration.toVersion) failed: \(error)")
            }
        }

        print("✅ Settings migration completed. Now at version \(currentVersion)")
    }

    /// Migrates settings from UserDefaults to database (one-time migration)
    static func migrateFromUserDefaults() async {
        let migrationKey = "settingsUserDefaultsMigrationCompleted"
        guard !userDefaults.bool(forKey: migrationKey) else {
            print("✅ UserDefaults migration already completed")
            return
        }

        print("🔄 Migrating settings from UserDefaults to database...")

        // This is where we would migrate any existing UserDefaults-based settings
        // For now, we'll just mark the migration as complete since this is a new system

        userDefaults.set(true, forKey: migrationKey)
        print("✅ UserDefaults migration completed")
    }

    /// Resets all migrations (for testing purposes only)
    static func resetMigrations() {
        currentVersion = 0
        userDefaults.removeObject(forKey: "settingsUserDefaultsMigrationCompleted")
        print("⚠️ Settings migrations reset to version 0")
    }

    /// Validates that all settings can be loaded and are valid
    static func validateSettings() async -> Bool {
        do {
            let manager = await SettingsManager.shared

            // Try to validate each settings category
            try manager.aiProvider.validate()
            try manager.recording.validate()
            try manager.retention.validate()
            try manager.notifications.validate()
            try manager.analytics.validate()
            try manager.focusLock.validate()

            print("✅ All settings validated successfully")
            return true
        } catch {
            print("❌ Settings validation failed: \(error)")
            return false
        }
    }
}
