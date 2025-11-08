# FocusLock Privacy Policy

**Last Updated:** 2025-11-08

## Overview

FocusLock is designed with a privacy-first philosophy. This document explains what data is collected, how it's processed, and your control over it.

## Core Privacy Principles

### 1. Local-First Architecture
- **All screen recordings stay on your Mac** in `~/Library/Application Support/FocusLock/recordings/`
- **AI analysis can be done entirely locally** using Ollama or LM Studio
- **No cloud dependency** - you can use FocusLock completely offline with local AI models

### 2. Explicit Opt-In for Cloud Services
- **Analytics and crash reporting are OFF by default**
- You must explicitly opt-in during onboarding or in settings
- You can change your preference at any time

### 3. Data Minimization
- Only collect what's necessary for features to work
- Automatic cleanup of recordings after 3 days (configurable)
- No personally identifiable information (PII) in analytics

## Data Storage

### What is Stored Locally

| Data Type | Location | Purpose | Retention |
|-----------|----------|---------|-----------|
| Screen recordings (1 FPS video) | `~/Library/Application Support/FocusLock/recordings/` | Timeline generation, playback | 3 days (auto-cleanup) |
| Timeline cards | `FocusLock/chunks.sqlite` | Activity timeline | Persistent until manual deletion |
| AI analysis results | `FocusLock/chunks.sqlite` | Timeline summaries | Persistent until manual deletion |
| Focus session data | `FocusLock/chunks.sqlite` | Session tracking | Persistent until manual deletion |
| App preferences | `UserDefaults` | Settings | Persistent |
| AI provider keys | macOS Keychain | Secure API key storage | Persistent |

### Data You Can Delete Anytime

1. **Screen Recordings**: Menu Bar → Open Recordings → Delete files
2. **Timeline & Database**: Delete `~/Library/Application Support/FocusLock/` folder
3. **Preferences**: Reset in app settings or delete UserDefaults

## Cloud Services (Opt-In Only)

### 1. AI Providers

#### Google Gemini (Optional, BYO Key)
- **What is sent:** 15-minute video batches for analysis
- **Data use:** Processed to generate timeline cards
- **Privacy notes:**
  - If you enable Cloud Billing on your Gemini API project, Google does NOT use your data for model training
  - See [Gemini API Terms](https://ai.google.dev/gemini-api/terms) for details
  - Logs kept for limited period for abuse monitoring
- **How to avoid:** Use local AI instead (Ollama/LM Studio)

#### Ollama / LM Studio (Local, Private)
- **What is sent:** Nothing - runs entirely on your Mac
- **Privacy:** Complete - no data leaves your device
- **Trade-offs:** May be slower than cloud AI, requires good hardware

#### Custom Backend (Optional)
- **What is sent:** Depends on your backend implementation
- **Privacy:** You control the server and data handling

### 2. Analytics & Crash Reporting (Opt-In Only)

**Default:** OFF - You must explicitly enable

**What we collect (IF opted in):**
- Anonymous usage statistics (which features you use, how often)
- Performance metrics (memory usage, CPU, battery impact)
- Crash logs with stack traces (to fix bugs)
- App version, macOS version, device model
- Anonymous user ID (random UUID)

**What we NEVER collect:**
- ❌ Screen recordings or screenshots
- ❌ Window titles or app names from your screen
- ❌ File paths, URLs, or clipboard content
- ❌ Any personally identifiable information
- ❌ API keys or passwords

**Providers (only if opted in):**
- **PostHog** - Anonymous analytics
- **Sentry** - Crash reporting

**How to disable:**
- Settings → Privacy → Disable "Help improve FocusLock"
- Takes effect immediately

## macOS Permissions

FocusLock requires certain macOS permissions to function:

| Permission | Required | Purpose | Frequency |
|-----------|----------|---------|-----------|
| Screen & System Audio Recording | Yes | Capture your screen at 1 FPS | Continuous when recording |
| Accessibility | Optional | Detect active window/app for task detection | When FocusLock Suite enabled |
| Notifications | Optional | Focus session reminders | On-demand |
| Full Disk Access | No | Not required | Never |

**Reviewing Permissions:**
System Settings → Privacy & Security → Screen & System Audio Recording / Accessibility

## FocusLock Suite Privacy

When using advanced FocusLock features:

### Task Detection
- **What it accesses:** Active window title via Accessibility API, optional OCR on screen content
- **Processing:** All done locally on your Mac
- **Storage:** Task summaries stored in local database, no raw screen content retained
- **Privacy:** You can disable at any time

### App/Website Blocking
- **Soft Block (Default):** Detects app/site, shows overlay - no system modifications
- **Hard Block (Opt-In):** May modify system settings (hosts file) - fully reversible
- **Privacy:** Blocklist stored locally, never shared

### Focus Sessions
- **What is tracked:** Session start/end times, category, interruptions
- **Storage:** Local database only
- **Privacy:** Never shared unless you export

## Data Sharing

**We DO NOT:**
- Sell your data
- Share your data with third parties (except analytics providers IF opted in)
- Use your screen content for any purpose other than local AI analysis

**We DO:**
- Keep all screen recordings local
- Allow you to delete all data at any time
- Provide full transparency about what's collected

## Children's Privacy

FocusLock is not directed at children under 13. We do not knowingly collect data from children.

## Changes to Privacy Policy

We may update this policy. Changes will be reflected in the app and this document with a new "Last Updated" date.

## Contact

Questions about privacy? Open an issue on [GitHub](https://github.com/JerryZLiu/Dayflow/issues) or contact us through the repository.

## Your Rights

You have the right to:
- ✅ Access all your data (it's on your Mac)
- ✅ Delete all your data (delete app folder + uninstall)
- ✅ Opt out of analytics (Settings → Privacy)
- ✅ Export your timeline data (Export feature in app)
- ✅ Use FocusLock completely offline with local AI

## Compliance

- **GDPR/CCPA:** Since all data is local and cloud services are opt-in, users maintain full control
- **Data Portability:** SQLite database can be exported/backed up
- **Right to Deletion:** Simple - delete the app folder

---

**Remember:** FocusLock is open source. You can review all code on GitHub to verify these privacy claims.
