# Epic Technical Specification: Critical Memory Management Rescue

Date: 2025-11-13
Author: darius
Epic ID: epic-1
Status: Draft

---

## Overview

Epic 1 addresses critical memory management failures that prevent FocusLock from running for more than 2 minutes without crashing. The root cause is concurrent access to GRDB database operations from multiple threads, specifically in `StorageManager.chunksForBatch()`, which triggers "freed pointer was not last allocation" errors. This epic implements a serial database access pattern, bounded buffer management for screen recording, thread-safe background processing, and comprehensive memory leak detection to achieve 8+ hour continuous operation.

The rescue architecture prioritizes memory safety through serial database operations, thread isolation, bounded resource management, and enhanced diagnostics. All four stories in this epic are IMMEDIATE PRIORITY and must be completed before any other feature development can proceed.

## Objectives and Scope

### In Scope
- Fix database threading crash in `StorageManager.chunksForBatch()` by implementing serial queue wrapper
- Implement bounded video frame buffer management with automatic cleanup (max 100 frames)
- Create thread-safe database access wrapper (`DatabaseManager`) for all GRDB operations
- Add memory leak detection system with real-time monitoring and alerting
- Ensure proper QoS configuration for database threads to prevent priority inversion
- Validate 8+ hour continuous operation without crashes or memory leaks
- Add comprehensive memory usage tracking and diagnostic logging

### Out of Scope
- Feature development or UI improvements (deferred to later epics)
- Performance optimization beyond memory safety (addressed in Epic 2)
- AI analysis improvements (addressed in Epic 3)
- Database schema changes or migrations (addressed in Epic 4)
- Cloud synchronization or backup features (future enhancement)

## System Architecture Alignment

### Architecture Components Referenced

**Rescue Architecture Pattern (from architecture.md):**
- **Serial Database Queue**: All database operations must go through a single `DispatchQueue` with label `com.focusLock.database`
- **DatabaseManager Wrapper**: New component that wraps GRDB operations with serial queue guarantees
- **BufferManager**: Bounded memory management for `CVPixelBuffer` instances in screen recording
- **MemoryMonitor**: Real-time memory leak detection and alerting system

**Existing Components Modified:**
- `StorageManager.chunksForBatch()`: Must call through `DatabaseManager` instead of direct GRDB access
- `ScreenRecorder`: Add `BufferManager` integration for frame buffer lifecycle
- `AnalysisManager`: Update background processing to use `DatabaseManager` for thread-safe access
- `LLMService`: Ensure AI processing doesn't access database directly from background threads

**Architecture Constraints:**
- macOS 13.0+ (Ventura) minimum OS requirement
- Swift concurrency (async/await, actors) for thread safety
- GRDB 6.x for database persistence
- AVFoundation for video frame processing
- ScreenCaptureKit for screen capture

## Detailed Design

### Services and Modules

| Module/Service | Responsibility | Input/Output | Owner/Dependencies |
|----------------|----------------|--------------|-------------------|
| **DatabaseManager** | Serial queue wrapper for all GRDB operations | Input: Database operations (closures)<br>Output: Results on serial queue | Core/Database<br>Depends on: GRDB |
| **StorageManager** | Recording chunk management and metadata | Input: Video URLs, batch IDs<br>Output: Recording chunks, file metadata | Core/Recording<br>Depends on: DatabaseManager |
| **BufferManager** | Bounded video frame buffer lifecycle | Input: CVPixelBuffer instances<br>Output: Managed buffer pool (max 100) | Core/Recording<br>Depends on: AVFoundation |
| **MemoryMonitor** | Real-time memory leak detection and alerting | Input: Memory usage samples<br>Output: Alerts, logs, trend data | Core/Diagnostics<br>Depends on: Foundation |
| **ScreenRecorder** | Screen capture and video encoding | Input: SCStream frames<br>Output: Video chunks on disk | Core/Recording<br>Depends on: BufferManager, StorageManager |
| **AnalysisManager** | Background AI processing coordinator | Input: Recording chunks<br>Output: Timeline cards via AI | Core/Analysis<br>Depends on: DatabaseManager, LLMService |

