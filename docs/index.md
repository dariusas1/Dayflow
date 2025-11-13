# Project Documentation Index - FocusLock

## Project Overview

### Project Type: Monolith Desktop macOS Application  
### Primary Language: Swift  
### Architecture: MVVM with Component-Based UI  

## Quick Reference

### Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (iOS 17+ / macOS 14+ features)
- **Database**: GRDB (SQLite)
- **Screen Capture**: ScreenCaptureKit (native)
- **Auto Updates**: Sparkle framework
- **Error Tracking**: Sentry (opt-in)
- **Analytics**: PostHog (opt-in)
- **AI Providers**: Gemini (cloud), Ollama/LM Studio (local)

### Entry Point
- **Main App**: `Dayflow/Dayflow/App/DayflowApp.swift`
- **Architecture Pattern**: MVVM with Component-Based UI
- **Minimum OS**: macOS 13.0 (Ventura)

## Generated Documentation

### Core Documentation
- [Project Overview](./project-overview.md) - Complete project introduction and getting started
- [Architecture](./architecture.md) - Technical architecture and design patterns
- [Source Tree Analysis](./source-tree-analysis.md) - Annotated directory structure
- [Component Inventory](./component-inventory.md) - UI component library documentation
- [Development Guide](./development-guide.md) - Development setup and workflows
- [Deployment Guide](./deployment-guide.md) - Build and release processes
- [Contribution Guide](./contribution-guide.md) - Contributing guidelines and standards

### Specialized Analysis
- [State Management Patterns](./state-management-patterns_focuslock.md) - Data flow and state handling
- [UI Component Inventory](./ui-component-inventory_focuslock.md) - User interface components
- [Asset Inventory](./asset-inventory_focuslock.md) - Project assets and resources
- [Deployment Configuration](./deployment-configuration_focuslock.md) - Infrastructure setup
- [Technology Stack](./technology-stack.md) - Detailed technology analysis
- [Project Structure Analysis](./project-structure-analysis.md) - Code organization

### Analysis Reports
- [Existing Documentation Inventory](./existing-documentation-inventory.md) - Documentation catalog
- [BETA LAUNCH ANALYSIS REPORT](./BETA_LAUNCH_ANALYSIS_REPORT.md) - Beta launch analysis
- [BETA READINESS ANALYSIS - INTEGRATION](./BETA_READINESS_ANALYSIS_INTEGRATION.md) - Integration readiness
- [BETA READINESS ANALYSIS - PERFORMANCE](./BETA_READINESS_ANALYSIS_PERFORMANCE.md) - Performance readiness
- [SPARC Analysis Report](./SPARC_Analysis_Report.md) - SPARC framework analysis

### Technical Documentation
- [CRASH FIX SUMMARY](./CRASH_FIX_SUMMARY.md) - Crash fix documentation
- [CRASH FIX TESTING](./CRASH_FIX_TESTING.md) - Crash fix testing
- [SINGLETON DATABASE CRASH FIXES](./SINGLETON_DATABASE_CRASH_FIXES.md) - Database crash fixes
- [TECH DEBT](./TECH_DEBT.md) - Technical debt tracking
- [USERDEFAULTS KEYS](./USERDEFAULTS_KEYS.md) - Configuration keys

### Release and Deployment
- [PRIVACY](./PRIVACY.md) - Privacy policy and data handling
- [Build Baseline](./build-baseline-2025-10-27.md) - Build performance baseline
- [Mission Completion Report](./MISSION_COMPLETION_REPORT.md) - Project completion
- [Launch Decision](./LAUNCH_DECISION.md) - Launch readiness decision

## Existing Documentation

### Project Documentation
- [Main README](../README.md) - Project overview, installation, and usage
- [Agents Documentation](../AGENTS.md) - AI agent configuration and usage
- [Code Review Responses](../CODE_REVIEW_RESPONSE.md) - Code review feedback and responses

### Configuration Files
- [Formatted Prompt](./formatted_prompt.txt) - AI prompt templates
- [Errors Documentation](./errors.md) - Error handling and troubleshooting

## Getting Started

