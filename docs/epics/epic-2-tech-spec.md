# Epic Technical Specification: Core Recording Pipeline Stabilization

Date: 2025-11-13
Author: darius
Epic ID: epic-2
Status: Draft

---

## Overview

Epic 2 focuses on stabilizing and optimizing the core screen recording pipeline after the critical memory management fixes from Epic 1. This epic ensures that FocusLock's fundamental screen recording functionality works reliably across multiple displays, efficiently compresses video for long-term storage, and provides clear real-time status feedback to users.

The scope includes three critical stories: multi-display screen capture that seamlessly handles display configuration changes, video compression optimization to maintain reasonable storage requirements for 8+ hour recording sessions, and real-time recording status indicators that provide users with immediate feedback on recording state and any issues that arise.

This epic builds directly on the memory safety foundations established in Epic 1, particularly the serial database queue pattern and bounded buffer management, to ensure recording operations remain stable during extended usage.

## Objectives and Scope

**In Scope:**
- Multi-display screen capture with automatic display switching and configuration change handling
- Video compression optimization targeting <2GB storage per 8-hour day at 1 FPS
- Real-time recording status UI with <1 second update latency
- Display addition/removal detection and graceful handling
- Error state recovery with user-friendly guidance
- Recording performance monitoring and optimization

**Out of Scope:**
- Higher frame rate recording (remains 1 FPS for MVP)
- Video editing or post-processing features
- Cloud storage integration for recordings
- Advanced recording settings (scheduling, selective app recording, etc.)
- Audio capture integration
- Multi-user or team recording features

**Dependencies:**
- Epic 1 memory management fixes must be completed first
- ScreenCaptureKit framework requires macOS 13.0+
- Database operations rely on GRDB 7.8.0 thread-safety patterns

## System Architecture Alignment

This epic aligns with FocusLock's MVVM architecture and leverages the following architectural components:

**Core Services Integration:**
- `ScreenRecorder` service handles low-level screen capture operations
- `ActiveDisplayTracker` monitors display configuration changes
- `TimelapseStorageManager` manages video chunk storage with retention policies
- `DatabaseManager` persists recording metadata using serial queue pattern from Epic 1

**UI Layer Integration:**
- SwiftUI views in `Views/UI/` directory display recording status
- `StateManager` coordinates recording state across view hierarchy
- Real-time status updates propagate through `@Published` properties using Combine framework

**Data Flow:**
```
ScreenCaptureKit → ScreenRecorder → Video Chunks → TimelapseStorageManager → File System
                       ↓
                  DatabaseManager (serial queue) → recordings table
                       ↓
                  StateManager → SwiftUI Views → User Status Display
```

**Memory Safety Constraints:**
- All recording operations must respect bounded buffer limits (100 frames max from Epic 1)
- Database writes for recording metadata use serial queue pattern
- Display tracking runs on dedicated background queue with proper isolation

## Detailed Design

### Services and Modules

| Service/Module | Responsibilities | Inputs | Outputs | Owner |
|----------------|------------------|--------|---------|-------|
| **ScreenRecorder** | Core screen recording orchestration, frame capture timing, lifecycle management | Display IDs, capture configuration | CVPixelBuffer frames, recording status events | Core/Recording/ScreenRecorder.swift |
| **ActiveDisplayTracker** | Multi-display detection, configuration change monitoring, active display determination | System display events, CGDisplayStream | Display configuration snapshots, change events | Core/Recording/ActiveDisplayTracker.swift |
| **CompressionEngine** | Video frame compression, codec configuration, quality/size optimization | Raw CVPixelBuffer frames, compression settings | Compressed video chunks (H.264/HEVC) | Core/Recording/CompressionEngine.swift (new) |
| **TimelapseStorageManager** | Video chunk file management, retention policy enforcement, storage cleanup | Compressed video chunks, retention settings | File paths, storage metrics | Core/Recording/TimelapseStorageManager.swift |
| **RecordingStatusViewModel** | UI state management, status indicator updates, error message formatting | Recording events, error conditions | UI-ready status models, user messages | Views/UI/RecordingStatusViewModel.swift (new) |
| **DatabaseManager** | Recording metadata persistence, serial queue access pattern | Recording start/end times, file paths, status | Database write confirmations, query results | Core/Database/DatabaseManager.swift |

