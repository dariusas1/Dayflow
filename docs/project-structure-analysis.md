# Project Structure Analysis

## Project Classification

**Repository Type:** Monolith (single cohesive macOS application)
**Project Type:** Desktop (macOS SwiftUI application)
**Primary Language:** Swift
**Framework:** SwiftUI + AppKit
**Architecture Pattern:** MVVM with SwiftUI

## Project Parts

### Single Part: FocusLock (Dayflow)
- **Part ID:** focuslock
- **Root Path:** `/Dayflow/Dayflow/`
- **Project Type:** desktop
- **Technology Stack:** Swift, SwiftUI, GRDB (SQLite), Sparkle (updates), Sentry (analytics), PostHog (analytics)

## Key Technology Detection

From documentation requirements for "desktop" project type:
- ✅ Swift/SwiftUI detected (primary language)
- ✅ Desktop app structure confirmed (macOS .app bundle)
- ✅ Assets and resources present (Assets.xcassets, Fonts/)
- ✅ Configuration files (Info.plist, entitlements)
- ✅ Dependencies managed via Swift Package Manager (GRDB, Sparkle, Sentry, PostHog)

## Directory Structure Analysis

```
FocusLock/
├── Dayflow/                    # Main application source
│   ├── Dayflow/               # Application root
│   │   ├── App/               # Application lifecycle and entry points
│   │   ├── Core/              # Core business logic
│   │   │   ├── AI/            # AI/LLM integration
│   │   │   └── Thumbnails/    # Video thumbnail processing
│   │   ├── System/            # macOS system integrations
│   │   ├── Utilities/         # Shared utilities
│   │   ├── Views/             # SwiftUI views
│   │   │   ├── Components/    # Reusable UI components
│   │   │   ├── Onboarding/    # First-run experience
│   │   │   └── UI/            # Main application views
│   │   ├── Assets.xcassets/   # App assets and icons
│   │   └── Fonts/             # Custom fonts
│   └── Dayflow.xcodeproj/     # Xcode project configuration
├── DayflowTests/              # Unit and integration tests
├── DayflowUITests/            # UI automation tests
├── docs/                      # Documentation and reports
├── scripts/                   # Build and release automation
└── .bmad/                     # BMAD framework configuration
```

## Architecture Pattern Detection

Based on code structure analysis:
- **MVVM Pattern:** SwiftUI views with separate business logic in Core/
- **Component-Based UI:** Reusable components in Views/Components/
- **Service Layer:** Core services for AI, thumbnails, analytics
- **System Integration:** macOS-specific features in System/
- **Configuration Management:** Info.plist, entitlements, build settings