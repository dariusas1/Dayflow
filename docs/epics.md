# FocusLock Epics and Stories

**Generated**: 2025-11-13
**Project**: FocusLock (Brownfield Rescue Mission)
**Methodology**: BMM Epic & Story Breakdown
**Target**: 200k context development agents

---

## Epic 1: Critical Memory Management Rescue (IMMEDIATE PRIORITY)

**Epic Goal**: Fix critical memory corruption crashes that prevent any features from being tested or used.

### Story 1.1: Database Threading Crash Fix
**As a** user trying to use FocusLock
**I want** the application to run for more than 2 minutes without crashing
**So that** I can actually test and use the features

**Acceptance Criteria**:
- **Given** the application launches successfully
- **When** database operations are accessed from multiple threads
- **Then** no "freed pointer was not last allocation" crashes occur
- **And** the app remains stable for at least 30 minutes of normal operation
- **And** GRDB database operations complete without memory corruption

**Implementation Notes**:
- Fix StorageManager.chunksForBatch() threading issues
- Implement serial database queue pattern
- Add proper error handling for concurrent access
- Test with StressTest: 10 concurrent database operations

### Story 1.2: Screen Recording Memory Cleanup
**As a** user recording screen activity
**I want** video frame buffers to be properly managed
**So that** memory usage stays below 100MB during continuous recording

**Acceptance Criteria**:
- **Given** screen recording is active for 1+ hours
- **When** video frames are captured and processed
- **Then** memory usage remains stable under 100MB
- **And** old frame buffers are automatically released
- **And** no memory leaks are detected in the recording pipeline

**Implementation Notes**:
- Implement bounded buffer management (max 100 frames)
- Add automatic cleanup for old buffers
- Test with 8-hour continuous recording
- Monitor memory usage patterns

### Story 1.3: Thread-Safe Database Operations
**As a** developer working with the database
**I want** all database operations to be thread-safe
**So that** background analysis doesn't crash the application

**Acceptance Criteria**:
- **Given** AI analysis is running in background threads
- **When** database access is required for storing timeline data
- **Then** all operations complete without priority inversion errors
- **And** UI remains responsive during background processing
- **And** database transactions are properly isolated

**Implementation Notes**:
- Implement DatabaseManager serial queue wrapper
- Add proper QoS configuration for database threads
- Test concurrent AI analysis + UI database access
- Validate transaction isolation

### Story 1.4: Memory Leak Detection System
**As a** developer debugging memory issues
**I want** automatic memory leak detection and reporting
**So that** memory issues are caught early and fixed systematically

**Acceptance Criteria**:
- **Given** the application is running for extended periods
- **When** memory leaks start to develop
- **Then** automatic alerts are generated with specific leak locations
- **And** memory usage trends are logged for analysis
- **And** critical memory thresholds trigger graceful cleanup

**Implementation Notes**:
- Implement MemoryMonitor with leak detection
- Add automatic memory usage tracking
- Create alert system for memory thresholds
- Test with artificial memory leaks

---

## Epic 2: Core Recording Pipeline Stabilization

**Epic Goal**: Ensure fundamental screen recording functionality works reliably after memory fixes.

### Story 2.1: Multi-Display Screen Capture
**As a** user with multiple monitors
**I want** FocusLock to capture activity across all displays
**So that** my complete work session is recorded accurately

**Acceptance Criteria**:
- **Given** multiple displays are connected and active
- **When** FocusLock starts recording
- **Then** screen capture works across all displays automatically
- **And** display switching is handled seamlessly
- **And** recording continues when displays are added/removed

**Implementation Notes**:
- Test with 2-4 monitor configurations
- Implement ActiveDisplayTracker improvements
- Handle display configuration changes gracefully
- Validate frame capture across all displays

### Story 2.2: Video Compression Optimization
**As a** user recording for 8+ hours
**I want** efficient video compression to manage storage
**So that** disk space usage remains reasonable

**Acceptance Criteria**:
- **Given** continuous 1 FPS recording for 8 hours
- **When** video frames are compressed and stored
- **Then** storage usage stays under 2GB per day
- **And** video quality remains sufficient for AI analysis
- **And** compression doesn't impact system performance

