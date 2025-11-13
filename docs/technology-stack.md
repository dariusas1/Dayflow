# Technology Stack Analysis

## Project Technology Overview

**Project Type:** Desktop macOS Application  
**Primary Language:** Swift 5.9+  
**UI Framework:** SwiftUI  
**Minimum OS:** macOS 13.0+  
**Architecture:** MVVM with Component-Based UI

## Core Dependencies

### Database & Storage
- **GRDB.swift** v7.0.0+ - SQLite database toolkit for data persistence
  - Purpose: Timeline cards, batches, observations storage
  - Features: Migration support, query building, database pooling

### User Interface & Updates
- **Sparkle** v2.7.1+ - Auto-update framework for macOS
  - Purpose: Automatic app updates and release management
  - Features: Background updates, delta updates, signed updates

### Analytics & Monitoring
- **Sentry** v8.56.2+ - Error tracking and performance monitoring
  - Purpose: Crash reporting, error logging, performance metrics
  - Features: Real-time error tracking, release health
- **PostHog** v3.31.0+ - Product analytics and user behavior
  - Purpose: Feature usage tracking, user analytics
  - Features: Event tracking, funnel analysis, user properties

## System Integration

### macOS Frameworks
- **SwiftUI** - Modern declarative UI framework
- **AppKit** - Native macOS app integration (via NSApplicationDelegateAdaptor)
- **AVFoundation** - Screen recording and video processing
- **Core Graphics** - Image processing and thumbnails
- **Keychain Services** - Secure credential storage
- **UserDefaults** - App preferences and settings
- **NotificationCenter** - System-wide event handling

### Permissions & Entitlements
- **Screen & System Audio Recording** - Core functionality
- **Hardened Runtime** - Security and sandboxing
- **App Transport Security** - Network security
- **URL Scheme Registration** - `dayflow://` deep links

## AI/ML Integration Architecture

### Multi-Provider Support
1. **Gemini Direct** (Primary)
   - Google Gemini API integration
   - Video understanding capabilities
   - Direct API calls with retry logic

2. **Ollama Local** (Privacy-focused)
   - Local model inference
   - Frame-by-frame analysis
   - Offline processing capability

3. **Dayflow Backend** (Enterprise)
   - Managed service option
   - Token-based authentication
   - Centralized processing

### Video Processing Pipeline
- **1 FPS Capture** - Low resource screen recording
- **15-minute Intervals** - Batch processing timing
- **AVFoundation** - Video composition and export
- **Sliding Window** - Context-aware activity generation

## Application Architecture

### Directory Structure Pattern
```
Dayflow/
├── App/                    # Application lifecycle & entry points
├── Core/                   # Business logic & services
│   ├── AI/                # LLM provider implementations
│   └── Thumbnails/        # Video thumbnail caching
├── System/                 # macOS integrations
├── Utilities/              # Shared helpers & tools
└── Views/                 # SwiftUI interface
    ├── Components/         # Reusable UI elements
    ├── Onboarding/        # First-run experience
    └── UI/                # Main application views
```

### Design Patterns
- **MVVM Architecture** - SwiftUI views with separate business logic
- **Service Layer** - Centralized business services (LLMService, StorageManager)
- **Provider Pattern** - Pluggable AI providers
- **Observer Pattern** - Combine publishers for state management
- **Factory Pattern** - Provider instantiation and configuration

## Data Architecture

### Storage Strategy
- **SQLite Database** (GRDB) - Structured data persistence
- **File System** - Video chunks and thumbnails
- **Keychain** - Secure credential storage
- **UserDefaults** - App preferences and settings

### Data Models
- **Timeline Cards** - Activity summaries and metadata
- **Batches** - Recording session management
- **Observations** - Raw AI analysis results
- **Categories** - User-defined activity classifications

## Performance & Resource Management

### Memory Management
- **Automatic Cleanup** - 3-day video retention
- **Thumbnail Caching** - Efficient image handling
- **Database Pooling** - Connection reuse via GRDB

### CPU Optimization
- **1 FPS Recording** - Minimal capture overhead
- **Batch Processing** - 15-minute analysis intervals
- **Background Processing** - Non-blocking AI operations

### Storage Efficiency
- **Compression** - Video chunk optimization
- **Selective Retention** - Configurable data policies
- **Cache Management** - Temporary file cleanup

## Security & Privacy

### Data Protection
- **Local Processing Option** - Ollama for privacy
- **Keychain Storage** - Secure API key management
- **Sandboxing** - macOS app sandbox compliance
- **HTTPS Only** - Secure network communications

### Privacy Features
- **Provider Choice** - Cloud vs local processing
- **Data Minimization** - Only essential data collection
- **Transparent Policies** - Open source and documented
- **User Control** - Granular permission management