# Architecture Documentation - FocusLock

## Executive Summary

FocusLock is a native macOS application built with SwiftUI that automatically records user screen activity at 1 FPS and analyzes it every 15 minutes using AI to generate a timeline of daily activities. This is a **brownfield rescue mission** - all features are implemented but critical memory management bugs cause immediate crashes. The rescue architecture prioritizes memory safety through serial database operations, thread-safe patterns, and enhanced diagnostics to achieve 8+ hour continuous operation.

## Technology Stack

### Core Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (iOS 17+ / macOS 14+ features)
- **Minimum OS**: macOS 13.0 (Ventura)
- **Architecture**: 64-bit Intel and Apple Silicon

### Key Dependencies
- **GRDB**: Type-safe SQLite database for data persistence
- **Sparkle**: Automatic update framework for macOS
- **Sentry**: Error tracking and crash reporting
- **PostHog**: Product analytics and user behavior tracking
- **ScreenCaptureKit**: Native screen recording framework
- **AVFoundation**: Media processing and video handling

### Development Tools
- **Xcode 15+**: Primary development environment
- **Swift Package Manager**: Dependency management
- **Git**: Version control
- **GitHub Actions**: CI/CD pipeline (future)

## Rescue Architecture Pattern

### MVVM with Memory-Safe Serial Database Layer

FocusLock implements a modern MVVM architecture with critical memory safety modifications for the rescue mission:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     View        │    │   ViewModel     │    │     Model       │
│                 │    │                 │    │                 │
│ • SwiftUI      │◄──►│ • @StateObject  │◄──►│ • Serial DB     │
│ • Components   │    │ • Business     │    │ • Buffer Mgmt   │
│ • State Mgmt   │    │   Logic        │    │ • Memory Track │
│ • User Input   │    │ • Validation   │    │ • Thread Safe   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                     ▲                     ▲
         │                     │                     │
    ┌─────────────────────────────────────────────────────┐
    │           RESCUE LAYER - MEMORY SAFETY            │
    │  ┌─────────────────────────────────────────────┐ │
    │  │       Serial Database Queue (Critical)        │ │
    │  │  ┌─────────────────────────────────────────┐ │ │
    │  │  │ DatabaseManager (thread-safe wrapper)     │ │ │
    │  │  │ StorageManager (fixed chunksForBatch)    │ │ │
    │  │  │ BufferManager (memory tracking)          │ │ │
    │  │  │ MemoryMonitor (leak detection)           │ │ │
    │  │  └─────────────────────────────────────────┘ │ │
    │  └─────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────┘
```

### Rescue Architectural Principles

1. **Memory Safety First**: All database operations serialized, no concurrent access
2. **Thread Isolation**: Background processing isolated from UI and database
3. **Buffer Management**: Bounded memory usage with automatic cleanup
4. **Error Recovery**: Graceful degradation when memory issues detected
5. **Diagnostic Transparency**: Comprehensive memory usage tracking and logging

## Data Architecture

### Database Schema (GRDB/SQLite)

#### Core Tables

**recordings**
```sql
CREATE TABLE recordings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    file_path TEXT NOT NULL,
    file_size INTEGER,
    duration_seconds INTEGER,
    processing_status TEXT DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**timeline_cards**
```sql
CREATE TABLE timeline_cards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recording_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    category TEXT,
    confidence_score REAL,
    ai_provider TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (recording_id) REFERENCES recordings(id)
);
```

**ai_providers**
```sql
CREATE TABLE ai_providers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_type TEXT NOT NULL, -- 'gemini', 'ollama', 'lm_studio'
    name TEXT NOT NULL,
    config JSON, -- API keys, endpoints, model settings
    is_active BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**app_settings**
```sql
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Data Flow Architecture

```
ScreenCaptureKit → Video Chunks → AI Processing → Timeline Cards → UI Display
       ↓                    ↓                    ↓                  ↓
   File Storage      Background Queue      Database        SwiftUI Views
```

