# Epic 4: Database & Persistence Reliability - Technical Specification

**Epic ID**: Epic 4
**Epic Title**: Database & Persistence Reliability
**Priority**: 3 (Critical Foundation)
**Status**: Contexted
**Generated**: 2025-11-13
**Target**: FocusLock (Brownfield Rescue Mission)

---

## Executive Summary

Epic 4 focuses on ensuring all data persistence mechanisms work reliably after the critical memory management fixes from Epic 1. This epic addresses three core persistence layers: timeline data, recording chunk management, and settings/configuration. The implementation must maintain thread-safe database operations, efficient storage management, and robust data integrity across app restarts and long-running sessions.

**Success Criteria**:
- All timeline data persists reliably across app restarts
- Recording chunks are managed efficiently with automatic cleanup
- Settings persist correctly with proper validation
- Database operations complete without crashes or corruption
- Data integrity maintained under concurrent access patterns

---

## 1. Technical Architecture

### 1.1 Current Database Architecture

FocusLock uses **GRDB (SQLite)** for all persistence layers with the following database files:

```
~/Library/Application Support/Dayflow/
├── chunks.sqlite              # Main timeline, recordings, batches
├── MemoryStore.sqlite          # Hybrid BM25 + vector search index
├── FocusLockData.sqlite        # Focus sessions, activities, categories
└── FocusLockAnalytics.sqlite   # Analytics and metrics
```

#### Primary Database Schema (chunks.sqlite)

**Core Tables**:

```sql
-- Recording Chunks
CREATE TABLE IF NOT EXISTS recording_chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_url TEXT NOT NULL,
    start_ts INTEGER NOT NULL,
    end_ts INTEGER NOT NULL,
    status TEXT DEFAULT 'pending',  -- pending, completed, failed
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Analysis Batches
CREATE TABLE IF NOT EXISTS analysis_batches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_ts INTEGER NOT NULL,
    end_ts INTEGER NOT NULL,
    status TEXT DEFAULT 'pending',  -- pending, processing, completed, failed
    reason TEXT,                     -- failure reason if status = failed
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Batch-Chunk Relationship
CREATE TABLE IF NOT EXISTS batch_chunks (
    batch_id INTEGER NOT NULL,
    chunk_id INTEGER NOT NULL,
    FOREIGN KEY (batch_id) REFERENCES analysis_batches(id) ON DELETE CASCADE,
    FOREIGN KEY (chunk_id) REFERENCES recording_chunks(id) ON DELETE CASCADE,
    PRIMARY KEY (batch_id, chunk_id)
);

-- Timeline Cards
CREATE TABLE IF NOT EXISTS timeline_cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER,
    day TEXT NOT NULL,              -- YYYY-MM-DD format
    start_timestamp TEXT NOT NULL,  -- ISO 8601 format
    end_timestamp TEXT NOT NULL,    -- ISO 8601 format
    start_ts INTEGER NOT NULL,      -- Unix timestamp
    end_ts INTEGER NOT NULL,        -- Unix timestamp
    category TEXT NOT NULL,
    subcategory TEXT,
    title TEXT NOT NULL,
    summary TEXT,
    detailed_summary TEXT,
    video_summary_url TEXT,         -- Path to video clip
    metadata TEXT,                  -- JSON: distractions, appSites
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (batch_id) REFERENCES analysis_batches(id) ON DELETE SET NULL
);

-- Observations (First-class transcript storage)
CREATE TABLE IF NOT EXISTS observations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER NOT NULL,
    start_ts INTEGER NOT NULL,
    end_ts INTEGER NOT NULL,
    observation TEXT NOT NULL,
    metadata TEXT,                  -- JSON metadata
    llm_model TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (batch_id) REFERENCES analysis_batches(id) ON DELETE CASCADE
);

-- LLM Call Tracking
CREATE TABLE IF NOT EXISTS llm_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id INTEGER,
    call_group_id TEXT,
    attempt INTEGER DEFAULT 1,
    provider TEXT NOT NULL,         -- gemini, ollama, lm_studio
    model TEXT,
    operation TEXT NOT NULL,        -- analyze, summarize, categorize
    status TEXT NOT NULL,           -- success, failure
    latency_ms INTEGER,
    http_status INTEGER,
    request_method TEXT,
    request_url TEXT,
    request_headers_json TEXT,
    request_body TEXT,
    response_headers_json TEXT,
    response_body TEXT,
    error_domain TEXT,
    error_code INTEGER,
    error_message TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (batch_id) REFERENCES analysis_batches(id) ON DELETE SET NULL
);

-- App Settings
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);
```

