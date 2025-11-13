# FocusLock Repository Documentation

**Project Name:** FocusLock (codename: Dayflow)  
**Platform:** macOS 13+  
**Language:** Swift (SwiftUI)  
**License:** MIT  
**Repository:** https://github.com/JerryZLiu/Dayflow  
**Distribution:** macOS app via DMG, Homebrew, and auto-updates (Sparkle)

---

## 📋 Overview

FocusLock is a native macOS app that automatically records your screen at 1 FPS, analyzes activity every 15 minutes with AI, and generates a timeline of your day. It's privacy-first by design: you choose your AI provider (Gemini or local models like Ollama/LM Studio), control all data locally, and can keep everything on-device.

**Key Features:**
- Automatic timeline generation with AI summaries
- Screen recording at 1 FPS with minimal resource usage (~100MB RAM, <1% CPU)
- 15-minute analysis intervals for near-real-time updates
- Distraction highlighting
- Dashboard with customizable tiles
- Daily journal with mood/productivity tracking
- Jarvis AI assistant for coaching and insights
- Smart planning with auto-extracted todos
- Focus sessions with app/website blocking
- Bedtime enforcement for healthy sleep habits

---

## 🏗️ Architecture Overview

### Core Systems

1. **Recording Pipeline** (`Core/Recording/`)
   - Screen capture at 1 FPS in 15-second chunks
   - Local storage with automatic cleanup (3-day retention)
   - Video chunk indexing and metadata management

2. **AI Analysis Pipeline** (`Core/AI/`)
   - Multi-provider support (Gemini, Ollama, LM Studio)
   - Two-stage processing: frame analysis → timeline generation
   - Local processing with 30+ LLM calls vs cloud processing with 2 LLM calls

3. **Timeline & Analytics** (`Core/Analysis/`)
   - Timeline card generation from AI outputs
   - Activity categorization (Work, Personal, Distractions)
   - Time distribution and focus metrics

4. **FocusLock Features** (`Core/FocusLock/`)
   - Journal engine with daily summaries
   - Smart todo suggestion from emails/code
   - Focus session management with interruption tracking
   - Bedtime enforcement with configurable modes
   - Memory store for context-aware suggestions

5. **System Integration** (`System/`)
   - Analytics (PostHog) - opt-in by default
   - Crash reporting (Sentry) - opt-in by default
   - Auto-updates (Sparkle) with daily checks
   - Menu bar integration
   - Accessibility API integration (with privacy safeguards)

### Data Models

- **FocusLockModels.swift** (171 KB) - Core data structures
- **AnalysisModels.swift** - AI analysis outputs
- **PerformanceModels.swift** - Performance metrics
- **TimelineCategory.swift** - Activity categorization

### Storage

- **SQLite Database** (`chunks.sqlite`)
  - Recording metadata
  - Timeline cards
  - Focus sessions
  - Todo history

- **File System** (`~/Library/Application Support/Dayflow/`)
  - Video chunks (`recordings/` folder)
  - Local configuration
  - Export artifacts

---

## 📁 Directory Structure