### Data Models and Contracts

**Recording Model:**
```swift
struct Recording: Codable, Identifiable {
    let id: Int64
    let startTime: Date
    let endTime: Date?
    let filePath: String
    let fileSize: Int64?
    let durationSeconds: Int?
    let displayConfiguration: DisplayConfiguration
    let processingStatus: ProcessingStatus
    let createdAt: Date
}

struct DisplayConfiguration: Codable {
    let displayCount: Int
    let primaryDisplayID: CGDirectDisplayID
    let displayResolutions: [DisplayResolution]
    let captureMode: CaptureMode
}

struct DisplayResolution: Codable {
    let displayID: CGDirectDisplayID
    let width: Int
    let height: Int
    let scaleFactor: CGFloat
}

enum CaptureMode: String, Codable {
    case singleDisplay
    case multiDisplay
    case activeDisplay
}

enum ProcessingStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}
```

**Recording Status Model:**
```swift
enum RecordingState: Equatable {
    case idle
    case initializing
    case recording(displayCount: Int)
    case paused
    case error(RecordingError)
    case stopping
}

struct RecordingError: Equatable {
    let code: ErrorCode
    let message: String
    let recoveryOptions: [RecoveryAction]
    let timestamp: Date
}

enum ErrorCode {
    case permissionDenied
    case displayConfigurationChanged
    case storageSpaceLow
    case compressionFailed
    case frameCaptureTimeout
    case databaseWriteFailed
}

struct RecoveryAction {
    let title: String
    let action: () -> Void
    let isPrimary: Bool
}
```

**Storage Metrics Model:**
```swift
struct StorageMetrics {
    let totalStorageUsed: Int64 // bytes
    let recordingCount: Int
    let oldestRecordingDate: Date?
    let compressionRatio: Double
    let dailyAverageSize: Int64
    let retentionDays: Int
}
```

### APIs and Interfaces

**ScreenRecorder Public API:**
```swift
actor ScreenRecorder {
    // Lifecycle Management
    func startRecording(displayMode: DisplayMode) async throws
    func stopRecording() async
    func pauseRecording() async
    func resumeRecording() async

    // Status Queries
    var currentState: RecordingState { get }
    var activeDisplays: [CGDirectDisplayID] { get }
    var recordingDuration: TimeInterval { get }

    // Configuration
    func updateCompressionSettings(_ settings: CompressionSettings) async
    func setFrameRate(_ fps: Int) async throws

    // Event Stream
    var statusUpdates: AsyncStream<RecordingState> { get }
}

enum DisplayMode {
    case automatic // Follows active display
    case all       // Captures all displays
    case specific([CGDirectDisplayID])
}
```

**CompressionEngine API:**
```swift
protocol CompressionEngine {
    func compress(frame: CVPixelBuffer, timestamp: CMTime) async throws -> CompressedChunk
    func finalizeChunk() async throws -> URL
    func estimateChunkSize(frameCount: Int) -> Int64

    var compressionSettings: CompressionSettings { get set }
    var currentChunkSize: Int64 { get }
}

struct CompressionSettings {
    let codec: VideoCodec
    let quality: CompressionQuality
    let targetBitrate: Int // bits per second
    let keyFrameInterval: Int
}

enum VideoCodec {
    case h264
    case hevc // H.265 for better compression
}

enum CompressionQuality {
    case low, medium, high, auto
}
```

**ActiveDisplayTracker API:**
```swift
class ActiveDisplayTracker {
    // Display Monitoring
    func startMonitoring() throws
    func stopMonitoring()

    // Display Queries
    func getActiveDisplays() -> [DisplayInfo]
    func getPrimaryDisplay() -> DisplayInfo?
    func getDisplayConfiguration() -> DisplayConfiguration

    // Change Notifications
    var configurationChanges: AsyncStream<DisplayChangeEvent> { get }
}

struct DisplayInfo {
    let id: CGDirectDisplayID
    let bounds: CGRect
    let scaleFactor: CGFloat
    let isActive: Bool
    let isPrimary: Bool
}

enum DisplayChangeEvent {
    case added(DisplayInfo)
    case removed(CGDirectDisplayID)
    case reconfigured([DisplayInfo])
}
```