### Data Models and Contracts

**DatabaseManager Protocol**
```swift
protocol DatabaseManagerProtocol: Sendable {
    /// Execute a read operation on the serial database queue
    func read<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T

    /// Execute a write operation on the serial database queue
    func write<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T

    /// Execute a transaction on the serial database queue
    func transaction<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T
}
```

**BufferManager Data Model**
```swift
actor BufferManager {
    private struct ManagedBuffer {
        let buffer: CVPixelBuffer
        let createdAt: Date
        let id: UUID
    }

    private var buffers: [UUID: ManagedBuffer] = [:]
    private let maxBuffers: Int = 100

    /// Add a buffer to the managed pool, automatically evicting oldest if at capacity
    func addBuffer(_ buffer: CVPixelBuffer) -> UUID

    /// Remove and release a specific buffer
    func releaseBuffer(_ id: UUID)

    /// Get current buffer count for diagnostics
    func bufferCount() -> Int
}
```

**MemoryMonitor Data Model**
```swift
struct MemorySnapshot: Codable {
    let timestamp: Date
    let usedMemoryMB: Double
    let availableMemoryMB: Double
    let bufferCount: Int
    let databaseConnectionCount: Int
}

struct MemoryAlert: Codable {
    let severity: AlertSeverity // .warning, .critical
    let message: String
    let snapshot: MemorySnapshot
    let recommendedAction: String
}

enum AlertSeverity: String, Codable {
    case warning   // Memory usage >75%
    case critical  // Memory usage >90% or leak detected
}
```

**RecordingChunk Model (Enhanced)**
```swift
struct RecordingChunk: Codable, Identifiable {
    let id: Int64
    let fileURL: URL
    let startTime: Date
    let endTime: Date
    let batchId: Int64
    let status: ChunkStatus
    let fileSizeBytes: Int64
    let frameCount: Int

    // New fields for memory diagnostics
    let peakMemoryMB: Double?
    let averageMemoryMB: Double?
}

enum ChunkStatus: String, Codable {
    case pending
    case completed
    case failed
    case processing
}
```

### APIs and Interfaces

**DatabaseManager Implementation**
```swift
actor DatabaseManager: DatabaseManagerProtocol {
    static let shared = DatabaseManager()

    private let serialQueue = DispatchQueue(
        label: "com.focusLock.database",
        qos: .userInitiated
    )

    private let pool: DatabasePool

    private init() {
        // Initialize GRDB database pool
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dayflow")
            .appendingPathComponent("chunks.sqlite")

        self.pool = try! DatabasePool(path: url.path)
    }

    func read<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            serialQueue.async {
                do {
                    let result = try self.pool.read(operation)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func write<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            serialQueue.async {
                do {
                    let result = try self.pool.write(operation)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

**StorageManager.chunksForBatch() - Fixed Implementation**
```swift
// OLD (CRASHES):
func chunksForBatch(_ batchId: Int64) -> [RecordingChunk] {
    // PROBLEM: Direct database access from any thread
    return try! dbPool.read { db in
        try RecordingChunk.fetchAll(db, sql: "SELECT * FROM chunks WHERE batch_id = ?", arguments: [batchId])
    }
}

