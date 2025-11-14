//
//  StorageManager.swift
//  Dayflow
//

import Foundation
import GRDB
import Sentry
import os.log

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = Calendar.current.timeZone
        return formatter
    }()
}

extension Date {
    /// Calculates the "day" based on a 4 AM start time.
    /// Returns the date string (YYYY-MM-DD) and the Date objects for the start and end of that day.
    func getDayInfoFor4AMBoundary() -> (dayString: String, startOfDay: Date, endOfDay: Date) {
        let calendar = Calendar.current
        guard let fourAMToday = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: self) else {
            print("Error: Could not calculate 4 AM for date \(self). Falling back to standard day.")
            let start = calendar.startOfDay(for: self)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (DateFormatter.yyyyMMdd.string(from: start), start, end)
        }

        let startOfDay: Date
        if self < fourAMToday {
            startOfDay = calendar.date(byAdding: .day, value: -1, to: fourAMToday)!
        } else {
            startOfDay = fourAMToday
        }
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let dayString = DateFormatter.yyyyMMdd.string(from: startOfDay)
        return (dayString, startOfDay, endOfDay)
    }
}


/// File + database persistence used by screen‑recorder & Gemini pipeline.
///
/// _No_ `@MainActor` isolation ⇒ can be called from any thread/actor.
/// If you add UI‑touching methods later, isolate **those** individually.
protocol StorageManaging: Sendable {
    // Recording‑chunk lifecycle (Story 1.3: migrated to async + DatabaseManager)
    func nextFileURL() -> URL
    func registerChunk(url: URL) async throws
    func markChunkCompleted(url: URL) async throws
    func markChunkFailed(url: URL) async throws

    // Fetch unprocessed (completed + not yet batched) chunks (Story 1.3: migrated to async + DatabaseManager)
    func fetchUnprocessedChunks(olderThan oldestAllowed: Int) async throws -> [RecordingChunk]
    func fetchChunksInTimeRange(startTs: Int, endTs: Int) async throws -> [RecordingChunk]

    // Analysis‑batch management (Story 1.3: migrated to async + DatabaseManager)
    func saveBatch(startTs: Int, endTs: Int, chunkIds: [Int64]) async throws -> Int64?
    func updateBatchStatus(batchId: Int64, status: String) async throws
    func markBatchFailed(batchId: Int64, reason: String)

    // Record details about all LLM calls for a batch (Story 1.3: migrated to async + DatabaseManager)
    func updateBatchLLMMetadata(batchId: Int64, calls: [LLMCall]) async throws
    func fetchBatchLLMMetadata(batchId: Int64) async throws -> [LLMCall]

    // Timeline‑cards (Story 1.3: migrated to async + DatabaseManager)
    func saveTimelineCardShell(batchId: Int64, card: TimelineCardShell) async throws -> Int64?
    func updateTimelineCardVideoURL(cardId: Int64, videoSummaryURL: String) async throws
    func fetchTimelineCards(forBatch batchId: Int64) async throws -> [TimelineCard]
    func fetchTimelineCard(byId id: Int64) async throws -> TimelineCardWithTimestamps?

    // Timeline Queries (Story 1.3: migrated to async + DatabaseManager)
    func fetchTimelineCards(forDay day: String) async throws -> [TimelineCard]
    func fetchTimelineCardsByTimeRange(from: Date, to: Date) async throws -> [TimelineCard]
    func replaceTimelineCardsInRange(from: Date, to: Date, with: [TimelineCardShell], batchId: Int64) -> (insertedIds: [Int64], deletedVideoPaths: [String])
    func fetchRecentTimelineCardsForDebug(limit: Int) async throws -> [TimelineCardDebugEntry]

    // LLM debug methods (Story 1.3: migrated to async + DatabaseManager)
    func fetchRecentLLMCallsForDebug(limit: Int) async throws -> [LLMCallDebugEntry]
    func fetchRecentAnalysisBatchesForDebug(limit: Int) async throws -> [AnalysisBatchDebugEntry]
    func fetchLLMCallsForBatches(batchIds: [Int64], limit: Int) async throws -> [LLMCallDebugEntry]

    // Note: Transcript storage methods removed in favor of Observations
    
    // NEW: Observations Storage
    func saveObservations(batchId: Int64, observations: [Observation])
    func fetchObservations(batchId: Int64) -> [Observation]
    func fetchObservations(startTs: Int, endTs: Int) -> [Observation]
    func fetchObservationsByTimeRange(from: Date, to: Date) -> [Observation]

    // Helper for GeminiService – map file paths → timestamps
    func getTimestampsForVideoFiles(paths: [String]) -> [String: (startTs: Int, endTs: Int)]
    
    // Reprocessing Methods
    func deleteTimelineCards(forDay day: String) -> [String]  // Returns video paths to clean up
    func deleteTimelineCards(forBatchIds batchIds: [Int64]) -> [String]
    func deleteObservations(forBatchIds batchIds: [Int64])
    func resetBatchStatuses(forDay day: String) -> [Int64]  // Returns affected batch IDs
    func resetBatchStatuses(forBatchIds batchIds: [Int64]) -> [Int64]
    func fetchBatches(forDay day: String) -> [(id: Int64, startTs: Int, endTs: Int, status: String)]

    /// Chunks that belong to one batch, already sorted.
    func chunksForBatch(_ batchId: Int64) async throws -> [RecordingChunk]

    /// All batches, newest first
    func allBatches() async throws -> [(id: Int64, start: Int, end: Int, status: String)]
}


// NEW: Observation struct for first-class transcript storage
struct Observation: Codable, Sendable {
    let id: Int64?
    let batchId: Int64
    let startTs: Int
    let endTs: Int
    let observation: String
    let metadata: String?
    let llmModel: String?
    let createdAt: Date?
}

// Re-add Distraction struct, as it's used by TimelineCard
struct Distraction: Codable, Sendable, Identifiable {
    let id: UUID
    let startTime: String
    let endTime: String
    let title: String
    let summary: String
    let videoSummaryURL: String? // Optional link to video summary for the distraction

    // Custom decoder to handle missing 'id'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try to decode 'id', if not found or nil, assign a new UUID
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.startTime = try container.decode(String.self, forKey: .startTime)
        self.endTime = try container.decode(String.self, forKey: .endTime)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.videoSummaryURL = try container.decodeIfPresent(String.self, forKey: .videoSummaryURL)
    }

    // Add explicit init to maintain memberwise initializer if needed elsewhere,
    // though Codable synthesis might handle this. It's good practice.
    init(id: UUID = UUID(), startTime: String, endTime: String, title: String, summary: String, videoSummaryURL: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.summary = summary
        self.videoSummaryURL = videoSummaryURL
    }

    // CodingKeys needed for custom decoder
    private enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, title, summary, videoSummaryURL
    }
}

struct TimelineCard: Codable, Sendable, Identifiable {
    var id = UUID()
    let batchId: Int64? // Tracks source batch for retry functionality
    let startTimestamp: String
    let endTimestamp: String
    let category: String
    let subcategory: String
    let title: String
    let summary: String
    let detailedSummary: String
    let day: String
    let distractions: [Distraction]?
    let videoSummaryURL: String? // Optional link to primary video summary
    let otherVideoSummaryURLs: [String]? // For merged cards, subsequent video URLs
    let appSites: AppSites?
}

/// Metadata about a single LLM request/response cycle
struct LLMCall: Codable, Sendable {
    let timestamp: Date?
    let latency: TimeInterval?
    let input: String?
    let output: String?
}

// DB record for llm_calls table
struct LLMCallDBRecord: Sendable {
    let batchId: Int64?
    let callGroupId: String?
    let attempt: Int
    let provider: String
    let model: String?
    let operation: String
    let status: String // "success" | "failure"
    let latencyMs: Int?
    let httpStatus: Int?
    let requestMethod: String?
    let requestURL: String?
    let requestHeadersJSON: String?
    let requestBody: String?
    let responseHeadersJSON: String?
    let responseBody: String?
    let errorDomain: String?
    let errorCode: Int?
    let errorMessage: String?
}

struct TimelineCardDebugEntry: Sendable {
    let createdAt: Date?
    let batchId: Int64?
    let day: String
    let startTime: String
    let endTime: String
    let category: String
    let subcategory: String?
    let title: String
    let summary: String?
    let detailedSummary: String?
}

struct LLMCallDebugEntry: Sendable {
    let createdAt: Date?
    let batchId: Int64?
    let callGroupId: String?
    let attempt: Int
    let provider: String
    let model: String?
    let operation: String
    let status: String
    let latencyMs: Int?
    let httpStatus: Int?
    let requestMethod: String?
    let requestURL: String?
    let requestBody: String?
    let responseBody: String?
    let errorMessage: String?
}

// Add TimelineCardShell struct for the new save function
struct TimelineCardShell: Sendable {
    let startTimestamp: String
    let endTimestamp: String
    let category: String
    let subcategory: String
    let title: String
    let summary: String
    let detailedSummary: String
    let distractions: [Distraction]? // Keep this, it's part of the initial save
    let appSites: AppSites?
    // No videoSummaryURL here, as it's added later
    // No batchId here, as it's passed as a separate parameter to the save function
}

// New metadata envelope to support multiple fields under one JSON column
private struct TimelineMetadata: Codable {
    let distractions: [Distraction]?
    let appSites: AppSites?
}

struct AnalysisBatchDebugEntry: Sendable {
    let id: Int64
    let status: String
    let startTs: Int
    let endTs: Int
    let createdAt: Date?
    let reason: String?
}

// Extended TimelineCard with timestamp fields for internal use
struct TimelineCardWithTimestamps: Sendable {
    let id: Int64
    let startTimestamp: String
    let endTimestamp: String
    let startTs: Int
    let endTs: Int
    let category: String
    let subcategory: String
    let title: String
    let summary: String
    let detailedSummary: String
    let day: String
    let distractions: [Distraction]?
    let videoSummaryURL: String?
}


final class StorageManager: StorageManaging, @unchecked Sendable {
    static let shared = StorageManager()

    private let dbURL: URL
    private let db: DatabasePool
    private let fileMgr = FileManager.default
    private let root: URL
    var recordingsRoot: URL { root }
    
    // Connection monitoring
    private var connectionCount: Int {
        get {
            UserDefaults.standard.integer(forKey: "storageManager_connectionCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "storageManager_connectionCount")
        }
    }
    
    private var lastConnectionCheck: Date {
        get {
            if let timestamp = UserDefaults.standard.double(forKey: "storageManager_lastConnectionCheck") as TimeInterval?,
               timestamp > 0 {
                return Date(timeIntervalSince1970: timestamp)
            }
            return Date()
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "storageManager_lastConnectionCheck")
        }
    }

    // TEMPORARY DEBUG: Remove after identifying slow queries
    private let debugSlowQueries = true
    private let slowThresholdMs: Double = 100  // Log anything over 100ms

    // Dedicated queue for database writes to prevent main thread blocking
    private let dbWriteQueue = DispatchQueue(label: "com.dayflow.storage.writes", qos: .utility)

    private init() {
        UserDefaultsMigrator.migrateIfNeeded()
        StoragePathMigrator.migrateIfNeeded()

        let appSupport = fileMgr.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let baseDir = appSupport.appendingPathComponent("Dayflow", isDirectory: true)
        let recordingsDir = baseDir.appendingPathComponent("recordings", isDirectory: true)

        // Ensure directories exist before opening database
        try? fileMgr.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? fileMgr.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        // Create Second Brain file system storage directories
        let journalsDir = baseDir.appendingPathComponent("journals", isDirectory: true)
        let decisionsDir = baseDir.appendingPathComponent("decisions", isDirectory: true)
        let insightsDir = baseDir.appendingPathComponent("insights", isDirectory: true)
        
        try? fileMgr.createDirectory(at: journalsDir, withIntermediateDirectories: true)
        try? fileMgr.createDirectory(at: decisionsDir, withIntermediateDirectories: true)
        try? fileMgr.createDirectory(at: insightsDir, withIntermediateDirectories: true)

        root = recordingsDir
        dbURL = baseDir.appendingPathComponent("chunks.sqlite")

        StorageManager.migrateDatabaseLocationIfNeeded(
            fileManager: fileMgr,
            legacyRecordingsDir: recordingsDir,
            newDatabaseURL: dbURL
        )

        // Configure database with WAL mode for better performance and safety
        var config = Configuration()
        config.maximumReaderCount = 5
        
        // CRITICAL: Set QoS to userInitiated to prevent priority inversion
        // when database is accessed from main thread during UI updates
        config.qos = .userInitiated
        
        config.prepareDatabase { db in
            if !db.configuration.readonly {
                try? db.execute(sql: "PRAGMA journal_mode = WAL")
                try? db.execute(sql: "PRAGMA synchronous = NORMAL")
            }
            try? db.execute(sql: "PRAGMA busy_timeout = 5000")
        }
        
        // Track connection pool usage for monitoring
        // Note: defaultTransactionKind is now automatically managed by GRDB
        #if DEBUG
        // Add connection monitoring in debug builds
        // Trace is set on the database instance after creation, not on config
        #endif

        db = try! DatabasePool(path: dbURL.path, configuration: config)

        // TEMPORARY DEBUG: SQL statement tracing (via configuration)
        #if DEBUG
        try? db.write { db in
            db.trace { event in
                if case .profile(let statement, let duration) = event, duration > 0.1 {
                    print("📊 SLOW SQL (\(Int(duration * 1000))ms): \(statement)")
                }
            }
        }
        #endif

        migrate()
        migrateLegacyChunkPathsIfNeeded()

        // Run initial purge, then schedule hourly
        purgeIfNeeded()
        TimelapseStorageManager.shared.purgeIfNeeded()
        startPurgeScheduler()
        
        // Run initial database optimization check, then schedule weekly
        optimizeDatabaseIfNeeded()
        startDatabaseOptimizationScheduler()
        
        // Start connection monitoring
        startConnectionMonitoring()
    }
    
