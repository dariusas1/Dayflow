# {{project_name}} - Product Requirements Document

**Author:** {{user_name}}
**Date:** {{date}}
**Version:** 1.0

---

## Executive Summary

FocusLock is a native macOS application that serves as an entrepreneur's "second brain" - continuously recording screen activity at 1 FPS and using AI to provide complete contextual awareness, intelligent coaching, and automated productivity optimization. The app transforms from passive observation into active assistance: categorizing work patterns, creating smart todos, generating journals, and providing a Jarvis-like AI chat that knows everything about the user's actual work (not just their plans).

The current codebase contains all envisioned features but suffers from critical memory management bugs causing immediate crashes, requiring a brownfield rescue mission to stabilize the existing implementation before feature validation can occur.

### What Makes This Special

FocusLock delivers the holy grail of personal productivity: **perfect contextual awareness without manual input**. The AI becomes a true digital companion that sees your actual work patterns, provides real-time coaching ("You seem stuck - want me to pull up similar challenges you solved last month?"), identifies blind spots ("I notice you always switch to social media after 3 PM when working on financial models"), and maintains complete continuity across context switches. This isn't another todo app - it's an external brain that compensates for human cognitive limits through continuous, intelligent observation.

---

## Project Classification

**Technical Type:** Desktop Application (Native macOS)
**Domain:** General Productivity Tools
**Complexity:** Medium (Memory Management Focus)

**Project Type:** Brownfield Rescue Mission - All features implemented but critical memory bugs prevent stable operation. The app successfully initializes all systems (database, screen recording, AI analysis, keychain access) but crashes after 1-2 minutes due to "freed pointer was not last allocation" error in GRDB database operations.

**Target User:** Busy entrepreneurs managing 100+ concurrent tasks who need to focus on critical priorities while maintaining perfect contextual awareness across all work activities.