**Implementation Notes**:
- Optimize compression settings for 1 FPS capture
- Test storage usage patterns over 24-hour periods
- Validate AI can still process compressed video
- Monitor CPU usage during compression

### Story 2.3: Real-Time Recording Status
**As a** user monitoring recording status
**I want** clear indicators of recording state
**So that** I know the app is working correctly

**Acceptance Criteria**:
- **Given** FocusLock is running
- **When** recording is active/inactive/error states
- **Then** status indicators are clearly visible in the UI
- **And** status updates in real-time (<1 second latency)
- **And** error states provide clear recovery instructions

**Implementation Notes**:
- Implement RecordingStatus enum with clear states
- Add real-time status updates to UI
- Create error handling with user-friendly messages
- Test status accuracy across all recording scenarios

---

## Epic 3: AI Analysis Engine Validation

**Epic Goal**: Ensure AI processing pipeline works reliably for generating timeline insights.

### Story 3.1: Batch Processing Validation
**As a** user reviewing my daily timeline
**I want** AI analysis to process recorded segments every 15 minutes
**So that** timeline updates happen regularly throughout the day

**Acceptance Criteria**:
- **Given** 15 minutes of screen recording is available
- **When** the AI analysis batch process runs
- **Then** timeline cards are generated automatically
- **And** processing completes within 5 minutes
- **And** no crashes occur during AI processing

**Implementation Notes**:
- Test 15-minute batch processing cycle
- Validate AI processing time under 5 minutes
- Handle AI service failures gracefully
- Monitor processing queue backlog

### Story 3.2: OCR Text Extraction
**As a** user analyzing my work patterns
**I want** text extracted from screen captures
**So that** AI can understand what I'm working on

**Acceptance Criteria**:
- **Given** screen recordings contain text content
- **When** OCR processing runs on video frames
- **Then** text is extracted with 90%+ accuracy
- **And** extracted text is stored with timeline data
- **And** OCR processing doesn't impact overall performance

**Implementation Notes**:
- Integrate macOS Vision framework for OCR
- Test OCR accuracy across different screen content
- Optimize OCR processing for 1 FPS video
- Validate text storage and retrieval

### Story 3.3: Activity Categorization System
**As a** user reviewing my timeline
**I want** activities automatically categorized (coding, meetings, browsing, etc.)
**So that** I can understand how I spend my time

**Acceptance Criteria**:
- **Given** extracted text and visual data from screen captures
- **When** activity categorization runs
- **Then** activities are categorized with 80%+ accuracy
- **And** categories include: coding, meetings, browsing, writing, research
- **And** user can correct mis-categorizations

**Implementation Notes**:
- Implement rule-based classification system
- Create category definitions with keywords/patterns
- Add machine learning improvement capability
- Test categorization accuracy across diverse activities

### Story 3.4: Gemini API Integration Testing
**As a** user using cloud AI analysis
**I want** reliable Gemini API integration
**So that** AI processing works consistently

**Acceptance Criteria**:
- **Given** valid Gemini API configuration
- **When** video analysis requests are sent to Gemini
- **Then** API calls succeed 95%+ of the time
- **And** rate limits are handled gracefully
- **And** fallback options work when Gemini is unavailable

**Implementation Notes**:
- Test API reliability under various conditions
- Implement exponential backoff for retries
- Add local AI fallback (Ollama/LM Studio)
- Monitor API usage and costs

---

## Epic 4: Database & Persistence Reliability

**Epic Goal**: Ensure all data persistence works reliably after memory stabilization.

### Story 4.1: Timeline Data Persistence
**As a** user reviewing past activities
**I want** timeline data saved reliably to database
**So that** I can access my activity history

**Acceptance Criteria**:
- **Given** AI analysis generates timeline cards
- **When** timeline cards are saved to database
- **Then** data persists across app restarts
- **And** timeline data loads quickly (<2 seconds)
- **And** data integrity is maintained (no corruption)

**Implementation Notes**:
- Test database persistence across app restarts
- Validate timeline data loading performance
- Add data integrity checks and recovery
- Test with large timeline datasets (30+ days)

### Story 4.2: Recording Chunk Management
**As a** user with extended recording sessions
**I want** video chunks managed efficiently
**So that** storage doesn't fill up and old data is handled properly