**Error Response Codes:**
- `200` - Success (not HTTP, internal status)
- `1001` - Permission denied (ScreenCaptureKit)
- `1002` - Display not found
- `1003` - Compression failed
- `1004` - Storage space insufficient
- `1005` - Database write failed
- `1006` - Frame capture timeout

### Workflows and Sequencing

**Story 2.1: Multi-Display Recording Workflow**

```
1. User initiates recording
   ├─> ScreenRecorder.startRecording(displayMode: .automatic)
   └─> ActiveDisplayTracker.startMonitoring()

2. Display configuration detection
   ├─> ActiveDisplayTracker.getActiveDisplays()
   ├─> Detect display count and resolutions
   └─> Configure ScreenCaptureKit for detected displays

3. Start capture streams
   ├─> For each active display:
   │   ├─> Create CGDisplayStream
   │   ├─> Configure 1 FPS capture rate
   │   └─> Register frame callback
   └─> Update RecordingState to .recording(displayCount: N)

4. Handle display configuration changes
   ├─> ActiveDisplayTracker emits .reconfigured event
   ├─> Pause existing capture streams
   ├─> Re-detect display configuration
   ├─> Restart capture streams with new config
   └─> Continue recording without data loss

5. Frame capture pipeline
   ├─> CGDisplayStream delivers CVPixelBuffer
   ├─> BufferManager validates buffer count < 100
   ├─> CompressionEngine.compress(frame)
   └─> TimelapseStorageManager.saveChunk()

6. Stop recording
   ├─> ScreenRecorder.stopRecording()
   ├─> Flush pending frames to storage
   ├─> DatabaseManager.saveRecording(metadata) [via serial queue]
   └─> ActiveDisplayTracker.stopMonitoring()
```

**Story 2.2: Compression Optimization Workflow**

```
1. Initialize compression settings
   ├─> Load user preferences (default: auto quality)
   ├─> Calculate target bitrate for 1 FPS capture
   │   └─> Target: ~2GB/8hrs = ~70KB per frame
   └─> Initialize AVAssetWriter with H.265 codec

2. Frame compression loop (every 1 second)
   ├─> Receive CVPixelBuffer from ScreenRecorder
   ├─> Timestamp calculation: CMTime
   ├─> AVAssetWriter.append(frame, timestamp)
   └─> Monitor chunk size accumulation

3. Chunk finalization (every 15 minutes)
   ├─> CompressionEngine.finalizeChunk()
   ├─> Close AVAssetWriter
   ├─> Calculate actual compression ratio
   ├─> Save chunk file to storage
   ├─> DatabaseManager.saveChunk(metadata) [serial queue]
   └─> Reset for next chunk

4. Quality adjustment (adaptive)
   ├─> Monitor actual file sizes vs target
   ├─> If oversized: reduce quality by 10%
   ├─> If undersized: increase quality by 5%
   └─> Apply changes to next chunk

5. Storage monitoring
   ├─> Calculate daily storage usage
   ├─> Check retention policy (3 days default)
   ├─> TimelapseStorageManager.cleanup() if needed
   └─> Update StorageMetrics
```

**Story 2.3: Real-Time Status Workflow**

```
1. Status update propagation
   ├─> ScreenRecorder emits RecordingState change
   ├─> RecordingStatusViewModel receives update
   ├─> Transform to UI-friendly status model
   └─> Publish via @Published property (<1s latency)

2. UI rendering (SwiftUI)
   ├─> RecordingStatusView observes ViewModel
   ├─> Update status indicator (color, icon, text)
   ├─> Animate state transitions
   └─> Display additional context (display count, duration)

3. Error handling
   ├─> ScreenRecorder encounters error
   ├─> Create RecordingError with recovery options
   ├─> RecordingStatusViewModel formats error message
   ├─> Display error banner with recovery actions
   └─> Log error to Sentry (if enabled)

4. User recovery actions
   ├─> User clicks recovery action button
   ├─> ViewModel executes recovery procedure
   │   ├─> requestPermissions()
   │   ├─> retryRecording()
   │   └─> openSystemPreferences()
   └─> Update status based on recovery result
```

