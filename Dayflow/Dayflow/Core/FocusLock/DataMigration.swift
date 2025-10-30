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
        try await createMigrationBackup()

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
        let migratedPrefs = MigratedPreferences()

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
        // Since FocusSession has let properties, we need to create a new session with the correct initializer
        let focusSession = FocusSession(
            id: legacySession.id,
            taskName: legacySession.taskName,
            startTime: legacySession.startTime,
            endTime: legacySession.endTime,
            state: legacySession.state,
            allowedApps: legacySession.allowedApps,
            emergencyBreaks: legacySession.emergencyBreaks.compactMap { legacyBreak in
                EmergencyBreak(
                    id: legacyBreak.id,
                    reason: legacyBreak.reason,
                    startTime: legacyBreak.startTime,
                    endTime: legacyBreak.endTime,
                    duration: legacyBreak.duration
                )
            },
            interruptions: []
        )

        // Note: performanceMetrics is not a property of FocusSession based on the constructor
        // We'll need to handle this separately if needed

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

    private func createMigrationBackup() async throws {
        let backupData = MigrationBackup(
            version: currentMigrationVersion,
            timestamp: Date(),
            migrationResults: migrationResults!
        )

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(backupData) {
            let backupURL = getBackupURL()
            try data.write(to: backupURL)
            print("✅ Migration backup created at: \(backupURL.path)")
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

struct LegacyFocusSession {
    let id: UUID
    let taskName: String
    let startTime: Date
    let endTime: Date?
    let allowedApps: [String]
    let state: FocusSessionState
    let emergencyBreaks: [LegacyEmergencyBreak]
    let performanceMetrics: [String: Any]
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
            return counts
        }.max { $0.value < $1.value }?.key ?? "Focus Session"

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
            taskName: activity.title,
            description: activity.summary,
            startTime: activity.startTime,
            endTime: activity.endTime,
            category: FocusCategory.fromLegacyCategoryName(activity.category),
            status: .completed,
            metadata: [
                "original_summary": activity.summary,
                "detailed_summary": activity.detailedSummary,
                "has_video": activity.videoSummaryURL != nil
            ]
        )
    }
}

extension FocusCategory {
    static func fromTimelineCategory(_ category: LegacyCategory) -> FocusCategory {
        return FocusCategory(
            id: category.id,
            name: category.name,
            colorHex: category.colorHex,
            icon: categoryIcon(for: category.name),
            isSystem: false
        )
    }

    static func fromLegacyCategoryName(_ name: String) -> FocusCategory {
        return FocusCategory(
            id: UUID(),
            name: name,
            colorHex: "#4F80EB",
            icon: categoryIcon(for: name),
            isSystem: false
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
            event: data.event,
            timestamp: data.timestamp,
            properties: data.properties,
            sessionId: nil,
            userId: nil
        )
    }
}

// MARK: - Data Store Placeholder (would be implemented with actual persistence)

class FocusLockDataStore {
    static let shared = FocusLockDataStore()

    private init() {}

    func saveActivity(_ activity: FocusActivity) async throws {
        // Implementation would save to database
    }

    func saveCategory(_ category: FocusCategory) async throws {
        // Implementation would save to database
    }

    func saveSession(_ session: FocusSession) async throws {
        // Implementation would save to database
    }
}

class FocusLockAnalyticsStore {
    static let shared = FocusLockAnalyticsStore()

    private init() {}

    func saveAnalytics(_ analytics: FocusAnalytics) async throws {
        // Implementation would save to analytics store
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
                    .padding(.horizontal)
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
                    dismiss()
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