```
FocusLock/
├── Dayflow/
│   ├── Dayflow/                          # Main app source
│   │   ├── App/                          # App lifecycle & configuration
│   │   │   ├── AppDelegate.swift         # Initialization, analytics setup
│   │   │   ├── DayflowApp.swift          # SwiftUI app entry point
│   │   │   ├── AppState.swift            # Global app state
│   │   │   ├── AppDeepLinkRouter.swift   # URL scheme handling
│   │   │   └── InactivityMonitor.swift   # Background inactivity detection
│   │   │
│   │   ├── Core/                         # Core business logic
│   │   │   ├── AI/                       # AI providers (Gemini, Local)
│   │   │   ├── Analysis/                 # Timeline generation, categorization
│   │   │   ├── Recording/                # Screen capture, chunk management
│   │   │   ├── FocusLock/                # Focus features (journal, todos, bedtime)
│   │   │   ├── Net/                      # Network operations
│   │   │   ├── Security/                 # Keychain, encryption
│   │   │   └── Thumbnails/               # Video thumbnail generation
│   │   │
│   │   ├── Models/                       # Data structures
│   │   │   ├── FocusLockModels.swift     # Core models
│   │   │   ├── AnalysisModels.swift      # AI outputs
│   │   │   ├── PerformanceModels.swift   # Metrics
│   │   │   └── TimelineCategory.swift    # Activity categories
│   │   │
│   │   ├── System/                       # System integration
│   │   │   ├── AnalyticsService.swift    # PostHog (opt-in)
│   │   │   ├── SentryHelper.swift        # Error reporting (opt-in)
│   │   │   ├── UpdaterManager.swift      # Sparkle auto-updates
│   │   │   ├── StatusBarController.swift # Menu bar UI
│   │   │   ├── HardwareInfo.swift        # Device info
│   │   │   └── SilentUserDriver.swift    # Audio recording setup
│   │   │
│   │   ├── Utilities/                    # Helper functions
│   │   │   ├── GeminiAPIHelper.swift     # Gemini API wrapper
│   │   │   ├── DebugLogFormatter.swift   # Logging utilities
│   │   │   ├── Color+Luminance.swift     # Color calculations
│   │   │   ├── StoragePathMigrator.swift # Data location migration
│   │   │   └── UserDefaultsMigrator.swift # Settings migration
│   │   │
│   │   ├── Views/                        # SwiftUI UI
│   │   │   ├── UI/                       # Main interface
│   │   │   │   ├── TimelineView.swift
│   │   │   │   ├── DashboardView.swift
│   │   │   │   ├── JournalView.swift
│   │   │   │   ├── JarvisChatView.swift
│   │   │   │   ├── FocusLockView.swift
│   │   │   │   ├── SettingsView.swift
│   │   │   │   ├── BedtimeSettingsView.swift
│   │   │   │   ├── PlannerView.swift
│   │   │   │   ├── InsightsView.swift
│   │   │   │   └── [30+ more UI views]
│   │   │   │
│   │   │   ├── Components/               # Reusable components
│   │   │   │   ├── UnifiedCard.swift
│   │   │   │   ├── UnifiedTextField.swift
│   │   │   │   └── [additional components]
│   │   │   │
│   │   │   └── Onboarding/               # First-run experience
│   │   │       ├── OnboardingFlow.swift
│   │   │       ├── PrivacyConsentView.swift
│   │   │       ├── LLMProviderSetupView.swift
│   │   │       └── [onboarding views]
│   │   │
│   │   ├── Assets.xcassets/              # Images, colors, app icon
│   │   ├── Fonts/                        # Custom fonts
│   │   │   ├── Nunito-VariableFont_wght.ttf
│   │   │   ├── InstrumentSerif-Regular.ttf
│   │   │   └── Figtree-VariableFont_wght.ttf
│   │   │
│   │   ├── Info.plist                    # App configuration
│   │   ├── Dayflow.entitlements          # Capabilities (screen recording, etc.)
│   │   └── AnalyticsEventDictionary.md   # Analytics event catalog
│   │
│   ├── DayflowTests/                     # Unit & integration tests
│   │   └── [11 test suites]
│   │
│   ├── DayflowUITests/                   # UI tests
│   │   └── [scenario-driven tests]
│   │
│   └── Dayflow.xcodeproj                 # Xcode project
│
├── scripts/                              # Build & release automation
│   ├── ci.sh                             # CI/CD orchestration
│   ├── build_validation.sh               # Build verification
│   ├── release.sh                        # Release workflow
│   ├── release_dmg.sh                    # DMG creation
│   ├── make_appcast.sh                   # Sparkle appcast generation
│   ├── clean_derived_data.sh             # Build cleanup
│   ├── sparkle_sign_from_keychain.sh     # Update signing
│   └── release.env.example               # Environment template
│
├── docs/                                 # Documentation & assets
│   ├── appcast.xml                       # Sparkle update feed
│   ├── PRIVACY.md                        # Privacy policy
│   ├── images/                           # Marketing/documentation images
│   ├── assets/                           # Additional assets
│   └── [analysis reports, screenshots]
│
├── README.md                             # User-facing documentation
├── CHANGELOG.md                          # Version history
├── LICENSE                               # MIT license
├── Makefile                              # Development commands
└── .gitignore                            # Git ignore rules
```

---

## 🛠️ Technology Stack

### Core Technologies
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (native macOS)
- **Database:** SQLite (via GRDB)
- **Package Manager:** Swift Package Manager