## Non-Functional Requirements

### Performance

**Recording Performance:**
- **Frame Capture Latency:** <100ms from screen update to frame buffer delivery
- **Compression Time:** <500ms per frame (1 FPS allows 1 second budget)
- **CPU Usage:** <2% CPU during 1 FPS recording on Apple Silicon
- **Memory Usage:** <150MB additional RAM during recording (including buffers)

**Storage Performance:**
- **Target Storage:** <2GB per 8-hour recording day at 1920x1080 resolution
- **Chunk Write Speed:** >10MB/s to ensure real-time write capability
- **Retention Cleanup:** Complete within 5 seconds for 3-day retention window
- **Database Operations:** <50ms for recording metadata writes (serial queue)

**UI Responsiveness:**
- **Status Update Latency:** <1 second from state change to UI update
- **Status Indicator Render:** <16ms (60fps) for smooth animations
- **Error Display:** <500ms from error occurrence to user notification

**Multi-Display Performance:**
- **Display Detection:** <100ms to detect configuration changes
- **Stream Restart:** <2 seconds to restart capture after display reconfiguration
- **Simultaneous Streams:** Support up to 4 displays without performance degradation

### Security

**Privacy Requirements:**
- **Screen Content Protection:** Respect system privacy indicators for sensitive content
- **Recording Notification:** Clear visual indicator when recording is active (follows macOS guidelines)
- **Data Encryption:** Video files encrypted at rest using FileVault (system-level)
- **Permission Handling:** Graceful degradation if Screen Recording permission denied

**Data Handling:**
- **Local-First Storage:** All recordings stored locally by default
- **Access Control:** Recording files readable only by FocusLock application
- **Secure Deletion:** Overwrite video chunks during cleanup (not just file deletion)
- **API Key Protection:** No cloud APIs used for recording (local-only operation)

### Reliability/Availability

**Stability Requirements:**
- **Zero Crashes:** No crashes during 8+ hour recording sessions
- **Graceful Recovery:** Automatic recovery from temporary display disconnection
- **Data Integrity:** No corrupted video chunks even during unexpected termination
- **State Persistence:** Recording state survives app restart (can resume)

**Error Recovery:**
- **Display Disconnection:** Pause recording, resume when display reconnects
- **Storage Space Low:** Stop recording, notify user, preserve existing chunks
- **Compression Failure:** Retry compression with lower quality settings
- **Database Write Failure:** Queue metadata writes, retry with exponential backoff

**Availability Targets:**
- **Recording Uptime:** 99.9% during normal operation (43 minutes downtime/month max)
- **Mean Time to Recovery:** <5 seconds for recoverable errors
- **Data Loss Prevention:** Zero data loss for completed chunks

### Observability

**Logging Requirements:**
- **Recording Lifecycle:** Log all state transitions (start, stop, pause, error)
- **Performance Metrics:** Log frame capture timing, compression duration, chunk size
- **Display Changes:** Log display configuration changes with timestamps
- **Error Events:** Structured error logs with context and stack traces

**Metrics to Track:**
- **Frame Capture Rate:** Actual FPS achieved (target: 1.0 ±0.1)
- **Compression Ratio:** Actual vs target compression (target: ~50:1)
- **Storage Usage:** Daily storage consumption trend
- **Error Rate:** Errors per recording session (target: <0.1%)
- **Status Update Latency:** Time from state change to UI update

**Monitoring Signals:**
- **CPU/Memory Usage:** Track resource consumption during recording
- **Disk I/O:** Monitor write throughput and latency
- **Display Event Rate:** Frequency of configuration changes
- **Recovery Success Rate:** Percentage of successful error recoveries

**Diagnostic Tools:**
- **Debug Mode:** Enhanced logging for troubleshooting recording issues
- **Performance Profiler:** Built-in timing instrumentation for bottleneck identification
- **Recording Health Check:** Validate recording pipeline integrity on demand