**Acceptance Criteria**:
- **Given** continuous recording over multiple days
- **When** storage reaches retention limits (3 days default)
- **Then** old video chunks are automatically deleted
- **And** associated timeline data is preserved
- **And** storage usage stays within configured limits

**Implementation Notes**:
- Implement retention policy management
- Test automatic cleanup of old recordings
- Validate timeline data preservation
- Create user-configurable retention settings

### Story 4.3: Settings and Configuration Persistence
**As a** user customizing app settings
**I want** my preferences saved reliably
**So that** my configuration persists across app restarts

**Acceptance Criteria**:
- **Given** user modifies app settings (AI providers, retention, etc.)
- **When** settings are saved to database
- **Then** settings persist across app restarts
- **And** settings load correctly on app launch
- **And** invalid settings are handled gracefully

**Implementation Notes**:
- Implement robust settings validation
- Test settings persistence across app versions
- Add migration for settings format changes
- Create settings backup/restore capability

---

## Epic 5: User Interface & Experience

**Epic Goal**: Ensure UI is responsive, intuitive, and provides excellent user experience.

### Story 5.1: Dashboard Timeline Visualization
**As a** user reviewing my daily activities
**I want** a clean, intuitive timeline dashboard
**So that** I can quickly understand how I spent my time

**Acceptance Criteria**:
- **Given** timeline data is available for the current day
- **When** user opens the dashboard
- **Then** timeline displays activities in chronological order
- **And** timeline is scrollable and zoomable
- **And** activity categories are color-coded
- **And** dashboard loads in under 2 seconds

**Implementation Notes**:
- Implement SwiftUI timeline component
- Add smooth scrolling and zoom gestures
- Create color scheme for activity categories
- Optimize dashboard loading performance

### Story 5.2: Real-Time Status Indicators
**As a** user monitoring FocusLock
**I want** clear visual indicators of system status
**So that** I know everything is working correctly

**Acceptance Criteria**:
- **Given** FocusLock is running in various states
- **When** user views the main interface
- **Then** recording status is clearly visible (active/inactive/error)
- **And** AI processing status is indicated
- **And** memory/CPU usage is displayed
- **And** status updates reflect real-time changes

**Implementation Notes**:
- Design intuitive status indicator components
- Add real-time status refresh mechanism
- Create user-friendly error status displays
- Test status indicator accuracy

### Story 5.3: Responsive SwiftUI Interface
**As a** user interacting with the application
**I want** smooth, responsive interface interactions
**So that** the app feels fast and professional

**Acceptance Criteria**:
- **Given** the application interface is loaded
- **When** user interacts with any UI element
- **Then** responses occur within 200ms for simple actions
- **And** complex operations show progress indicators
- **And** UI never freezes or becomes unresponsive
- **And** animations are smooth and professional

**Implementation Notes**:
- Optimize SwiftUI view updates
- Add progress indicators for slow operations
- Implement proper background task management
- Test UI responsiveness under load

---

## Epic 6: AI Chat & Intelligence Features (Jarvis)

**Epic Goal**: Implement advanced AI assistant that provides contextual coaching and insights.

### Story 6.1: AI Chat Interface Implementation
**As a** user wanting AI assistance
**I want** a conversational chat interface with contextual awareness
**So that** I can get help understanding my work patterns

**Acceptance Criteria**:
- **Given** timeline data is available
- **When** user opens AI chat interface
- **Then** chat responds with knowledge of user's work history
- **And** responses are contextual and relevant
- **And** chat interface is intuitive and responsive
- **And** AI maintains conversation context

**Implementation Notes**:
- Implement SwiftUI chat interface
- Integrate with timeline data for context
- Add conversation memory management
- Test chat response quality and relevance

### Story 6.2: Work Pattern Memory System
**As a** user getting AI insights
**I want** AI to remember my work patterns over time
**So that** insights become more personalized and accurate

**Acceptance Criteria**:
- **Given** user has been using FocusLock for multiple weeks
- **When** AI analyzes work patterns
- **Then** insights reference historical patterns
- **And** AI recognizes recurring behaviors
- **And** suggestions improve based on learned patterns
- **And** pattern memory is efficient and fast