### For End Users
1. **Download**: Get latest `Dayflow.dmg` from [GitHub Releases](https://github.com/JerryZLiu/Dayflow/releases)
2. **Install**: Drag Dayflow to Applications folder
3. **Permissions**: Grant Screen & System Audio Recording permission in System Settings
4. **Configure**: Choose AI provider (Gemini or local) and enter API key if needed
5. **Start**: Begin recording and timeline generation

### For Developers
1. **Clone Repository**: `git clone https://github.com/JerryZLiu/Dayflow.git`
2. **Open in Xcode**: `open Dayflow.xcodeproj`
3. **Configure Signing**: Set your Apple Developer team in project settings
4. **Set Environment**: Add `GEMINI_API_KEY` to scheme environment variables
5. **Run**: Build and run application (Cmd+R)

### For Local AI Development
1. **Install Ollama**: `brew install ollama && ollama pull llama2`
2. **Or Install LM Studio**: Download from https://lmstudio.ai
3. **Start Local Server**: Ensure AI service is running on localhost
4. **Configure in App**: Select local provider in FocusLock settings

## Development Workflow

### Build Commands
```bash
# Open project in Xcode
open Dayflow.xcodeproj

# Build from command line
xcodebuild -project Dayflow.xcodeproj -scheme Dayflow -configuration Debug build

# Run all tests
xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS'

# Release automation
./scripts/release.sh
```

### Key Configuration Files
- **Info.plist**: App metadata, permissions, and configuration
- **Dayflow.entitlements**: macOS app entitlements and capabilities
- **project.pbxproj**: Xcode project configuration
- **appcast.xml**: Sparkle automatic update feed

### Environment Variables
- **GEMINI_API_KEY**: Google Gemini API key for cloud AI processing
- **DEBUG_SCREEN_CAPTURE**: Enable debug logging for screen recording
- **FORCE_LOCAL_MODELS**: Force local AI model usage

## Architecture Highlights

### MVVM Pattern Implementation
- **Models**: GRDB database models and data structures
- **Views**: SwiftUI components with clear separation from business logic
- **ViewModels**: Business logic, state management, and data transformation

### Component-Based UI Design
- **Reusable Components**: Modular UI components for consistency
- **Design System**: Unified colors, typography, and spacing
- **Accessibility**: Full accessibility support throughout the app

### Service Layer Architecture
- **AI Service**: Pluggable AI provider architecture
- **Recording Service**: Screen capture and storage management
- **Storage Service**: Database operations and data persistence

## Testing Strategy

### Test Coverage
- **Unit Tests**: Business logic validation (XCTest)
- **Integration Tests**: Service interaction testing
- **UI Tests**: User interface automation (XCUITest)
- **Performance Tests**: Memory and CPU validation
- **System Tests**: End-to-end workflow validation

### Test Categories
- **AI Provider Tests**: LLM provider integration validation
- **Error Scenario Tests**: Error handling and recovery
- **FocusLock Integration Tests**: End-to-end workflow testing
- **Performance Validation Tests**: Performance benchmarking
- **Recording Pipeline Tests**: Screen recording edge cases

## Deployment and Release

### Release Process
1. **Version Bump**: Update version numbers in Xcode project
2. **Build**: Create release build with proper signing
3. **DMG Creation**: Generate professional DMG installer
4. **Code Signing**: Sign with Developer ID certificate
5. **Notarization**: Submit to Apple for notarization
6. **Sparkle Signing**: Sign update for automatic updates
7. **GitHub Release**: Create release and upload DMG
8. **Appcast Update**: Update Sparkle feed

### Automation Scripts
- **release.sh**: One-button release automation
- **release_dmg.sh**: DMG creation and styling
- **make_appcast.sh**: Sparkle appcast generation
- **update_appcast.sh**: Appcast update management

## Privacy and Security

### Data Privacy
- **Local Processing**: Option for fully local AI processing
- **User Control**: Users choose AI provider and data handling
- **Transparent**: Open source code for complete auditability
- **Minimal Collection**: Only necessary data collected and processed

### Security Measures
- **Code Signing**: Developer ID verification for macOS Gatekeeper
- **Notarization**: Apple malware scan verification
- **Secure Storage**: API keys stored in macOS Keychain
- **Permission Control**: Explicit user permission for screen recording

## Community and Support

### Contributing
- **Pull Requests**: Welcome with code review
- **Issues**: Bug reports and feature requests via GitHub
- **Discussions**: Community discussions and questions
- **Contribution Guide**: [Detailed contributing guidelines](./contribution-guide.md)

### Support Channels
- **Documentation**: Comprehensive guides and API documentation
- **GitHub Issues**: Bug reports and feature requests
- **Analytics**: Opt-in crash reporting and usage analytics
- **Community**: Discussions and community support

## Performance and Optimization

### Resource Usage
- **Memory**: Target ~100MB RAM during normal operation
- **CPU**: <1% during recording, spikes during AI processing
- **Storage**: Configurable retention with automatic cleanup
- **Network**: Minimal usage (only for cloud AI providers)

### Optimization Strategies
- **1 FPS Recording**: Minimal performance impact
- **Background Processing**: AI processing on background queues
- **Efficient Caching**: Thumbnail and data caching
- **Lazy Loading**: UI components loaded on demand

## Future Development

### Roadmap
- **Customizable Dashboard**: User-configurable analytics dashboard
- **Daily Journal**: Guided reflection with timeline integration
- **Advanced Analytics**: Trend analysis and productivity insights
- **Team Features**: Multi-user support and sharing

### Technical Enhancements
- **Performance Optimization**: Enhanced GPU acceleration
- **Plugin Architecture**: Support for custom AI providers
- **Mobile Expansion**: Potential iOS/iPadOS companion
- **Cloud Sync**: Optional synchronization across devices

---

**This index serves as the primary entry point for AI-assisted development and understanding of the FocusLock project. For detailed technical information, refer to the specialized documentation linked above.**

**Last Updated**: 2025-11-13  
**Project Version**: Active development  
**Documentation Version**: 1.0