{{#if domain_context_summary}}

### Domain Context

{{domain_context_summary}}
{{/if}}

---

## Success Criteria

**Technical Success (Immediate Priority):**
- App launches and runs continuously for 8+ hours without crashes
- Screen recording pipeline operates stably without memory leaks
- Database operations complete without "freed pointer" errors
- All existing features can be tested and validated

**User Success (Post-Stabilization):**
- Entrepreneurs report feeling "in control" instead of "overwhelmed"
- Measurable reduction in context switching through AI coaching
- Users experience "aha!" moments about their work patterns
- Smart todos accurately reflect user's actual work priorities
- AI chat becomes indispensable for decision-making with perfect recall

**Business Success:**
- Zero crash reports in production
- Users report "can't imagine working without this"
- Feature adoption across all major capabilities (recording, analysis, coaching)

{{#if business_metrics}}

### Business Metrics

{{business_metrics}}
{{/if}}

---

## Product Scope

### MVP - Minimum Viable Product (Stabilization Focus)

**Critical Bug Fixes (Only Priority):**
- Fix memory management bug causing "freed pointer was not last allocation" crashes
- Resolve GRDB database threading issues in StorageManager.chunksForBatch()
- Ensure proper memory cleanup in screen recording pipeline
- Stabilize concurrent access to database from analysis threads

**Core Functionality Validation:**
- Continuous screen recording (1 FPS) for 8+ hour sessions
- AI analysis pipeline processing without crashes
- Database persistence of timeline entries and metadata
- Basic UI navigation and dashboard rendering

### Growth Features (Post-Stabilization)

**Feature Validation & Polish:**
- Test and fix all existing features (Jarvis chat, smart todos, journaling, focus mode)
- Optimize performance and memory usage
- Improve error handling and user feedback
- Enhance UI responsiveness and polish

### Vision (Future)

**Enhanced Capabilities:**
- Advanced pattern recognition and behavioral insights
- Multi-device synchronization and cloud backup
- Team features and shared productivity insights
- Plugin architecture for custom AI providers and extensions

---

{{#if domain_considerations}}

## Domain-Specific Requirements

{{domain_considerations}}

This section shapes all functional and non-functional requirements below.
{{/if}}

---

{{#if innovation_patterns}}

## Innovation & Novel Patterns

{{innovation_patterns}}

### Validation Approach

{{validation_approach}}
{{/if}}

---

## Desktop Application Specific Requirements

### Memory Management & Performance

**Critical Requirements:**
- Zero memory leaks during continuous screen recording sessions
- Proper thread-safe database operations using GRDB
- Efficient video frame processing without memory accumulation
- Stable background processing for AI analysis

**Performance Targets:**
- <100MB RAM usage during idle recording
- <1% CPU usage during 1 FPS capture
- <2 second UI response time for all interactions
- 8+ hour continuous operation without restart

### macOS Integration

**System Requirements:**
- ScreenCaptureKit permissions handling with proper error recovery
- Keychain access for secure API key storage
- LaunchAgent integration for background operation
- Native macOS notifications and system integration

**Platform Support:**
- macOS 13.0+ (Intel and Apple Silicon)
- SwiftUI with iOS 17+ features where applicable
- Native performance optimization for Apple Silicon

{{#if endpoint_specification}}

### API Specification

{{endpoint_specification}}
{{/if}}

{{#if authentication_model}}

### Authentication & Authorization

{{authentication_model}}
{{/if}}

{{#if platform_requirements}}

### Platform Support

{{platform_requirements}}
{{/if}}

{{#if device_features}}

### Device Capabilities

{{device_features}}
{{/if}}

{{#if tenant_model}}

### Multi-Tenancy Architecture

{{tenant_model}}
{{/if}}

{{#if permission_matrix}}

### Permissions & Roles

{{permission_matrix}}
{{/if}}
{{/if}}

---

{{#if ux_principles}}

## User Experience Principles

{{ux_principles}}

### Key Interactions

{{key_interactions}}
{{/if}}

---

## Functional Requirements

### Core Recording & Analysis Pipeline

**Screen Recording System:**
- Continuous 1 FPS screen capture using ScreenCaptureKit
- Automatic display switching handling (multi-monitor support)
- Efficient video frame compression and storage
- Memory-safe buffer management for recording pipeline

**AI Analysis Engine:**
- Batch processing of recorded segments every 15 minutes
- OCR text extraction from screen captures
- Activity categorization using rule-based classification
- Gemini API integration with proper error handling

**Data Persistence:**
- Thread-safe database operations using GRDB
- Recording chunk storage and retrieval without memory corruption
- Timeline entry creation and management
- User preferences and settings persistence

### User Interface & Experience

**Dashboard & Timeline:**
- Clean timeline visualization of daily activities
- Real-time recording status indicators
- Activity category breakdown and metrics
- Responsive SwiftUI interface without freezing

**AI Chat Interface (Jarvis):**
- Conversational AI with complete contextual awareness
- Memory of user's work patterns and history
- Real-time coaching and behavioral insights
- Smart task suggestions based on observed activities

### Productivity Features

**Focus Mode:**
- Distraction blocking and session management
- Task prioritization based on observed work patterns
- Context switching reduction through intelligent notifications
- Progress tracking and goal completion

**Smart Task Management:**
- Automatic todo creation from observed activities
- Task prioritization based on actual work patterns
- Integration with timeline and coaching insights
- Deadline and priority management

**Automated Journaling:**
- Daily activity summaries and reflections
- Pattern recognition and behavioral insights
- Productivity metrics and trend analysis
- Personal growth recommendations

---

## Non-Functional Requirements

### Performance

**Memory Management:**
- Zero memory leaks during 8+ hour recording sessions
- Proper cleanup of video frame buffers and database connections
- Efficient garbage collection and memory pool usage
- <100MB RAM usage during normal operation

**Processing Speed:**
- <1% CPU usage during 1 FPS screen recording
- <2 second UI response time for all interactions
- <5 second AI analysis processing for 15-minute segments
- Real-time dashboard updates without lag

### Security

**Data Privacy:**
- Local-first data processing with user-controlled cloud options
- Secure API key storage using macOS Keychain
- End-to-end encryption for cloud AI processing
- User consent for all data collection and analysis

**System Security:**
- Proper ScreenCaptureKit permission handling
- Sandboxed application following macOS security guidelines
- Secure database encryption for sensitive timeline data
- Privacy-first design with minimal data retention

### Reliability

**Stability Requirements:**
- Zero crashes during normal 8-hour work sessions
- Graceful error handling for network and AI service failures
- Automatic recovery from temporary system issues
- Data integrity guarantees for timeline and settings

**Error Recovery:**
- Automatic retry mechanisms for AI API failures
- Database transaction rollback on errors
- User-friendly error messages and recovery suggestions
- Crash reporting with diagnostic information

### Integration

**macOS Integration:**
- Native ScreenCaptureKit API usage
- Proper LaunchAgent integration for background operation
- System notification integration for important events
- Native file system access and permissions handling

**AI Service Integration:**
- Flexible AI provider architecture (Gemini, Ollama, LM Studio)
- Robust error handling for API failures and rate limits
- Local AI model support for privacy-sensitive users
- Fallback mechanisms for service unavailability

---

## Implementation Planning

### Critical Bug Fix Epic (Immediate Priority)

**Memory Management Rescue:**
- Fix "freed pointer was not last allocation" crash in GRDB operations
- Resolve threading issues in StorageManager.chunksForBatch()
- Implement proper memory cleanup in screen recording pipeline
- Ensure thread-safe database access from analysis threads

**Stabilization Stories:**
- Debug and fix memory corruption in database operations
- Implement proper error handling for concurrent database access
- Add memory leak detection and prevention
- Validate 8+ hour continuous operation without crashes

### Feature Validation Epic (Post-Stabilization)

**Core Feature Testing:**
- Validate screen recording pipeline stability
- Test AI analysis end-to-end functionality
- Verify database persistence and retrieval
- Confirm UI responsiveness and navigation

**Feature Polish Stories:**
- Optimize performance and memory usage
- Improve error handling and user feedback
- Enhance UI polish and user experience
- Fix any remaining feature-specific bugs

### Epic Breakdown Required

Requirements must be decomposed into implementable epics and bite-sized stories (200k context limit).

**Next Step:** Run `workflow epics-stories` to create the implementation breakdown.

---

## References

- Project Overview: docs/project-overview.md
- Architecture Documentation: docs/architecture.md
- Development Guide: docs/development-guide.md
- Source Tree Analysis: docs/source-tree-analysis.md
- Technology Stack: docs/technology-stack.md

---

## Next Steps

1. **Epic & Story Breakdown** - Run: `workflow epics-stories`
2. **UX Design** (if UI) - Run: `workflow ux-design`
3. **Architecture** - Run: `workflow create-architecture`

---

_This PRD captures the essence of FocusLock - perfect contextual awareness without manual input, transforming from passive observation to active AI-powered coaching and productivity optimization._

_Created through collaborative discovery between darius and AI facilitator._