### Key Dependencies
- **Sparkle** - Auto-updates with Appcast
- **PostHog** - Analytics (opt-in)
- **Sentry** - Crash reporting (opt-in)
- **GRDB** - SQLite abstraction layer
- **Google Gemini API** - Cloud AI analysis
- **Ollama / LM Studio** - Local AI models

### Build & Testing
- **Build System:** Xcode 15+ (xcodebuild)
- **Testing:** XCTest
- **Linting:** SwiftLint
- **Coverage:** Swift code coverage tools

---

## 🚀 Development Setup

### Prerequisites
- **macOS** 13.0+
- **Xcode** 15.0+
- **Swift** 5.9+
- **Gemini API Key** (optional, if using cloud AI): https://ai.google.dev/gemini-api/docs/api-key
- **Local AI** (optional): Ollama or LM Studio

### Quick Start (Developers)

```bash
# Clone repository
git clone https://github.com/JerryZLiu/Dayflow.git
cd FocusLock

# Open in Xcode
open Dayflow/Dayflow.xcodeproj

# Configure for Gemini (if using cloud AI)
# In Xcode: Select Dayflow target → Run scheme → Edit scheme
# Under Arguments tab → Environment Variables
# Add: GEMINI_API_KEY = <your-key>

# Build
xcodebuild -project Dayflow/Dayflow.xcodeproj -scheme Dayflow build

# Test
xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow
```

### Install Dependencies
```bash
make deps  # Installs SwiftLint, xcbeautify via Homebrew
```

---

## 📦 Build & Testing Commands

All commands are available via `Makefile` or direct `scripts/ci.sh`:

### Build Commands
```bash
make build              # Build the project
xcodebuild -project Dayflow/Dayflow.xcodeproj -scheme Dayflow build
```

### Test Commands
```bash
make test               # Run all unit & integration tests
make coverage          # Generate code coverage report
make sanitizers        # Run tests with memory/thread sanitizers
```

### Code Quality
```bash
make lint              # Run SwiftLint
```

### Complete Validation
```bash
make beta-check        # Full beta validation (lint + build + test)
make all               # Comprehensive check (all of the above)
```

### Release Commands
```bash
./scripts/release.sh --dry-run    # Validate release workflow
./scripts/release_dmg.sh          # Create DMG distribution
./scripts/make_appcast.sh         # Generate Sparkle appcast
```

### Cleanup
```bash
make clean             # Remove build artifacts
./scripts/clean_derived_data.sh  # Deep clean derived data
```

---

## 🏛️ Code Organization & Conventions

### Swift Style Guide
- **Indentation:** 4 spaces
- **Naming:**
  - `camelCase` for variables, functions, properties
  - `PascalCase` for types, protocols, enums
  - `UPPER_SNAKE_CASE` for constants
- **SwiftUI Views:** Mark with `@ViewBuilder` or `@Main`
- **Value Types:** Prefer `struct` over `class` for models
- **Access Control:** Explicit `private`, `internal`, `public` modifiers

### File Organization
- Views colocate their SwiftUI previews below the main view definition
- Models grouped by domain (Analysis, FocusLock, Performance)
- Core logic separated from UI
- Components under `Views/Components/` for reuse

### Testing Conventions
- Test files in `DayflowTests/` (unit & integration)
- UI tests in `DayflowUITests/`
- Test names follow `testBehavior_WhenCondition_ExpectedResult` pattern
- Each test suite focuses on a specific module/feature

---

## 🔐 Privacy & Security

### Privacy Principles
1. **Local First** - Recordings stay on your machine by default
2. **Opt-In Analytics** - PostHog and Sentry are disabled by default
3. **Transparent** - Open source, fully auditable
4. **User Control** - Choose AI provider, configure retention, delete data anytime

### Data Handling
- **Screen Recordings:** Stored in `~/Library/Application Support/Dayflow/recordings/`
- **Timeline Cards:** SQLite database (`chunks.sqlite`)
- **API Keys:** Stored in macOS Keychain
- **Analytics:** Only sent if user explicitly opts in
- **Retention:** Automatic deletion of recordings after 3 days

### Permissions
- **Screen & System Audio Recording** - Required for capturing screen
- **System Settings → Privacy & Security → Screen & System Audio Recording** - Where to grant