## Dependencies and Integrations

**System Framework Dependencies:**
- **ScreenCaptureKit** (macOS 13.0+): Core screen capture functionality
  - Version: System framework (no explicit version)
  - Usage: CGDisplayStream for frame capture, display configuration
- **AVFoundation**: Video compression and encoding
  - Version: System framework
  - Usage: AVAssetWriter, H.264/H.265 encoding
- **CoreMedia**: Media timing and buffer management
  - Version: System framework
  - Usage: CMTime, CVPixelBuffer operations
- **Combine**: Reactive state management
  - Version: System framework
  - Usage: @Published properties, AsyncStream bridging

**Swift Package Dependencies (from Package.resolved):**
- **GRDB.swift** v7.8.0
  - Usage: Recording metadata persistence in SQLite database
  - Critical: Must use serial queue pattern from Epic 1
- **Sentry-Cocoa** v8.56.2
  - Usage: Optional error reporting for recording failures
  - Note: User opt-in required
- **PostHog-iOS** v3.31.0
  - Usage: Optional analytics for recording usage patterns
  - Note: User opt-in required
- **Sparkle** v2.7.1
  - Usage: Auto-update framework (not directly used by Epic 2)

**Internal Service Dependencies:**
- **DatabaseManager** (Epic 1): Serial queue pattern for thread-safe writes
- **BufferManager** (Epic 1): Bounded buffer management (100 frame limit)
- **MemoryMonitor** (Epic 1): Memory leak detection during recording
- **StateManager**: Global app state coordination for recording status

**Storage Dependencies:**
- **File System**: Local storage for video chunks
  - Location: `~/Library/Application Support/Dayflow/recordings/`
  - Required Space: ~2GB per day × retention period (default 3 days = 6GB)
- **Database**: SQLite for recording metadata
  - Location: `~/Library/Application Support/Dayflow/chunks.sqlite`
  - Size: <10MB for 30 days of metadata

**Integration Points:**
- **Epic 1 Memory Safety**: Inherits serial database queue and bounded buffers
- **Epic 3 AI Analysis**: Provides video chunks as input to AI processing pipeline
- **Epic 4 Database Persistence**: Extends recording metadata with timeline data
- **Epic 5 UI Experience**: Integrates recording status into dashboard views

**Version Constraints:**
- **Minimum macOS Version**: 13.0 (Ventura) for ScreenCaptureKit
- **Swift Version**: 5.9+ for actor isolation and async/await
- **Xcode Version**: 15.0+ for SwiftUI and concurrency features

## Acceptance Criteria (Authoritative)

### Story 2.1: Multi-Display Screen Capture

**AC 2.1.1 - Multi-Display Detection:**
- **Given** multiple displays are connected (2-4 monitors)
- **When** FocusLock starts recording
- **Then** screen capture automatically detects and captures from all active displays
- **And** display configuration is persisted in recording metadata

**AC 2.1.2 - Display Configuration Changes:**
- **Given** recording is active across multiple displays
- **When** a display is added, removed, or reconfigured
- **Then** recording automatically adapts to new configuration within 2 seconds
- **And** no frames are lost during transition
- **And** no crashes or errors occur

**AC 2.1.3 - Active Display Tracking:**
- **Given** user has multiple displays connected
- **When** user switches between displays while working
- **Then** ActiveDisplayTracker correctly identifies active display
- **And** recording continues seamlessly without interruption

**AC 2.1.4 - Frame Capture Validation:**
- **Given** multi-display recording is active
- **When** frames are captured from each display
- **Then** all displays produce valid CVPixelBuffer frames at 1 FPS
- **And** frame timestamps are monotonically increasing
- **And** no memory leaks occur during 8+ hour sessions

### Story 2.2: Video Compression Optimization

**AC 2.2.1 - Storage Target Achievement:**
- **Given** continuous 1 FPS recording for 8 hours at 1920x1080 resolution
- **When** video frames are compressed and stored
- **Then** total storage usage is less than 2GB per 8-hour day
- **And** compression quality is sufficient for AI text extraction (>90% OCR accuracy)

