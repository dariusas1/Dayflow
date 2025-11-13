# Development Guide - FocusLock

## Prerequisites and Dependencies

### System Requirements
- **macOS 13.0+** (Ventura or later)
- **Xcode 15+** with Apple Developer account
- **Apple Silicon** (recommended) or Intel Mac
- **Git** for version control

### Development Tools Required
- **Xcode 15+** - Primary IDE and build system
- **Swift Package Manager** - Dependency management (built into Xcode)
- **GitHub CLI (gh)** - For release automation
- **Sparkle CLI (sign_update)** - For update signing

### Apple Developer Requirements
- **Apple Developer ID** for code signing
- **Developer ID Installer certificate** for DMG signing
- **Notarization credentials** (Apple ID or App Store Connect API key)

## Environment Setup

### 1. Clone and Open Project
```bash
git clone https://github.com/JerryZLiu/Dayflow.git
cd Dayflow
open Dayflow.xcodeproj
```

### 2. Configure Xcode Project
1. Select **Dayflow** target in Xcode
2. Configure **Signing & Capabilities**:
   - Set your **Team** (Apple Developer account)
   - Ensure **Automatically manage signing** is enabled
   - Verify **Bundle Identifier** matches your developer ID

### 3. Environment Variables for Development
In Xcode scheme settings (**Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**):

**For Gemini AI Provider:**
```
GEMINI_API_KEY=your_gemini_api_key_here
```

**Optional Debug Variables:**
```
DEBUG_SCREEN_CAPTURE=1          # Enable debug logging for screen capture
DEBUG_AI_PROCESSING=1          # Enable AI processing debug logs
FORCE_LOCAL_MODELS=1          # Force local model usage
```

### 4. Local AI Provider Setup (Optional)

**For Ollama:**
```bash
# Install Ollama
brew install ollama

# Pull a model
ollama pull llama2

# Start Ollama server
ollama serve
```

