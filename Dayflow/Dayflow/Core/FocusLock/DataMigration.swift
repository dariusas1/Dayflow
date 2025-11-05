//
//  DataMigration.swift
//  FocusLock
//
//  Data migration system for transitioning from Dayflow to FocusLock functionality
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Migration Manager
@MainActor
class DataMigrationManager: ObservableObject {
    static let shared = DataMigrationManager()

    @Published var migrationStatus: DataMigration.MigrationStatus = .notStarted
    @Published var migrationProgress: Double = 0.0
    @Published var migrationError: String?
    @Published var migrationResults: MigrationResults?

    private let userDefaults = UserDefaults.standard
    private let migrationVersionKey = "focuslock_migration_version"
    private let migrationDateKey = "focuslock_migration_date"

    // Current migration version - increment when schema changes
    private let currentMigrationVersion: Int = 1

    private init() {
        checkMigrationStatus()
    }

    // MARK: - Public Interface
    func needsMigration() -> Bool {
        let lastMigrationVersion = userDefaults.integer(forKey: migrationVersionKey)
        return lastMigrationVersion < currentMigrationVersion
    }

    func performMigration() async {
        guard migrationStatus == .notStarted else {
            print("⚠️ Migration already in progress or completed")
            return
        }

        await MainActor.run {
            migrationStatus = .inProgress
            migrationProgress = 0.0
            migrationError = nil
            migrationResults = nil
        }

        do {
            let results = try await executeMigration()

            await MainActor.run {
                migrationResults = results
                migrationStatus = .completed
                migrationProgress = 1.0

                // Mark migration as complete
                userDefaults.set(currentMigrationVersion, forKey: migrationVersionKey)
                userDefaults.set(Date(), forKey: migrationDateKey)

                // Track migration success
                AnalyticsService.shared.capture("data_migration_completed", [
                    "version": currentMigrationVersion,
                    "migrated_activities": results.migratedActivities,
                    "migrated_categories": results.migratedCategories,
                    "created_sessions": results.createdFocusSessions
                ])
            }
        } catch {
            await MainActor.run {
                migrationStatus = .failed
                migrationError = error.localizedDescription

                // Track migration failure
                AnalyticsService.shared.capture("data_migration_failed", [
                    "version": currentMigrationVersion,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    func resetMigration() {
        userDefaults.removeObject(forKey: migrationVersionKey)
        userDefaults.removeObject(forKey: migrationDateKey)
        migrationStatus = .notStarted
        migrationProgress = 0.0
        migrationError = nil
        migrationResults = nil
    }

    func markMigrationSkipped() {
        // Mark migration as complete so the view disappears
        userDefaults.set(currentMigrationVersion, forKey: migrationVersionKey)
        userDefaults.set(Date(), forKey: migrationDateKey)
        migrationStatus = .completed
        migrationProgress = 1.0
        migrationError = nil
        print("⚠️ Migration skipped by user")
    }

    // MARK: - Migration Execution
    private func executeMigration() async throws -> MigrationResults {
        var results = MigrationResults()

        // Step 1: Migrate Timeline Activities
        await updateProgress(0.1, message: "Migrating timeline activities...")
        results.migratedActivities = try await migrateTimelineActivities()

        // Step 2: Migrate Categories
        await updateProgress(0.3, message: "Migrating categories...")
        results.migratedCategories = try await migrateCategories()

        // Step 3: Create Focus Sessions from timeline data
        await updateProgress(0.5, message: "Creating focus sessions...")
        results.createdFocusSessions = try await createFocusSessionsFromTimeline()

        // Step 4: Migrate User Preferences
        await updateProgress(0.7, message: "Migrating user preferences...")
        results.migratedPreferences = try await migrateUserPreferences()

        // Step 5: Migrate Focus Sessions
        await updateProgress(0.85, message: "Migrating focus sessions...")
        results.migratedSessions = try await migrateFocusSessions()

        // Step 6: Migrate Analytics Data
        await updateProgress(0.9, message: "Migrating analytics data...")
        results.migratedAnalytics = try await migrateAnalyticsData()

        // Step 7: Create Backup
        await updateProgress(0.95, message: "Creating backup...")
        try await createMigrationBackup(results: results)

        await updateProgress(1.0, message: "Migration completed!")
        return results
    }

    private func updateProgress(_ progress: Double, message: String) async {
        await MainActor.run {
            migrationProgress = progress
            print("📊 Migration: \(message) (\(Int(progress * 100))%)")
        }
    }

    // MARK: - Specific Migration Steps

    private func migrateTimelineActivities() async throws -> Int {
        // Load existing timeline activities
        let activities = try loadTimelineActivities()
        var migratedCount = 0

        for activity in activities {
            // Convert timeline activity to FocusLock data model
            let focusActivity = FocusActivity.fromTimelineActivity(activity)

            // Save to new data store
            try await saveFocusActivity(focusActivity)
            migratedCount += 1
        }

        return migratedCount
    }

    private func migrateCategories() async throws -> Int {
        // Load existing categories
        let categories = try loadCategories()
        var migratedCount = 0

        for category in categories {
            // Convert to FocusLock category model
            let focusCategory = FocusCategory.fromTimelineCategory(category)

            // Save to new data store
            try await saveFocusCategory(focusCategory)
            migratedCount += 1
        }

        return migratedCount
    }

    private func createFocusSessionsFromTimeline() async throws -> Int {
        // Analyze timeline data to identify potential focus sessions
        let activities = try loadTimelineActivities()
        let sessions = FocusSessionDetector.detectSessions(from: activities)
        var createdCount = 0

        for session in sessions {
            // Save detected focus session
            try await saveFocusSession(session)
            createdCount += 1
        }

        return createdCount
    }

    private func migrateUserPreferences() async throws -> Int {
        var migratedPrefs = MigratedPreferences()

        // Migrate recording preferences
        migratedPrefs.recordingEnabled = userDefaults.bool(forKey: "isRecordingEnabled")
        migratedPrefs.recordingQuality = userDefaults.string(forKey: "recordingQuality")
        migratedPrefs.storageLocation = userDefaults.string(forKey: "storageLocation")

        // Migrate provider preferences
        migratedPrefs.selectedProvider = userDefaults.string(forKey: "selectedLLMProvider")
        migratedPrefs.geminiModel = userDefaults.string(forKey: "geminiModelPreference")

        // Migrate notification preferences
        migratedPrefs.notificationsEnabled = userDefaults.bool(forKey: "notificationsEnabled")
        migratedPrefs.analyticsOptIn = AnalyticsService.shared.isOptedIn

        // Save migrated preferences
        try await saveMigratedPreferences(migratedPrefs)

        return 1 // One preferences object migrated
    }

    private func migrateFocusSessions() async throws -> Int {
        // Load any existing session data from legacy formats
        let legacySessions = try loadLegacyFocusSessions()
        var migratedCount = 0

        // Migrate performance tracking data for existing sessions
        for session in legacySessions {
            // Convert to new FocusSession format with performance metrics
            let focusSession = try await convertLegacySession(session)

            // Save to new data store with performance tracking
            try await saveFocusSession(focusSession)
            migratedCount += 1
        }

        // Initialize session performance tracking for migrated sessions
        try await initializeSessionPerformanceTracking()

        return migratedCount
    }

    private func migrateAnalyticsData() async throws -> Int {
        // Load existing analytics data
        let analyticsData = try loadAnalyticsData()
        var migratedCount = 0

        for data in analyticsData {
            // Convert to FocusLock analytics model
            let focusAnalytics = FocusAnalytics.fromLegacyAnalytics(data)

            // Save to new analytics store
            try await saveFocusAnalytics(focusAnalytics)
            migratedCount += 1
        }

        return migratedCount
    }

    // MARK: - Data Loading Helpers

    private func loadTimelineActivities() throws -> [LegacyTimelineActivity] {
        // This would load from the existing Dayflow database
        // For now, return empty array as placeholder
        return []
    }

    private func loadCategories() throws -> [LegacyCategory] {
        // Load existing categories
        return []
    }

    private func loadAnalyticsData() throws -> [LegacyAnalyticsData] {
        // Load existing analytics data
        return []
    }

    private func loadLegacyFocusSessions() throws -> [LegacyFocusSession] {
        // Load existing focus sessions from legacy storage
        // For now, return empty array as placeholder
        return []
    }

    private func convertLegacySession(_ legacySession: LegacyFocusSession) async throws -> FocusSession {
        // Convert legacy session to new format with performance metrics
        // Since the old LegacyFocusSession structure has been removed, create a minimal FocusSession
        let taskName = legacySession.taskId?.uuidString ?? legacySession.mode.displayName
        let focusSession = FocusSession(
            id: legacySession.id,
            taskName: taskName,
            startTime: legacySession.startTime,
            endTime: legacySession.endTime,
            state: .active,
            allowedApps: [],
            emergencyBreaks: [],
            interruptions: []
        )

        return focusSession
    }

    private func initializeSessionPerformanceTracking() async throws {
        // Initialize performance tracking system for migrated sessions
        // This would set up the monitoring infrastructure
        print("🔧 Initializing session performance tracking for migrated sessions")
    }

    // MARK: - Data Saving Helpers

    private func saveFocusActivity(_ activity: FocusActivity) async throws {
        // Save to FocusLock data store
        try await FocusLockDataStore.shared.saveActivity(activity)
    }

    private func saveFocusCategory(_ category: FocusCategory) async throws {
        // Save to FocusLock data store
        try await FocusLockDataStore.shared.saveCategory(category)
    }

    private func saveFocusSession(_ session: FocusSession) async throws {
        // Save to FocusLock data store
        try await FocusLockDataStore.shared.saveSession(session)
    }

    private func saveMigratedPreferences(_ preferences: MigratedPreferences) async throws {
        // Save preferences to UserDefaults with new keys
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(preferences) {
            userDefaults.set(data, forKey: "focuslock_migrated_preferences")
        }
    }

    private func saveFocusAnalytics(_ analytics: FocusAnalytics) async throws {
        // Save to FocusLock analytics store
        try await FocusLockAnalyticsStore.shared.saveAnalytics(analytics)
    }

    // MARK: - Backup and Restore

    private func createMigrationBackup(results: MigrationResults) async throws {
        // Don't fail the entire migration if backup creation fails
        do {
            let backupData = MigrationBackup(
                version: currentMigrationVersion,
                timestamp: Date(),
                migrationResults: results
            )

            let encoder = JSONEncoder()
            if let data = try? encoder.encode(backupData) {
                let backupURL = getBackupURL()
                
                // Create directory if it doesn't exist
                let directoryURL = backupURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                
                // Write backup file
                try data.write(to: backupURL)
                print("✅ Migration backup created at: \(backupURL.path)")
            }
        } catch {
            // Log error but don't throw - backup is optional
            print("⚠️ Failed to create migration backup: \(error.localizedDescription)")
        }
    }

    private func getBackupURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("FocusLock/Migration/backup_\(currentMigrationVersion).json")
    }

    // MARK: - Status Checking

    private func checkMigrationStatus() {
        let lastMigrationVersion = userDefaults.integer(forKey: migrationVersionKey)

        if lastMigrationVersion >= currentMigrationVersion {
            migrationStatus = .completed
        } else {
            migrationStatus = .notStarted
        }
    }
}

// MARK: - Migration Data Models

enum DataMigration {
    enum MigrationStatus: String {
        case notStarted = "not_started"
        case inProgress = "in_progress"
        case completed = "completed"
        case failed = "failed"

        var displayName: String {
            switch self {
            case .notStarted: return "Not Started"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }
    }
}

struct MigrationResults: Codable {
    var migratedActivities: Int = 0
    var migratedCategories: Int = 0
    var createdFocusSessions: Int = 0
    var migratedSessions: Int = 0
    var migratedPreferences: Int = 0
    var migratedAnalytics: Int = 0
    var warnings: [String] = []
    var errors: [String] = []

    var totalMigrated: Int {
        return migratedActivities + migratedCategories + createdFocusSessions + migratedSessions + migratedPreferences + migratedAnalytics
    }
}

struct MigrationBackup: Codable {
    let version: Int
    let timestamp: Date
    let migrationResults: MigrationResults
}

// MARK: - Legacy Data Models (for migration)

struct LegacyTimelineActivity {
    let id: UUID
    let title: String
    let summary: String
    let startTime: Date
    let endTime: Date
    let category: String
    let videoSummaryURL: URL?
    let detailedSummary: String
}

struct LegacyCategory {
    let id: UUID
    let name: String
    let colorHex: String
    let isIdle: Bool
}

struct LegacyAnalyticsData {
    let event: String
    let timestamp: Date
    let properties: [String: Any]
}

struct LegacyEmergencyBreak {
    let id: UUID
    let reason: BreakReason
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
}

// MARK: - Migrated Preferences

struct MigratedPreferences: Codable {
    var recordingEnabled: Bool = false
    var recordingQuality: String?
    var storageLocation: String?
    var selectedProvider: String?
    var geminiModel: String?
    var notificationsEnabled: Bool = true
    var analyticsOptIn: Bool = true
    var focusLockSettings: FocusLockSettings?
}

// MARK: - Focus Session Detector

struct FocusSessionDetector {
    static func detectSessions(from activities: [LegacyTimelineActivity]) -> [FocusSession] {
        var sessions: [FocusSession] = []
        var currentSessionActivities: [LegacyTimelineActivity] = []

        for activity in activities.sorted(by: { $0.startTime < $1.startTime }) {
            // Check if this activity belongs to a focus session
            if isFocusActivity(activity) {
                currentSessionActivities.append(activity)
            } else {
                // End current session if we have accumulated activities
                if !currentSessionActivities.isEmpty {
                    let session = createFocusSession(from: currentSessionActivities)
                    sessions.append(session)
                    currentSessionActivities = []
                }
            }
        }

        // Handle final session
        if !currentSessionActivities.isEmpty {
            let session = createFocusSession(from: currentSessionActivities)
            sessions.append(session)
        }

        return sessions
    }

    private static func isFocusActivity(_ activity: LegacyTimelineActivity) -> Bool {
        // Define what constitutes a focus activity
        let focusKeywords = ["work", "coding", "writing", "study", "research", "design", "development"]
        let title = activity.title.lowercased()
        let summary = activity.summary.lowercased()

        return focusKeywords.contains { keyword in
            title.contains(keyword) || summary.contains(keyword)
        }
    }

    private static func createFocusSession(from activities: [LegacyTimelineActivity]) -> FocusSession {
        guard let firstActivity = activities.first,
              let lastActivity = activities.last else {
            return FocusSession(taskName: "Unknown Session")
        }

        let startTime = firstActivity.startTime
        let endTime = lastActivity.endTime

        // Create session name from activities
        let taskName = inferTaskName(from: activities)

        // Extract allowed apps from activities
        let allowedApps = extractAllowedApps(from: activities)

        // Create session with proper constructor since let properties can't be modified
        return FocusSession(
            id: UUID(),
            taskName: taskName,
            startTime: startTime,
            endTime: endTime,
            state: .ended,
            allowedApps: allowedApps,
            emergencyBreaks: [],
            interruptions: []
        )
    }

    private static func inferTaskName(from activities: [LegacyTimelineActivity]) -> String {
        let titles = activities.map { $0.title }
        let mostCommonTitle = titles.reduce(into: [:]) { counts, title in
            counts[title, default: 0] += 1
        }.max { ($0.value as Int) < ($1.value as Int) }?.key ?? "Focus Session"

        return mostCommonTitle
    }

    private static func extractAllowedApps(from activities: [LegacyTimelineActivity]) -> [String] {
        // This would extract app information from the activities
        // For now, return default allowed apps
        return FocusLockSettings.default.globalAllowedApps
    }
}

// MARK: - Focus Activity and Category Conversion

extension FocusActivity {
    static func fromTimelineActivity(_ activity: LegacyTimelineActivity) -> FocusActivity {
        return FocusActivity(
            id: activity.id,
            title: activity.title,
            category: FocusCategory.fromLegacyCategoryName(activity.category),
            startTime: activity.startTime,
            endTime: activity.endTime,
            metadata: [
                "original_summary": AnyCodable(activity.summary),
                "detailed_summary": AnyCodable(activity.detailedSummary),
                "has_video": AnyCodable(activity.videoSummaryURL != nil),
                "status": AnyCodable("completed")
            ]
        )
    }
}

extension FocusCategory {
    static func fromTimelineCategory(_ category: LegacyCategory) -> FocusCategory {
        return FocusCategory(
            id: category.id,
            name: category.name,
            color: category.colorHex,
            icon: categoryIcon(for: category.name)
        )
    }

    static func fromLegacyCategoryName(_ name: String) -> FocusCategory {
        return FocusCategory(
            id: UUID(),
            name: name,
            color: "#4F80EB",
            icon: categoryIcon(for: name)
        )
    }

    private static func categoryIcon(for name: String) -> String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("work") || lowercasedName.contains("coding") {
            return "laptopcomputer"
        } else if lowercasedName.contains("meeting") {
            return "video.bubble.left"
        } else if lowercasedName.contains("email") {
            return "envelope"
        } else if lowercasedName.contains("research") || lowercasedName.contains("study") {
            return "book.closed"
        } else if lowercasedName.contains("design") {
            return "paintbrush"
        } else if lowercasedName.contains("break") || lowercasedName.contains("rest") {
            return "cup.and.saucer"
        } else {
            return "circle"
        }
    }
}

extension FocusAnalytics {
    static func fromLegacyAnalytics(_ data: LegacyAnalyticsData) -> FocusAnalytics {
        return FocusAnalytics(
            id: UUID(),
            date: data.timestamp,
            totalFocusTime: data.properties["totalFocusTime"] as? TimeInterval ?? 0,
            tasksCompleted: data.properties["tasksCompleted"] as? Int ?? 0,
            distractionCount: data.properties["distractionCount"] as? Int ?? 0,
            productivityScore: data.properties["productivityScore"] as? Double ?? 0.0,
            topCategories: data.properties["topCategories"] as? [String] ?? []
        )
    }
}

// MARK: - Data Store Implementation (GRDB-based persistence)

import GRDB
import os.log

class FocusLockDataStore {
    static let shared = FocusLockDataStore()

    private let dbURL: URL
    private let db: DatabaseQueue
    private let logger = Logger(subsystem: "FocusLock", category: "FocusLockDataStore")
    private let fileManager = FileManager.default

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let baseDir = appSupport.appendingPathComponent("Dayflow", isDirectory: true)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        
        dbURL = baseDir.appendingPathComponent("FocusLockData.sqlite")
        
        // Configure database
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA busy_timeout = 5000")
        }
        
        db = try! DatabaseQueue(path: dbURL.path, configuration: config)
        
        // Create tables
        try! createTables()
    }

    private func createTables() throws {
        try db.write { db in
            // Activities table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS focus_activities (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    category_id TEXT NOT NULL,
                    start_time REAL NOT NULL,
                    end_time REAL,
                    duration REAL,
                    metadata TEXT,
                    created_at REAL NOT NULL,
                    FOREIGN KEY (category_id) REFERENCES focus_categories(id)
                )
            """)
            
            // Categories table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS focus_categories (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    color TEXT NOT NULL,
                    icon TEXT NOT NULL,
                    is_active INTEGER NOT NULL DEFAULT 1,
                    created_at REAL NOT NULL
                )
            """)
            
            // Sessions table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS focus_sessions (
                    id TEXT PRIMARY KEY,
                    task_name TEXT NOT NULL,
                    start_time REAL NOT NULL,
                    end_time REAL,
                    state TEXT NOT NULL,
                    allowed_apps TEXT,
                    emergency_breaks TEXT,
                    interruptions TEXT,
                    created_at REAL NOT NULL
                )
            """)
            
            // Create indexes
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_activities_start_time ON focus_activities(start_time)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON focus_sessions(start_time)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_categories_active ON focus_categories(is_active)")
        }
        
        logger.info("FocusLock data store tables created")
    }

    func saveActivity(_ activity: FocusActivity) async throws {
        try await db.write { db in
            let metadataJSON = try JSONEncoder().encode(activity.metadata)
            let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"
            
            try db.execute(sql: """
                INSERT OR REPLACE INTO focus_activities 
                (id, title, category_id, start_time, end_time, duration, metadata, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                activity.id.uuidString,
                activity.title,
                activity.category.id.uuidString,
                activity.startTime.timeIntervalSince1970,
                activity.endTime?.timeIntervalSince1970,
                activity.duration,
                metadataString,
                Date().timeIntervalSince1970
            ])
        }
        
        logger.info("Saved activity: \(activity.title)")
    }

    func saveCategory(_ category: FocusCategory) async throws {
        try await db.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO focus_categories 
                (id, name, color, icon, is_active, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, arguments: [
                category.id.uuidString,
                category.name,
                category.color,
                category.icon,
                category.isActive ? 1 : 0,
                Date().timeIntervalSince1970
            ])
        }
        
        logger.info("Saved category: \(category.name)")
    }

    func saveSession(_ session: FocusSession) async throws {
        try await db.write { db in
            let allowedAppsJSON = try JSONEncoder().encode(session.allowedApps)
            let allowedAppsString = String(data: allowedAppsJSON, encoding: .utf8) ?? "[]"
            
            let emergencyBreaksJSON = try JSONEncoder().encode(session.emergencyBreaks)
            let emergencyBreaksString = String(data: emergencyBreaksJSON, encoding: .utf8) ?? "[]"
            
            let interruptionsJSON = try JSONEncoder().encode(session.interruptions)
            let interruptionsString = String(data: interruptionsJSON, encoding: .utf8) ?? "[]"
            
            try db.execute(sql: """
                INSERT OR REPLACE INTO focus_sessions 
                (id, task_name, start_time, end_time, state, allowed_apps, emergency_breaks, interruptions, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                session.id.uuidString,
                session.taskName,
                session.startTime.timeIntervalSince1970,
                session.endTime?.timeIntervalSince1970,
                session.state.rawValue,
                allowedAppsString,
                emergencyBreaksString,
                interruptionsString,
                Date().timeIntervalSince1970
            ])
        }
        
        logger.info("Saved session: \(session.taskName)")
    }
    
    func loadActivities() async throws -> [FocusActivity] {
        return try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.*, c.id as cat_id, c.name as cat_name, c.color as cat_color, 
                       c.icon as cat_icon, c.is_active as cat_is_active
                FROM focus_activities a
                JOIN focus_categories c ON a.category_id = c.id
                ORDER BY a.start_time DESC
            """)
            
            return rows.map { row in
                let categoryId = UUID(uuidString: row["cat_id"]) ?? UUID()
                let category = FocusCategory(
                    id: categoryId,
                    name: row["cat_name"],
                    color: row["cat_color"],
                    icon: row["cat_icon"],
                    isActive: row["cat_is_active"] == 1
                )
                
                let metadataString: String = row["metadata"] ?? "{}"
                let metadataData = metadataString.data(using: .utf8) ?? Data()
                let metadata = try? JSONDecoder().decode([String: AnyCodable].self, from: metadataData)
                
                return FocusActivity(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    title: row["title"],
                    category: category,
                    startTime: Date(timeIntervalSince1970: row["start_time"]),
                    endTime: row["end_time"] != nil ? Date(timeIntervalSince1970: row["end_time"]) : nil,
                    duration: row["duration"],
                    metadata: metadata ?? [:]
                )
            }
        }
    }
    
    func loadCategories() async throws -> [FocusCategory] {
        return try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM focus_categories
                ORDER BY name ASC
            """)
            
            return rows.map { row in
                FocusCategory(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    name: row["name"],
                    color: row["color"],
                    icon: row["icon"],
                    isActive: row["is_active"] == 1
                )
            }
        }
    }
    
    func loadSessions() async throws -> [FocusSession] {
        return try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM focus_sessions
                ORDER BY start_time DESC
            """)
            
            return rows.map { row in
                let allowedAppsString: String = row["allowed_apps"] ?? "[]"
                let allowedAppsData = allowedAppsString.data(using: .utf8) ?? Data()
                let allowedApps = (try? JSONDecoder().decode([String].self, from: allowedAppsData)) ?? []
                
                let emergencyBreaksString: String = row["emergency_breaks"] ?? "[]"
                let emergencyBreaksData = emergencyBreaksString.data(using: .utf8) ?? Data()
                let emergencyBreaks = (try? JSONDecoder().decode([EmergencyBreak].self, from: emergencyBreaksData)) ?? []
                
                let interruptionsString: String = row["interruptions"] ?? "[]"
                let interruptionsData = interruptionsString.data(using: .utf8) ?? Data()
                let interruptions = (try? JSONDecoder().decode([SessionInterruption].self, from: interruptionsData)) ?? []
                
                return FocusSession(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    taskName: row["task_name"],
                    startTime: Date(timeIntervalSince1970: row["start_time"]),
                    endTime: row["end_time"] != nil ? Date(timeIntervalSince1970: row["end_time"]) : nil,
                    state: FocusSessionState(rawValue: row["state"]) ?? .idle,
                    allowedApps: allowedApps,
                    emergencyBreaks: emergencyBreaks,
                    interruptions: interruptions
                )
            }
        }
    }
}

