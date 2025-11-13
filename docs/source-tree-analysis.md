# Source Tree Analysis - FocusLock

## Project Overview

**Repository Type:** Monolith  
**Project Type:** Desktop macOS Application  
**Primary Language:** Swift  
**Framework:** SwiftUI  
**Architecture Pattern:** MVVM with Component-Based UI  

## Annotated Source Tree

```
FocusLock/
├── Dayflow/                           # Main application bundle (Part: focuslock)
│   ├── Dayflow/                       # Primary source code directory
│   │   ├── App/                       # Application entry points and lifecycle
│   │   │   ├── AppDeepLinkRouter.swift    # Deep link URL routing handler
│   │   │   ├── AppDelegate.swift          # macOS app delegate (window management, menu bar)
│   │   │   ├── AppState.swift             # Global application state management
│   │   │   ├── DayflowApp.swift           # Main SwiftUI app entry point
│   │   │   └── InactivityMonitor.swift    # User activity tracking for auto-pause
│   │   ├── Core/                      # Business logic and services layer
│   │   │   ├── AI/                     # AI/LLM integration services
│   │   │   │   ├── DayflowBackendProvider.swift  # Custom backend API integration
│   │   │   │   ├── GeminiDirectProvider.swift     # Google Gemini API client
│   │   │   │   ├── GeminiModelPreference.swift    # User's Gemini model settings
│   │   │   │   ├── GeminiPromptPreferences.swift  # Gemini prompt customization
│   │   │   │   ├── LLMLogger.swift                # LLM request/response logging
│   │   │   │   ├── LLMProvider.swift              # Abstract LLM provider interface
│   │   │   │   ├── LLMService.swift               # LLM service orchestration
│   │   │   │   ├── OllamaPromptPreferences.swift   # Ollama prompt settings
│   │   │   │   └── OllamaProvider.swift           # Local Ollama server integration
│   │   │   ├── Recording/                # Screen recording and capture services
│   │   │   │   ├── ActiveDisplayTracker.swift     # Multi-display tracking
│   │   │   │   ├── ScreenRecorder.swift           # Core screen recording engine
│   │   │   │   ├── StoragePreferences.swift       # Recording storage settings
│   │   │   │   └── TimelapseStorageManager.swift  # Timelapse file management
│   │   │   └── Thumbnails/              # Thumbnail generation and caching
│   │   │       └── ThumbnailCache.swift           # Efficient thumbnail caching system
│   │   ├── Views/                     # SwiftUI user interface components
│   │   │   └── Onboarding/            # First-run user experience flow
│   │   │       ├── APIKeyInputView.swift           # API key input interface
│   │   │       ├── FeatureOnboardingView.swift     # Feature introduction screens
│   │   │       ├── FocusLockOnboardingFlow.swift   # Main onboarding coordinator
│   │   │       ├── HowItWorksCard.swift            # Feature explanation cards
│   │   │       ├── HowItWorksView.swift            # How-it-works tutorial
│   │   │       ├── LLMProviderSetupView.swift      # LLM provider configuration
│   │   │       ├── OnboardingFlow.swift            # Onboarding state management
│   │   │       ├── OnboardingLLMSelectionView.swift # LLM provider selection
│   │   │       ├── PermissionExplanationDialog.swift # macOS permission explanations
│   │   │       ├── PrivacyConsentView.swift         # Privacy policy consent
│   │   │       ├── ScreenRecordingPermissionView.swift # Screen recording permission
│   │   │       ├── SetupContinueButton.swift       # Onboarding navigation
│   │   │       ├── SetupSidebarView.swift          # Setup sidebar interface
│   │   │       ├── TerminalCommandView.swift       # Terminal command display
│   │   │       ├── TestConnectionView.swift         # LLM connection testing
│   │   │       └── VideoLaunchView.swift            # App launch video
│   │   ├── Assets.xcassets/           # Application assets and icons
│   │   │   └── IconBackground.imageset/ # App icon backgrounds
│   │   ├── Preview Content/           # Xcode preview assets
│   │   │   └── Preview Assets.xcassets/ # Preview-specific assets
│   │   ├── AnalyticsEventDictionary.md # Analytics event definitions
│   │   └── Info.plist                  # App metadata and permissions
│   └── DayflowTests/                  # Unit and integration test suite
│       ├── AIProviderTests.swift               # LLM provider integration tests
│       ├── ErrorScenarioTests.swift            # Error handling validation
│       ├── FocusLockCompatibilityTests.swift   # macOS compatibility tests
│       ├── FocusLockIntegrationTests.swift      # End-to-end integration tests
│       ├── FocusLockPerformanceValidationTests.swift # Performance benchmarks
│       ├── FocusLockSystemTests.swift          # System-level integration tests
│       ├── FocusLockUITests.swift              # UI automation tests
│       ├── RecordingPipelineEdgeCaseTests.swift # Recording edge cases
│       └── TimeParsingTests.swift              # Time parsing utilities tests
├── docs/                              # Project documentation and analysis
│   ├── assets/                        # Documentation assets
│   │   └── dmg-background.png            # DMG installer background
│   ├── images/                        # Documentation images and previews
│   │   ├── DashboardPreview.png          # Main dashboard screenshot
│   │   ├── JournalPreview.png             # Journal view screenshot
│   │   ├── README.md                      # Image inventory
│   │   ├── dayflow_header.png             # Project header image
│   │   └── hero_animation_1080p.gif       # Hero animation demo
│   ├── .nojekyll                        # GitHub Pages disable flag
│   ├── BETA_LAUNCH_ANALYSIS_REPORT.md   # Beta launch analysis
│   ├── BETA_READINESS_ANALYSIS_INTEGRATION.md # Integration readiness
│   ├── BETA_READINESS_ANALYSIS_PERFORMANCE.md # Performance readiness
│   ├── CRASH_FIX_SUMMARY.md             # Crash fix documentation
│   ├── CRASH_FIX_TESTING.md             # Crash fix testing
│   ├── PRIVACY.md                       # Privacy policy documentation
│   ├── SPARC_Analysis_Report.md         # SPARC framework analysis
│   ├── appcast.xml                      # Sparkle update feed
│   ├── asset-inventory_focuslock.md     # Asset inventory documentation
│   ├── bmm-workflow-status.yaml         # BMAD workflow status
│   ├── build-baseline-2025-10-27.md     # Build performance baseline
│   ├── deployment-configuration_focuslock.md # Deployment configuration
│   ├── errors.md                        # Error handling documentation
│   ├── existing-documentation-inventory.md # Documentation inventory
│   ├── formatted_prompt.txt             # AI prompt templates
│   ├── project-scan-report.json         # Project scan state (this file)
│   ├── project-structure-analysis.md    # Project structure analysis
│   ├── state-management-patterns_focuslock.md # State management patterns
│   ├── state-management.md               # State management overview
│   ├── technology-stack.md              # Technology stack documentation
│   └── ui-component-inventory_focuslock.md # UI component inventory
├── scripts/                           # Build and deployment automation
│   ├── build_validation.sh             # Build validation script
│   ├── ci.sh                          # Continuous integration script
│   ├── clean_derived_data.sh          # Xcode cleanup script
│   ├── make_appcast.sh                # Sparkle appcast generation
│   ├── release.env.example            # Release environment template
│   ├── release.sh                     # Release automation script
│   ├── release_dmg.sh                 # DMG creation script
│   ├── sparkle_sign_from_keychain.sh  # Sparkle signing script
│   └── update_appcast.sh              # Appcast update script
├── .gitignore                         # Git ignore patterns
├── .roomodes                          # Roomode AI assistant configuration
├── AGENTS.md                          # AI agent documentation
├── CODE_REVIEW_RESPONSE.md            # Code review responses
├── CRITICAL_FIXES_DEADLOCK 2.md       # Deadlock fix documentation
├── FINAL_RESOLUTION_ALL_ISSUES_FIXED.md # Issue resolution summary
├── LAUNCH_DECISION.md                 # Launch decision documentation
├── MISSION_COMPLETION_REPORT.md       # Project completion report
├── README.md                          # Main project README
├── SECOND_BRAIN_IMPLEMENTATION.md    # Second brain AI implementation
├── SINGLETON_DATABASE_CRASH_FIXES.md # Database crash fixes
├── TECH_DEBT.md                       # Technical debt tracking
└── USERDEFAULTS_KEYS.md               # UserDefaults key documentation
```