**AC 2.2.2 - Compression Performance:**
- **Given** recording is active at 1 FPS
- **When** each frame is compressed
- **Then** compression completes within 500ms per frame
- **And** CPU usage remains below 2% on Apple Silicon
- **And** no frame backlog accumulates during continuous operation

**AC 2.2.3 - Quality Preservation:**
- **Given** video compression is configured for optimal storage
- **When** AI analysis processes compressed video
- **Then** OCR text extraction maintains >90% accuracy
- **And** activity categorization remains effective
- **And** visual quality is sufficient for user review

**AC 2.2.4 - Adaptive Compression:**
- **Given** compression settings are in auto-quality mode
- **When** actual file sizes deviate from 2GB/day target
- **Then** compression quality adjusts automatically
- **And** adjustments do not cause visual artifacts
- **And** storage target is maintained within ±10%

### Story 2.3: Real-Time Recording Status

**AC 2.3.1 - Status Indicator Visibility:**
- **Given** FocusLock is running in any state
- **When** user views the main interface
- **Then** recording status indicator is clearly visible
- **And** status shows current state (idle/recording/paused/error)
- **And** additional context is displayed (display count, duration)

**AC 2.3.2 - Real-Time Updates:**
- **Given** recording state changes (start/stop/error)
- **When** state transition occurs
- **Then** UI status indicator updates within 1 second
- **And** smooth animation transitions between states
- **And** no UI freezing or lag occurs

**AC 2.3.3 - Error State Handling:**
- **Given** recording encounters an error condition
- **When** error occurs (permission denied, storage full, display issue)
- **Then** error banner displays clear error message
- **And** recovery options are provided to user
- **And** recovery instructions are actionable and specific

**AC 2.3.4 - Status Persistence:**
- **Given** recording is active or paused
- **When** app is restarted or user switches views
- **Then** recording status persists correctly
- **And** status indicator shows accurate current state
- **And** recording duration continues tracking accurately

## Traceability Mapping

| Acceptance Criteria | Spec Section | Component/API | Test Approach |
|---------------------|--------------|---------------|---------------|
| **AC 2.1.1** - Multi-Display Detection | Services: ActiveDisplayTracker | `ActiveDisplayTracker.getActiveDisplays()` | Unit test with mock CGDisplayStream, integration test with 2-4 physical displays |
| **AC 2.1.2** - Configuration Changes | Workflows: Display Change Handling | `ActiveDisplayTracker.configurationChanges` stream | Integration test: disconnect/reconnect display during recording, verify no data loss |
| **AC 2.1.3** - Active Display Tracking | Services: ActiveDisplayTracker | `ActiveDisplayTracker.getPrimaryDisplay()` | Integration test: switch active window between displays, verify tracking accuracy |
| **AC 2.1.4** - Frame Capture Validation | Services: ScreenRecorder | `ScreenRecorder.startRecording()` | Memory profiler: run 8-hour recording, validate no leaks with Instruments |
| **AC 2.2.1** - Storage Target | Services: CompressionEngine | `CompressionEngine.compress()` | End-to-end test: 8-hour recording, measure total storage, validate <2GB |
| **AC 2.2.2** - Compression Performance | Workflows: Compression Loop | `CompressionEngine.compress()` timing | Performance test: measure per-frame compression time, CPU usage profiling |
| **AC 2.2.3** - Quality Preservation | NFR: Security & Performance | Compressed video output | Integration with Epic 3: run OCR on compressed video, measure accuracy |
| **AC 2.2.4** - Adaptive Compression | Workflows: Quality Adjustment | `CompressionSettings.quality` logic | Unit test: simulate oversized chunks, verify quality reduction, measure convergence |
| **AC 2.3.1** - Status Visibility | Services: RecordingStatusViewModel | `RecordingStatusView` UI | UI test: verify status indicator visible in all app states, screenshot comparison |
| **AC 2.3.2** - Real-Time Updates | Workflows: Status Propagation | `ScreenRecorder.statusUpdates` AsyncStream | Integration test: trigger state changes, measure latency to UI update (<1s) |
| **AC 2.3.3** - Error Handling | Data Models: RecordingError | `RecordingError.recoveryOptions` | Unit test: inject errors, verify recovery actions displayed, test recovery flows |
| **AC 2.3.4** - Status Persistence | Services: StateManager | `StateManager` + UserDefaults | Integration test: stop/restart app during recording, verify state restoration |