### Storage Management

**Local Storage Locations**:
- **Recordings**: `~/Library/Application Support/Dayflow/recordings/`
- **Database**: `~/Library/Application Support/Dayflow/chunks.sqlite`
- **Thumbnails**: `~/Library/Application Support/Dayflow/thumbnails/`
- **Configuration**: `~/Library/Application Support/Dayflow/settings/`

**Retention Policies**:
- **Video Recordings**: 3 days (configurable)
- **Timeline Cards**: Indefinite (user can delete)
- **Thumbnails**: 7 days (regenerated on demand)
- **Database**: Pruned based on recording retention

## Component Architecture

### Core Services Layer

#### AI Service Architecture
```
LLMService (Orchestrator)
├── GeminiProvider (Cloud AI)
│   ├── Video Upload & Transcription
│   └── Card Generation (2 LLM calls)
├── OllamaProvider (Local AI)
│   ├── Frame Extraction (30 frames)
│   ├── Individual Frame Analysis (30 LLM calls)
│   └── Card Generation (3 LLM calls)
└── LMStudioProvider (Local AI)
    └── Similar to Ollama with different endpoint
```

#### Recording Service Architecture
```
ScreenRecorder (Core)
├── ActiveDisplayTracker
│   ├── Multi-display detection
│   └── Display configuration changes
├── TimelapseStorageManager
│   ├── Chunk management (15-second segments)
│   └── Storage cleanup (3-day retention)
└── ThumbnailCache
    ├── Efficient caching system
    └── On-demand generation
```

### UI Component Architecture

#### Component Hierarchy
```
MainView
├── TimelineView
│   ├── TimelineCard
│   ├── ScrubberView
│   └── VideoPlayerModal
├── DashboardView
│   ├── ProductivityCharts
│   └── InsightsView
├── JournalView
│   ├── JournalEntry
│   └── JournalExport
├── SettingsView
│   ├── AIProviderSetupView
│   └── FeatureFlagsSettingsView
└── FocusLockView
    ├── EnhancedFocusLockView
    └── EmergencyBreakView
```

#### Reusable Components
- **DayflowButton**: Primary button component
- **UnifiedCard**: Card container component
- **LoadingState**: Loading indicator component
- **GlassmorphismContainer**: Glass effect container
- **VideoThumbnailView**: Thumbnail display component

## API Design

### Internal Service APIs

#### LLM Provider Protocol
```swift
protocol LLMProvider {
    func processVideo(_ videoURL: URL) async throws -> [TimelineCard]
    func validateConfiguration() -> Bool
    func getProviderInfo() -> ProviderInfo
}
```

#### Recording Service Protocol
```swift
protocol RecordingService {
    func startRecording() async throws
    func stopRecording() async
    func getRecordingStatus() -> RecordingStatus
    func getActiveDisplays() -> [DisplayInfo]
}
```

### External API Integration

#### Google Gemini API
- **Endpoint**: `https://generativelanguage.googleapis.com/v1/models/gemini-pro-vision:generateContent`
- **Authentication**: API Key in request header
- **Request Format**: Video file upload with text prompt
- **Response**: Structured JSON with timeline card data

#### Ollama API
- **Endpoint**: `http://localhost:11434/api/generate`
- **Authentication**: None (local service)
- **Request Format**: Individual frame images with prompts
- **Response**: Text descriptions for each frame

## Source Tree Organization

### Application Structure
```
Dayflow/Dayflow/
├── App/                    # Application lifecycle
│   ├── DayflowApp.swift     # Main app entry point
│   ├── AppDelegate.swift     # macOS app delegate
│   ├── AppState.swift        # Global app state
│   └── InactivityMonitor.swift # User activity tracking
├── Core/                   # Business logic
│   ├── AI/                 # AI/LLM integration
│   ├── Recording/          # Screen recording services
│   └── Thumbnails/        # Image processing
├── Views/                 # User interface
│   ├── Components/        # Reusable UI components
│   ├── Onboarding/        # First-run experience
│   └── UI/               # Main application views
├── Assets.xcassets/       # App assets and icons
└── Utilities/            # Helper utilities
```