**For LM Studio:**
1. Download and install LM Studio from https://lmstudio.ai
2. Launch LM Studio and load a model
3. Start the local server (usually on http://localhost:1234)

## Build Process

### Development Build
```bash
# Using Xcode
# 1. Select "Dayflow" scheme
# 2. Choose "My Mac" as destination
# 3. Press Cmd+R or Product → Run
```

### Command Line Build
```bash
# Build for development
xcodebuild -project Dayflow.xcodeproj -scheme Dayflow -configuration Debug build

# Build for release
xcodebuild -project Dayflow.xcodeproj -scheme Dayflow -configuration Release build
```

### Archive for Distribution
```bash
# Create archive
xcodebuild -project Dayflow.xcodeproj -scheme Dayflow -configuration Release archive

# Export archive (if needed)
xcodebuild -exportArchive -archivePath ./build/Dayflow.xcarchive -exportPath ./build/ -exportOptionsPlist ExportOptions.plist
```

## Testing Approach and Commands

### Unit Tests
```bash
# Run all unit tests
xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS'

# Run specific test class
xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' -only-testing:DayflowTests/AIProviderTests

# Run with code coverage
xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' -enableCodeCoverage YES
```

### UI Tests
```bash
# Run UI tests
xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' -only-testing:DayflowUITests
```

### Performance Tests
```bash
# Run performance validation tests
xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' -only-testing:DayflowTests/FocusLockPerformanceValidationTests
```

### Test Categories
The test suite includes several categories:

**AI Provider Tests** (`AIProviderTests.swift`)
- LLM provider integration validation
- API key authentication testing
- Response parsing verification

**Error Scenario Tests** (`ErrorScenarioTests.swift`)
- Network failure handling
- API error response processing
- Graceful degradation testing

**FocusLock Integration Tests** (`FocusLockIntegrationTests.swift`)
- End-to-end workflow validation
- Screen recording pipeline testing
- AI processing integration

**Performance Validation** (`FocusLockPerformanceValidationTests.swift`)
- Memory usage benchmarks
- CPU performance validation
- Storage efficiency testing

**Recording Pipeline Tests** (`RecordingPipelineEdgeCaseTests.swift`)
- Edge case handling in screen recording
- Multi-display support testing
- Error recovery scenarios

## Common Development Tasks

### Adding New AI Providers
1. Create new provider class conforming to `LLMProvider` protocol
2. Implement required methods: `processVideo()`, `validateConfiguration()`
3. Add provider to `LLMService` provider registry
4. Update UI in `LLMProviderSetupView.swift`
5. Add tests in `AIProviderTests.swift`

### Modifying Recording Settings
1. Update constants in `ScreenRecorder.swift`
2. Modify UI in `SettingsView.swift`
3. Update analytics events in `AnalyticsEventDictionary.md`
4. Add corresponding tests

### Adding New Timeline Features
1. Update data models in `TimelineDataModels.swift`
2. Implement UI components in `Views/UI/`
3. Add processing logic in `Core/Recording/`
4. Update analytics tracking
5. Add comprehensive tests

### Debugging Screen Capture Issues
1. Enable debug logging: `DEBUG_SCREEN_CAPTURE=1`
2. Check macOS permissions in System Settings → Privacy & Security
3. Verify ScreenCaptureKit framework usage
4. Test with different display configurations
5. Check `ActiveDisplayTracker.swift` logs

### Performance Optimization
1. Use Instruments for profiling (Time Profiler, Allocations, Leaks)
2. Focus on:
   - Screen recording efficiency (1 FPS target)
   - Memory usage during AI processing
   - Database query performance (GRDB)
   - Thumbnail generation and caching

## Debugging Tools

### Xcode Debugging
- **Breakpoints**: Set in Xcode for step-through debugging
- **LLDB Console**: Use `po` command for object inspection
- **View Hierarchy**: Debug SwiftUI view layouts
- **Memory Graph**: Detect memory leaks and retain cycles

### Logging
The app uses structured logging with different levels:
```swift
// Debug logging (development builds only)
LLMLogger.debug("Processing video chunk: \(chunkId)")

// Info logging (always visible)
LLMLogger.info("AI provider configured successfully")

// Error logging
LLMLogger.error("Failed to process video: \(error)")
```

### Analytics Events
All user actions are tracked via analytics (see `AnalyticsEventDictionary.md`):
- Screen recording start/stop
- AI provider selection
- Configuration changes
- Error occurrences

## Release Process

### Automated Release (Recommended)
```bash
# Minor version bump (default)
./scripts/release.sh

# Major version bump
./scripts/release.sh --major

# Patch version bump
./scripts/release.sh --patch

# Dry run (no changes)
./scripts/release.sh --dry-run
```

### Manual Release Steps
1. **Version Bump**: Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode project
2. **Build**: Create release build with proper signing
3. **DMG Creation**: Use `scripts/release_dmg.sh`
4. **Code Signing**: Sign DMG with Developer ID
5. **Notarization**: Submit to Apple for notarization
6. **Sparkle Signing**: Sign update with `sign_update`
7. **GitHub Release**: Create release and upload DMG
8. **Appcast Update**: Update `docs/appcast.xml`

### Release Validation
Before each release:
1. Run full test suite: `xcodebuild test -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS'`
2. Validate build on clean machine
3. Test auto-update functionality
4. Verify notarization status
5. Test on multiple macOS versions (13.0, 14.0, 15.0)

## Code Style and Conventions

### Swift Style Guide
- **4-space indentation** (no tabs)
- **camelCase** for methods and properties
- **PascalCase** for types and SwiftUI views
- **Trailing commas** for multiline literals
- **final** where inheritance is not required
- **@MainActor** for UI-related code

### SwiftUI Best Practices
- **Prefer value types** for models
- **Colocate previews** with view definitions
- **Break large components** into smaller, reusable views
- **Use @StateObject** for view models
- **Prefer @Environment** for shared dependencies

### File Organization
```
Views/
├── Components/     # Reusable UI components
├── Onboarding/    # First-run experience
└── UI/           # Main application views

Core/
├── AI/           # AI/LLM integration
├── Recording/    # Screen recording logic
└── Thumbnails/   # Image caching
```

## Troubleshooting

### Common Build Issues
- **Code Signing Errors**: Verify certificates in Keychain Access
- **Missing Dependencies**: Use Xcode → File → Add Package Dependencies
- **Xcode Version**: Ensure using Xcode 15+ for macOS 13+ deployment

### Runtime Issues
- **Screen Recording Permission**: Check System Settings → Privacy & Security
- **AI Provider Errors**: Verify API keys and network connectivity
- **Database Issues**: Check GRDB migration logs

### Performance Issues
- **High CPU Usage**: Check screen recording frame rate (should be 1 FPS)
- **Memory Leaks**: Use Instruments → Leaks instrument
- **Slow AI Processing**: Consider switching to Gemini for faster processing

## Contributing Guidelines

### Pull Request Process
1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Make changes with comprehensive tests
4. Ensure all tests pass: `xcodebuild test`
5. Submit pull request with clear description

### Code Review Checklist
- [ ] Tests added for new functionality
- [ ] Documentation updated if needed
- [ ] Analytics events added for user actions
- [ ] Performance impact considered
- [ ] Privacy implications reviewed
- [ ] Error handling implemented
- [ ] UI follows existing design patterns

### Release Readiness
Before merging changes for release:
1. Full test suite passes
2. Manual testing on multiple macOS versions
3. Performance regression testing
4. Security review for sensitive data handling
5. Documentation updates completed