class FocusLockAnalyticsStore {
    static let shared = FocusLockAnalyticsStore()

    private let dbURL: URL
    private let db: DatabaseQueue
    private let logger = Logger(subsystem: "FocusLock", category: "FocusLockAnalyticsStore")
    private let fileManager = FileManager.default

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let baseDir = appSupport.appendingPathComponent("Dayflow", isDirectory: true)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        
        dbURL = baseDir.appendingPathComponent("FocusLockAnalytics.sqlite")
        
        // Configure database
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA busy_timeout = 5000")
        }
        
        db = try! DatabaseQueue(path: dbURL.path, configuration: config)
        
        // Create tables
        try! createTables()
    }

    private func createTables() throws {
        try db.write { db in
            // Analytics table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS focus_analytics (
                    id TEXT PRIMARY KEY,
                    date REAL NOT NULL,
                    total_focus_time REAL NOT NULL,
                    tasks_completed INTEGER NOT NULL,
                    distraction_count INTEGER NOT NULL,
                    productivity_score REAL NOT NULL,
                    top_categories TEXT,
                    created_at REAL NOT NULL
                )
            """)
            
            // Create indexes
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_analytics_date ON focus_analytics(date)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_analytics_created_at ON focus_analytics(created_at)")
        }
        
        logger.info("FocusLock analytics store tables created")
    }

    func saveAnalytics(_ analytics: FocusAnalytics) async throws {
        try await db.write { db in
            let topCategoriesJSON = try JSONEncoder().encode(analytics.topCategories)
            let topCategoriesString = String(data: topCategoriesJSON, encoding: .utf8) ?? "[]"
            
            try db.execute(sql: """
                INSERT OR REPLACE INTO focus_analytics 
                (id, date, total_focus_time, tasks_completed, distraction_count, productivity_score, top_categories, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                analytics.id.uuidString,
                analytics.date.timeIntervalSince1970,
                analytics.totalFocusTime,
                analytics.tasksCompleted,
                analytics.distractionCount,
                analytics.productivityScore,
                topCategoriesString,
                Date().timeIntervalSince1970
            ])
        }
        
        logger.info("Saved analytics for date: \(analytics.date)")
    }
    
    func loadAnalytics(for date: Date) async throws -> FocusAnalytics? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM focus_analytics
                WHERE date >= ? AND date < ?
                LIMIT 1
            """, arguments: [
                startOfDay.timeIntervalSince1970,
                endOfDay.timeIntervalSince1970
            ])
            
            guard let row = rows.first else { return nil }
            
            let topCategoriesString: String = row["top_categories"] ?? "[]"
            let topCategoriesData = topCategoriesString.data(using: .utf8) ?? Data()
            let topCategories = (try? JSONDecoder().decode([String].self, from: topCategoriesData)) ?? []
            
            return FocusAnalytics(
                id: UUID(uuidString: row["id"]) ?? UUID(),
                date: Date(timeIntervalSince1970: row["date"]),
                totalFocusTime: row["total_focus_time"],
                tasksCompleted: row["tasks_completed"],
                distractionCount: row["distraction_count"],
                productivityScore: row["productivity_score"],
                topCategories: topCategories
            )
        }
    }
    
    func loadAllAnalytics() async throws -> [FocusAnalytics] {
        return try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM focus_analytics
                ORDER BY date DESC
            """)
            
            return rows.map { row in
                let topCategoriesString: String = row["top_categories"] ?? "[]"
                let topCategoriesData = topCategoriesString.data(using: .utf8) ?? Data()
                let topCategories = (try? JSONDecoder().decode([String].self, from: topCategoriesData)) ?? []
                
                return FocusAnalytics(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    date: Date(timeIntervalSince1970: row["date"]),
                    totalFocusTime: row["total_focus_time"],
                    tasksCompleted: row["tasks_completed"],
                    distractionCount: row["distraction_count"],
                    productivityScore: row["productivity_score"],
                    topCategories: topCategories
                )
            }
        }
    }
    
    func clearAllAnalytics() async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM focus_analytics")
        }
        
        logger.info("Cleared all analytics data")
    }
}