// NEW (THREAD-SAFE):
func chunksForBatch(_ batchId: Int64) async throws -> [RecordingChunk] {
    // SOLUTION: All access goes through serial DatabaseManager
    return try await DatabaseManager.shared.read { db in
        try RecordingChunk.fetchAll(db, sql: "SELECT * FROM chunks WHERE batch_id = ?", arguments: [batchId])
    }
}
```

**MemoryMonitor Public API**
```swift
actor MemoryMonitor {
    static let shared = MemoryMonitor()

    /// Start continuous memory monitoring with configurable interval
    func startMonitoring(interval: TimeInterval = 10.0)

    /// Stop memory monitoring
    func stopMonitoring()

    /// Get current memory snapshot
    func currentSnapshot() async -> MemorySnapshot

    /// Get memory trend over time period
    func memoryTrend(lastMinutes: Int) async -> [MemorySnapshot]

    /// Register callback for memory alerts
    func onAlert(_ handler: @escaping (MemoryAlert) -> Void)

    /// Force garbage collection and memory cleanup
    func forceCleanup() async
}
```

### Workflows and Sequencing

**Story 1.1: Database Threading Crash Fix**

Sequence:
1. Developer creates `DatabaseManager` actor with serial queue
2. `DatabaseManager` initializes GRDB `DatabasePool` on first access
3. All existing database operations refactored to call through `DatabaseManager.read()` or `DatabaseManager.write()`
4. `StorageManager.chunksForBatch()` becomes async and uses `DatabaseManager.shared.read()`
5. `AnalysisManager` background processing updated to await database calls
6. Stress test runs 10 concurrent database operations without crashes

**Story 1.2: Screen Recording Memory Cleanup**

Sequence:
1. Developer creates `BufferManager` actor to manage `CVPixelBuffer` lifecycle
2. `ScreenRecorder.stream(_:didOutputSampleBuffer:)` integrates `BufferManager.addBuffer()`
3. `BufferManager` automatically evicts oldest buffers when count exceeds 100
4. Each buffer properly locked/unlocked with `CVPixelBufferLockBaseAddress`/`CVPixelBufferUnlockBaseAddress`
5. `BufferManager.deinit` ensures all buffers released on cleanup
6. Memory usage monitored during 8-hour recording session (target: <100MB stable)

**Story 1.3: Thread-Safe Database Operations**

Sequence:
1. Audit all database access points in codebase (StorageManager, AnalysisManager, LLMService)
2. Replace synchronous database calls with async `DatabaseManager` calls
3. Configure QoS for database serial queue: `.userInitiated` to prevent priority inversion
4. Add transaction isolation for batch operations (AI analysis + timeline writes)
5. Update UI layer to handle async database calls (loading states, error handling)
6. Stress test: Run concurrent AI analysis + UI database access without crashes

**Story 1.4: Memory Leak Detection System**

Sequence:
1. Developer implements `MemoryMonitor` actor with periodic sampling (every 10 seconds)
2. `MemoryMonitor` tracks: total memory, buffer count, database connections, AVFoundation resources
3. Alert thresholds configured: Warning >75% memory, Critical >90% or 5% increase over 5 minutes
4. Integrate with Sentry for crash context (memory state included in crash reports)
5. Add UI indicator for memory status in status bar
6. Test with artificial memory leak (intentionally retain buffers) to validate detection

## Non-Functional Requirements

### Performance

**Memory Usage Targets:**
- **Baseline (idle)**: <50MB RAM usage when recording but not processing AI
- **Active recording**: <100MB RAM usage during continuous 1 FPS screen capture
- **AI processing peak**: <300MB RAM usage during batch AI analysis (transient)
- **Memory leak threshold**: No >5% memory increase over 1-hour period during steady-state operation

**Latency Targets:**
- **Database operations**: <50ms for read operations, <100ms for write operations
- **Buffer allocation**: <10ms for `BufferManager.addBuffer()` operation
- **Memory monitoring overhead**: <1% CPU usage for periodic sampling
- **UI responsiveness**: No blocking operations on main thread (all database calls async)

**Throughput Targets:**
- **Database transactions**: Support 100+ transactions per second without queue buildup
- **Frame processing**: Process 1 FPS screen capture without dropped frames
- **Memory cleanup**: Automatic buffer eviction in <5ms when threshold exceeded

### Security

**Data Protection:**
- **Database encryption**: GRDB database file encrypted at rest using macOS FileVault
- **Memory buffer security**: Video frame buffers cleared on release (no data remnants)
- **Crash report privacy**: Memory snapshots sanitized to exclude user screen content
- **Keychain integration**: API keys stored securely (outside Epic 1 scope, but integration point preserved)

**Thread Safety:**
- **Database isolation**: Serial queue prevents race conditions and data corruption
- **Actor isolation**: Swift actors used for `DatabaseManager`, `BufferManager`, `MemoryMonitor` to guarantee thread safety
- **Sendable conformance**: All data crossing actor boundaries conforms to `Sendable` protocol

### Reliability/Availability

**Stability Requirements:**
- **Zero crashes**: No "freed pointer was not last allocation" errors during 8-hour continuous operation
- **Crash recovery**: If crash occurs, database transactions roll back cleanly (GRDB ACID guarantees)
- **Memory exhaustion handling**: Graceful degradation when memory >90% (pause AI processing, continue recording)
- **Automatic cleanup**: Failed database operations don't leak connections or locks

**Error Recovery:**
- **Database operation failures**: Retry with exponential backoff (max 3 attempts)
- **Memory allocation failures**: Release oldest buffers and retry operation
- **Critical memory state**: Alert user and suggest app restart if cleanup fails
- **Diagnostic logging**: All errors logged with memory context for debugging

**Availability Targets:**
- **Uptime**: 99.9% uptime during 8-hour work sessions (allows <5 minutes downtime)
- **Recovery time**: Automatic recovery from transient errors within 30 seconds
- **Data integrity**: 100% database consistency (no corrupted chunks or missing data)

### Observability

**Logging Requirements:**
- **Database operations**: Log all database errors with stack traces, memory context
- **Memory monitoring**: Log memory snapshots at 10-second intervals (compressed to trends)
- **Buffer lifecycle**: Log buffer allocation/release events (sampled at 1% to reduce overhead)
- **Thread safety**: Log priority inversion warnings, queue depth alerts

**Metrics to Track:**
- `memory_used_mb`: Current memory usage in megabytes
- `buffer_count`: Number of active CVPixelBuffer instances
- `database_queue_depth`: Number of pending database operations
- `database_operation_duration_ms`: P50, P95, P99 latency for database operations
- `crash_free_session_duration_hours`: Time since last crash
- `memory_cleanup_triggered_count`: Number of automatic buffer evictions

**Tracing Requirements:**
- **Database transaction traces**: Trace database operations from caller through `DatabaseManager` to GRDB
- **Memory allocation traces**: Track buffer allocation paths to identify leak sources
- **Thread transition traces**: Log thread hops (main → recorder queue → database queue)

**Alerting:**
- **Memory threshold exceeded**: Alert when memory >90% for >1 minute
- **Database queue backlog**: Alert when queue depth >50 operations
- **Crash detected**: Immediate Sentry report with memory snapshot
- **Memory leak detected**: Alert when memory increases >5% over 5 minutes without cleanup

## Dependencies and Integrations

### External Dependencies

**Swift Packages (from Package.resolved / Xcode project):**
- **GRDB.swift**: Version 6.x - Type-safe SQLite database wrapper
- **Sparkle**: Version 2.x - Automatic update framework (no direct Epic 1 dependency)
- **Sentry**: Version 8.x - Error tracking and crash reporting integration
- **PostHog**: Version 3.x - Product analytics (optional, sampling enabled)

**System Frameworks:**
- **Foundation**: Core Swift framework for system primitives
- **AVFoundation**: Video frame processing, `CVPixelBuffer` management
- **ScreenCaptureKit**: Screen capture stream integration (existing, no changes needed)
- **CoreGraphics**: Pixel buffer manipulation (existing, no changes needed)

### Internal Service Integrations

**Existing Services Modified:**
- **StorageManager**:
  - Current: Direct GRDB access from `chunksForBatch()`, `registerChunk()`, `markChunkCompleted()`
  - After Epic 1: All database calls routed through `DatabaseManager`
  - Breaking change: `chunksForBatch()` becomes async

- **AnalysisManager**:
  - Current: Background thread calls `StorageManager.chunksForBatch()` synchronously
  - After Epic 1: Await async database calls, handle async context
  - File: `Dayflow/Dayflow/Core/Analysis/AnalysisManager.swift` line 364

- **ScreenRecorder**:
  - Current: Unbounded buffer retention in `stream(_:didOutputSampleBuffer:)`
  - After Epic 1: Integrate `BufferManager` for bounded lifecycle
  - File: `Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift` lines 657-682

- **LLMService**:
  - Current: Unknown if direct database access occurs (needs audit)
  - After Epic 1: Ensure no synchronous database calls from AI processing threads

**New Services Introduced:**
- `DatabaseManager`: Actor-based serial queue wrapper for GRDB
- `BufferManager`: Actor-based bounded buffer pool for video frames
- `MemoryMonitor`: Actor-based memory leak detection and alerting

### Integration Points

**ScreenRecorder → BufferManager:**
```swift
// In ScreenRecorder.stream(_:didOutputSampleBuffer:)
func stream(_ s: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sb) else { return }

    // NEW: Register buffer with BufferManager
    Task {
        let bufferId = await BufferManager.shared.addBuffer(pixelBuffer)
        // Buffer automatically released when count exceeds 100
    }

    // Existing video encoding logic continues...
}
```

**AnalysisManager → DatabaseManager:**
```swift
// OLD: Synchronous database access from background thread
let chunks = StorageManager.shared.chunksForBatch(batchId) // CRASHES