**Implementation Notes**:
- Implement pattern recognition algorithms
- Create efficient pattern storage system
- Add pattern learning and improvement
- Test pattern accuracy over time

### Story 6.3: Real-Time Coaching Insights
**As a** user working throughout the day
**I want** proactive coaching based on current activities
**So that** I can improve productivity and focus

**Acceptance Criteria**:
- **Given** user is currently working on tracked activities
- **When** AI detects patterns or opportunities
- **Then** coaching insights are provided proactively
- **And** insights are timely and relevant
- **And** coaching is helpful, not annoying
- **And** user can adjust coaching frequency

**Implementation Notes**:
- Implement real-time pattern detection
- Create helpful coaching algorithm
- Add user preference controls
- Test coaching usefulness and timing

---

## Epic 7: Productivity & Focus Features

**Epic Goal**: Implement smart productivity features that help users focus and work more efficiently.

### Story 7.1: Focus Mode Implementation
**As a** user needing to concentrate
**I want** focus mode that blocks distractions
**So that** I can work without interruptions

**Acceptance Criteria**:
- **Given** user activates focus mode
- **When** distracting websites/applications are accessed
- **Then** distractions are blocked or delayed
- **And** user can customize block lists
- **And** focus sessions can be scheduled
- **And** focus mode can be overridden when needed

**Implementation Notes**:
- Implement distraction detection and blocking
- Create customizable block lists
- Add scheduling capability
- Test focus mode effectiveness

### Story 7.2: Smart Task Management
**As a** user managing my work
**I want** automatic task creation from observed activities
**So that** I don't have to manually track everything

**Acceptance Criteria**:
- **Given** AI analysis identifies work activities
- **When** meaningful work is detected
- **Then** tasks are automatically created and suggested
- **And** tasks include relevant context and details
- **And** user can edit, accept, or reject suggested tasks
- **And** tasks integrate with timeline data

**Implementation Notes**:
- Implement task detection algorithms
- Create task suggestion interface
- Add task editing and management
- Test task relevance and usefulness

---

## Epic 8: Security & Privacy Implementation

**Epic Goal**: Ensure user data is secure and privacy is protected.

### Story 8.1: Secure API Key Storage
**As a** user configuring AI services
**I want** my API keys stored securely
**So that** my credentials are protected

**Acceptance Criteria**:
- **Given** user enters API keys for AI services
- **When** keys are stored by the application
- **Then** keys are encrypted in macOS Keychain
- **And** keys are never stored in plain text
- **And** key access requires proper authentication
- **And** keys can be securely updated and deleted

**Implementation Notes**:
- Integrate with macOS Keychain
- Implement proper key encryption
- Add key management interface
- Test key security and recovery

### Story 8.2: Local-First Data Processing
**As a** user concerned about privacy
**I want** my data processed locally by default
**So that** I maintain control over my information

**Acceptance Criteria**:
- **Given** user enables local AI processing
- **When** AI analysis is performed
- **Then** all processing happens on the local device
- **And** no data is sent to external servers
- **And** local AI models work effectively
- **And** user can opt into cloud processing if desired

**Implementation Notes**:
- Integrate Ollama/LM Studio for local AI
- Create local processing preference
- Test local AI performance and accuracy
- Add cloud processing opt-in controls

---

## Story Guidelines Applied

**Bite-Sized Scope**: Each story is designed for 1-3 day completion by a single development agent
**Vertical Slicing**: Each story delivers complete functionality across multiple layers
**BDD Format**: Given/When/Then acceptance criteria with clear success conditions
**Independent**: Stories can be developed in any order within their epic
**Testable**: Each story has clear validation criteria and testing requirements

## Implementation Priority

1. **Epic 1** (Critical Memory Management) - Must be completed first
2. **Epic 2** (Core Recording Pipeline) - Foundation for all other features
3. **Epic 4** (Database & Persistence) - Required for data reliability
4. **Epic 5** (UI & Experience) - User interaction foundation
5. **Epic 3** (AI Analysis Engine) - Core intelligence functionality
6. **Remaining Epics** - Advanced features and polish

---

*Generated through BMM Epic & Story Creation workflow*
*Date: 2025-11-13*
*Target: 200k context development agents*