    private func startConnectionMonitoring() {
        // Monitor connection pool usage periodically
        let monitorQueue = DispatchQueue(label: "com.dayflow.storage.connectionMonitor", qos: .utility)
        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now() + 300, repeating: 300) // Every 5 minutes
        timer.setEventHandler { [weak self] in
            self?.checkConnectionHealth()
        }
        timer.resume()
    }
    
    private func checkConnectionHealth() {
        let logger = Logger(subsystem: "Dayflow", category: "StorageManager")
        
        // Check if we're holding too many connections
        // GRDB's DatabasePool manages connections internally, but we can monitor usage patterns
        do {
            // Perform a simple query to verify connection health
            _ = try db.read { db in
                try db.execute(sql: "SELECT 1")
            }
            
            #if DEBUG
            logger.debug("Connection pool health check passed")
            #endif
        } catch {
            logger.error("Connection pool health check failed: \(error.localizedDescription)")
        }
        
        // Check for connection leaks by monitoring query patterns
        // In a real implementation, you'd track connection usage over time
        lastConnectionCheck = Date()
    }

    // TEMPORARY DEBUG: Timing helpers for database operations
    private func timedWrite<T>(_ label: String, _ block: (Database) throws -> T) throws -> T {
        let callStart = CFAbsoluteTimeGetCurrent()
        var execStart: CFAbsoluteTime = 0
        var execEnd: CFAbsoluteTime = 0

        let writeBreadcrumb = Breadcrumb(level: .debug, category: "database")
        writeBreadcrumb.message = "DB write: \(label)"
        writeBreadcrumb.type = "debug"
        SentryHelper.addBreadcrumb(writeBreadcrumb)

        do {
            let result = try db.write { db in
                execStart = CFAbsoluteTimeGetCurrent()
                defer { execEnd = CFAbsoluteTimeGetCurrent() }
                return try block(db)
            }

            let waitMs = max(0, (execStart - callStart) * 1000)
            let execMs = max(0, (execEnd - execStart) * 1000)

            if debugSlowQueries && (execMs > slowThresholdMs || waitMs > slowThresholdMs) {
                print("⚠️ SLOW WRITE [\(label)]: wait=\(Int(waitMs))ms exec=\(Int(execMs))ms")

                let slowWriteBreadcrumb = Breadcrumb(level: .warning, category: "database")
                slowWriteBreadcrumb.message = "SLOW DB write: \(label)"
                slowWriteBreadcrumb.data = [
                    "duration_ms": Int((waitMs + execMs).rounded()),
                    "wait_ms": Int(waitMs.rounded()),
                    "exec_ms": Int(execMs.rounded())
                ]
                slowWriteBreadcrumb.type = "error"
                SentryHelper.addBreadcrumb(slowWriteBreadcrumb)
            }

            return result
        } catch {
            if execStart == 0 {
                execStart = CFAbsoluteTimeGetCurrent()
            }
            if execEnd == 0 {
                execEnd = CFAbsoluteTimeGetCurrent()
            }
            let waitMs = max(0, (execStart - callStart) * 1000)
            let execMs = max(0, (execEnd - execStart) * 1000)

            let slowWriteBreadcrumb = Breadcrumb(level: .error, category: "database")
            slowWriteBreadcrumb.message = "FAILED DB write: \(label)"
            slowWriteBreadcrumb.data = [
                "wait_ms": Int(waitMs.rounded()),
                "exec_ms": Int(execMs.rounded()),
                "error": "\(error)"
            ]
            slowWriteBreadcrumb.type = "error"
            SentryHelper.addBreadcrumb(slowWriteBreadcrumb)
            throw error
        }
    }

    private func timedRead<T>(_ label: String, _ block: (Database) throws -> T) throws -> T {
        let callStart = CFAbsoluteTimeGetCurrent()
        var execStart: CFAbsoluteTime = 0
        var execEnd: CFAbsoluteTime = 0

        let readBreadcrumb = Breadcrumb(level: .debug, category: "database")
        readBreadcrumb.message = "DB read: \(label)"
        readBreadcrumb.type = "debug"
        SentryHelper.addBreadcrumb(readBreadcrumb)

        do {
            let result = try db.read { db in
                execStart = CFAbsoluteTimeGetCurrent()
                defer { execEnd = CFAbsoluteTimeGetCurrent() }
                return try block(db)
            }

            let waitMs = max(0, (execStart - callStart) * 1000)
            let execMs = max(0, (execEnd - execStart) * 1000)

            if debugSlowQueries && (execMs > slowThresholdMs || waitMs > slowThresholdMs) {
                print("⚠️ SLOW READ [\(label)]: wait=\(Int(waitMs))ms exec=\(Int(execMs))ms")

                let slowReadBreadcrumb = Breadcrumb(level: .warning, category: "database")
                slowReadBreadcrumb.message = "SLOW DB read: \(label)"
                slowReadBreadcrumb.data = [
                    "duration_ms": Int((waitMs + execMs).rounded()),
                    "wait_ms": Int(waitMs.rounded()),
                    "exec_ms": Int(execMs.rounded())
                ]
                slowReadBreadcrumb.type = "error"
                SentryHelper.addBreadcrumb(slowReadBreadcrumb)
            }

            return result
        } catch {
            if execStart == 0 {
                execStart = CFAbsoluteTimeGetCurrent()
            }
            if execEnd == 0 {
                execEnd = CFAbsoluteTimeGetCurrent()
            }
            let waitMs = max(0, (execStart - callStart) * 1000)
            let execMs = max(0, (execEnd - execStart) * 1000)

            let slowReadBreadcrumb = Breadcrumb(level: .error, category: "database")
            slowReadBreadcrumb.message = "FAILED DB read: \(label)"
            slowReadBreadcrumb.data = [
                "wait_ms": Int(waitMs.rounded()),
                "exec_ms": Int(execMs.rounded()),
                "error": "\(error)"
            ]
            slowReadBreadcrumb.type = "error"
            SentryHelper.addBreadcrumb(slowReadBreadcrumb)
            throw error
        }
    }

    private func migrate() {
        try? timedWrite("migrate") { db in
            // Create all tables with their final schema
            try db.execute(sql: """
                -- Chunks table: stores video recording segments
                CREATE TABLE IF NOT EXISTS chunks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    start_ts INTEGER NOT NULL,
                    end_ts INTEGER NOT NULL,
                    file_url TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'recording',
                    is_deleted INTEGER DEFAULT 0
                );
                CREATE INDEX IF NOT EXISTS idx_chunks_status ON chunks(status);
                CREATE INDEX IF NOT EXISTS idx_chunks_start_ts ON chunks(start_ts);
                
                -- Analysis batches: groups chunks for LLM processing
                CREATE TABLE IF NOT EXISTS analysis_batches (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    batch_start_ts INTEGER NOT NULL,
                    batch_end_ts INTEGER NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pending',
                    reason TEXT,
                    llm_metadata TEXT,
                    detailed_transcription TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_analysis_batches_status ON analysis_batches(status);
                
                -- Junction table linking batches to chunks
                CREATE TABLE IF NOT EXISTS batch_chunks (
                    batch_id INTEGER NOT NULL REFERENCES analysis_batches(id) ON DELETE CASCADE,
                    chunk_id INTEGER NOT NULL REFERENCES chunks(id) ON DELETE RESTRICT,
                    PRIMARY KEY (batch_id, chunk_id)
                );
                
                -- Timeline cards: stores activity summaries
                CREATE TABLE IF NOT EXISTS timeline_cards (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    batch_id INTEGER REFERENCES analysis_batches(id) ON DELETE CASCADE,
                    start TEXT NOT NULL,       -- Clock time (e.g., "2:30 PM")
                    end TEXT NOT NULL,         -- Clock time (e.g., "3:45 PM")
                    start_ts INTEGER,          -- Unix timestamp
                    end_ts INTEGER,            -- Unix timestamp
                    day DATE NOT NULL,
                    title TEXT NOT NULL,
                    summary TEXT,
                    category TEXT NOT NULL,
                    subcategory TEXT,
                    detailed_summary TEXT,
                    metadata TEXT,             -- For distractions JSON
                    video_summary_url TEXT,    -- Link to video summary on filesystem
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_timeline_cards_day ON timeline_cards(day);
                CREATE INDEX IF NOT EXISTS idx_timeline_cards_start_ts ON timeline_cards(start_ts);
                CREATE INDEX IF NOT EXISTS idx_timeline_cards_time_range ON timeline_cards(start_ts, end_ts);
                
                -- Observations: stores LLM transcription outputs
                CREATE TABLE IF NOT EXISTS observations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    batch_id INTEGER NOT NULL REFERENCES analysis_batches(id) ON DELETE CASCADE,
                    start_ts INTEGER NOT NULL,
                    end_ts INTEGER NOT NULL,
                    observation TEXT NOT NULL,
                    metadata TEXT,
                    llm_model TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_observations_batch_id ON observations(batch_id);
                CREATE INDEX IF NOT EXISTS idx_observations_start_ts ON observations(start_ts);
                CREATE INDEX IF NOT EXISTS idx_observations_time_range ON observations(start_ts, end_ts);
            """)

            // LLM calls logging table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS llm_calls (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    batch_id INTEGER NULL,
                    call_group_id TEXT NULL,
                    attempt INTEGER NOT NULL DEFAULT 1,
                    provider TEXT NOT NULL,
                    model TEXT NULL,
                    operation TEXT NOT NULL,
                    status TEXT NOT NULL CHECK(status IN ('success','failure')),
                    latency_ms INTEGER NULL,
                    http_status INTEGER NULL,
                    request_method TEXT NULL,
                    request_url TEXT NULL,
                    request_headers TEXT NULL,
                    request_body TEXT NULL,
                    response_headers TEXT NULL,
                    response_body TEXT NULL,
                    error_domain TEXT NULL,
                    error_code INTEGER NULL,
                    error_message TEXT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_llm_calls_created ON llm_calls(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_llm_calls_group ON llm_calls(call_group_id, attempt);
                CREATE INDEX IF NOT EXISTS idx_llm_calls_batch ON llm_calls(batch_id);
            """)

            // Migration: Add soft delete column to timeline_cards if it doesn't exist
            let timelineCardsColumns = try db.columns(in: "timeline_cards").map { $0.name }
            if !timelineCardsColumns.contains("is_deleted") {
                try db.execute(sql: """
                    ALTER TABLE timeline_cards ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;
                """)

                // Create composite partial indexes for common query patterns
                try db.execute(sql: """
                    CREATE INDEX IF NOT EXISTS idx_timeline_cards_active_start_ts
                    ON timeline_cards(start_ts)
                    WHERE is_deleted = 0;
                """)

                try db.execute(sql: """
                    CREATE INDEX IF NOT EXISTS idx_timeline_cards_active_batch
                    ON timeline_cards(batch_id)
                    WHERE is_deleted = 0;
                """)

                print("✅ Added is_deleted column and composite indexes to timeline_cards")
            }
            
            // Second Brain Platform Tables
            try db.execute(sql: """
                -- Journal entries: stores daily journal metadata
                CREATE TABLE IF NOT EXISTS journal_entries (
                    id TEXT PRIMARY KEY,
                    date DATE NOT NULL UNIQUE,
                    generated_summary TEXT,
                    execution_score REAL,
                    metadata TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(date DESC);
                CREATE INDEX IF NOT EXISTS idx_journal_entries_created ON journal_entries(created_at DESC);
                
                -- Journal sections: stores individual sections of a journal entry
                CREATE TABLE IF NOT EXISTS journal_sections (
                    id TEXT PRIMARY KEY,
                    journal_id TEXT NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
                    section_type TEXT NOT NULL,
                    title TEXT NOT NULL,
                    content TEXT,
                    order_index INTEGER NOT NULL,
                    is_custom INTEGER NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_journal_sections_journal ON journal_sections(journal_id, order_index);
                CREATE INDEX IF NOT EXISTS idx_journal_sections_type ON journal_sections(section_type);
                
                -- Todos: smart task management with priorities
                CREATE TABLE IF NOT EXISTS todos (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    project TEXT,
                    priority TEXT NOT NULL,
                    scheduled_time DATETIME,
                    duration INTEGER,
                    context TEXT,
                    source TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pending',
                    dependencies TEXT,
                    subtasks TEXT,
                    metadata TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    completed_at DATETIME,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_todos_status ON todos(status);
                CREATE INDEX IF NOT EXISTS idx_todos_priority ON todos(priority, status);
                CREATE INDEX IF NOT EXISTS idx_todos_scheduled ON todos(scheduled_time);
                CREATE INDEX IF NOT EXISTS idx_todos_project ON todos(project, status);
                CREATE INDEX IF NOT EXISTS idx_todos_created ON todos(created_at DESC);
                
                -- Decisions log: track decisions with context
                CREATE TABLE IF NOT EXISTS decisions_log (
                    id TEXT PRIMARY KEY,
                    question TEXT NOT NULL,
                    options TEXT,
                    tradeoffs TEXT,
                    owner TEXT,
                    deadline DATETIME,
                    decision TEXT,
                    outcome TEXT,
                    metadata TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    decided_at DATETIME,
                    reviewed_at DATETIME
                );
                CREATE INDEX IF NOT EXISTS idx_decisions_created ON decisions_log(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_decisions_deadline ON decisions_log(deadline);
                CREATE INDEX IF NOT EXISTS idx_decisions_owner ON decisions_log(owner);
                
                -- Conversations log: track meaningful conversations
                CREATE TABLE IF NOT EXISTS conversations_log (
                    id TEXT PRIMARY KEY,
                    person_name TEXT NOT NULL,
                    context TEXT,
                    key_points TEXT,
                    decisions TEXT,
                    follow_ups TEXT,
                    sentiment TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    conversation_date DATE NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_conversations_date ON conversations_log(conversation_date DESC);
                CREATE INDEX IF NOT EXISTS idx_conversations_person ON conversations_log(person_name);
                
                -- User context: profile data and preferences
                CREATE TABLE IF NOT EXISTS user_context (
                    id TEXT PRIMARY KEY,
                    key TEXT NOT NULL UNIQUE,
                    value TEXT NOT NULL,
                    category TEXT,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_user_context_category ON user_context(category);
                
                -- Proactive alerts: coaching and intelligence alerts
                CREATE TABLE IF NOT EXISTS proactive_alerts (
                    id TEXT PRIMARY KEY,
                    alert_type TEXT NOT NULL,
                    message TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    context TEXT,
                    is_dismissed INTEGER NOT NULL DEFAULT 0,
                    dismissed_at DATETIME,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_proactive_alerts_active ON proactive_alerts(created_at DESC) WHERE is_dismissed = 0;
                CREATE INDEX IF NOT EXISTS idx_proactive_alerts_type ON proactive_alerts(alert_type, created_at DESC);
                
                -- Context switches: track task switching behavior
                CREATE TABLE IF NOT EXISTS context_switches (
                    id TEXT PRIMARY KEY,
                    from_activity TEXT,
                    to_activity TEXT,
                    from_app TEXT,
                    to_app TEXT,
                    duration_seconds INTEGER,
                    switch_reason TEXT,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE INDEX IF NOT EXISTS idx_context_switches_created ON context_switches(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_context_switches_date ON context_switches(DATE(created_at));
            """)
            
            print("✅ Second Brain platform tables created successfully")
        }
    }


    func nextFileURL() -> URL {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmmssSSS"
        return root.appendingPathComponent("\(df.string(from: Date())).mp4")
    }

    /// Register a new recording chunk in the database (Story 1.3: async + DatabaseManager)
    func registerChunk(url: URL) async throws {
        let ts = Int(Date().timeIntervalSince1970)
        let path = url.path

        try await DatabaseManager.shared.write { db in
            try db.execute(
                sql: "INSERT INTO chunks(start_ts, end_ts, file_url, status) VALUES (?, ?, ?, 'recording')",
                arguments: [ts, ts + 60, path]
            )
        }
    }

    /// Mark a recording chunk as completed (Story 1.3: async + DatabaseManager)
    func markChunkCompleted(url: URL) async throws {
        let end = Int(Date().timeIntervalSince1970)
        let path = url.path

        try await DatabaseManager.shared.write { db in
            try db.execute(
                sql: "UPDATE chunks SET end_ts = ?, status = 'completed' WHERE file_url = ?",
                arguments: [end, path]
            )
        }
    }

    /// Mark a recording chunk as failed and delete it (Story 1.3: async + DatabaseManager)
    func markChunkFailed(url: URL) async throws {
        let path = url.path

        // Delete from database first
        try await DatabaseManager.shared.write { db in
            try db.execute(sql: "DELETE FROM chunks WHERE file_url = ?", arguments: [path])
        }

        // Then delete the file from disk
        try? fileMgr.removeItem(at: url)
    }


    /// Fetch unprocessed chunks (Story 1.3: async + DatabaseManager)
    func fetchUnprocessedChunks(olderThan oldestAllowed: Int) async throws -> [RecordingChunk] {
        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM chunks
                WHERE start_ts >= ?
                  AND status = 'completed'
                  AND (is_deleted = 0 OR is_deleted IS NULL)
                  AND id NOT IN (SELECT chunk_id FROM batch_chunks)
                ORDER BY start_ts ASC
            """, arguments: [oldestAllowed])
            .map { row in
                RecordingChunk(
                    id: row["id"],
                    startTs: row["start_ts"],
                    endTs: row["end_ts"],
                    fileUrl: row["file_url"],
                    status: row["status"]
                )
            }
        }
    }

    /// Save a new batch with associated chunks (Story 1.3: async + DatabaseManager, uses transaction for atomicity)
    func saveBatch(startTs: Int, endTs: Int, chunkIds: [Int64]) async throws -> Int64? {
        guard !chunkIds.isEmpty else { return nil }

        // Use transaction to ensure atomicity of batch + chunk associations
        let batchID = try await DatabaseManager.shared.transaction { db in
            try db.execute(
                sql: "INSERT INTO analysis_batches(batch_start_ts, batch_end_ts) VALUES (?, ?)",
                arguments: [startTs, endTs]
            )
            let batchID = db.lastInsertedRowID

            for id in chunkIds {
                try db.execute(
                    sql: "INSERT INTO batch_chunks(batch_id, chunk_id) VALUES (?, ?)",
                    arguments: [batchID, id]
                )
            }

            return batchID
        }

        return batchID == 0 ? nil : batchID
    }

    /// Update batch status (Story 1.3: async + DatabaseManager)
    func updateBatchStatus(batchId: Int64, status: String) async throws {
        try await DatabaseManager.shared.write { db in
            try db.execute(
                sql: "UPDATE analysis_batches SET status = ? WHERE id = ?",
                arguments: [status, batchId]
            )
        }
    }

    func markBatchFailed(batchId: Int64, reason: String) {
        // Perform database write asynchronously to avoid blocking caller thread
        dbWriteQueue.async { [weak self] in
            try? self?.timedWrite("markBatchFailed") { db in
                try db.execute(sql: "UPDATE analysis_batches SET status = 'failed', reason = ? WHERE id = ?", arguments: [reason, batchId])
            }
        }
    }

    /// Update batch LLM metadata (Story 1.3: async + DatabaseManager)
    func updateBatchLLMMetadata(batchId: Int64, calls: [LLMCall]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try encoder.encode(calls),
              let json = String(data: data, encoding: .utf8) else {
            throw DatabaseError.invalidConfiguration
        }

        try await DatabaseManager.shared.write { db in
            try db.execute(
                sql: "UPDATE analysis_batches SET llm_metadata = ? WHERE id = ?",
                arguments: [json, batchId]
            )
        }
    }

    /// Fetch LLM metadata for a batch (Story 1.3: async + DatabaseManager)
    func fetchBatchLLMMetadata(batchId: Int64) async throws -> [LLMCall] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try await DatabaseManager.shared.read { db in
            if let row = try Row.fetchOne(
                db,
                sql: "SELECT llm_metadata FROM analysis_batches WHERE id = ?",
                arguments: [batchId]
            ),
               let json: String = row["llm_metadata"],
               let data = json.data(using: .utf8) {
                return try decoder.decode([LLMCall].self, from: data)
            }
            return []
        }
    }

    /// Chunks that belong to one batch, already sorted.
    /// Updated to use DatabaseManager for thread-safe access (Story 1.1)
    func chunksForBatch(_ batchId: Int64) async throws -> [RecordingChunk] {
        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT c.* FROM batch_chunks bc
                JOIN chunks c ON c.id = bc.chunk_id
                WHERE bc.batch_id = ?
                  AND (c.is_deleted = 0 OR c.is_deleted IS NULL)
                ORDER BY c.start_ts ASC
                """, arguments: [batchId]
            ).map { r in
                RecordingChunk(id: r["id"], startTs: r["start_ts"], endTs: r["end_ts"],
                               fileUrl: r["file_url"], status: r["status"])
            }
        }
    }

    /// Helper to get the batch start timestamp for date calculations (Story 1.3: async + DatabaseManager)
    private func getBatchStartTimestamp(batchId: Int64) async throws -> Int? {
        return try await DatabaseManager.shared.read { db in
            try Int.fetchOne(db, sql: """
                SELECT batch_start_ts FROM analysis_batches WHERE id = ?
            """, arguments: [batchId])
        }
    }
    
    /// Fetch chunks that overlap with a specific time range (Story 1.3: async + DatabaseManager)
    func fetchChunksInTimeRange(startTs: Int, endTs: Int) async throws -> [RecordingChunk] {
        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM chunks
                WHERE status = 'completed'
                  AND (is_deleted = 0 OR is_deleted IS NULL)
                  AND ((start_ts <= ? AND end_ts >= ?)
                       OR (start_ts >= ? AND start_ts <= ?)
                       OR (end_ts >= ? AND end_ts <= ?))
                ORDER BY start_ts ASC
            """, arguments: [endTs, startTs, startTs, endTs, startTs, endTs])
            .map { r in
                RecordingChunk(
                    id: r["id"],
                    startTs: r["start_ts"],
                    endTs: r["end_ts"],
                    fileUrl: r["file_url"],
                    status: r["status"]
                )
            }
        }
    }


    /// Save a timeline card shell (Story 1.3: async + DatabaseManager)
    func saveTimelineCardShell(batchId: Int64, card: TimelineCardShell) async throws -> Int64? {
        let encoder = JSONEncoder()

        // Get the batch's actual start timestamp to use as the base date
        guard let batchStartTs = try await getBatchStartTimestamp(batchId: batchId) else {
            return nil
        }
        let baseDate = Date(timeIntervalSince1970: TimeInterval(batchStartTs))

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startTime = timeFormatter.date(from: card.startTimestamp),
              let endTime = timeFormatter.date(from: card.endTimestamp) else {
            return nil
        }

        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        guard let startHour = startComponents.hour, let startMinute = startComponents.minute else { return nil }

        var startDate = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: baseDate) ?? baseDate

        // If the parsed time is between midnight and 4 AM, and it's earlier than baseDate,
        // disambiguate whether it's same day (before batch) or next day (after midnight crossing)
        if startHour < 4 && startDate < baseDate {
            let nextDayStartDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate

            // Pick whichever is closer to batch start time
            let sameDayDistance = abs(startDate.timeIntervalSince(baseDate))
            let nextDayDistance = abs(nextDayStartDate.timeIntervalSince(baseDate))

            if nextDayDistance < sameDayDistance {
                // Next day is closer - legitimate midnight crossing
                startDate = nextDayStartDate
            }
            // Otherwise keep same day (LLM provided time before batch started)
        }

        let startTs = Int(startDate.timeIntervalSince1970)

        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let endHour = endComponents.hour, let endMinute = endComponents.minute else { return nil }

        var endDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: baseDate) ?? baseDate

        // Disambiguate end time day using same logic as start time
        if endHour < 4 && endDate < baseDate {
            let nextDayEndDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate

            let sameDayDistance = abs(endDate.timeIntervalSince(baseDate))
            let nextDayDistance = abs(nextDayEndDate.timeIntervalSince(baseDate))

            if nextDayDistance < sameDayDistance {
                endDate = nextDayEndDate
            }
        }

        // Handle midnight crossing: if end time is before start time, it must be the next day
        if endDate < startDate {
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }

        let endTs = Int(endDate.timeIntervalSince1970)

        // Encode metadata as an object for forward-compatibility
        let meta = TimelineMetadata(distractions: card.distractions, appSites: card.appSites)
        let metadataString: String? = (try? encoder.encode(meta)).flatMap { String(data: $0, encoding: .utf8) }

        // Calculate the day string using 4 AM boundary rules
        let (dayString, _, _) = startDate.getDayInfoFor4AMBoundary()

        // Write to database using DatabaseManager
        let lastId = try await DatabaseManager.shared.write { db in
            try db.execute(sql: """
                INSERT INTO timeline_cards(
                    batch_id, start, end, start_ts, end_ts, day, title,
                    summary, category, subcategory, detailed_summary, metadata
                    -- video_summary_url is omitted here
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                batchId, card.startTimestamp, card.endTimestamp, startTs, endTs, dayString, card.title,
                card.summary, card.category, card.subcategory, card.detailedSummary, metadataString
            ])
            return db.lastInsertedRowID
        }

        return lastId
    }

    /// Update timeline card video URL (Story 1.3: async + DatabaseManager)
    func updateTimelineCardVideoURL(cardId: Int64, videoSummaryURL: String) async throws {
        try await DatabaseManager.shared.write { db in
            try db.execute(sql: """
                UPDATE timeline_cards
                SET video_summary_url = ?
                WHERE id = ?
            """, arguments: [videoSummaryURL, cardId])
        }
    }

    /// Fetch timeline cards for a batch (Story 1.3: async + DatabaseManager)
    func fetchTimelineCards(forBatch batchId: Int64) async throws -> [TimelineCard] {
        let decoder = JSONDecoder()
        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM timeline_cards
                WHERE batch_id = ?
                  AND is_deleted = 0
                ORDER BY start ASC
            """, arguments: [batchId]).map { row in
                var distractions: [Distraction]? = nil
                var appSites: AppSites? = nil
                if let metadataString: String = row["metadata"],
                   let jsonData = metadataString.data(using: .utf8) {
                    if let meta = try? decoder.decode(TimelineMetadata.self, from: jsonData) {
                        distractions = meta.distractions
                        appSites = meta.appSites
                    } else if let legacy = try? decoder.decode([Distraction].self, from: jsonData) {
                        distractions = legacy
                    }
                }
                return TimelineCard(
                    batchId: batchId,
                    startTimestamp: row["start"] ?? "",
                    endTimestamp: row["end"] ?? "",
                    category: row["category"],
                    subcategory: row["subcategory"],
                    title: row["title"],
                    summary: row["summary"],
                    detailedSummary: row["detailed_summary"],
                    day: row["day"],
                    distractions: distractions,
                    videoSummaryURL: row["video_summary_url"],
                    otherVideoSummaryURLs: nil,
                    appSites: appSites
                )
            }
        }
    }

    // All batches, newest first
    /// Updated to use DatabaseManager for thread-safe access (Story 1.1)
    func allBatches() async throws -> [(id: Int64, start: Int, end: Int, status: String)] {
        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql:
                "SELECT id, batch_start_ts, batch_end_ts, status FROM analysis_batches ORDER BY id DESC"
            ).map { row in
                (row["id"], row["batch_start_ts"], row["batch_end_ts"], row["status"])
            }
        }
    }

    /// Fetch recent analysis batches for debug (Story 1.3: async + DatabaseManager)
    func fetchRecentAnalysisBatchesForDebug(limit: Int) async throws -> [AnalysisBatchDebugEntry] {
        guard limit > 0 else { return [] }

        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, status, batch_start_ts, batch_end_ts, created_at, reason
                FROM analysis_batches
                ORDER BY id DESC
                LIMIT ?
            """, arguments: [limit]).map { row in
                AnalysisBatchDebugEntry(
                    id: row["id"],
                    status: row["status"] ?? "unknown",
                    startTs: row["batch_start_ts"] ?? 0,
                    endTs: row["batch_end_ts"] ?? 0,
                    createdAt: row["created_at"],
                    reason: row["reason"]
                )
            }
        }
    }


    /// Fetch timeline cards for a specific day (Story 1.3: async + DatabaseManager)
    func fetchTimelineCards(forDay day: String) async throws -> [TimelineCard] {
        let decoder = JSONDecoder()

        guard let dayDate = dateFormatter.date(from: day) else {
            return []
        }

        let calendar = Calendar.current

        // Get 4 AM of the given day as the start
        var startComponents = calendar.dateComponents([.year, .month, .day], from: dayDate)
        startComponents.hour = 4
        startComponents.minute = 0
        startComponents.second = 0
        guard let dayStart = calendar.date(from: startComponents) else { return [] }

        // Get 4 AM of the next day as the end
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayDate) else { return [] }
        var endComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
        endComponents.hour = 4
        endComponents.minute = 0
        endComponents.second = 0
        guard let dayEnd = calendar.date(from: endComponents) else { return [] }

        let startTs = Int(dayStart.timeIntervalSince1970)
        let endTs = Int(dayEnd.timeIntervalSince1970)

        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM timeline_cards
                WHERE start_ts >= ? AND start_ts < ?
                  AND is_deleted = 0
                ORDER BY start_ts ASC, start ASC
            """, arguments: [startTs, endTs])
            .map { row in
                // Decode metadata JSON (supports object or legacy array)
                var distractions: [Distraction]? = nil
                var appSites: AppSites? = nil
                if let metadataString: String = row["metadata"],
                   let jsonData = metadataString.data(using: .utf8) {
                    if let meta = try? decoder.decode(TimelineMetadata.self, from: jsonData) {
                        distractions = meta.distractions
                        appSites = meta.appSites
                    } else if let legacy = try? decoder.decode([Distraction].self, from: jsonData) {
                        distractions = legacy
                    }
                }

                // Create TimelineCard instance using renamed columns
                return TimelineCard(
                    batchId: row["batch_id"],
                    startTimestamp: row["start"] ?? "",
                    endTimestamp: row["end"] ?? "",
                    category: row["category"],
                    subcategory: row["subcategory"],
                    title: row["title"],
                    summary: row["summary"],
                    detailedSummary: row["detailed_summary"],
                    day: row["day"],
                    distractions: distractions,
                    videoSummaryURL: row["video_summary_url"],
                    otherVideoSummaryURLs: nil,
                    appSites: appSites
                )
            }
        }
    }

    /// Fetch timeline cards by time range (Story 1.3: async + DatabaseManager)
    func fetchTimelineCardsByTimeRange(from: Date, to: Date) async throws -> [TimelineCard] {
        let decoder = JSONDecoder()
        let fromTs = Int(from.timeIntervalSince1970)
        let toTs = Int(to.timeIntervalSince1970)

        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM timeline_cards
                WHERE ((start_ts < ? AND end_ts > ?)
                   OR (start_ts >= ? AND start_ts < ?))
                  AND is_deleted = 0
                ORDER BY start_ts ASC
            """, arguments: [toTs, fromTs, fromTs, toTs])
            .map { row in
                // Decode metadata JSON (supports object or legacy array)
                var distractions: [Distraction]? = nil
                var appSites: AppSites? = nil
                if let metadataString: String = row["metadata"],
                   let jsonData = metadataString.data(using: .utf8) {
                    if let meta = try? decoder.decode(TimelineMetadata.self, from: jsonData) {
                        distractions = meta.distractions
                        appSites = meta.appSites
                    } else if let legacy = try? decoder.decode([Distraction].self, from: jsonData) {
                        distractions = legacy
                    }
                }

                // Create TimelineCard instance using renamed columns
                return TimelineCard(
                    batchId: row["batch_id"],
                    startTimestamp: row["start"] ?? "",
                    endTimestamp: row["end"] ?? "",
                    category: row["category"],
                    subcategory: row["subcategory"],
                    title: row["title"],
                    summary: row["summary"],
                    detailedSummary: row["detailed_summary"],
                    day: row["day"],
                    distractions: distractions,
                    videoSummaryURL: row["video_summary_url"],
                    otherVideoSummaryURLs: nil,
                    appSites: appSites
                )
            }
        }
    }

    /// Fetch recent timeline cards for debug (Story 1.3: async + DatabaseManager)
    func fetchRecentTimelineCardsForDebug(limit: Int) async throws -> [TimelineCardDebugEntry] {
        guard limit > 0 else { return [] }

        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT batch_id, day, start, end, category, subcategory, title, summary, detailed_summary, created_at
                FROM timeline_cards
                WHERE is_deleted = 0
                ORDER BY created_at DESC, id DESC
                LIMIT ?
            """, arguments: [limit]).map { row in
                TimelineCardDebugEntry(
                    createdAt: row["created_at"],
                    batchId: row["batch_id"],
                    day: row["day"] ?? "",
                    startTime: row["start"] ?? "",
                    endTime: row["end"] ?? "",
                    category: row["category"],
                    subcategory: row["subcategory"],
                    title: row["title"],
                    summary: row["summary"],
                    detailedSummary: row["detailed_summary"]
                )
            }
        }
    }

    /// Fetch recent LLM calls for debug (Story 1.3: async + DatabaseManager)
    func fetchRecentLLMCallsForDebug(limit: Int) async throws -> [LLMCallDebugEntry] {
        guard limit > 0 else { return [] }

        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT created_at, batch_id, call_group_id, attempt, provider, model, operation, status, latency_ms, http_status, request_method, request_url, request_body, response_body, error_message
                FROM llm_calls
                ORDER BY created_at DESC, id DESC
                LIMIT ?
            """, arguments: [limit]).map { row in
                LLMCallDebugEntry(
                    createdAt: row["created_at"],
                    batchId: row["batch_id"],
                    callGroupId: row["call_group_id"],
                    attempt: row["attempt"] ?? 0,
                    provider: row["provider"] ?? "",
                    model: row["model"],
                    operation: row["operation"] ?? "",
                    status: row["status"] ?? "",
                    latencyMs: row["latency_ms"],
                    httpStatus: row["http_status"],
                    requestMethod: row["request_method"],
                    requestURL: row["request_url"],
                    requestBody: row["request_body"],
                    responseBody: row["response_body"],
                    errorMessage: row["error_message"]
                )
            }
        }
    }

    func updateStorageLimit(bytes: Int64) {
        let previous = StoragePreferences.recordingsLimitBytes
        StoragePreferences.recordingsLimitBytes = bytes

        if bytes < previous {
            purgeIfNeeded()
        }
    }

    /// Fetch LLM calls for specific batches (Story 1.3: async + DatabaseManager)
    func fetchLLMCallsForBatches(batchIds: [Int64], limit: Int) async throws -> [LLMCallDebugEntry] {
        guard !batchIds.isEmpty, limit > 0 else { return [] }

        // Create SQL placeholders for batch IDs
        let placeholders = Array(repeating: "?", count: batchIds.count).joined(separator: ",")

        return try await DatabaseManager.shared.read { db in
            try Row.fetchAll(db, sql: """
                SELECT created_at, batch_id, call_group_id, attempt, provider, model, operation, status, latency_ms, http_status, request_method, request_url, request_body, response_body, error_message
                FROM llm_calls
                WHERE batch_id IN (\(placeholders))
                ORDER BY created_at DESC, id DESC
                LIMIT ?
            """, arguments: StatementArguments(batchIds + [Int64(limit)])).map { row in
                LLMCallDebugEntry(
                    createdAt: row["created_at"],
                    batchId: row["batch_id"],
                    callGroupId: row["call_group_id"],
                    attempt: row["attempt"] ?? 0,
                    provider: row["provider"] ?? "",
                    model: row["model"],
                    operation: row["operation"] ?? "",
                    status: row["status"] ?? "",
                    latencyMs: row["latency_ms"],
                    httpStatus: row["http_status"],
                    requestMethod: row["request_method"],
                    requestURL: row["request_url"],
                    requestBody: row["request_body"],
                    responseBody: row["response_body"],
                    errorMessage: row["error_message"]
                )
            }
        }
    }

    /// Fetch a specific timeline card by ID including timestamp fields (Story 1.3: async + DatabaseManager)
    func fetchTimelineCard(byId id: Int64) async throws -> TimelineCardWithTimestamps? {
        let decoder = JSONDecoder()

        return try await DatabaseManager.shared.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT * FROM timeline_cards
                WHERE id = ?
                  AND is_deleted = 0
            """, arguments: [id]) else { return nil }

            // Decode distractions from metadata JSON
            var distractions: [Distraction]? = nil
            if let metadataString: String = row["metadata"],
               let jsonData = metadataString.data(using: .utf8) {
                if let meta = try? decoder.decode(TimelineMetadata.self, from: jsonData) {
                    distractions = meta.distractions
                } else if let legacy = try? decoder.decode([Distraction].self, from: jsonData) {
                    distractions = legacy
                }
            }

            return TimelineCardWithTimestamps(
                id: id,
                startTimestamp: row["start"] ?? "",
                endTimestamp: row["end"] ?? "",
                startTs: row["start_ts"] ?? 0,
                endTs: row["end_ts"] ?? 0,
                category: row["category"],
                subcategory: row["subcategory"],
                title: row["title"],
                summary: row["summary"],
                detailedSummary: row["detailed_summary"],
                day: row["day"],
                distractions: distractions,
                videoSummaryURL: row["video_summary_url"]
            )
        }
    }
    
    func replaceTimelineCardsInRange(from: Date, to: Date, with newCards: [TimelineCardShell], batchId: Int64) -> (insertedIds: [Int64], deletedVideoPaths: [String]) {
        let fromTs = Int(from.timeIntervalSince1970)
        let toTs = Int(to.timeIntervalSince1970)
        
        
        let encoder = JSONEncoder()
        var insertedIds: [Int64] = []
        var videoPaths: [String] = []
        
        // Setup date formatter for parsing clock times
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        try? timedWrite("replaceTimelineCardsInRange(\(newCards.count)_cards)") { db in
            // First, fetch the video paths that will be soft-deleted
            let videoRows = try Row.fetchAll(db, sql: """
                SELECT video_summary_url FROM timeline_cards
                WHERE ((start_ts < ? AND end_ts > ?)
                   OR (start_ts >= ? AND start_ts < ?))
                   AND video_summary_url IS NOT NULL
                   AND is_deleted = 0
            """, arguments: [toTs, fromTs, fromTs, toTs])

            videoPaths = videoRows.compactMap { $0["video_summary_url"] as? String }

            // Fetch the cards that will be deleted for debugging
            let cardsToDelete = try Row.fetchAll(db, sql: """
                SELECT id, start, end, title FROM timeline_cards
                WHERE ((start_ts < ? AND end_ts > ?)
                   OR (start_ts >= ? AND start_ts < ?))
                   AND is_deleted = 0
            """, arguments: [toTs, fromTs, fromTs, toTs])

            for card in cardsToDelete {
                _ = card["id"]
                _ = card["start"]
                _ = card["end"]
                _ = card["title"]
            }

            // Soft delete existing cards in the range using timestamp columns
            try? db.execute(sql: """
                UPDATE timeline_cards
                SET is_deleted = 1
                WHERE ((start_ts < ? AND end_ts > ?)
                   OR (start_ts >= ? AND start_ts < ?))
                   AND is_deleted = 0
            """, arguments: [toTs, fromTs, fromTs, toTs])

            // Verify soft deletion (count remaining active cards)
            let remainingCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM timeline_cards
                WHERE ((start_ts < ? AND end_ts > ?)
                   OR (start_ts >= ? AND start_ts < ?))
                   AND is_deleted = 0
            """, arguments: [toTs, fromTs, fromTs, toTs]) ?? 0
            
            if remainingCount > 0 {
            } else {
            }
            
            // Insert new cards
            for card in newCards {
                // Encode metadata object with distractions and appSites
                let meta = TimelineMetadata(distractions: card.distractions, appSites: card.appSites)
                let metadataString: String? = (try? encoder.encode(meta)).flatMap { String(data: $0, encoding: .utf8) }

                // Resolve clock-only timestamps by picking the nearest day to the window midpoint
                let calendar = Calendar.current
                let anchor = from.addingTimeInterval(to.timeIntervalSince(from) / 2.0)

                let resolveClock: (Int, Int) -> Date = { hour, minute in
                    guard let sameDay = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: anchor) else {
                        return anchor
                    }
                    let previousDay = calendar.date(byAdding: .day, value: -1, to: sameDay) ?? sameDay
                    let nextDay = calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay

                    let candidates = [previousDay, sameDay, nextDay]
                    return candidates.min { lhs, rhs in
                        abs(lhs.timeIntervalSince(anchor)) < abs(rhs.timeIntervalSince(anchor))
                    } ?? sameDay
                }

                guard let startTime = timeFormatter.date(from: card.startTimestamp),
                      let endTime = timeFormatter.date(from: card.endTimestamp) else {
                    continue
                }

                let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                guard let startHour = startComponents.hour, let startMinute = startComponents.minute else { continue }

                let startDate = resolveClock(startHour, startMinute)

                let startTs = Int(startDate.timeIntervalSince1970)

                let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                guard let endHour = endComponents.hour, let endMinute = endComponents.minute else { continue }

                var endDate = resolveClock(endHour, endMinute)

                // Handle midnight crossing: if end time is before start time, it must be the next day
                if endDate < startDate {
                    endDate = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
                }

                let endTs = Int(endDate.timeIntervalSince1970)

                // Calculate the day string using 4 AM boundary rules
                let (dayString, _, _) = startDate.getDayInfoFor4AMBoundary()

                try db.execute(sql: """
                    INSERT INTO timeline_cards(
                        batch_id, start, end, start_ts, end_ts, day, title,
                        summary, category, subcategory, detailed_summary, metadata
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    batchId, card.startTimestamp, card.endTimestamp, startTs, endTs, dayString, card.title,
                    card.summary, card.category, card.subcategory, card.detailedSummary, metadataString
                ])
                
                // Capture the ID of the inserted card
                let insertedId = db.lastInsertedRowID
                insertedIds.append(insertedId)
            }
        }
        
        return (insertedIds, videoPaths)
    }

    // Note: Transcript storage methods removed in favor of Observations table
    
    
    func saveObservations(batchId: Int64, observations: [Observation]) {
        guard !observations.isEmpty else { return }
        try? timedWrite("saveObservations(\(observations.count)_items)") { db in
            for obs in observations {
                try db.execute(sql: """
                    INSERT INTO observations(
                        batch_id, start_ts, end_ts, observation, metadata, llm_model
                    )
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [
                    batchId, obs.startTs, obs.endTs, obs.observation, 
                    obs.metadata, obs.llmModel
                ])
            }
        }
    }
    
    func fetchObservations(batchId: Int64) -> [Observation] {
        (try? timedRead("fetchObservations(batchId)") { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM observations 
                WHERE batch_id = ? 
                ORDER BY start_ts ASC
            """, arguments: [batchId]).map { row in
                Observation(
                    id: row["id"],
                    batchId: row["batch_id"],
                    startTs: row["start_ts"],
                    endTs: row["end_ts"],
                    observation: row["observation"],
                    metadata: row["metadata"],
                    llmModel: row["llm_model"],
                    createdAt: row["created_at"]
                )
            }
        }) ?? []
    }
    
    func fetchObservationsByTimeRange(from: Date, to: Date) -> [Observation] {
        let fromTs = Int(from.timeIntervalSince1970)
        let toTs = Int(to.timeIntervalSince1970)
        
        return (try? db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM observations 
                WHERE (start_ts < ? AND end_ts > ?) 
                   OR (start_ts >= ? AND start_ts < ?)
                ORDER BY start_ts ASC
            """, arguments: [toTs, fromTs, fromTs, toTs]).map { row in
                Observation(
                    id: row["id"],
                    batchId: row["batch_id"],
                    startTs: row["start_ts"],
                    endTs: row["end_ts"],
                    observation: row["observation"],
                    metadata: row["metadata"],
                    llmModel: row["llm_model"],
                    createdAt: row["created_at"]
                )
            }
        }) ?? []
    }
    
    
    /// Get chunk files for a batch (Story 1.3: async + DatabaseManager)
    func getChunkFilesForBatch(batchId: Int64) async throws -> [String] {
        return try await DatabaseManager.shared.read { db in
            let sql = """
                SELECT c.file_url
                FROM chunks c
                JOIN batch_chunks bc ON c.id = bc.chunk_id
                WHERE bc.batch_id = ?
                  AND (c.is_deleted = 0 OR c.is_deleted IS NULL)
                ORDER BY c.start_ts
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [batchId])
            return rows.compactMap { $0["file_url"] as? String }
        }
    }
    
    func updateBatch(_ batchId: Int64, status: String, reason: String? = nil) {
        try? db.write { db in
            let sql = """
                UPDATE analysis_batches
                SET status = ?, reason = ?
                WHERE id = ?
            """
            try db.execute(sql: sql, arguments: [status, reason, batchId])
        }
    }
    
    func updateBatchMetadata(_ batchId: Int64, metadata: String) {
        try? db.write { db in
            let sql = """
                UPDATE analysis_batches
                SET llm_metadata = ?
                WHERE id = ?
            """
            try db.execute(sql: sql, arguments: [metadata, batchId])
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Insert an LLM call record (Story 1.3: async + DatabaseManager)
    func insertLLMCall(_ rec: LLMCallDBRecord) async throws {
        try await DatabaseManager.shared.write { db in
            try db.execute(sql: """
                INSERT INTO llm_calls (
                    batch_id, call_group_id, attempt, provider, model, operation,
                    status, latency_ms, http_status, request_method, request_url,
                    request_headers, request_body, response_headers, response_body,
                    error_domain, error_code, error_message
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                rec.batchId,
                rec.callGroupId,
                rec.attempt,
                rec.provider,
                rec.model,
                rec.operation,
                rec.status,
                rec.latencyMs,
                rec.httpStatus,
                rec.requestMethod,
                rec.requestURL,
                rec.requestHeadersJSON,
                rec.requestBody,
                rec.responseHeadersJSON,
                rec.responseBody,
                rec.errorDomain,
                rec.errorCode,
                rec.errorMessage
            ])
        }
    }
    
    func fetchObservations(startTs: Int, endTs: Int) -> [Observation] {
        (try? db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM observations 
                WHERE start_ts >= ? AND end_ts <= ?
                ORDER BY start_ts ASC
            """, arguments: [startTs, endTs]).map { row in
                Observation(
                    id: row["id"],
                    batchId: row["batch_id"],
                    startTs: row["start_ts"],
                    endTs: row["end_ts"],
                    observation: row["observation"],
                    metadata: row["metadata"],
                    llmModel: row["llm_model"],
                    createdAt: row["created_at"]
                )
            }
        }) ?? []
    }

    func getTimestampsForVideoFiles(paths: [String]) -> [String: (startTs: Int, endTs: Int)] {
        guard !paths.isEmpty else { return [:] }
        var out: [String: (Int, Int)] = [:]
        let placeholders = Array(repeating: "?", count: paths.count).joined(separator: ",")
        let sql = "SELECT file_url, start_ts, end_ts FROM chunks WHERE file_url IN (\(placeholders)) AND (is_deleted = 0 OR is_deleted IS NULL)"
        try? db.read { db in
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(paths))
            for row in rows {
                if let path: String = row["file_url"],
                   let start: Int  = row["start_ts"],
                   let end:   Int  = row["end_ts"] {
                    out[path] = (start, end)
                }
            }
        }
        return out
    }

    
    func deleteTimelineCards(forDay day: String) -> [String] {
        var videoPaths: [String] = []
        
        guard let dayDate = dateFormatter.date(from: day) else {
            return []
        }
        
        let calendar = Calendar.current
        
        // Get 4 AM of the given day as the start
        var startComponents = calendar.dateComponents([.year, .month, .day], from: dayDate)
        startComponents.hour = 4
        startComponents.minute = 0
        startComponents.second = 0
        guard let dayStart = calendar.date(from: startComponents) else { return [] }
        
        // Get 4 AM of the next day as the end
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayDate) else { return [] }
        var endComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
        endComponents.hour = 4
        endComponents.minute = 0
        endComponents.second = 0
        guard let dayEnd = calendar.date(from: endComponents) else { return [] }
        
        let startTs = Int(dayStart.timeIntervalSince1970)
        let endTs = Int(dayEnd.timeIntervalSince1970)

        try? timedWrite("deleteTimelineCards(forDay:\(day))") { db in
            // First fetch all video paths before soft deletion
            let rows = try Row.fetchAll(db, sql: """
                SELECT video_summary_url FROM timeline_cards
                WHERE start_ts >= ? AND start_ts < ?
                  AND video_summary_url IS NOT NULL
                  AND is_deleted = 0
            """, arguments: [startTs, endTs])

            videoPaths = rows.compactMap { $0["video_summary_url"] as? String }

            // Soft delete the timeline cards by setting is_deleted = 1
            try db.execute(sql: """
                UPDATE timeline_cards
                SET is_deleted = 1
                WHERE start_ts >= ? AND start_ts < ?
                  AND is_deleted = 0
            """, arguments: [startTs, endTs])
        }
        
        return videoPaths
    }

    func deleteTimelineCards(forBatchIds batchIds: [Int64]) -> [String] {
        guard !batchIds.isEmpty else { return [] }
        var videoPaths: [String] = []
        let placeholders = Array(repeating: "?", count: batchIds.count).joined(separator: ",")

        do {
            try timedWrite("deleteTimelineCards(forBatchIds:\(batchIds.count))") { db in
                // Fetch video paths for active records only
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT video_summary_url
                        FROM timeline_cards
                        WHERE batch_id IN (\(placeholders))
                          AND video_summary_url IS NOT NULL
                          AND is_deleted = 0
                    """,
                    arguments: StatementArguments(batchIds)
                )

                videoPaths = rows.compactMap { $0["video_summary_url"] as? String }

                // Soft delete the records
                try db.execute(
                    sql: """
                        UPDATE timeline_cards
                        SET is_deleted = 1
                        WHERE batch_id IN (\(placeholders))
                          AND is_deleted = 0
                    """,
                    arguments: StatementArguments(batchIds)
                )
            }
        } catch {
            print("deleteTimelineCards(forBatchIds:) failed: \(error)")
        }

        return videoPaths
    }

    func deleteObservations(forBatchIds batchIds: [Int64]) {
        guard !batchIds.isEmpty else { return }
        
        try? db.write { db in
            let placeholders = Array(repeating: "?", count: batchIds.count).joined(separator: ",")
            try db.execute(sql: """
                DELETE FROM observations WHERE batch_id IN (\(placeholders))
            """, arguments: StatementArguments(batchIds))
        }
    }
    
    func resetBatchStatuses(forDay day: String) -> [Int64] {
        var affectedBatchIds: [Int64] = []
        
        // Calculate day boundaries (4 AM to 4 AM)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let dayDate = formatter.date(from: day) else { return [] }
        
        let calendar = Calendar.current
        guard let startOfDay = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: dayDate) else { return [] }
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let startTs = Int(startOfDay.timeIntervalSince1970)
        let endTs = Int(endOfDay.timeIntervalSince1970)
        
        try? db.write { db in
            // Fetch batch IDs first
            let rows = try Row.fetchAll(db, sql: """
                SELECT id FROM analysis_batches
                WHERE batch_start_ts >= ? AND batch_end_ts <= ?
                  AND status IN ('completed', 'failed', 'processing', 'analyzed')
            """, arguments: [startTs, endTs])
            
            affectedBatchIds = rows.compactMap { $0["id"] as? Int64 }
            
            // Reset their status to pending
            if !affectedBatchIds.isEmpty {
                let placeholders = Array(repeating: "?", count: affectedBatchIds.count).joined(separator: ",")
                try db.execute(sql: """
                    UPDATE analysis_batches
                    SET status = 'pending', reason = NULL, llm_metadata = NULL
                    WHERE id IN (\(placeholders))
                """, arguments: StatementArguments(affectedBatchIds))
            }
        }
        
        return affectedBatchIds
    }

    func resetBatchStatuses(forBatchIds batchIds: [Int64]) -> [Int64] {
        guard !batchIds.isEmpty else { return [] }
        var affectedBatchIds: [Int64] = []
        let placeholders = Array(repeating: "?", count: batchIds.count).joined(separator: ",")

        do {
            try timedWrite("resetBatchStatuses(forBatchIds:\(batchIds.count))") { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT id FROM analysis_batches
                        WHERE id IN (\(placeholders))
                    """,
                    arguments: StatementArguments(batchIds)
                )

                affectedBatchIds = rows.compactMap { $0["id"] as? Int64 }
                guard !affectedBatchIds.isEmpty else { return }

                let affectedPlaceholders = Array(repeating: "?", count: affectedBatchIds.count).joined(separator: ",")
                try db.execute(
                    sql: """
                        UPDATE analysis_batches
                        SET status = 'pending', reason = NULL, llm_metadata = NULL
                        WHERE id IN (\(affectedPlaceholders))
                    """,
                    arguments: StatementArguments(affectedBatchIds)
                )
            }
        } catch {
            print("resetBatchStatuses(forBatchIds:) failed: \(error)")
        }

        return affectedBatchIds
    }
    
    func fetchBatches(forDay day: String) -> [(id: Int64, startTs: Int, endTs: Int, status: String)] {
        // Calculate day boundaries (4 AM to 4 AM)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let dayDate = formatter.date(from: day) else { return [] }
        
        let calendar = Calendar.current
        guard let startOfDay = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: dayDate) else { return [] }
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let startTs = Int(startOfDay.timeIntervalSince1970)
        let endTs = Int(endOfDay.timeIntervalSince1970)
        
        return (try? db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, batch_start_ts, batch_end_ts, status FROM analysis_batches
                WHERE batch_start_ts >= ? AND batch_end_ts <= ?
                ORDER BY batch_start_ts ASC
            """, arguments: [startTs, endTs]).map { row in
                (
                    id: row["id"] as? Int64 ?? 0,
                    startTs: Int(row["batch_start_ts"] as? Int64 ?? 0),
                    endTs: Int(row["batch_end_ts"] as? Int64 ?? 0),
                    status: row["status"] as? String ?? ""
                )
            }
        }) ?? []
    }
    
    func resetSpecificBatchStatuses(batchIds: [Int64]) {
        guard !batchIds.isEmpty else { return }
        
        try? db.write { db in
            let placeholders = Array(repeating: "?", count: batchIds.count).joined(separator: ",")
            try db.execute(sql: """
                UPDATE analysis_batches
                SET status = 'pending', reason = NULL, llm_metadata = NULL
                WHERE id IN (\(placeholders))
            """, arguments: StatementArguments(batchIds))
        }
    }
    
    // MARK: - Second Brain Platform Operations
    
    // MARK: Journal Operations
    
    func saveJournal(_ journal: EnhancedDailyJournal) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let journalId = journal.id.uuidString
        let metadataJSON = (try? encoder.encode(journal.metadata)).flatMap { String(data: $0, encoding: .utf8) }
        
        try timedWrite("saveJournal") { db in
            // Insert or replace journal entry
            try db.execute(sql: """
                INSERT OR REPLACE INTO journal_entries (
                    id, date, generated_summary, execution_score, metadata, updated_at
                ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            """, arguments: [
                journalId,
                DateFormatter.yyyyMMdd.string(from: journal.date),
                journal.generatedSummary,
                journal.executionScore,
                metadataJSON
            ])
            
            // Delete existing sections for this journal
            try db.execute(sql: "DELETE FROM journal_sections WHERE journal_id = ?", arguments: [journalId])
            
            // Insert sections
            for section in journal.sections {
                try db.execute(sql: """
                    INSERT INTO journal_sections (
                        id, journal_id, section_type, title, content, order_index, is_custom
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    section.id.uuidString,
                    journalId,
                    section.type.rawValue,
                    section.title,
                    section.content,
                    section.order,
                    section.isCustom ? 1 : 0
                ])
            }
        }
        
        return journalId
    }
    
    func loadJournal(forDate date: Date) throws -> EnhancedDailyJournal? {
        let dayString = DateFormatter.yyyyMMdd.string(from: date)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try timedRead("loadJournal") { db in
            // Fetch journal entry
            guard let journalRow = try Row.fetchOne(db, sql: """
                SELECT * FROM journal_entries WHERE date = ?
            """, arguments: [dayString]) else {
                return nil
            }
            
            let journalId: String = journalRow["id"]
            
            // Fetch sections
            let sectionRows = try Row.fetchAll(db, sql: """
                SELECT * FROM journal_sections
                WHERE journal_id = ?
                ORDER BY order_index ASC
            """, arguments: [journalId])
            
            let sections = sectionRows.map { row -> JournalSection in
                let sectionTypeRaw: String = row["section_type"]
                let sectionType = JournalSectionType(rawValue: sectionTypeRaw) ?? .daySummary
                
                return JournalSection(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    type: sectionType,
                    title: row["title"],
                    content: row["content"] ?? "",
                    order: row["order_index"],
                    isCustom: (row["is_custom"] as? Int64 ?? 0) != 0
                )
            }
            
            // Parse metadata
            var metadata = JournalMetadata()
            if let metadataString: String = journalRow["metadata"],
               let metadataData = metadataString.data(using: .utf8),
               let decodedMetadata = try? decoder.decode(JournalMetadata.self, from: metadataData) {
                metadata = decodedMetadata
            }
            
            return EnhancedDailyJournal(
                id: UUID(uuidString: journalId) ?? UUID(),
                date: date,
                sections: sections,
                generatedSummary: journalRow["generated_summary"] ?? "",
                executionScore: journalRow["execution_score"] ?? 5.0,
                metadata: metadata
            )
        }
    }
    
    func deleteJournal(id: UUID) throws {
        try timedWrite("deleteJournal") { db in
            try db.execute(sql: "DELETE FROM journal_entries WHERE id = ?", arguments: [id.uuidString])
        }
    }
    
    func fetchJournals(limit: Int = 30) throws -> [EnhancedDailyJournal] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try timedRead("fetchJournals") { db in
            let journalRows = try Row.fetchAll(db, sql: """
                SELECT * FROM journal_entries
                ORDER BY date DESC
                LIMIT ?
            """, arguments: [limit])
            
            return try journalRows.compactMap { journalRow -> EnhancedDailyJournal? in
                let journalId: String = journalRow["id"]
                let dateString: String = journalRow["date"]
                
                guard let date = DateFormatter.yyyyMMdd.date(from: dateString) else {
                    return nil
                }
                
                // Fetch sections
                let sectionRows = try Row.fetchAll(db, sql: """
                    SELECT * FROM journal_sections
                    WHERE journal_id = ?
                    ORDER BY order_index ASC
                """, arguments: [journalId])
                
                let sections = sectionRows.map { row -> JournalSection in
                    let sectionTypeRaw: String = row["section_type"]
                    let sectionType = JournalSectionType(rawValue: sectionTypeRaw) ?? .daySummary
                    
                    return JournalSection(
                        id: UUID(uuidString: row["id"]) ?? UUID(),
                        type: sectionType,
                        title: row["title"],
                        content: row["content"] ?? "",
                        order: row["order_index"],
                        isCustom: (row["is_custom"] as? Int64 ?? 0) != 0
                    )
                }
                
                // Parse metadata
                var metadata = JournalMetadata()
                if let metadataString: String = journalRow["metadata"],
                   let metadataData = metadataString.data(using: .utf8),
                   let decodedMetadata = try? decoder.decode(JournalMetadata.self, from: metadataData) {
                    metadata = decodedMetadata
                }
                
                return EnhancedDailyJournal(
                    id: UUID(uuidString: journalId) ?? UUID(),
                    date: date,
                    sections: sections,
                    generatedSummary: journalRow["generated_summary"] ?? "",
                    executionScore: journalRow["execution_score"] ?? 5.0,
                    metadata: metadata
                )
            }
        }
    }
    
    // MARK: Todo Operations
    
    func saveTodo(_ todo: SmartTodo) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let todoId = todo.id.uuidString
        let dependenciesJSON = (try? encoder.encode(todo.dependencies)).flatMap { String(data: $0, encoding: .utf8) }
        let subtasksJSON = todo.subtasks.flatMap { (try? encoder.encode($0)).flatMap { String(data: $0, encoding: .utf8) } }
        let metadataJSON = (try? encoder.encode(todo.metadata)).flatMap { String(data: $0, encoding: .utf8) }
        
        try timedWrite("saveTodo") { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO todos (
                    id, title, description, project, priority,
                    scheduled_time, duration, context, source, status,
                    dependencies, subtasks, metadata, updated_at,
                    completed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?)
            """, arguments: [
                todoId,
                todo.title,
                todo.description,
                todo.project.rawValue,
                todo.priority.rawValue,
                todo.scheduledTime?.timeIntervalSince1970,
                Int(todo.duration),
                todo.context.rawValue,
                todo.source.rawValue,
                todo.status.rawValue,
                dependenciesJSON,
                subtasksJSON,
                metadataJSON,
                todo.completedAt?.timeIntervalSince1970
            ])
        }
        
        return todoId
    }
    
    func updateTodoStatus(id: UUID, status: TodoStatus) throws {
        let completedAt = status == .completed ? Date().timeIntervalSince1970 : nil
        
        try timedWrite("updateTodoStatus") { db in
            try db.execute(sql: """
                UPDATE todos
                SET status = ?, updated_at = CURRENT_TIMESTAMP, completed_at = ?
                WHERE id = ?
            """, arguments: [status.rawValue, completedAt, id.uuidString])
        }
    }
    
    func fetchTodos(priority: TodoPriority? = nil, project: TodoProject? = nil, status: TodoStatus? = nil) throws -> [SmartTodo] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try timedRead("fetchTodos") { db in
            var sql = "SELECT * FROM todos WHERE 1=1"
            var arguments: [DatabaseValueConvertible] = []
            
            if let priority = priority {
                sql += " AND priority = ?"
                arguments.append(priority.rawValue)
            }
            
            if let project = project {
                sql += " AND project = ?"
                arguments.append(project.rawValue)
            }
            
            if let status = status {
                sql += " AND status = ?"
                arguments.append(status.rawValue)
            }
            
            sql += " ORDER BY CASE priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 END, created_at DESC"
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            
            return try rows.compactMap { row -> SmartTodo? in
                guard let id = UUID(uuidString: row["id"]),
                      let projectRaw: String = row["project"],
                      let project = TodoProject(rawValue: projectRaw),
                      let priorityRaw: String = row["priority"],
                      let priority = TodoPriority(rawValue: priorityRaw),
                      let contextRaw: String = row["context"],
                      let context = TodoContext(rawValue: contextRaw),
                      let sourceRaw: String = row["source"],
                      let source = TodoSource(rawValue: sourceRaw),
                      let statusRaw: String = row["status"],
                      let status = TodoStatus(rawValue: statusRaw) else {
                    return nil
                }
                
                let scheduledTime: Date? = {
                    if let timestamp: Double = row["scheduled_time"] {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    return nil
                }()
                
                let completedAt: Date? = {
                    if let timestamp: Double = row["completed_at"] {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    return nil
                }()
                
                let dependencies: [UUID] = {
                    if let jsonString: String = row["dependencies"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([UUID].self, from: data) {
                        return decoded
                    }
                    return []
                }()
                
                let subtasks: [Subtask]? = {
                    if let jsonString: String = row["subtasks"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([Subtask].self, from: data) {
                        return decoded
                    }
                    return nil
                }()
                
                let metadata: [String: AnyCodable] = {
                    if let jsonString: String = row["metadata"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([String: AnyCodable].self, from: data) {
                        return decoded
                    }
                    return [:]
                }()
                
                return SmartTodo(
                    id: id,
                    title: row["title"],
                    description: row["description"],
                    project: project,
                    priority: priority,
                    scheduledTime: scheduledTime,
                    duration: TimeInterval(row["duration"] ?? 0),
                    context: context,
                    source: source,
                    status: status,
                    dependencies: dependencies,
                    subtasks: subtasks,
                    metadata: TodoMetadata()
                )
            }
        }
    }
    
    func fetchP0Tasks() throws -> [SmartTodo] {
        return try fetchTodos(priority: .p0, status: .pending)
    }
    
    func deleteTodo(id: UUID) throws {
        try timedWrite("deleteTodo") { db in
            try db.execute(sql: "DELETE FROM todos WHERE id = ?", arguments: [id.uuidString])
        }
    }
    
    // MARK: Proactive Alerts Operations
    
    func saveProactiveAlert(_ alert: ProactiveAlert) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let alertId = alert.id.uuidString
        let contextJSON = (try? encoder.encode(alert.context)).flatMap { String(data: $0, encoding: .utf8) }
        
        try timedWrite("saveProactiveAlert") { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO proactive_alerts (
                    id, alert_type, message, severity, context,
                    is_dismissed, dismissed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                alertId,
                alert.alertType.rawValue,
                alert.message,
                alert.severity.rawValue,
                contextJSON,
                alert.isDismissed ? 1 : 0,
                alert.dismissedAt?.timeIntervalSince1970
            ])
        }
        
        return alertId
    }
    
    func fetchActiveAlerts(severity: AlertSeverity? = nil) throws -> [ProactiveAlert] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try timedRead("fetchActiveAlerts") { db in
            var sql = "SELECT * FROM proactive_alerts WHERE is_dismissed = 0"
            var arguments: [DatabaseValueConvertible] = []
            
            if let severity = severity {
                sql += " AND severity = ?"
                arguments.append(severity.rawValue)
            }
            
            sql += " ORDER BY created_at DESC"
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            
            return try rows.compactMap { row -> ProactiveAlert? in
                guard let id = UUID(uuidString: row["id"]),
                      let alertTypeRaw: String = row["alert_type"],
                      let alertType = AlertType(rawValue: alertTypeRaw),
                      let severityRaw: String = row["severity"],
                      let severity = AlertSeverity(rawValue: severityRaw),
                      let createdAtTimestamp: Double = row["created_at"] else {
                    return nil
                }
                
                let context: String? = row["context"]
                
                let dismissedAt: Date? = {
                    if let timestamp: Double = row["dismissed_at"] {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    return nil
                }()
                
                return ProactiveAlert(
                    id: id,
                    alertType: alertType,
                    message: row["message"],
                    severity: severity,
                    context: context,
                    isDismissed: (row["is_dismissed"] as? Int64 ?? 0) != 0
                )
            }
        }
    }
    
    func dismissAlert(id: UUID) throws {
        try timedWrite("dismissAlert") { db in
            try db.execute(sql: """
                UPDATE proactive_alerts
                SET is_dismissed = 1, dismissed_at = ?
                WHERE id = ?
            """, arguments: [Date().timeIntervalSince1970, id.uuidString])
        }
    }
    
    // MARK: Context Switches Operations
    
    func saveContextSwitch(_ contextSwitch: ContextSwitch) throws -> String {
        let switchId = contextSwitch.id.uuidString
        
        try timedWrite("saveContextSwitch") { db in
            try db.execute(sql: """
                INSERT INTO context_switches (
                    id, from_activity, to_activity, from_app, to_app,
                    duration_seconds, switch_reason
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                switchId,
                contextSwitch.fromActivity,
                contextSwitch.toActivity,
                contextSwitch.fromApp,
                contextSwitch.toApp,
                Int(contextSwitch.durationSeconds),
                contextSwitch.switchReason
            ])
        }
        
        return switchId
    }
    
    func fetchContextSwitches(since: Date) throws -> [ContextSwitch] {
        let sinceTimestamp = since.timeIntervalSince1970
        
        return try timedRead("fetchContextSwitches") { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM context_switches
                WHERE created_at >= ?
                ORDER BY created_at DESC
            """, arguments: [sinceTimestamp])
            
            return try rows.compactMap { row -> ContextSwitch? in
                guard let id = UUID(uuidString: row["id"]),
                      let createdAtTimestamp: Double = row["created_at"] else {
                    return nil
                }
                
                return ContextSwitch(
                    id: id,
                    fromActivity: row["from_activity"] ?? "",
                    toActivity: row["to_activity"] ?? "",
                    fromApp: row["from_app"] ?? "",
                    toApp: row["to_app"] ?? "",
                    durationSeconds: Int(row["duration_seconds"] ?? 0),
                    switchReason: row["switch_reason"]
                )
            }
        }
    }
    
    // MARK: Conversation Log Operations
    
    func saveConversation(_ conversation: ConversationLog) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let conversationId = conversation.id.uuidString
        let keyPointsJSON = (try? encoder.encode(conversation.keyPoints)).flatMap { String(data: $0, encoding: .utf8) }
        let decisionsJSON = (try? encoder.encode(conversation.decisions)).flatMap { String(data: $0, encoding: .utf8) }
        let followUpsJSON = (try? encoder.encode(conversation.followUps)).flatMap { String(data: $0, encoding: .utf8) }
        
        try timedWrite("saveConversation") { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO conversations_log (
                    id, person_name, context, key_points, decisions,
                    follow_ups, sentiment, conversation_date
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId,
                conversation.personName,
                conversation.context,
                keyPointsJSON,
                decisionsJSON,
                followUpsJSON,
                conversation.sentiment,
                DateFormatter.yyyyMMdd.string(from: conversation.conversationDate)
            ])
        }
        
        return conversationId
    }
    
    func fetchConversations(person: String? = nil, limit: Int = 50) throws -> [ConversationLog] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try timedRead("fetchConversations") { db in
            var sql = "SELECT * FROM conversations_log WHERE 1=1"
            var arguments: [DatabaseValueConvertible] = []
            
            if let person = person {
                sql += " AND person_name = ?"
                arguments.append(person)
            }
            
            sql += " ORDER BY conversation_date DESC LIMIT ?"
            arguments.append(Int64(limit))
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            
            return rows.compactMap { row -> ConversationLog? in
                guard let id = UUID(uuidString: row["id"]),
                      let dateString: String = row["conversation_date"],
                      let conversationDate = DateFormatter.yyyyMMdd.date(from: dateString) else {
                    return nil
                }
                
                let keyPoints: [String] = {
                    if let jsonString: String = row["key_points"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([String].self, from: data) {
                        return decoded
                    }
                    return []
                }()
                
                let decisions: [String] = {
                    if let jsonString: String = row["decisions"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([String].self, from: data) {
                        return decoded
                    }
                    return []
                }()
                
                let followUps: [String] = {
                    if let jsonString: String = row["follow_ups"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([String].self, from: data) {
                        return decoded
                    }
                    return []
                }()
                
                return ConversationLog(
                    id: id,
                    personName: row["person_name"],
                    context: row["context"],
                    keyPoints: keyPoints,
                    decisions: decisions,
                    followUps: followUps,
                    sentiment: row["sentiment"],
                    conversationDate: conversationDate
                )
            }
        }
    }
    
    // MARK: User Context Operations
    
    func saveUserContext(key: String, value: String, category: String? = nil) throws {
        let contextId = UUID().uuidString
        
        try timedWrite("saveUserContext") { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO user_context (
                    id, key, value, category, updated_at
                ) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            """, arguments: [contextId, key, value, category])
        }
    }
    
    func getUserContext(key: String) throws -> String? {
        return try timedRead("getUserContext") { db in
            try String.fetchOne(db, sql: """
                SELECT value FROM user_context WHERE key = ?
            """, arguments: [key])
        }
    }
    
    func fetchUserContextByCategory(category: String) throws -> [String: String] {
        return try timedRead("fetchUserContextByCategory") { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT key, value FROM user_context
                WHERE category = ?
                ORDER BY updated_at DESC
            """, arguments: [category])
            
            var result: [String: String] = [:]
            for row in rows {
                if let key: String = row["key"], let value: String = row["value"] {
                    result[key] = value
                }
            }
            return result
        }
    }
    
    // MARK: Screen Recall Operations
    
    func recallActivity(at timestamp: Date, contextWindow: TimeInterval = 600) throws -> ActivityRecall {
        let startTs = Int(timestamp.timeIntervalSince1970 - contextWindow)
        let endTs = Int(timestamp.timeIntervalSince1970 + contextWindow)
        
        return try timedRead("recallActivity") { db in
            // Find timeline cards that overlap with the timestamp
            let cardRows = try Row.fetchAll(db, sql: """
                SELECT * FROM timeline_cards
                WHERE start_ts <= ? AND end_ts >= ?
                  AND is_deleted = 0
                ORDER BY start_ts ASC
            """, arguments: [endTs, startTs])
            
            let decoder = JSONDecoder()
            let cards = cardRows.compactMap { row -> TimelineCard? in
                var distractions: [Distraction]? = nil
                var appSites: AppSites? = nil
                if let metadataString: String = row["metadata"],
                   let jsonData = metadataString.data(using: .utf8) {
                    if let meta = try? decoder.decode(TimelineMetadata.self, from: jsonData) {
                        distractions = meta.distractions
                        appSites = meta.appSites
                    }
                }
                
                return TimelineCard(
                    batchId: row["batch_id"],
                    startTimestamp: row["start"] ?? "",
                    endTimestamp: row["end"] ?? "",
                    category: row["category"],
                    subcategory: row["subcategory"],
                    title: row["title"],
                    summary: row["summary"],
                    detailedSummary: row["detailed_summary"],
                    day: row["day"],
                    distractions: distractions,
                    videoSummaryURL: row["video_summary_url"],
                    otherVideoSummaryURLs: nil,
                    appSites: appSites
                )
            }
            
            // Find the exact card at the timestamp
            let exactCard = cards.first { card in
                guard let startTs = try? parseTimestampFromCard(card),
                      let endTs = try? parseTimestampFromCard(card, isEnd: true) else {
                    return false
                }
                let targetTs = Int(timestamp.timeIntervalSince1970)
                return startTs <= targetTs && endTs >= targetTs
            }
            
            // Get observations for context
            let observations = try Row.fetchAll(db, sql: """
                SELECT observation FROM observations
                WHERE start_ts <= ? AND end_ts >= ?
                ORDER BY start_ts ASC
                LIMIT 5
            """, arguments: [endTs, startTs]).compactMap { $0["observation"] as? String }
            
            // Get context switches around this time
            let contextSwitches = try Row.fetchAll(db, sql: """
                SELECT from_activity, to_activity, from_app, to_app
                FROM context_switches
                WHERE created_at >= ? AND created_at <= ?
                ORDER BY created_at ASC
                LIMIT 3
            """, arguments: [startTs, endTs]).map { row -> String in
                let from: String = row["from_activity"] ?? ""
                let to: String = row["to_activity"] ?? ""
                return "\(from) → \(to)"
            }
            
            return ActivityRecall(
                timestamp: timestamp,
                primaryActivity: exactCard,
                nearbyActivities: cards.filter { $0.id != exactCard?.id },
                observations: observations,
                contextSwitches: contextSwitches,
                videoPath: exactCard?.videoSummaryURL
            )
        }
    }
    
    private func parseTimestampFromCard(_ card: TimelineCard, isEnd: Bool = false) throws -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let timeString = isEnd ? card.endTimestamp : card.startTimestamp
        guard let time = formatter.date(from: timeString) else {
            throw NSError(domain: "StorageManager", code: -1, userInfo: nil)
        }
        
        // Use the day from the card to construct full date
        guard let dayDate = DateFormatter.yyyyMMdd.date(from: card.day) else {
            throw NSError(domain: "StorageManager", code: -1, userInfo: nil)
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let fullDate = calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: dayDate) else {
            throw NSError(domain: "StorageManager", code: -1, userInfo: nil)
        }
        
        return Int(fullDate.timeIntervalSince1970)
    }
    
    // MARK: Decision Log Operations
    
    func saveDecision(_ decision: DecisionLog) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decisionId = decision.id.uuidString
        let optionsJSON = (try? encoder.encode(decision.options)).flatMap { String(data: $0, encoding: .utf8) }
        let tradeoffsJSON = (try? encoder.encode(decision.tradeoffs)).flatMap { String(data: $0, encoding: .utf8) }
        let metadataJSON = (try? encoder.encode(decision.metadata)).flatMap { String(data: $0, encoding: .utf8) }
        
        try timedWrite("saveDecision") { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO decisions_log (
                    id, question, options, tradeoffs, owner, deadline,
                    decision, outcome, metadata, decided_at, reviewed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                decisionId,
                decision.question,
                optionsJSON,
                tradeoffsJSON,
                decision.owner,
                decision.deadline?.timeIntervalSince1970,
                decision.decision,
                decision.outcome,
                metadataJSON,
                decision.decidedAt?.timeIntervalSince1970,
                decision.reviewedAt?.timeIntervalSince1970
            ])
        }
        
        return decisionId
    }
    
    func fetchDecisions(limit: Int = 50) throws -> [DecisionLog] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try timedRead("fetchDecisions") { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM decisions_log
                ORDER BY created_at DESC
                LIMIT ?
            """, arguments: [limit])
            
            return try rows.compactMap { row -> DecisionLog? in
                guard let id = UUID(uuidString: row["id"]),
                      let createdAtTimestamp: Double = row["created_at"] else {
                    return nil
                }
                
                let options: [DecisionOption] = {
                    if let jsonString: String = row["options"],
                       let data = jsonString.data(using: .utf8),
                       let decoded = try? decoder.decode([DecisionOption].self, from: data) {
                        return decoded
                    }
                    return []
                }()
                
                let tradeoffs: String? = row["tradeoffs"]
                
                let deadline: Date? = {
                    if let timestamp: Double = row["deadline"] {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    return nil
                }()
                
                return DecisionLog(
                    id: id,
                    question: row["question"],
                    options: options,
                    tradeoffs: tradeoffs,
                    owner: row["owner"],
                    deadline: deadline,
                    decision: row["decision"],
                    outcome: row["outcome"],
                    metadata: DecisionMetadata()
                )
            }
        }
    }


    private let purgeQ = DispatchQueue(label: "com.dayflow.storage.purge", qos: .background)
    private var purgeTimer: DispatchSourceTimer?
    
    private let optimizationQ = DispatchQueue(label: "com.dayflow.storage.optimization", qos: .utility)
    private var optimizationTimer: DispatchSourceTimer?
    private var lastVacuumDate: Date? {
        get {
            if let timestamp = UserDefaults.standard.double(forKey: "storageManager_lastVacuumDate") as TimeInterval?,
               timestamp > 0 {
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "storageManager_lastVacuumDate")
        }
    }

    private func startPurgeScheduler() {
        let timer = DispatchSource.makeTimerSource(queue: purgeQ)
        timer.schedule(deadline: .now() + 3600, repeating: 3600) // Every hour
        timer.setEventHandler { [weak self] in
            self?.purgeIfNeeded()
            TimelapseStorageManager.shared.purgeIfNeeded()
        }
        timer.resume()
        purgeTimer = timer
    }
    
    private func startDatabaseOptimizationScheduler() {
        let timer = DispatchSource.makeTimerSource(queue: optimizationQ)
        // Check daily, but only run VACUUM weekly or when needed
        timer.schedule(deadline: .now() + 86400, repeating: 86400) // Every day
        timer.setEventHandler { [weak self] in
            self?.optimizeDatabaseIfNeeded()
        }
        timer.resume()
        optimizationTimer = timer
    }

    private func purgeIfNeeded() {
        purgeQ.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check current size and user-defined limit
                let currentSize = try self.fileMgr.allocatedSizeOfDirectory(at: self.root)
                let limit = StoragePreferences.recordingsLimitBytes

                if limit == Int64.max {
                    return // Unlimited storage - skip purge
                }
                
                // 3 days cutoff for all chunks
                let cutoffDate = Date().addingTimeInterval(-3 * 24 * 60 * 60)
                let cutoffTimestamp = Int(cutoffDate.timeIntervalSince1970)
                
                // Clean up if above limit
                if currentSize > limit {

                    try self.timedWrite("purgeIfNeeded") { db in
                        // Get chunks older than 3 days with file paths still set
                        let oldChunks = try Row.fetchAll(db, sql: """
                            SELECT id, file_url, start_ts 
                            FROM chunks 
                            WHERE start_ts < ?
                            AND file_url IS NOT NULL
                            AND file_url != ''
                            AND (is_deleted = 0 OR is_deleted IS NULL)
                            ORDER BY start_ts ASC 
                            LIMIT 500
                        """, arguments: [cutoffTimestamp])
                        
                        var deletedCount = 0
                        var freedSpace: Int64 = 0
                        
                        for chunk in oldChunks {
                            guard let id: Int64 = chunk["id"],
                                  let path: String = chunk["file_url"] else { continue }

                            // Get file size before deletion
                            var fileSize: Int64 = 0
                            if FileManager.default.fileExists(atPath: path) {
                                if let attrs = try? self.fileMgr.attributesOfItem(atPath: path),
                                   let size = attrs[.size] as? NSNumber {
                                    fileSize = size.int64Value
                                }
                            }

                            // Mark as deleted in DB first (safer ordering)
                            try db.execute(sql: """
                                UPDATE chunks
                                SET is_deleted = 1
                                WHERE id = ?
                            """, arguments: [id])

                            // Then delete physical file
                            if FileManager.default.fileExists(atPath: path) {
                                do {
                                    try self.fileMgr.removeItem(atPath: path)
                                    freedSpace += fileSize
                                    deletedCount += 1
                                } catch {
                                    print("⚠️ Failed to delete chunk file at \(path): \(error)")
                                    // Don't count as freed space if deletion failed
                                }
                            } else {
                                // File already gone, still count the DB cleanup
                                deletedCount += 1
                            }

                            // Stop if we've freed enough space (under 10GB)
                            if currentSize - freedSpace < limit {
                                break
                            }
                        }
                        
                        // freedGB retained for future use if needed
                    }
                }
            } catch {
                print("❌ Purge error: \(error)")
            }
        }
    }
}