### Key Architectural Files

**Core Services**:
- `LLMService.swift`: AI service orchestration
- `ScreenRecorder.swift`: Screen recording engine
- `ActiveDisplayTracker.swift`: Multi-display support
- `TimelapseStorageManager.swift`: File management

**UI Architecture**:
- `MainView.swift`: Root view container
- `StateManager.swift`: Global UI state management
- `TimelineDataModels.swift`: Timeline data structures

**Configuration**:
- `Info.plist`: App metadata and permissions
- `Dayflow.entitlements`: macOS app entitlements

## Development Workflow

### Build Process
1. **Xcode Compilation**: Swift source → Mach-O binary
2. **Asset Processing**: Assets.xcassets → Asset.car
3. **Code Signing**: Developer ID signature application
4. **App Bundle Creation**: .app package assembly
5. **Notarization**: Apple notary service verification
6. **DMG Creation**: Disk image for distribution

### Testing Strategy
- **Unit Tests**: Business logic validation (XCTest)
- **Integration Tests**: Service interaction testing
- **UI Tests**: User interface automation (XCUITest)
- **Performance Tests**: Memory and CPU validation
- **System Tests**: End-to-end workflow validation

## Deployment Architecture

### Distribution Model
- **Direct Distribution**: GitHub releases with DMG downloads
- **Automatic Updates**: Sparkle framework for update management
- **Code Signing**: Developer ID for macOS Gatekeeper compliance
- **Notarization**: Apple notary service for security

### Update Mechanism
```
App Launch → Check Appcast → Download Update → Verify Signature → Install Update → Restart
```

### Security Architecture
- **Code Signing**: Developer ID certificate verification
- **Notarization**: Apple malware scan verification
- **Sandboxing**: App Store sandbox (optional)
- **Privacy**: Local AI processing options

## Performance Architecture

### Resource Management
- **Memory Usage**: Target ~100MB RAM during normal operation
- **CPU Usage**: <1% during recording, spikes during AI processing
- **Storage**: Configurable retention with automatic cleanup
- **Network**: Minimal usage (only for cloud AI providers)

### Optimization Strategies
- **1 FPS Recording**: Minimal performance impact
- **Background Processing**: AI processing on background queues
- **Efficient Caching**: Thumbnail and data caching
- **Lazy Loading**: UI components loaded on demand

## Security Architecture

### Data Protection
- **Local Storage**: All data stored locally by default
- **API Keys**: Secure storage in macOS Keychain
- **Privacy Controls**: User control over data sharing
- **Transparency**: Open source code for audit

### Permission Model
- **Screen Recording**: User permission required and clearly explained
- **File System**: Limited to app container and user-selected folders
- **Network**: User-controlled for AI provider communication
- **Accessibility**: Not used (privacy-focused approach)

## Integration Architecture

### macOS Integration
- **Menu Bar**: System menu integration for quick access
- **URL Scheme**: `dayflow://` for automation and Shortcuts
- **Deep Links**: Support for external app integration
- **Notifications**: System notifications for important events

### Third-Party Services
- **Gemini API**: Cloud AI processing (user-controlled)
- **Ollama**: Local AI server integration
- **LM Studio**: Local AI service integration
- **Sentry**: Error reporting (opt-in)
- **PostHog**: Analytics (opt-in)

## Monitoring and Observability

### Logging Strategy
- **Structured Logging**: JSON-formatted logs for analysis
- **Log Levels**: Debug, Info, Warning, Error
- **Privacy Filtering**: No sensitive data in logs
- **Local Storage**: Logs stored locally with rotation

