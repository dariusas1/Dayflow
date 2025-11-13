# Project Overview - FocusLock

## Project Name and Purpose

**FocusLock** is a native macOS application that automatically records user screen activity at 1 FPS and analyzes it every 15 minutes using AI to generate a comprehensive timeline of daily activities. The application emphasizes privacy, user control, and minimal performance impact while providing valuable insights into how users spend their time.

### Core Value Proposition
- **Automatic Timeline Generation**: No manual data entry required
- **Privacy-First Design**: Local processing options with transparent data handling
- **Minimal Performance Impact**: ~100MB RAM usage and <1% CPU during recording
- **AI-Powered Insights**: Intelligent activity summarization and categorization
- **User Control**: Choice between cloud (Gemini) and local (Ollama/LM Studio) AI providers

## Executive Summary

FocusLock addresses the common problem of time tracking accuracy by leveraging the reality that our screens, not our calendars, reflect how we actually spend our time. The application captures screen activity passively, processes it with AI, and presents it in a clean, understandable timeline format.

### Key Differentiators
1. **Passive Operation**: Works automatically in the background
2. **Privacy Respect**: Users choose their AI provider and data processing location
3. **Native Performance**: Built with SwiftUI for optimal macOS integration
4. **Professional Automation**: Complete build, test, and release pipeline
5. **Open Source**: MIT licensed with transparent development

## Tech Stack Summary

| Category | Technology | Version | Purpose |
|-----------|------------|----------|---------|
| **Language** | Swift | 5.9+ | Primary development language |
| **UI Framework** | SwiftUI | iOS 17+ / macOS 14+ features | Native user interface |
| **Database** | GRDB | Latest | Type-safe SQLite persistence |
| **Screen Capture** | ScreenCaptureKit | Native | Efficient screen recording |
| **Auto Updates** | Sparkle | Latest | Automatic app updates |
| **Error Tracking** | Sentry | Latest | Crash reporting and monitoring |
| **Analytics** | PostHog | Latest | Product analytics (opt-in) |
| **AI Providers** | Gemini, Ollama, LM Studio | Various | Flexible AI processing |
| **Build System** | Xcode | 15+ | IDE and build management |

## Architecture Type Classification

### Repository Structure
- **Type**: Monolith
- **Platform**: macOS Desktop Application
- **Architecture Pattern**: MVVM with Component-Based UI
- **Deployment**: Direct distribution with automatic updates

### Key Architectural Characteristics
- **Single Codebase**: Unified application code in one repository
- **Modular Design**: Clear separation between UI, business logic, and data layers
- **Service-Oriented**: Pluggable AI provider architecture
- **Event-Driven**: Reactive programming with Combine framework
- **Privacy-Focused**: Local-first data processing with cloud options

## Repository Structure

### High-Level Organization
```
FocusLock/
├── Dayflow/                    # Main application bundle
│   ├── Dayflow/               # Source code directory
│   │   ├── App/               # Application lifecycle
│   │   ├── Core/              # Business logic services
│   │   ├── Views/             # SwiftUI user interface
│   │   └── Utilities/         # Helper utilities
│   └── DayflowTests/          # Test suite
├── docs/                      # Documentation and analysis
├── scripts/                   # Build and release automation
└── Configuration files        # Project metadata
```