## Risks, Assumptions, Open Questions

### Risks

**R1: Display Configuration Change Data Loss (HIGH)**
- **Description:** Rapid display configuration changes could cause frame drops or recording corruption
- **Impact:** Users lose recording data during critical work periods
- **Mitigation:** Implement robust buffering during display transitions, add integration tests for rapid display changes
- **Contingency:** Add frame loss detection and user notification system

**R2: Compression Performance on Intel Macs (MEDIUM)**
- **Description:** H.265 compression may be slower on older Intel Macs without hardware acceleration
- **Impact:** Frame backlog accumulation, potential memory issues, failed recordings
- **Mitigation:** Implement CPU architecture detection, fallback to H.264 on Intel Macs
- **Contingency:** Add performance monitoring to detect compression delays and adjust quality dynamically

**R3: Storage Target Missed for High-Resolution Displays (MEDIUM)**
- **Description:** 4K/5K displays may produce larger compressed frames, exceeding 2GB/day target
- **Impact:** Increased storage usage, premature storage exhaustion
- **Mitigation:** Resolution-aware compression settings, aggressive quality reduction for >1080p
- **Contingency:** User notification when storage target is exceeded, option to reduce capture resolution

**R4: Status Update Latency Under Load (LOW)**
- **Description:** Heavy AI processing (Epic 3) concurrent with recording could delay status updates
- **Impact:** Users see stale recording status, confusion about recording state
- **Mitigation:** Prioritize status updates on main thread, use actor isolation for state management
- **Contingency:** Add background task monitoring to detect and report excessive delays

### Assumptions

**A1: ScreenCaptureKit Reliability**
- **Assumption:** ScreenCaptureKit framework provides stable 1 FPS frame delivery on macOS 13+
- **Validation:** Test on variety of Mac hardware (Intel, M1, M2, M3) with different display configs
- **Impact if Invalid:** May need fallback to older CGDisplayStream API

**A2: Compression Codec Availability**
- **Assumption:** H.265 hardware encoding available on all Apple Silicon Macs
- **Validation:** Query AVAssetWriter for available codecs during initialization
- **Impact if Invalid:** Fallback to H.264 with adjusted quality settings

**A3: User Display Configurations**
- **Assumption:** Most users have 1-2 displays, rarely 3-4, almost never >4
- **Validation:** Collect analytics (opt-in) on display count distribution
- **Impact if Invalid:** May need optimization for high display count scenarios

**A4: Storage Availability**
- **Assumption:** Users have >10GB free disk space for recording retention
- **Validation:** Check available storage before starting recording, warn user if low
- **Impact if Invalid:** Implement aggressive retention cleanup, user notification system

**A5: Frame Rate Consistency**
- **Assumption:** 1 FPS recording is sufficient for AI analysis and user review
- **Validation:** Validate with Epic 3 AI processing, user feedback on recording quality
- **Impact if Invalid:** May need variable frame rate or selective high-FPS capture

### Open Questions

**Q1: Display Priority for Active Tracking**
- **Question:** When multiple displays have active windows, which display should be considered "primary" for single-display recording mode?
- **Decision Needed:** Before Story 2.1 implementation
- **Stakeholders:** Product team, UX designer
- **Impact:** Affects ActiveDisplayTracker logic and user experience

**Q2: Compression Codec Selection Strategy**
- **Question:** Should we always prefer H.265 for better compression, or allow user selection?
- **Decision Needed:** Before Story 2.2 implementation
- **Options:** Auto (best available), user preference, performance-based selection
- **Impact:** Affects CompressionEngine API design and settings UI

**Q3: Error Recovery Automation Level**
- **Question:** How aggressive should automatic error recovery be? (e.g., auto-retry vs always ask user)
- **Decision Needed:** Before Story 2.3 implementation
- **Options:** Fully automatic, semi-automatic with notifications, manual only
- **Impact:** Affects RecordingError model and recovery workflow design