private extension StorageManager {
    func migrateLegacyChunkPathsIfNeeded() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        guard let appSupport = fileMgr.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let legacyBase = fileMgr.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Application Support/Dayflow", isDirectory: true)
        let newBase = appSupport.appendingPathComponent("Dayflow", isDirectory: true)

        guard legacyBase.path != newBase.path else { return }

        func normalizedPrefix(_ path: String) -> String {
            path.hasSuffix("/") ? path : path + "/"
        }

        let legacyRecordings = normalizedPrefix(legacyBase.appendingPathComponent("recordings", isDirectory: true).path)
        let newRecordings = normalizedPrefix(root.path)

        let legacyTimelapses = normalizedPrefix(legacyBase.appendingPathComponent("timelapses", isDirectory: true).path)
        let newTimelapses = normalizedPrefix(newBase.appendingPathComponent("timelapses", isDirectory: true).path)

        let replacements: [(label: String, table: String, column: String, legacyPrefix: String, newPrefix: String)] = [
            ("chunk file paths", "chunks", "file_url", legacyRecordings, newRecordings),
            ("timelapse video paths", "timeline_cards", "video_summary_url", legacyTimelapses, newTimelapses)
        ]

        do {
            try timedWrite("migrateLegacyFileURLs") { db in
                for replacement in replacements {
                    guard replacement.legacyPrefix != replacement.newPrefix else { continue }

                    let pattern = replacement.legacyPrefix + "%"
                    let count = try Int.fetchOne(
                        db,
                        sql: "SELECT COUNT(*) FROM \(replacement.table) WHERE \(replacement.column) LIKE ?",
                        arguments: [pattern]
                    ) ?? 0

                    guard count > 0 else { continue }

                    try db.execute(
                        sql: """
                            UPDATE \(replacement.table)
                            SET \(replacement.column) = REPLACE(\(replacement.column), ?, ?)
                            WHERE \(replacement.column) LIKE ?
                        """,
                        arguments: [replacement.legacyPrefix, replacement.newPrefix, pattern]
                    )

                    let updated = db.changesCount
                    print("ℹ️ StorageManager: migrated \(updated) \(replacement.label) to \(replacement.newPrefix)")
                }
            }
        } catch {
            print("⚠️ StorageManager: failed to migrate legacy file URLs: \(error)")
        }
    }

    static func migrateDatabaseLocationIfNeeded(
        fileManager: FileManager,
        legacyRecordingsDir: URL,
        newDatabaseURL: URL
    ) {
        let destinationDir = newDatabaseURL.deletingLastPathComponent()
        let filenames = ["chunks.sqlite", "chunks.sqlite-wal", "chunks.sqlite-shm"]

        guard filenames.contains(where: { fileManager.fileExists(atPath: legacyRecordingsDir.appendingPathComponent($0).path) }) else {
            return
        }

        if !fileManager.fileExists(atPath: destinationDir.path) {
            try? fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        }

        for name in filenames {
            let legacyURL = legacyRecordingsDir.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: legacyURL.path) else { continue }

            let destinationURL = destinationDir.appendingPathComponent(name)
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: legacyURL, to: destinationURL)
                print("ℹ️ StorageManager: migrated \(name) to \(destinationURL.path)")
            } catch {
                print("⚠️ StorageManager: failed to migrate \(name): \(error)")
            }
        }
    }
    
    func optimizeDatabaseIfNeeded() {
        optimizationQ.async { [weak self] in
            guard let self = self else { return }
            
            // Check if VACUUM is needed
            let shouldVacuum: Bool = {
                // Run VACUUM weekly
                if let lastVacuum = self.lastVacuumDate {
                    let daysSinceLastVacuum = Date().timeIntervalSince(lastVacuum) / 86400
                    if daysSinceLastVacuum >= 7 {
                        return true
                    }
                } else {
                    // First time - run after 7 days of usage
                    return false
                }
                
                // Or run if database size exceeds threshold
                do {
                    let dbSize = try self.getDatabaseSize()
                    let dbSizeMB = Double(dbSize) / (1024 * 1024)
                    
                    // Run VACUUM if database exceeds 100MB
                    if dbSizeMB > 100 {
                        return true
                    }
                } catch {
                    // If we can't check size, don't run VACUUM
                    return false
                }
                
                return false
            }()
            
            guard shouldVacuum else { return }
            
            // Perform VACUUM operation
            do {
                let startTime = Date()
                try self.timedWrite("VACUUM") { db in
                    try db.execute(sql: "VACUUM")
                }
                let duration = Date().timeIntervalSince(startTime)
                
                // Update last vacuum date
                self.lastVacuumDate = Date()
                
                // Log for debugging
                let logger = Logger(subsystem: "Dayflow", category: "StorageManager")
                logger.info("Database VACUUM completed in \(String(format: "%.2f", duration))s")
                
                // Track growth rate
                self.trackDatabaseGrowth()
                
            } catch {
                let logger = Logger(subsystem: "Dayflow", category: "StorageManager")
                logger.error("Database VACUUM failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func getDatabaseSize() throws -> Int64 {
        let dbPath = dbURL.path
        var totalSize: Int64 = 0
        
        // Get main database file size
        if FileManager.default.fileExists(atPath: dbPath) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
               let size = attrs[.size] as? NSNumber {
                totalSize += size.int64Value
            }
        }
        
        // Get WAL file size
        let walPath = dbPath + "-wal"
        if FileManager.default.fileExists(atPath: walPath) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: walPath),
               let size = attrs[.size] as? NSNumber {
                totalSize += size.int64Value
            }
        }
        
        // Get SHM file size
        let shmPath = dbPath + "-shm"
        if FileManager.default.fileExists(atPath: shmPath) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: shmPath),
               let size = attrs[.size] as? NSNumber {
                totalSize += size.int64Value
            }
        }
        
        return totalSize
    }
    
    private func trackDatabaseGrowth() {
        do {
            let currentSize = try getDatabaseSize()
            let sizeMB = Double(currentSize) / (1024 * 1024)
            
            // Store growth history (last 30 days)
            var growthHistory = UserDefaults.standard.array(forKey: "storageManager_dbGrowthHistory") as? [[String: Any]] ?? []
            
            let entry: [String: Any] = [
                "date": Date().timeIntervalSince1970,
                "sizeMB": sizeMB
            ]
            
            growthHistory.append(entry)
            
            // Keep only last 30 entries
            if growthHistory.count > 30 {
                growthHistory.removeFirst(growthHistory.count - 30)
            }
            
            UserDefaults.standard.set(growthHistory, forKey: "storageManager_dbGrowthHistory")
            
            // Calculate growth rate if we have enough data
            if growthHistory.count >= 2,
               let firstEntry = growthHistory.first,
               let firstSize = firstEntry["sizeMB"] as? Double,
               let lastEntry = growthHistory.last,
               let lastDate = lastEntry["date"] as? TimeInterval {
                let daysDiff = (Date().timeIntervalSince1970 - lastDate) / 86400
                if daysDiff > 0 {
                    let growthRate = (sizeMB - firstSize) / daysDiff // MB per day
                    
                    // Log if growth rate is concerning (> 10 MB per day)
                    if growthRate > 10 {
                        let logger = Logger(subsystem: "Dayflow", category: "StorageManager")
                        logger.warning("Database growth rate is high: \(String(format: "%.2f", growthRate)) MB/day")
                    }
                }
            }
        } catch {
            let logger = Logger(subsystem: "Dayflow", category: "StorageManager")
            logger.error("Failed to track database growth: \(error.localizedDescription)")
        }
    }
}


extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey])
                if values.isDirectory == true {
                    // Directories report 0, rely on enumerator to traverse contents
                    continue
                }
                total += Int64(values.totalFileAllocatedSize ?? 0)
            } catch {
                continue
            }
        }
        return total
    }
}
