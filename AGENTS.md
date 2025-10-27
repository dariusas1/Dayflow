# Repository Guidelines

## Project Structure & Module Organization
The macOS app lives in `Dayflow/Dayflow`, with SwiftUI features grouped by responsibility: `App` for entry points, `Core` for capture + processing services, `System` for macOS integrations, `Utilities` for shared helpers, and `Views` for composable UI. Data definitions sit in `Models`, assets in `Assets.xcassets`, and analytics copy in `AnalyticsEventDictionary.md`. Tests are split between `Dayflow/DayflowTests` for unit and integration suites and `Dayflow/DayflowUITests` for scenario-driven UI checks. Reference marketing and release assets under `docs/`, and automation scripts (DMG, Sparkle, notarization) under `scripts/`.

## Build, Test, and Development Commands
Open the project in Xcode with `xed Dayflow/Dayflow.xcodeproj`. For command-line builds use `xcodebuild -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -configuration Debug build`. Run all automated tests locally with `xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS'`. Dry-run the release pipeline via `./scripts/release.sh --dry-run` before shipping; it validates version bumps, signing, and Sparkle artifacts.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: four-space indentation, trailing commas for multiline literals, `camelCase` for methods/properties, and `PascalCase` for types and SwiftUI views. Keep SwiftUI views declarative and break large components into composable subviews under `Views/`. Use `final` where inheritance is not required, favor value types for models, and colocate previews under the corresponding view file. When touching assets or localized strings, keep naming consistent with existing suffixes (`Timeline`, `Capture`, `Onboarding`).

## Testing Guidelines
Dayflow employs `XCTest` with feature-focused suites (e.g., `FocusLockIntegrationTests`). Name tests with behavior-first verbs (`testDisplaysTimelineAfterCapture`). Write regression coverage for new services in `DayflowTests`, keeping UI assertions in `DayflowUITests`. Integration tests may rely on sample recordings; avoid adding large binaries—reference fixtures in `docs/` where possible. Run the full `xcodebuild test` command before opening a PR, and note any skipped tests with justification.

## Commit & Pull Request Guidelines
Commit messages follow a `<scope>: <action>` prefix (`ui: clarify provider setup`, `core: migrate storage`). Group related file changes per commit and avoid mixing release automation with feature work. For PRs, include: a concise summary, linked GitHub issues (if any), screenshots or screen recordings for UI changes, and explicit testing notes (commands executed, environments). Tag regressions or risky migrations so reviewers can prioritize validation steps.

## Release & Configuration Tips
Environment secrets (Gemini/Sentry/PostHog) are injected at release time—never commit real values. When working on release automation, copy `scripts/release.env.example` to `scripts/release.env` and keep it out of version control. DMG signing relies on local Keychain certificates; see comments in `release.sh` for the expected setup. Before merging release-related changes, confirm `docs/appcast.xml` updates and Sparkle signatures with the dry-run workflow.