### AI Provider Privacy
- **Gemini (Cloud):** Requires opt-in and Google API key. Data handling depends on Cloud Billing activation.
- **Local (Ollama/LM Studio):** Processing stays on-device. Fully offline capable once models are downloaded.

---

## 🎯 Feature Flags

Feature flags allow toggling advanced features. Currently all major features are **enabled by default** for the beta release.

### Available Features
- `timelineGeneration` - Timeline cards from AI
- `dailyJournal` - Daily summaries and mood tracking
- `jarvisChat` - AI coaching assistant
- `smartPlanning` - Auto-generated todos
- `focusSessions` - Timed focus blocks with blocking
- `bedtimeEnforcer` - Sleep time enforcement
- `taskDetection` - OCR-based task extraction
- `emergencyBreak` - Emergency distraction breaker
- `productivityCharts` - Analytics dashboards
- `performanceAnalytics` - Real-time metrics

### Managing Features
```swift
// Check if enabled
if FeatureFlagManager.shared.isEnabled(.jarvisChat) {
    // Show feature
}

// Set enabled/disabled
FeatureFlagManager.shared.setEnabled(.focusSessions, enabled: true)
```

---

## 🗂️ Key Files Reference

### Critical Configuration
- **App/AppDelegate.swift** - Initialization, analytics/crash reporting setup
- **System/AnalyticsService.swift** - PostHog integration (opt-in)
- **Utilities/SentryHelper.swift** - Crash reporting (opt-in)
- **Info.plist** - App metadata, capabilities, Sparkle config
- **Dayflow.entitlements** - macOS capabilities (screen recording, etc.)