## Critical Directories Analysis

### Core Application Structure (`Dayflow/Dayflow/`)

**App/** - Application lifecycle and global state management
- **Entry Point:** `DayflowApp.swift` (SwiftUI app entry)
- **Key Integration:** `AppDelegate.swift` (macOS-specific integrations)
- **State Management:** `AppState.swift` (global application state)

**Core/** - Business logic and service layer
- **AI Integration:** Complete LLM provider abstraction supporting multiple backends
- **Recording Engine:** Screen capture with multi-display support
- **Storage Management:** Efficient thumbnail caching and timelapse storage

**Views/Onboarding/** - First-run user experience
- **Comprehensive Flow:** Permission handling, LLM setup, feature introduction
- **Privacy First:** Explicit consent and permission explanations
- **Provider Choice:** Support for multiple LLM providers (Gemini, Ollama, custom)

### Testing Infrastructure (`Dayflow/DayflowTests/`)

Comprehensive test coverage including:
- **Integration Tests:** End-to-end workflow validation
- **Performance Tests:** Benchmarking and performance regression detection
- **UI Tests:** Automated user interface testing
- **Edge Case Tests:** Recording pipeline error scenarios

### Documentation (`docs/`)

Rich documentation ecosystem including:
- **Technical Documentation:** Architecture, state management, deployment
- **Analysis Reports:** Beta readiness, performance analysis, crash fixes
- **Asset Management:** Complete inventory of project assets
- **Automation:** Build and release scripts with full documentation

### Build & Deployment (`scripts/`)

Professional-grade automation:
- **CI/CD Integration:** Continuous integration and deployment
- **Release Management:** Automated DMG creation, code signing, Sparkle updates
- **Validation:** Build validation and performance baseline tracking

## Integration Points

### macOS System Integration
- **Screen Recording:** Uses native ScreenCaptureKit for efficient capture
- **Permissions:** Proper macOS permission handling for screen recording and file access
- **App Distribution:** Sparkle framework for automatic updates
- **Code Signing:** Properly signed for distribution outside App Store

### AI/LLM Integration
- **Provider Abstraction:** Pluggable LLM provider architecture
- **Local & Cloud:** Support for both local (Ollama) and cloud (Gemini) providers
- **Fallback Strategy:** Multiple provider options for reliability
- **Logging:** Comprehensive LLM interaction logging for debugging

### Data Persistence
- **GRDB Integration:** SQLite database with type-safe Swift interface
- **Thumbnail Caching:** Efficient image caching for performance
- **Storage Management:** Configurable storage with cleanup strategies

## Entry Points

**Primary Entry Point:** `Dayflow/Dayflow/App/DayflowApp.swift`
- Main SwiftUI application entry point
- Configures global app state and dependencies

**macOS Integration:** `Dayflow/Dayflow/App/AppDelegate.swift`
- Handles macOS-specific app lifecycle events
- Manages window creation and menu bar integration

**Testing Entry Points:** `Dayflow/DayflowTests/`
- Comprehensive test suite covering all major components
- Performance validation and integration testing

## Key File Locations

- **Main App Configuration:** `Dayflow/Dayflow/Info.plist`
- **Analytics Events:** `Dayflow/Dayflow/AnalyticsEventDictionary.md`
- **Build Configuration:** `Dayflow.xcodeproj/` (Xcode project)
- **Release Automation:** `scripts/release.sh`
- **Documentation Index:** `docs/` (comprehensive documentation)

## Architecture Highlights

1. **MVVM Pattern:** Clear separation between Views, ViewModels, and Models
2. **Component-Based UI:** Reusable SwiftUI components in Views/ hierarchy
3. **Service Layer:** Core/ contains business logic separated from UI
4. **Provider Pattern:** Pluggable AI providers with common interface
5. **Comprehensive Testing:** Full test coverage with performance validation
6. **Professional Automation:** Complete build, test, and release pipeline