// NEW: Async database access through DatabaseManager
let chunks = try await StorageManager.shared.chunksForBatch(batchId) // SAFE
```

**AppState → MemoryMonitor:**
```swift
// In app initialization
Task {
    await MemoryMonitor.shared.startMonitoring(interval: 10.0)
    await MemoryMonitor.shared.onAlert { alert in
        // Update UI memory status indicator
        Task { @MainActor in
            AppState.shared.memoryStatus = alert.severity
        }
    }
}
```

## Acceptance Criteria (Authoritative)

### Story 1.1: Database Threading Crash Fix

1. **AC-1.1.1**: Application launches successfully and initializes `DatabaseManager` with serial queue
2. **AC-1.1.2**: When `StorageManager.chunksForBatch()` is called from multiple threads simultaneously, no "freed pointer was not last allocation" crashes occur
3. **AC-1.1.3**: Stress test with 10 concurrent database operations (reads + writes) completes without crashes or data corruption
4. **AC-1.1.4**: App remains stable for at least 30 minutes of continuous recording with background AI analysis
5. **AC-1.1.5**: All GRDB database operations complete successfully through `DatabaseManager` serial queue
6. **AC-1.1.6**: Database operation latency remains <100ms for 95th percentile of operations

### Story 1.2: Screen Recording Memory Cleanup

1. **AC-1.2.1**: Screen recording runs continuously for 1+ hours with stable memory usage
2. **AC-1.2.2**: Memory usage remains below 100MB during continuous recording (excluding AI processing spikes)
3. **AC-1.2.3**: `BufferManager` automatically evicts oldest buffers when count exceeds 100 frames
4. **AC-1.2.4**: No memory leaks detected in screen recording pipeline over 8-hour session
5. **AC-1.2.5**: All `CVPixelBuffer` instances properly locked/unlocked and released on eviction
6. **AC-1.2.6**: Buffer allocation time remains <10ms for 99th percentile

### Story 1.3: Thread-Safe Database Operations

1. **AC-1.3.1**: All database access points audited and routed through `DatabaseManager`
2. **AC-1.3.2**: Background AI analysis runs concurrently with UI database access without crashes
3. **AC-1.3.3**: No priority inversion errors detected (QoS configured correctly on database queue)
4. **AC-1.3.4**: UI remains responsive (<200ms) during background database operations
5. **AC-1.3.5**: Database transactions properly isolated (AI processing doesn't interfere with recording writes)
6. **AC-1.3.6**: Stress test with 50 concurrent AI analysis + UI interactions completes without crashes

### Story 1.4: Memory Leak Detection System

1. **AC-1.4.1**: `MemoryMonitor` starts successfully on app launch and samples memory every 10 seconds
2. **AC-1.4.2**: When memory usage exceeds 75%, warning alert generated with diagnostic snapshot
3. **AC-1.4.3**: When memory usage exceeds 90%, critical alert generated with recommended cleanup action
4. **AC-1.4.4**: Automatic memory leak detection: Alert generated when memory increases >5% over 5-minute period without cleanup
5. **AC-1.4.5**: Memory usage trends logged for analysis (available in Sentry crash context)
6. **AC-1.4.6**: Artificial memory leak test (intentionally retain buffers) triggers alert within 2 monitoring cycles
7. **AC-1.4.7**: `MemoryMonitor` overhead remains <1% CPU usage during continuous monitoring

## Traceability Mapping

| AC ID | Spec Section | Component/API | Test Idea |
|-------|--------------|---------------|-----------|
| AC-1.1.1 | Detailed Design → DatabaseManager | `DatabaseManager.init()` | Unit test: DatabaseManager initializes with correct queue label and QoS |
| AC-1.1.2 | APIs → StorageManager.chunksForBatch() | `StorageManager.chunksForBatch()`, `DatabaseManager.read()` | Integration test: Call chunksForBatch from 10 threads simultaneously, verify no crashes |
| AC-1.1.3 | Workflows → Story 1.1 | `DatabaseManager` serial queue | Stress test: Run mixed read/write operations, verify data consistency |
| AC-1.1.4 | NFR → Reliability | `DatabaseManager`, `ScreenRecorder`, `AnalysisManager` | System test: 30-minute continuous recording with AI analysis, monitor crash logs |
| AC-1.1.5 | APIs → DatabaseManager | `DatabaseManager.read()`, `DatabaseManager.write()` | Integration test: Verify all database operations use DatabaseManager wrapper |
| AC-1.1.6 | NFR → Performance | `DatabaseManager` queue latency | Performance test: Measure P95 latency for database operations under load |
| AC-1.2.1 | Workflows → Story 1.2 | `ScreenRecorder`, `BufferManager` | System test: 1-hour recording, verify no crashes |
| AC-1.2.2 | NFR → Performance → Memory Usage | `BufferManager`, `MemoryMonitor` | Performance test: Monitor memory usage every 10 seconds, verify <100MB |
| AC-1.2.3 | APIs → BufferManager | `BufferManager.addBuffer()` | Unit test: Add 150 buffers, verify count stays at 100 |
| AC-1.2.4 | NFR → Reliability | `BufferManager`, `MemoryMonitor` | System test: 8-hour recording, verify no memory leaks detected |
| AC-1.2.5 | Detailed Design → BufferManager | `BufferManager.addBuffer()`, `BufferManager.releaseBuffer()` | Unit test: Verify lock/unlock calls for each buffer |
| AC-1.2.6 | NFR → Performance → Latency | `BufferManager.addBuffer()` | Performance test: Measure P99 allocation latency |
| AC-1.3.1 | Workflows → Story 1.3 | All database access points | Code audit: Search for `dbPool.read` and `dbPool.write`, verify all use DatabaseManager |
| AC-1.3.2 | Workflows → Story 1.3 | `AnalysisManager`, UI database access | Integration test: Run AI analysis while UI loads timeline, verify no crashes |
| AC-1.3.3 | NFR → Reliability | `DatabaseManager` QoS configuration | Unit test: Verify queue QoS is `.userInitiated` |
| AC-1.3.4 | NFR → Performance → Latency | UI database operations | UI test: Measure UI response time during background database load |
| AC-1.3.5 | APIs → DatabaseManager | `DatabaseManager.transaction()` | Integration test: Verify transaction isolation with concurrent operations |
| AC-1.3.6 | Workflows → Story 1.3 | Stress test | Stress test: 50 concurrent AI + UI operations, verify no crashes |
| AC-1.4.1 | Workflows → Story 1.4 | `MemoryMonitor.startMonitoring()` | Unit test: Start monitoring, verify samples collected at correct interval |
| AC-1.4.2 | APIs → MemoryMonitor | `MemoryMonitor.onAlert()` | Integration test: Force memory to 75%, verify warning alert generated |
| AC-1.4.3 | APIs → MemoryMonitor | `MemoryMonitor.onAlert()` | Integration test: Force memory to 90%, verify critical alert generated |
| AC-1.4.4 | Workflows → Story 1.4 | Memory leak detection algorithm | Integration test: Gradually leak memory, verify alert within expected time |
| AC-1.4.5 | NFR → Observability | `MemoryMonitor`, Sentry integration | Integration test: Verify memory snapshot included in Sentry crash context |
| AC-1.4.6 | Workflows → Story 1.4 | Artificial memory leak | Integration test: Intentionally retain buffers, verify detection |
| AC-1.4.7 | NFR → Performance | `MemoryMonitor` CPU usage | Performance test: Monitor CPU usage during continuous monitoring |

## Risks, Assumptions, Open Questions

### Risks

**R-1 (HIGH): Async refactoring breaks existing synchronous callers**
- Impact: Changing `StorageManager.chunksForBatch()` to async breaks existing synchronous call sites
- Mitigation: Comprehensive code audit of all database access points before refactoring; create temporary synchronous wrapper during transition; thorough testing of each caller
- Owner: Story 1.1 implementer

**R-2 (MEDIUM): Actor reentrancy causes deadlocks**
- Impact: Swift actors can have reentrancy issues if not carefully designed
- Mitigation: Use `isolated` parameters, avoid calling other actors within actor methods, comprehensive deadlock testing
- Owner: Story 1.1, 1.2, 1.4 implementers

**R-3 (MEDIUM): BufferManager eviction causes visible frame drops**
- Impact: Evicting buffers while video encoding might cause dropped frames or visual artifacts
- Mitigation: Coordinate with `ScreenRecorder` to evict only processed buffers; add reference counting to prevent premature release
- Owner: Story 1.2 implementer

**R-4 (LOW): MemoryMonitor false positives**
- Impact: Memory monitoring might generate false positive alerts during legitimate AI processing spikes
- Mitigation: Tune thresholds based on actual usage patterns; add context awareness (e.g., suppress alerts during known AI batch processing)
- Owner: Story 1.4 implementer

**R-5 (LOW): Performance regression from serial queue**
- Impact: Forcing all database operations through serial queue might reduce throughput
- Mitigation: Benchmark current vs. new performance; optimize database operations; use read-only connections for parallel reads if needed
- Owner: Story 1.3 implementer

### Assumptions

**A-1**: GRDB 6.x supports the serial queue access pattern without internal conflicts
- Validation: Review GRDB documentation and GitHub issues for threading best practices

**A-2**: macOS provides sufficient memory monitoring APIs for leak detection
- Validation: Prototype `MemoryMonitor` using `task_info` and `mach_task_self()` APIs

**A-3**: 100-buffer limit is sufficient for 1 FPS recording with processing pipeline
- Validation: Calculate buffer retention time: 100 frames ÷ 1 FPS = 100 seconds; verify AI processing completes within 100 seconds per batch

**A-4**: Swift actors provide sufficient performance for high-frequency operations
- Validation: Benchmark actor message passing overhead vs. manual locking

**A-5**: Existing GRDB schema does not require changes for memory safety fixes
- Validation: Review `chunks.sqlite` schema; confirm no schema migrations needed

### Open Questions

**Q-1**: Should `DatabaseManager` support parallel reads while serializing writes?
- Context: GRDB supports multiple concurrent readers; current design serializes all operations
- Impact: Performance optimization opportunity vs. increased complexity
- Decision needed by: Story 1.1 kickoff
- Owner: darius + development agent

**Q-2**: What is the optimal buffer eviction strategy (FIFO vs. LRU vs. priority-based)?
- Context: Current design uses FIFO (oldest first); might need smarter eviction
- Impact: Frame quality and memory efficiency
- Decision needed by: Story 1.2 implementation
- Owner: Story 1.2 implementer

**Q-3**: Should memory alerts trigger automatic actions (e.g., pause AI processing)?
- Context: Current design only alerts; could implement automatic recovery
- Impact: User experience vs. system autonomy
- Decision needed by: Story 1.4 implementation
- Owner: darius + UX review

**Q-4**: How should we handle crash recovery if database is corrupted?
- Context: Rare edge case but needs recovery strategy
- Impact: Data loss vs. user experience
- Decision needed by: Before Epic 1 completion
- Owner: darius + Story 1.1 implementer

**Q-5**: Should we implement database connection pooling or single connection?
- Context: Current design uses single serial queue; pooling might improve throughput
- Impact: Performance vs. complexity and thread safety
- Decision needed by: Story 1.3 performance testing
- Owner: Story 1.3 implementer

## Test Strategy Summary

### Unit Testing
- **DatabaseManager**: Test serial queue behavior, error handling, timeout handling
- **BufferManager**: Test buffer lifecycle, eviction logic, boundary conditions (0 buffers, 100 buffers, 101st buffer)
- **MemoryMonitor**: Test sampling logic, alert threshold detection, trend calculation
- **StorageManager**: Test async database calls, error propagation, transaction handling

**Framework**: XCTest
**Coverage Target**: >80% code coverage for new components
**Mocking Strategy**: Mock GRDB database for unit tests, use in-memory database for integration tests

### Integration Testing
- **ScreenRecorder + BufferManager**: Test frame capture with automatic buffer management
- **AnalysisManager + DatabaseManager**: Test background AI processing with async database access
- **StorageManager + DatabaseManager**: Test chunk management end-to-end
- **MemoryMonitor + Sentry**: Test crash report integration with memory context

**Framework**: XCTest with real component integration
**Test Data**: Use pre-recorded video chunks for repeatable tests

### Stress Testing
- **Concurrent Database Access**: 10-50 threads accessing database simultaneously for 5 minutes
- **Memory Pressure**: Run with limited memory allocation, force buffer eviction and recovery
- **Long-Running Sessions**: 8-hour continuous recording with AI analysis every 15 minutes
- **Rapid Context Switching**: Simulate rapid app switching, sleep/wake cycles, display changes

**Framework**: Custom stress test harness
**Success Criteria**: Zero crashes, memory stable within target range, no data corruption

### System Testing
- **End-to-End Recording**: Launch app → enable recording → wait 30 minutes → verify no crashes
- **AI Processing Pipeline**: Record → trigger batch processing → verify timeline cards generated → check memory stable
- **Error Recovery**: Inject database errors → verify automatic recovery → check data consistency
- **User Workflows**: Simulate real user patterns (recording, browsing timeline, adjusting settings)

**Framework**: Manual testing with automation where feasible
**Test Environment**: macOS 13.0, 14.0, and 15.0 on both Intel and Apple Silicon

### Performance Testing
- **Database Latency**: Measure P50, P95, P99 latency for read/write operations under various loads
- **Memory Usage**: Monitor memory every second during 8-hour session, verify <100MB baseline
- **Buffer Allocation**: Measure allocation time for 1000 consecutive buffer adds
- **UI Responsiveness**: Measure main thread block time during background database operations

**Framework**: XCTest Performance Tests + Instruments profiling
**Benchmarks**: Baseline current performance, verify no regression >10%

### Regression Testing
- **Existing Features**: Verify all existing features still work after Epic 1 changes
- **Database Integrity**: Verify no data corruption or loss after refactoring
- **UI Functionality**: Verify UI remains responsive and functional
- **Settings Persistence**: Verify user settings survive app restart

**Framework**: Automated UI tests + manual smoke testing
**Test Cases**: 50+ existing test cases re-run after each story completion

---

**Notes for Implementation:**
- All four stories have interdependencies; recommended implementation order: 1.1 → 1.2 → 1.3 → 1.4
- Story 1.1 is a prerequisite for all others (foundation for thread safety)
- Each story should be feature-gated with compile-time flags during development to allow incremental rollout
- Consider implementing stories on feature branches with merge after thorough testing
- Budget 2-3 days per story for development + testing + documentation

**Success Metrics:**
- Zero "freed pointer" crashes in production after Epic 1 deployment
- Memory usage <100MB during continuous recording (measured over 1000+ user sessions)
- 99.9% uptime during 8-hour work sessions (crash-free rate)
- <100ms P95 database operation latency (no performance regression)

**Definition of Done for Epic 1:**
- All 4 stories completed with acceptance criteria validated
- Stress tests pass (10 concurrent operations, 8-hour session)
- Memory leak tests pass (no leaks detected over 8 hours)
- Code reviewed and merged to main branch
- Documentation updated (architecture.md, development-guide.md)
- Release notes prepared for users (what was fixed, expected improvements)

---

_This technical specification provides comprehensive context for implementing Epic 1: Critical Memory Management Rescue. All architectural decisions are based on existing PRD, architecture documentation, and codebase analysis._

_Generated: 2025-11-13 by darius through BMM epic-tech-context workflow_