**Q4: Storage Retention Policy Configuration**
- **Question:** Should retention policy be time-based (3 days), size-based (10GB), or hybrid?
- **Decision Needed:** Before Story 2.2 implementation
- **Options:** Time-only, size-only, hybrid with both limits
- **Impact:** Affects TimelapseStorageManager cleanup logic

**Q5: Status Indicator Placement**
- **Question:** Where should recording status indicator be displayed? (menu bar, app window, both?)
- **Decision Needed:** Before Story 2.3 implementation
- **Stakeholders:** UX designer, product team
- **Impact:** Affects RecordingStatusView design and implementation approach

## Test Strategy Summary

### Test Levels

**Unit Tests:**
- **Coverage:** All service APIs (ScreenRecorder, CompressionEngine, ActiveDisplayTracker)
- **Focus:** Individual method behavior, error handling, edge cases
- **Tools:** XCTest, Swift Testing framework
- **Target Coverage:** >80% code coverage for Epic 2 modules

**Integration Tests:**
- **Coverage:** Multi-display scenarios, compression pipeline, status propagation
- **Focus:** Component interaction, data flow correctness, state management
- **Tools:** XCTest with real ScreenCaptureKit, mock displays where needed
- **Key Scenarios:** Display addition/removal, 8-hour recording, error recovery

**Performance Tests:**
- **Coverage:** Frame capture timing, compression speed, memory usage, status latency
- **Focus:** Meeting non-functional requirements (CPU <2%, memory <150MB, status <1s)
- **Tools:** Xcode Instruments (CPU, Memory, Time Profiler), custom benchmarks
- **Thresholds:** Fail if performance degrades >10% from baseline

**System Tests:**
- **Coverage:** End-to-end recording workflows, multi-display setup, extended runtime
- **Focus:** Real-world usage scenarios, stability over 8+ hours
- **Tools:** Manual testing with test plans, automated UI tests for critical paths
- **Duration:** 24-hour continuous recording test (3× retention period)

### Test Coverage Mapping

**Story 2.1 Tests:**
- Multi-display detection: Unit tests with 1, 2, 3, 4 displays
- Display configuration changes: Integration test with simulated display events
- Active display tracking: Integration test with window focus changes
- 8-hour stability: System test with memory leak detection

**Story 2.2 Tests:**
- Compression ratio: End-to-end test measuring actual storage usage
- Compression performance: Performance test measuring per-frame timing
- Quality preservation: Integration test with Epic 3 OCR validation
- Adaptive compression: Unit test simulating oversized chunks

**Story 2.3 Tests:**
- Status indicator visibility: UI test with screenshot comparison
- Real-time updates: Integration test measuring latency (<1s)
- Error handling: Unit tests for all error types and recovery flows
- Status persistence: Integration test with app restart

### Edge Cases and Failure Modes

**Edge Cases to Test:**
- Single display → Multi-display transition during recording
- Display rotation (portrait/landscape) mid-recording
- Mac sleep/wake cycle during recording
- Extremely high resolution displays (6K+)
- Low storage space scenarios (<1GB free)
- Network drive storage (latency impact)

**Failure Modes to Validate:**
- ScreenCaptureKit permission revoked during recording
- Disk full during chunk write
- Display driver crash/reset
- Compression hardware unavailable
- Database corruption recovery
- Concurrent AI processing overload

### Test Automation Strategy

**CI/CD Integration:**
- Unit tests run on every commit
- Integration tests run on PR merge
- Performance tests run nightly
- System tests run weekly for long-duration validation

**Test Data:**
- Mock display configurations for repeatable tests
- Sample video frames for compression testing
- Error injection framework for failure simulation

**Regression Prevention:**
- Performance benchmarks tracked over time
- Memory leak detection in CI pipeline
- Critical user flow smoke tests before release

---

**Status:** Draft - Ready for implementation
**Next Steps:**
1. Review and approve technical specification
2. Break down into development tasks
3. Create Story 2.1 detailed implementation plan
4. Begin development with TDD approach