### Key Directories
- **Dayflow/Dayflow/**: Primary application source code
- **Dayflow/DayflowTests/**: Comprehensive test suite
- **docs/**: Project documentation, analysis reports, and assets
- **scripts/**: Professional build, test, and release automation

## Quick Reference

### Development Commands
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

## Getting Started Instructions

### For End Users
1. **Download**: Get latest `Dayflow.dmg` from GitHub Releases
2. **Install**: Drag Dayflow to Applications folder
3. **Permissions**: Grant Screen & System Audio Recording permission
4. **Configure**: Choose AI provider (Gemini or local)
5. **Start**: Begin recording and timeline generation

### For Developers
1. **Clone Repository**: `git clone https://github.com/JerryZLiu/Dayflow.git`
2. **Open in Xcode**: `open Dayflow.xcodeproj`
3. **Configure Signing**: Set Apple Developer team in project settings
4. **Set Environment**: Add `GEMINI_API_KEY` to scheme environment variables
5. **Run**: Build and run application in Xcode

### For Local AI Development
1. **Install Ollama**: `brew install ollama && ollama pull llama2`
2. **Or Install LM Studio**: Download from https://lmstudio.ai
3. **Start Local Server**: Ensure AI service is running on localhost
4. **Configure in App**: Select local provider in FocusLock settings

## Links to Detailed Documentation

### Core Documentation
- [Architecture Documentation](./architecture.md) - Complete technical architecture
- [Source Tree Analysis](./source-tree-analysis.md) - Annotated directory structure
- [Development Guide](./development-guide.md) - Development setup and workflows
- [Deployment Guide](./deployment-guide.md) - Build and release processes

### Specialized Documentation
- [State Management Patterns](./state-management-patterns_focuslock.md) - Data flow and state handling
- [UI Component Inventory](./ui-component-inventory_focuslock.md) - User interface components
- [Asset Inventory](./asset-inventory_focuslock.md) - Project assets and resources
- [Deployment Configuration](./deployment-configuration_focuslock.md) - Infrastructure setup

### Analysis and Reports
- [Technology Stack](./technology-stack.md) - Detailed technology analysis
- [Project Structure Analysis](./project-structure-analysis.md) - Code organization
- [Existing Documentation Inventory](./existing-documentation-inventory.md) - Documentation catalog

### External Resources
- [GitHub Repository](https://github.com/JerryZLiu/Dayflow) - Source code and issues
- [Releases Page](https://github.com/JerryZLiu/Dayflow/releases) - Download latest versions
- [Main README](../README.md) - Project overview and installation guide

## Project Status and Roadmap

### Current Status
- **Version**: Active development with regular releases
- **Stability**: Production-ready with comprehensive test coverage
- **Platform**: macOS 13.0+ (Intel and Apple Silicon)
- **Distribution**: Public GitHub releases with automatic updates

### Upcoming Features
- **Customizable Dashboard**: User-configurable analytics dashboard
- **Daily Journal**: Guided reflection with timeline integration
- **Advanced Analytics**: Trend analysis and productivity insights
- **Team Features**: Multi-user support and sharing capabilities

### Technical Roadmap
- **Performance Optimization**: Enhanced GPU acceleration for video processing
- **Plugin Architecture**: Support for custom AI providers and extensions
- **Mobile Expansion**: Potential iOS/iPadOS companion application
- **Cloud Sync**: Optional synchronization across devices

## Community and Support

### Contributing
- **Contributions Welcome**: Pull requests accepted with code review
- [Contribution Guide](./contribution-guide.md) - Detailed contribution guidelines
- **Issue Reporting**: GitHub issues with detailed reproduction steps
- **Feature Requests**: GitHub discussions for community input

### Support Channels
- **Documentation**: Comprehensive guides and API documentation
- **GitHub Issues**: Bug reports and feature requests
- **Community**: Discussions and community support
- **Analytics**: Opt-in crash reporting and usage analytics

## License and Legal

### Open Source License
- **License**: MIT License
- **Source Code**: Fully available on GitHub
- **Commercial Use**: Permitted under MIT terms
- **Modifications**: Allowed with attribution

### Privacy and Compliance
- **Data Privacy**: User-controlled data processing
- **GDPR Considerations**: Privacy-by-design approach
- **Apple Guidelines**: Mac App Store guidelines compliance
- **Security**: Regular security updates and vulnerability monitoring

This project overview provides a comprehensive introduction to FocusLock, its architecture, and how to get started with development or usage. For detailed technical information, refer to the specialized documentation linked above.