### Error Handling
- **Graceful Degradation**: Fallback options for service failures
- **User Feedback**: Clear error messages and recovery options
- **Crash Reporting**: Automatic crash reports with user consent
- **Recovery Mechanisms**: Automatic retry and state recovery

### Performance Monitoring
- **Memory Profiling**: Regular memory usage tracking
- **Performance Metrics**: CPU, storage, and network usage
- **User Analytics**: Feature usage and performance patterns
- **Benchmarks**: Performance regression detection

## Future Architecture Considerations

### Scalability
- **Multi-Platform**: Potential iOS/iPadOS expansion
- **Cloud Sync**: Optional cloud synchronization for timeline data
- **Team Features**: Multi-user support and sharing
- **API Integration**: Third-party service integrations

### Extensibility
- **Plugin Architecture**: Support for custom AI providers
- **Custom Components**: User-defined timeline card types
- **Automation**: Enhanced automation and scripting support
- **Export Options**: Additional data export formats

### Performance
- **Metal Integration**: GPU acceleration for video processing
- **Background Processing**: Enhanced background task management
- **Storage Optimization**: More efficient data compression
- **Network Optimization**: Reduced bandwidth usage

## Rescue Implementation Patterns

### Critical Memory Safety Rules for AI Agents

**DATABASE ACCESS PATTERN:**
```swift
// ✅ ALL database operations MUST use serial queue
class DatabaseManager {
    private let serialQueue = DispatchQueue(label: "com.focusLock.database")

    func execute<T>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            serialQueue.async {
                do {
                    let db = try DatabasePool.shared.read()
                    let result = try operation(db)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// ❌ NEVER access database directly from background threads
func processDataInBackground() {
    let chunks = storageManager.chunksForBatch(data) // CRASHES HERE
}
```

**BUFFER MANAGEMENT PATTERN:**
```swift
class BufferManager {
    private let maxBuffers = 100
    private var frameBuffers: [CVPixelBuffer] = []

    func addBuffer(_ buffer: CVPixelBuffer) {
        // Automatic cleanup to prevent memory growth
        if frameBuffers.count >= maxBuffers {
            let oldBuffer = frameBuffers.removeFirst()
            CVPixelBufferUnlockBaseAddress(oldBuffer, nil)
        }
        frameBuffers.append(buffer)
    }

    deinit {
        // Critical: Ensure all buffers are properly released
        frameBuffers.forEach { buffer in
            CVPixelBufferUnlockBaseAddress(buffer, nil)
        }
    }
}
```

**BACKGROUND PROCESSING PATTERN:**
```swift
// Actor isolation for thread safety
actor DataCoordinator {
    private var processingQueue: [TimelineData] = []

    func addProcessingTask(_ data: TimelineData) {
        processingQueue.append(data)
    }

    func processNextBatch() -> [TimelineData] {
        let batch = Array(processingQueue.prefix(10))
        processingQueue.removeFirst(min(batch.count, processingQueue.count))
        return batch
    }
}
```

### Memory Corruption Prevention

**ROOT CAUSE ANALYSIS:**
1. **StorageManager.chunksForBatch()** - Called from multiple threads
2. **GRDB Database Pool** - Concurrent access causing "freed pointer" errors
3. **Screen Recording Buffers** - Unbounded memory growth
4. **AI Processing Queue** - Database access from background threads

**RESCUE SOLUTIONS:**
1. **Serial Database Wrapper** - All operations through single dispatch queue
2. **Buffer Bounds Checking** - Maximum 100 video frames in memory
3. **Thread Isolation** - Background processing isolated from database
4. **Memory Monitoring** - Real-time leak detection and reporting

This rescue architecture provides immediate stabilization while preserving all existing functionality, enabling the transition from critical crashes to stable 8+ hour operation.

---

_Updated on 2025-11-13 for Memory Management Rescue Mission_