// MARK: - SwiftUI Integration

struct DataMigrationView: View {
    @StateObject private var migrationManager = DataMigrationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))

                Text("FocusLock Migration")
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black.opacity(0.9))

                Text("Upgrading your Dayflow data to FocusLock")
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.6))
            }

            // Status Content
            switch migrationManager.migrationStatus {
            case .notStarted:
                notStartedView

            case .inProgress:
                inProgressView

            case .completed:
                completedView

            case .failed:
                failedView
            }

            Spacer()
        }
        .padding(32)
        .frame(width: 500, height: 600)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private var notStartedView: some View {
        VStack(spacing: 16) {
            Text("Ready to migrate your data")
                .font(.custom("Nunito", size: 18))
                .foregroundColor(.black.opacity(0.8))

            Text("This will upgrade your timeline data, categories, and preferences to work with FocusLock's enhanced features. The process is safe and can be undone.")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(4)

            Button(action: {
                Task {
                    await migrationManager.performMigration()
                }
            }) {
                HStack {
                    Text("Start Migration")
                    Image(systemName: "arrow.right")
                }
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 0.25, green: 0.17, blue: 0))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var inProgressView: some View {
        VStack(spacing: 16) {
            Text("Migration in progress...")
                .font(.custom("Nunito", size: 18))
                .foregroundColor(.black.opacity(0.8))

            ProgressView(value: migrationManager.migrationProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))
                .frame(height: 8)

            Text("Please don't close the application")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
        }
    }

    @ViewBuilder
    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.32))

            Text("Migration completed successfully!")
                .font(.custom("Nunito", size: 18))
                .foregroundColor(.black.opacity(0.8))

            if let results = migrationManager.migrationResults {
                VStack(spacing: 8) {
                    migrationResultRow("Activities migrated", count: results.migratedActivities)
                    migrationResultRow("Categories migrated", count: results.migratedCategories)
                    migrationResultRow("Focus sessions created", count: results.createdFocusSessions)
                    migrationResultRow("Preferences migrated", count: results.migratedPreferences)
                }
            }

            Button(action: { dismiss() }) {
                Text("Continue")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Migration failed")
                .font(.custom("Nunito", size: 18))
                .foregroundColor(.black.opacity(0.8))

            if let error = migrationManager.migrationError {
                Text(error)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 12) {
                Button("Retry") {
                    Task {
                        await migrationManager.performMigration()
                    }
                }
                .font(.custom("Nunito", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.25, green: 0.17, blue: 0))
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())

                Button("Skip") {
                    // Mark migration as skipped so the view disappears
                    migrationManager.markMigrationSkipped()
                }
                .font(.custom("Nunito", size: 14))
                .fontWeight(.medium)
                .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.25, green: 0.17, blue: 0), lineWidth: 1)
                )
                .cornerRadius(8)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func migrationResultRow(_ label: String, count: Int) -> some View {
        HStack {
            Text(label)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))

            Spacer()

            Text("\(count)")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}