### Core Features
- **Core/Recording/** - Screen capture pipeline
- **Core/AI/** - Provider abstraction (Gemini, Local)
- **Core/Analysis/** - Timeline generation
- **Core/FocusLock/** - Journal, todos, bedtime enforcement
- **System/UpdaterManager.swift** - Sparkle auto-updates

### UI Entry Points
- **Views/UI/MainView.swift** - Primary app interface
- **Views/UI/TimelineView.swift** - Timeline display
- **Views/UI/DashboardView.swift** - Custom dashboard
- **Views/UI/JournalView.swift** - Daily journal
- **Views/UI/SettingsView.swift** - Configuration

### Models
- **Models/FocusLockModels.swift** - Core data structures (171 KB)
- **Models/TimelineCategory.swift** - Activity categories

---

## 🧪 Testing Strategy

### Test Coverage
- **11 test suites** covering:
  - AI provider selection and error handling
  - FocusLock integration (journal, todos, bedtime)
  - Recording pipeline edge cases
  - Time parsing utilities
  - UI launch and navigation

### Running Tests
```bash
# All tests
xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS'

# Specific test class
xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -only-testing:DayflowTests/FocusLockIntegrationTests

# With coverage
xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -enableCodeCoverage YES
```

### Test Files Location
- `Dayflow/DayflowTests/` - Unit and integration tests
- `Dayflow/DayflowUITests/` - Scenario-driven UI tests

---

## 📝 Logging & Debugging

### Debug Tools Available
- **Menu Bar Icon** - Access debug menu from Dayflow icon
- **View Recordings** - "Open Recordings..." option to browse stored chunks
- **Debug Logging** - Enhanced logging via `DebugLogFormatter.swift`
- **Console Output** - Clear indication of analytics/crash reporting status

### Analytics Events
See `AnalyticsEventDictionary.md` for complete list of tracked events.

### Feature Flags in Debug
When running with DEBUG configuration, failed singleton initialization shows `fatalError()` for visibility. In RELEASE, features degrade gracefully.

---

## 🚢 Distribution & Updates

### Sparkle Auto-Updates
- **Update Check:** Daily by default
- **Download:** Automatic background download
- **Installation:** Manual or automatic on quit
- **Configuration:** `Info.plist` with Sparkle settings
- **Public Key:** Included for signature verification

### Signed Releases
- **Code Signing:** Requires Apple Developer certificate
- **Notarization:** Required for macOS 10.15+
- **DMG Creation:** Automated via `scripts/release_dmg.sh`
- **Appcast:** Generated via `scripts/make_appcast.sh`

### Distribution Channels
- **GitHub Releases** - Direct download of `Dayflow.dmg`
- **Homebrew** - `brew install --cask dayflow`
- **Website** - Future: focuslock.so

---

## 🐛 Known Issues

### Medium Priority
1. **Session Persistence** (`Core/FocusLock/FocusSessionManager.swift:322`)
   - Database loading of past sessions not fully wired
   - Sessions still work but don't restore across relaunches

### Low Priority
2. **Interruption Logging** (`Views/UI/FocusSessionWidget.swift:124`)
   - Interruption button exists but doesn't log to database
   - Workaround: Manually track interruptions in journal

3. **App Intents**
   - Deep links work (`dayflow://start-recording`)
   - Native Shortcuts integration not yet implemented
   - Enhancement: Plan for Shortcuts app integration

4. **Accessibility**
   - VoiceOver labels present
   - Keyboard navigation needs comprehensive testing
   - TODO: Full accessibility audit

### Non-Blocking
- Hard Block feature exists but stays behind feature flag (default OFF)
- Advanced metrics dashboard has partial implementation

---

## 📋 Testing Checklist for Manual QA

### Before Release
- [ ] Test on macOS 13, 14, 15+
- [ ] Verify screen recording capture works
- [ ] Test Gemini API (if cloud mode)
- [ ] Test Ollama/LM Studio (if local mode)
- [ ] Verify timeline generation
- [ ] Test all UI views render correctly
- [ ] Validate auto-update mechanism
- [ ] Check memory usage remains <200MB
- [ ] Test with Sanitizers: `make sanitizers`
- [ ] Verify privacy: Check no analytics unless opted in

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| **README.md** | User-facing quickstart and feature overview |
| **CHANGELOG.md** | Version history and migration guides |
| **docs/PRIVACY.md** | Comprehensive privacy policy |
| **BETA_READINESS.md** | Beta audit report and compliance checklist |
| **Models/AnalyticsEventDictionary.md** | Analytics event catalog |
| **TECH_DEBT.md** | Known technical debt and improvements |
| **repo.md** | This file - developer reference |

---

## 🤝 Contributing

### Pull Request Process
1. Fork the repository
2. Create a feature branch
3. Make changes following code conventions
4. Add/update tests as needed
5. Run `make all` to validate
6. Open PR with description and testing notes

### Commit Message Format
```
<scope>: <action>

Examples:
- ui: clarify provider setup
- core: migrate storage to new location
- fix: prevent crash on empty timeline
```

### Areas for Contribution
- **Documentation** - Clarify user guides, tutorials
- **Accessibility** - VoiceOver support, keyboard navigation
- **Testing** - Expand test coverage, edge cases
- **Localization** - Translate UI and strings
- **Features** - Implement roadmap items

---

## 🗺️ Roadmap

### Active Development
- [x] Timeline generation with AI
- [x] Daily journal system
- [x] Jarvis AI assistant
- [x] Smart todo suggestions
- [x] Focus sessions
- [x] Bedtime enforcement
- [x] Dashboard with custom tiles
- [x] Local AI support (Ollama/LM Studio)

### In Progress
- [ ] Session persistence across relaunches
- [ ] Interruption logging integration
- [ ] Shortcuts app integration (App Intents)
- [ ] Full accessibility audit

### Planned
- [ ] Localization (multi-language support)
- [ ] Fine-tuned local VLM for improved summaries
- [ ] Advanced trend analysis
- [ ] Calendar integration
- [ ] App Store release
- [ ] Advanced export formats (PDF, Excel, etc.)

---

## 📞 Support & Resources

### Official Links
- **GitHub Issues:** https://github.com/JerryZLiu/Dayflow/issues
- **GitHub Discussions:** https://github.com/JerryZLiu/Dayflow/discussions
- **Privacy Policy:** `docs/PRIVACY.md`

### API Documentation
- **Google Gemini API:** https://ai.google.dev/gemini-api/docs
- **Ollama:** https://ollama.com/
- **LM Studio:** https://lmstudio.ai/

### Related Projects
- **Sparkle:** https://github.com/sparkle-project/Sparkle
- **GRDB:** https://github.com/groue/GRDB.swift
- **PostHog:** https://posthog.com/

---

## 📄 License

Licensed under the **MIT License**. See `LICENSE` file for full text.

Software is provided "AS IS", without warranty of any kind.

---

**Last Updated:** November 9, 2025  
**Repository:** https://github.com/JerryZLiu/Dayflow