**Indexes**:
```sql
CREATE INDEX IF NOT EXISTS idx_chunks_start_ts ON recording_chunks(start_ts);
CREATE INDEX IF NOT EXISTS idx_chunks_status ON recording_chunks(status);
CREATE INDEX IF NOT EXISTS idx_batches_start_ts ON analysis_batches(start_ts);
CREATE INDEX IF NOT EXISTS idx_batches_status ON analysis_batches(status);
CREATE INDEX IF NOT EXISTS idx_timeline_day ON timeline_cards(day);
CREATE INDEX IF NOT EXISTS idx_timeline_start_ts ON timeline_cards(start_ts);
CREATE INDEX IF NOT EXISTS idx_observations_batch ON observations(batch_id);
CREATE INDEX IF NOT EXISTS idx_observations_time_range ON observations(start_ts, end_ts);
CREATE INDEX IF NOT EXISTS idx_llm_calls_batch ON llm_calls(batch_id);
```

### 1.2 Thread Safety Architecture

**Critical Pattern**: All database operations MUST use serial queue pattern to prevent concurrent access crashes.

```swift
// DatabaseManager Wrapper Pattern
actor DatabaseManager {
    private let serialQueue = DispatchQueue(label: "com.focusLock.database.serial")
    private let pool: DatabasePool

    func execute<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            serialQueue.async {
                do {
                    let result = try self.pool.write { db in
                        try operation(db)
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

**Key Principles**:
1. **Serial Database Queue**: All write operations serialized
2. **Actor Isolation**: Database managers are actors
3. **Read/Write Separation**: Use `pool.read {}` for queries, `pool.write {}` for mutations
4. **Transaction Boundaries**: Explicit transaction management for multi-step operations

### 1.3 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ ScreenRecorder│  │ LLMService   │  │ SettingsView  │  │
│  └──────┬────────┘  └──────┬───────┘  └───────┬───────┘  │
└─────────┼────────────────┼──────────────────┼───────────┘
          │                │                  │
          ▼                ▼                  ▼
┌─────────────────────────────────────────────────────────┐
│              StorageManager (Singleton)                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │        DatabasePool (GRDB Serial Queue)          │   │
│  │  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │   │
│  │  │  Chunks    │  │ Batches  │  │  Timeline   │  │   │
│  │  │ Recording  │  │ Analysis │  │   Cards     │  │   │
│  │  └────────────┘  └──────────┘  └─────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
          │                │                  │
          ▼                ▼                  ▼
┌─────────────────────────────────────────────────────────┐
│                    File System Layer                     │
│  ~/Library/Application Support/Dayflow/                 │
│  ├── recordings/       (Video chunks)                    │
│  ├── thumbnails/       (Cached thumbnails)               │
│  └── chunks.sqlite     (Database file)                   │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Story-by-Story Implementation

### Story 4.1: Timeline Data Persistence

**Goal**: Ensure AI-generated timeline cards are saved reliably and load quickly across app restarts.

#### 2.1.1 Requirements

**Functional**:
- Timeline cards persist across app restarts
- Timeline data loads in < 2 seconds for 30 days of data
- Support for day-based queries (4AM boundary logic)
- Support for time-range queries (from/to timestamps)
- Data integrity maintained (no corruption or loss)

**Non-Functional**:
- Write latency: < 100ms per timeline card
- Read latency: < 2s for full day (up to 50 cards)
- Database size: ~10MB per 30 days of timeline data
- Concurrent read support (multiple views)

#### 2.1.2 Database Operations

**Save Timeline Card**:
```swift
func saveTimelineCardShell(batchId: Int64, card: TimelineCardShell) -> Int64? {
    try db.write { db in
        // Encode metadata (distractions, appSites)
        let metadata = TimelineMetadata(
            distractions: card.distractions,
            appSites: card.appSites
        )
        let metadataJSON = try JSONEncoder().encode(metadata)

        // Parse timestamps for indexing
        let formatter = ISO8601DateFormatter()
        let startDate = formatter.date(from: card.startTimestamp)!
        let endDate = formatter.date(from: card.endTimestamp)!
        let startTs = Int(startDate.timeIntervalSince1970)
        let endTs = Int(endDate.timeIntervalSince1970)

        // Compute day string (4AM boundary)
        let dayInfo = startDate.getDayInfoFor4AMBoundary()

        // Insert timeline card
        try db.execute(sql: """
            INSERT INTO timeline_cards
            (batch_id, day, start_timestamp, end_timestamp, start_ts, end_ts,
             category, subcategory, title, summary, detailed_summary, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [
            batchId, dayInfo.dayString, card.startTimestamp, card.endTimestamp,
            startTs, endTs, card.category, card.subcategory,
            card.title, card.summary, card.detailedSummary,
            String(data: metadataJSON, encoding: .utf8)
        ])

        return db.lastInsertedRowID
    }
}
```

**Load Timeline Cards for Day**:
```swift
func fetchTimelineCards(forDay day: String) -> [TimelineCard] {
    try db.read { db in
        let rows = try Row.fetchAll(db, sql: """
            SELECT id, batch_id, start_timestamp, end_timestamp, category,
                   subcategory, title, summary, detailed_summary, day,
                   video_summary_url, metadata
            FROM timeline_cards
            WHERE day = ?
            ORDER BY start_ts ASC
        """, arguments: [day])

        return rows.compactMap { row in
            // Decode metadata
            let metadataJSON: String? = row["metadata"]
            let metadata = metadataJSON.flatMap { json in
                try? JSONDecoder().decode(
                    TimelineMetadata.self,
                    from: json.data(using: .utf8)!
                )
            }

            return TimelineCard(
                batchId: row["batch_id"],
                startTimestamp: row["start_timestamp"],
                endTimestamp: row["end_timestamp"],
                category: row["category"],
                subcategory: row["subcategory"] ?? "",
                title: row["title"],
                summary: row["summary"] ?? "",
                detailedSummary: row["detailed_summary"] ?? "",
                day: row["day"],
                distractions: metadata?.distractions,
                videoSummaryURL: row["video_summary_url"],
                otherVideoSummaryURLs: nil,
                appSites: metadata?.appSites
            )
        }
    }
}
```

**Update Timeline Card Video URL**:
```swift
func updateTimelineCardVideoURL(cardId: Int64, videoSummaryURL: String) {
    try db.write { db in
        try db.execute(sql: """
            UPDATE timeline_cards
            SET video_summary_url = ?
            WHERE id = ?
        """, arguments: [videoSummaryURL, cardId])
    }
}
```

#### 2.1.3 Data Integrity

**Validation Rules**:
1. **Timestamp Consistency**: `end_ts >= start_ts`
2. **Day Boundary**: Timeline cards must fall within their assigned day (4AM logic)
3. **Foreign Key Integrity**: `batch_id` references must be valid
4. **Required Fields**: title, category, timestamps must not be null

**Integrity Checks**:
```swift
func validateTimelineCardIntegrity() async throws -> [String] {
    var issues: [String] = []

    // Check for invalid timestamps
    let invalidTimestamps = try await db.read { db in
        try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM timeline_cards
            WHERE end_ts < start_ts
        """) ?? 0
    }
    if invalidTimestamps > 0 {
        issues.append("\(invalidTimestamps) cards with invalid timestamps")
    }

    // Check for orphaned timeline cards (batch_id references non-existent batch)
    let orphanedCards = try await db.read { db in
        try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM timeline_cards tc
            LEFT JOIN analysis_batches ab ON tc.batch_id = ab.id
            WHERE tc.batch_id IS NOT NULL AND ab.id IS NULL
        """) ?? 0
    }
    if orphanedCards > 0 {
        issues.append("\(orphanedCards) orphaned timeline cards")
    }

    return issues
}
```

#### 2.1.4 Performance Optimization

**Indexing Strategy**:
- Primary index on `day` for day-based queries
- Secondary index on `start_ts` for time-range queries
- Composite index on `(day, start_ts)` for sorted day views

**Caching Layer**:
```swift
actor TimelineCache {
    private var cachedCards: [String: [TimelineCard]] = [:]
    private let cacheExpiry: TimeInterval = 60.0 // 1 minute

    func getCachedCards(forDay day: String) -> [TimelineCard]? {
        return cachedCards[day]
    }

    func cacheCards(_ cards: [TimelineCard], forDay day: String) {
        cachedCards[day] = cards

        // Expire cache after 1 minute
        Task {
            try? await Task.sleep(nanoseconds: UInt64(cacheExpiry * 1_000_000_000))
            cachedCards.removeValue(forKey: day)
        }
    }
}
```

#### 2.1.5 Testing Strategy

**Unit Tests**:
```swift
func testTimelineCardPersistence() async throws {
    // Create test card
    let card = TimelineCardShell(
        startTimestamp: "2025-11-13T10:00:00Z",
        endTimestamp: "2025-11-13T11:00:00Z",
        category: "Work",
        subcategory: "Coding",
        title: "Swift Development",
        summary: "Working on database layer",
        detailedSummary: "Implementing timeline persistence",
        distractions: nil,
        appSites: nil
    )

    // Save card
    let cardId = try await storageManager.saveTimelineCardShell(
        batchId: 1,
        card: card
    )
    XCTAssertNotNil(cardId)

    // Reload and verify
    let cards = try await storageManager.fetchTimelineCards(forDay: "2025-11-13")
    XCTAssertEqual(cards.count, 1)
    XCTAssertEqual(cards.first?.title, "Swift Development")
}
```

**Integration Tests**:
- Timeline persistence across app restart
- Concurrent read/write operations
- Large dataset performance (1000+ cards)
- Data integrity after power loss simulation

---

### Story 4.2: Recording Chunk Management

**Goal**: Efficiently manage video chunks with automatic cleanup based on retention policies.

#### 2.2.1 Requirements

**Functional**:
- Recording chunks tracked in database with file paths
- Automatic cleanup of old chunks based on retention policy (default: 3 days)
- Timeline data preserved when chunks are deleted
- Storage usage stays within configured limits
- Support for chunk-to-batch mapping

**Non-Functional**:
- Cleanup latency: < 5 seconds for batch deletion
- Storage overhead: < 1% of video file size for database records
- Retention check frequency: Every 1 hour
- Maximum storage: Configurable (default: 10GB)

#### 2.2.2 Recording Chunk Lifecycle

```
┌──────────────┐
│ Recording    │  1. Create chunk file
│ Started      │     nextFileURL()
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Chunk        │  2. Register in DB
│ Created      │     registerChunk(url)
└──────┬───────┘     status = 'pending'
       │
       ▼
┌──────────────┐
│ Recording    │  3. Mark completed
│ Completed    │     markChunkCompleted(url)
└──────┬───────┘     status = 'completed'
       │
       ▼
┌──────────────┐
│ AI Analysis  │  4. Batch creation
│ Batched      │     saveBatch(chunks)
└──────┬───────┘     Links chunks to batch
       │
       ▼
┌──────────────┐
│ Timeline     │  5. Timeline generation
│ Generated    │     saveTimelineCard()
└──────┬───────┘     Video reference stored
       │
       ▼
┌──────────────┐
│ Retention    │  6. Cleanup check
│ Exceeded     │     deleteOldChunks()
└──────┬───────┘     File + DB record deleted
       │
       ▼
┌──────────────┐
│ Chunk        │  Timeline preserved
│ Deleted      │  (video_summary_url cleared)
└──────────────┘
```

#### 2.2.3 Database Operations

**Register Recording Chunk**:
```swift
func registerChunk(url: URL) {
    // Extract timestamps from filename
    // Expected format: chunk_START_END.mov
    let filename = url.lastPathComponent
    let components = filename.replacingOccurrences(of: ".mov", with: "")
        .split(separator: "_")

    guard components.count >= 3,
          let startTs = Int(components[1]),
          let endTs = Int(components[2]) else {
        print("Invalid chunk filename: \(filename)")
        return
    }

    try db.write { db in
        try db.execute(sql: """
            INSERT INTO recording_chunks
            (file_url, start_ts, end_ts, status)
            VALUES (?, ?, ?, 'pending')
        """, arguments: [url.path, startTs, endTs])
    }
}
```

**Fetch Unprocessed Chunks**:
```swift
func fetchUnprocessedChunks(olderThan oldestAllowed: Int) -> [RecordingChunk] {
    try db.read { db in
        let rows = try Row.fetchAll(db, sql: """
            SELECT c.id, c.file_url, c.start_ts, c.end_ts
            FROM recording_chunks c
            LEFT JOIN batch_chunks bc ON c.id = bc.chunk_id
            WHERE c.status = 'completed'
              AND bc.batch_id IS NULL
              AND c.end_ts < ?
            ORDER BY c.start_ts ASC
        """, arguments: [oldestAllowed])

        return rows.map { row in
            RecordingChunk(
                id: row["id"],
                fileURL: URL(fileURLWithPath: row["file_url"]),
                startTs: row["start_ts"],
                endTs: row["end_ts"]
            )
        }
    }
}
```

**Automatic Cleanup**:
```swift
func cleanupOldChunks(retentionDays: Int = 3) async throws -> CleanupStats {
    let retentionSeconds = retentionDays * 24 * 60 * 60
    let cutoffTs = Int(Date().timeIntervalSince1970) - retentionSeconds

    var stats = CleanupStats()

    // Find chunks older than retention period
    let oldChunks = try await db.read { db -> [RecordingChunk] in
        let rows = try Row.fetchAll(db, sql: """
            SELECT id, file_url, start_ts, end_ts
            FROM recording_chunks
            WHERE end_ts < ?
        """, arguments: [cutoffTs])

        return rows.map { row in
            RecordingChunk(
                id: row["id"],
                fileURL: URL(fileURLWithPath: row["file_url"]),
                startTs: row["start_ts"],
                endTs: row["end_ts"]
            )
        }
    }

    stats.chunksFound = oldChunks.count

    // Delete files and database records
    for chunk in oldChunks {
        // Delete physical file
        do {
            try fileMgr.removeItem(at: chunk.fileURL)
            stats.filesDeleted += 1

            // Calculate freed space
            let fileSize = try fileMgr.attributesOfItem(atPath: chunk.fileURL.path)[.size] as? Int64 ?? 0
            stats.bytesFreed += fileSize
        } catch {
            print("Failed to delete chunk file: \(error)")
        }

        // Clear video references in timeline cards
        try await db.write { db in
            try db.execute(sql: """
                UPDATE timeline_cards
                SET video_summary_url = NULL
                WHERE video_summary_url LIKE ?
            """, arguments: ["%\(chunk.fileURL.lastPathComponent)%"])
        }

        // Delete database record
        try await db.write { db in
            try db.execute(sql: """
                DELETE FROM recording_chunks WHERE id = ?
            """, arguments: [chunk.id])
        }
        stats.recordsDeleted += 1
    }

    return stats
}

struct CleanupStats {
    var chunksFound: Int = 0
    var filesDeleted: Int = 0
    var recordsDeleted: Int = 0
    var bytesFreed: Int64 = 0
}
```

#### 2.2.4 Retention Policy Management

**Configuration**:
```swift
struct RetentionPolicy: Codable {
    var enabled: Bool = true
    var retentionDays: Int = 3
    var maxStorageGB: Int = 10
    var cleanupIntervalHours: Int = 1

    static let `default` = RetentionPolicy()
}

class RetentionManager {
    static let shared = RetentionManager()
    private var policy: RetentionPolicy
    private var cleanupTimer: Timer?

    init() {
        self.policy = loadPolicy()
        startAutomaticCleanup()
    }

    func startAutomaticCleanup() {
        let interval = TimeInterval(policy.cleanupIntervalHours * 3600)
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.performCleanup()
            }
        }
    }

    func performCleanup() async {
        guard policy.enabled else { return }

        do {
            let stats = try await StorageManager.shared.cleanupOldChunks(
                retentionDays: policy.retentionDays
            )
            print("Cleanup completed: \(stats)")
        } catch {
            print("Cleanup failed: \(error)")
        }
    }
}
```

#### 2.2.5 Storage Quota Management

**Storage Usage Tracking**:
```swift
func calculateStorageUsage() async throws -> StorageUsage {
    // Calculate database size
    let dbSize = try fileMgr.attributesOfItem(atPath: dbURL.path)[.size] as? Int64 ?? 0

    // Calculate total recording file size
    let recordingsSize = try await db.read { db -> Int64 in
        let chunks = try Row.fetchAll(db, sql: "SELECT file_url FROM recording_chunks")
        var totalSize: Int64 = 0

        for row in chunks {
            let path: String = row["file_url"]
            if let size = try? fileMgr.attributesOfItem(atPath: path)[.size] as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }

    return StorageUsage(
        databaseBytes: dbSize,
        recordingsBytes: recordingsSize,
        totalBytes: dbSize + recordingsSize
    )
}

struct StorageUsage {
    let databaseBytes: Int64
    let recordingsBytes: Int64
    let totalBytes: Int64

    var totalGB: Double {
        return Double(totalBytes) / (1024 * 1024 * 1024)
    }
}
```

#### 2.2.6 Testing Strategy

**Unit Tests**:
- Chunk registration and status transitions
- Unprocessed chunk queries
- Cleanup with various retention periods
- Storage calculation accuracy

**Integration Tests**:
- End-to-end chunk lifecycle
- Cleanup preserves timeline data
- Storage quota enforcement
- Concurrent cleanup operations

---

### Story 4.3: Settings and Configuration Persistence

**Goal**: Reliably persist user settings and app configuration across restarts with proper validation.

#### 2.3.1 Requirements

**Functional**:
- Settings persist across app restarts
- Settings load correctly on app launch
- Invalid settings handled gracefully with defaults
- Support for settings migration between app versions
- Settings backup/restore capability

**Non-Functional**:
- Load time: < 100ms for all settings
- Write latency: < 50ms per setting
- Storage overhead: < 100KB for all settings
- Validation time: < 10ms per setting

#### 2.3.2 Settings Architecture

**Settings Categories**:

```swift
// AI Provider Settings
struct AIProviderSettings: Codable {
    var selectedProvider: AIProviderType = .gemini
    var geminiAPIKey: String?           // Stored in Keychain
    var geminiModel: String = "gemini-1.5-flash"
    var ollamaEndpoint: String = "http://localhost:11434"
    var ollamaModel: String = "llava:latest"
    var lmStudioEndpoint: String = "http://localhost:1234"
    var lmStudioModel: String = "gpt-4-vision-preview"
}

// Recording Settings
struct RecordingSettings: Codable {
    var enabled: Bool = true
    var frameRate: Int = 1              // Frames per second
    var quality: VideoQuality = .medium
    var storageLocation: URL?
    var displays: [String] = []         // Empty = all displays
}

// Retention Settings
struct RetentionSettings: Codable {
    var enabled: Bool = true
    var retentionDays: Int = 3
    var maxStorageGB: Int = 10
    var cleanupIntervalHours: Int = 1
}

// Notification Settings
struct NotificationSettings: Codable {
    var enabled: Bool = true
    var analysisComplete: Bool = true
    var storageWarning: Bool = true
    var errorAlerts: Bool = true
}

// Analytics Settings
struct AnalyticsSettings: Codable {
    var sentryEnabled: Bool = false
    var postHogEnabled: Bool = false
    var crashReporting: Bool = false
}

// Focus Lock Settings
struct FocusLockSettings: Codable {
    var globalAllowedApps: [String] = ["Finder", "System Preferences"]
    var defaultSessionDuration: TimeInterval = 25 * 60  // 25 minutes
    var breakReminders: Bool = true
    var blockingMode: BlockingMode = .soft

    enum BlockingMode: String, Codable {
        case soft       // Warnings only
        case hard       // Block access
        case adaptive   // Learn from user behavior
    }
}
```

#### 2.3.3 Database Operations

**Save Setting**:
```swift
func saveSetting<T: Codable>(key: String, value: T) async throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    let jsonString = String(data: data, encoding: .utf8)!

    try await db.write { db in
        try db.execute(sql: """
            INSERT OR REPLACE INTO app_settings (key, value, updated_at)
            VALUES (?, ?, ?)
        """, arguments: [key, jsonString, Int(Date().timeIntervalSince1970)])
    }
}
```

**Load Setting**:
```swift
func loadSetting<T: Codable>(key: String, defaultValue: T) async throws -> T {
    let jsonString = try await db.read { db -> String? in
        try String.fetchOne(db, sql: """
            SELECT value FROM app_settings WHERE key = ?
        """, arguments: [key])
    }

    guard let jsonString = jsonString,
          let data = jsonString.data(using: .utf8) else {
        return defaultValue
    }

    let decoder = JSONDecoder()
    return try decoder.decode(T.self, from: data)
}
```

**Settings Manager**:
```swift
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var aiProvider: AIProviderSettings
    @Published var recording: RecordingSettings
    @Published var retention: RetentionSettings
    @Published var notifications: NotificationSettings
    @Published var analytics: AnalyticsSettings
    @Published var focusLock: FocusLockSettings

    private init() {
        // Load settings with defaults
        self.aiProvider = AIProviderSettings()
        self.recording = RecordingSettings()
        self.retention = RetentionSettings()
        self.notifications = NotificationSettings()
        self.analytics = AnalyticsSettings()
        self.focusLock = FocusLockSettings()

        Task {
            await loadAllSettings()
        }
    }

    func loadAllSettings() async {
        do {
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
        } catch {
            print("Failed to load settings: \(error)")
            // Settings remain at default values
        }
    }

    func save() async {
        do {
            try await StorageManager.shared.saveSetting(key: "aiProvider", value: aiProvider)
            try await StorageManager.shared.saveSetting(key: "recording", value: recording)
            try await StorageManager.shared.saveSetting(key: "retention", value: retention)
            try await StorageManager.shared.saveSetting(key: "notifications", value: notifications)
            try await StorageManager.shared.saveSetting(key: "analytics", value: analytics)
            try await StorageManager.shared.saveSetting(key: "focusLock", value: focusLock)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
}
```

#### 2.3.4 Settings Validation

**Validation Rules**:
```swift
protocol SettingsValidatable {
    func validate() throws
}

extension RecordingSettings: SettingsValidatable {
    func validate() throws {
        guard frameRate >= 1 && frameRate <= 30 else {
            throw SettingsError.invalidValue("Frame rate must be 1-30 FPS")
        }

        if let storageLocation = storageLocation {
            guard FileManager.default.fileExists(atPath: storageLocation.path) else {
                throw SettingsError.invalidPath("Storage location does not exist")
            }
        }
    }
}

extension RetentionSettings: SettingsValidatable {
    func validate() throws {
        guard retentionDays >= 1 && retentionDays <= 365 else {
            throw SettingsError.invalidValue("Retention days must be 1-365")
        }

        guard maxStorageGB >= 1 && maxStorageGB <= 1000 else {
            throw SettingsError.invalidValue("Max storage must be 1-1000 GB")
        }

        guard cleanupIntervalHours >= 1 && cleanupIntervalHours <= 24 else {
            throw SettingsError.invalidValue("Cleanup interval must be 1-24 hours")
        }
    }
}

enum SettingsError: Error {
    case invalidValue(String)
    case invalidPath(String)
    case migrationFailed(String)
}
```

#### 2.3.5 Settings Migration

**Version Management**:
```swift
struct SettingsMigration {
    let fromVersion: Int
    let toVersion: Int
    let migration: (Database) throws -> Void
}

class SettingsMigrationManager {
    static let migrations: [SettingsMigration] = [
        // Migration from version 1 to 2: Add new fields
        SettingsMigration(fromVersion: 1, toVersion: 2) { db in
            // Update AIProviderSettings schema
            let settings = try String.fetchOne(db, sql: """
                SELECT value FROM app_settings WHERE key = 'aiProvider'
            """)

            if var settings = settings,
               var data = settings.data(using: .utf8),
               var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Add new field with default value
                json["lmStudioEndpoint"] = "http://localhost:1234"

                let newData = try JSONSerialization.data(withJSONObject: json)
                let newString = String(data: newData, encoding: .utf8)!

                try db.execute(sql: """
                    UPDATE app_settings SET value = ? WHERE key = 'aiProvider'
                """, arguments: [newString])
            }
        }
    ]

    static func performMigrations(db: DatabasePool) throws {
        let currentVersion = UserDefaults.standard.integer(forKey: "settingsVersion")

        for migration in migrations where currentVersion < migration.toVersion {
            try db.write { db in
                try migration.migration(db)
            }
            UserDefaults.standard.set(migration.toVersion, forKey: "settingsVersion")
        }
    }
}
```

#### 2.3.6 Secure API Key Storage

**Keychain Integration**:
```swift
class KeychainManager {
    static let shared = KeychainManager()

    func saveAPIKey(_ key: String, for provider: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.focuslock.apikeys",
            kSecAttrAccount as String: provider,
            kSecValueData as String: key.data(using: .utf8)!
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func loadAPIKey(for provider: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.focuslock.apikeys",
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
    }
}
```

#### 2.3.7 Backup and Restore

**Settings Backup**:
```swift
struct SettingsBackup: Codable {
    let version: Int
    let timestamp: Date
    let settings: [String: String]  // All settings as JSON strings

    static func create() async throws -> SettingsBackup {
        let db = StorageManager.shared.db
        let settingsDict = try await db.read { db -> [String: String] in
            let rows = try Row.fetchAll(db, sql: "SELECT key, value FROM app_settings")
            var dict: [String: String] = [:]
            for row in rows {
                dict[row["key"]] = row["value"]
            }
            return dict
        }

        return SettingsBackup(
            version: 1,
            timestamp: Date(),
            settings: settingsDict
        )
    }

    func restore() async throws {
        let db = StorageManager.shared.db

        try await db.write { db in
            for (key, value) in settings {
                try db.execute(sql: """
                    INSERT OR REPLACE INTO app_settings (key, value, updated_at)
                    VALUES (?, ?, ?)
                """, arguments: [key, value, Int(Date().timeIntervalSince1970)])
            }
        }
    }
}
```

#### 2.3.8 Testing Strategy

**Unit Tests**:
- Settings save and load
- Default value fallback
- Validation rules enforcement
- Migration execution

**Integration Tests**:
- Settings persistence across app restart
- Invalid settings handling
- Keychain integration
- Backup/restore functionality

---

## 3. Threading and Concurrency

### 3.1 Actor-Based Architecture

**Database Access Pattern**:
```swift
actor DatabaseCoordinator {
    private let pool: DatabasePool
    private let serialQueue = DispatchQueue(label: "com.focuslock.db.serial")

    func write<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            serialQueue.async {
                do {
                    let result = try self.pool.write { db in
                        try operation(db)
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func read<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        return try await pool.read { db in
            try operation(db)
        }
    }
}
```

### 3.2 Transaction Management

**Multi-Step Operations**:
```swift
func saveTimelineWithBatch(
    batchId: Int64,
    cards: [TimelineCardShell]
) async throws -> [Int64] {
    return try await db.write { db in
        var cardIds: [Int64] = []

        // Start transaction
        try db.inTransaction {
            for card in cards {
                // Save each card
                try db.execute(sql: """
                    INSERT INTO timeline_cards (...)
                    VALUES (...)
                """, arguments: [...])

                cardIds.append(db.lastInsertedRowID)
            }

            // Update batch status
            try db.execute(sql: """
                UPDATE analysis_batches
                SET status = 'completed'
                WHERE id = ?
            """, arguments: [batchId])

            return .commit
        }

        return cardIds
    }
}
```

### 3.3 Concurrent Access Patterns

**Read-Heavy Workload**:
- Use `DatabasePool` for concurrent reads
- Single writer, multiple readers (GRDB default)
- Write operations serialized through queue

**Write Contention**:
- Batch write operations when possible
- Use transactions for multi-step operations
- Monitor write queue depth

---

## 4. Performance Requirements

### 4.1 Latency Targets

| Operation | Target | Maximum |
|-----------|--------|---------|
| Timeline card save | < 50ms | < 100ms |
| Timeline day load | < 500ms | < 2s |
| Settings save | < 20ms | < 50ms |
| Settings load | < 50ms | < 100ms |
| Chunk cleanup | < 2s | < 5s |
| Database query | < 100ms | < 500ms |

### 4.2 Throughput Targets

| Metric | Target |
|--------|--------|
| Timeline cards/second | 20+ |
| Concurrent reads | 10+ |
| Database size (30 days) | < 50MB |
| Memory footprint | < 10MB |

### 4.3 Performance Monitoring

**Metrics Collection**:
```swift
actor PerformanceMonitor {
    private var metrics: [String: [TimeInterval]] = [:]

    func record(operation: String, duration: TimeInterval) {
        metrics[operation, default: []].append(duration)

        // Keep last 100 measurements
        if metrics[operation]!.count > 100 {
            metrics[operation]!.removeFirst()
        }
    }

    func getStats(for operation: String) -> PerformanceStats? {
        guard let durations = metrics[operation], !durations.isEmpty else {
            return nil
        }

        let sorted = durations.sorted()
        return PerformanceStats(
            count: durations.count,
            average: durations.reduce(0, +) / Double(durations.count),
            median: sorted[sorted.count / 2],
            p95: sorted[Int(Double(sorted.count) * 0.95)],
            p99: sorted[Int(Double(sorted.count) * 0.99)]
        )
    }
}

struct PerformanceStats {
    let count: Int
    let average: TimeInterval
    let median: TimeInterval
    let p95: TimeInterval
    let p99: TimeInterval
}
```

---

## 5. Testing Strategy

### 5.1 Unit Testing

**Coverage Targets**:
- Database operations: 90%+
- Settings validation: 100%
- Migration logic: 100%
- Cleanup logic: 85%+

**Key Test Cases**:
```swift
class TimelinePersistenceTests: XCTestCase {
    func testSaveAndLoadTimelineCard() async throws
    func testTimelineCardIntegrity() async throws
    func testConcurrentTimelineWrites() async throws
    func testInvalidTimelineCardRejection() async throws
}

class ChunkManagementTests: XCTestCase {
    func testChunkLifecycle() async throws
    func testAutomaticCleanup() async throws
    func testRetentionPolicy() async throws
    func testStorageQuotaEnforcement() async throws
}

class SettingsPersistenceTests: XCTestCase {
    func testSettingsSaveAndLoad() async throws
    func testSettingsValidation() async throws
    func testSettingsMigration() async throws
    func testInvalidSettingsHandling() async throws
}
```

### 5.2 Integration Testing

**Test Scenarios**:
1. **End-to-End Timeline Flow**: Recording → Analysis → Timeline → Display
2. **Cleanup Under Load**: Cleanup during active recording
3. **Settings Persistence**: Modify settings → Restart app → Verify
4. **Concurrent Operations**: Multiple writes + reads simultaneously
5. **Data Migration**: Upgrade from v1 → v2 schema

### 5.3 Performance Testing

**Benchmarks**:
```swift
func testTimelineLoadPerformance() async throws {
    // Create 30 days of timeline data (1000+ cards)
    await createTestTimeline(days: 30)

    // Measure load time
    let start = Date()
    let cards = try await storageManager.fetchTimelineCards(forDay: "2025-11-13")
    let duration = Date().timeIntervalSince(start)

    XCTAssertLessThan(duration, 2.0, "Timeline load exceeded 2s target")
    XCTAssertGreaterThan(cards.count, 0)
}
```

### 5.4 Stress Testing

**Scenarios**:
- 10,000+ timeline cards
- 1000+ concurrent reads
- 100+ writes per second
- 8+ hour continuous operation
- Database file > 100MB

---

## 6. Implementation Roadmap

### Phase 1: Foundation (Week 1)
- ✅ Database schema finalized
- ✅ Thread-safe access patterns
- ✅ Basic CRUD operations
- ✅ Unit test framework

### Phase 2: Timeline Persistence (Week 1-2)
- Timeline card save/load
- Day-based queries
- Time-range queries
- Data integrity checks
- Performance optimization

### Phase 3: Chunk Management (Week 2)
- Recording chunk lifecycle
- Automatic cleanup
- Retention policies
- Storage quota management

### Phase 4: Settings Persistence (Week 2-3)
- Settings save/load
- Validation framework
- Migration system
- Keychain integration
- Backup/restore

### Phase 5: Testing & Optimization (Week 3)
- Integration tests
- Performance tests
- Stress tests
- Performance tuning

---

## 7. Success Metrics

### 7.1 Functional Metrics
- ✅ Timeline data persists across 100 app restarts (0 failures)
- ✅ Cleanup removes chunks correctly (100% success rate)
- ✅ Settings persist and validate (100% success rate)
- ✅ No data corruption detected (0 integrity violations)

### 7.2 Performance Metrics
- ✅ Timeline loads < 2s for 30 days (95th percentile)
- ✅ Database operations < 100ms (average)
- ✅ Memory footprint < 10MB (database layer)
- ✅ Storage overhead < 1% (metadata vs video)

### 7.3 Reliability Metrics
- ✅ Zero crashes related to database operations
- ✅ 100% data recovery after force quit
- ✅ Migration success rate 100%
- ✅ Cleanup success rate > 99%

---

## 8. Risk Mitigation

### 8.1 Identified Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Database corruption | High | Low | WAL mode, transactions, backups |
| Thread safety violations | High | Medium | Actor isolation, serial queue |
| Performance degradation | Medium | Medium | Indexes, caching, monitoring |
| Migration failures | Medium | Low | Versioning, rollback, testing |
| Storage quota exceeded | Low | Medium | Automatic cleanup, alerts |

### 8.2 Fallback Strategies

**Database Corruption**:
1. Detect corruption on app launch
2. Attempt automatic repair (SQLite PRAGMA)
3. Restore from backup if available
4. Create fresh database with data loss warning

**Migration Failure**:
1. Detect migration error
2. Rollback to previous version
3. Alert user with retry option
4. Log detailed error for debugging

---

## 9. Dependencies

### 9.1 External Dependencies
- **GRDB.swift** v7.0.0+: SQLite toolkit
- **Keychain Services**: Secure credential storage

### 9.2 Internal Dependencies
- **Epic 1**: Memory management fixes (prerequisite)
- **Epic 2**: Recording pipeline (data source)
- **Epic 3**: AI analysis (timeline generation)

---

## 10. Documentation Requirements

### 10.1 Developer Documentation
- Database schema reference
- API documentation (inline comments)
- Migration guide
- Performance tuning guide

### 10.2 User Documentation
- Settings configuration guide
- Storage management guide
- Troubleshooting guide
- Data backup/restore guide

---

## Appendix A: Database Schema SQL

See Section 1.1 for complete schema definitions.

## Appendix B: Sample Code

See relevant sections for implementation examples.

## Appendix C: Performance Benchmarks

See Section 4 for performance targets and monitoring.

---

**Document Version**: 1.0
**Last Updated**: 2025-11-13
**Author**: Claude Code (Epic Tech Context Workflow)
**Review Status**: Ready for Implementation
