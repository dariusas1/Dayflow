# UserDefaults Keys Documentation

This document catalogs all UserDefaults keys used in the FocusLock/Dayflow app for easy reference and to prevent key conflicts.

## Core Storage Keys

### LLM Configuration
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `llmProviderType` | Data (Codable) | `nil` | Stores the selected LLM provider type | `LLMService.swift` |
| `llmLocalModelId` | String | `nil` | Local LLM model identifier (Ollama/LM Studio) | `OllamaProvider.swift` |
| `llmLocalEngine` | String | `"ollama"` | Which local engine to use (`ollama` or `lmstudio`) | `OllamaProvider.swift` |

### User Preferences
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `GeneralPreferences` | Data (Codable) | `nil` | General app preferences | `UserPreferencesManager.swift` |
| `FocusPreferences` | Data (Codable) | `nil` | Focus session preferences | `UserPreferencesManager.swift` |
| `PrivacyPreferences` | Data (Codable) | `nil` | Privacy settings | `UserPreferencesManager.swift` |
| `AppearancePreferences` | Data (Codable) | `nil` | UI appearance settings | `UserPreferencesManager.swift` |
| `NotificationPreferences` | Data (Codable) | `nil` | Notification settings | `UserPreferencesManager.swift` |
| `AccessibilityPreferences` | Data (Codable) | `nil` | Accessibility options | `UserPreferencesManager.swift` |

### Journal System
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `JournalPreferences` | Data (Codable) | `nil` | Journal template and settings | `DailyJournalGenerator.swift` |
| `JournalUserLearningData` | Data (Codable) | `nil` | AI learning data for personalized journals | `DailyJournalGenerator.swift` |

### Bedtime Enforcement
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `bedtimeEnabled` | Bool | `false` | Whether bedtime enforcement is active | `BedtimeEnforcer.swift` |
| `bedtimeHour` | Int | `22` | Bedtime hour (24-hour format) | `BedtimeEnforcer.swift` |
| `bedtimeMinute` | Int | `0` | Bedtime minute | `BedtimeEnforcer.swift` |
| `bedtimeWarningMinutes` | Int | `15` | Warning time before bedtime | `BedtimeEnforcer.swift` |
| `bedtimeEnforcementMode` | String | `"countdown"` | Enforcement mode (countdown/force_shutdown/gentle_reminder/nuclear) | `BedtimeEnforcer.swift` |
| `bedtimeCanSnooze` | Bool | `true` | Whether snooze is allowed | `BedtimeEnforcer.swift` |
| `bedtimeMaxSnoozes` | Int | `1` | Maximum snooze count | `BedtimeEnforcer.swift` |
| `bedtimeSnoozeDuration` | Int | `10` | Snooze duration in minutes | `BedtimeEnforcer.swift` |
| `nuclearModeLastArmed` | Date | `nil` | Last time Nuclear mode was armed | `BedtimeEnforcer.swift` |
| `nuclearModeConfirmedAt` | Date | `nil` | When Nuclear mode was initially confirmed | `BedtimeEnforcer.swift` |
| `nuclearRequiresDailyArming` | Bool | `true` | Whether Nuclear mode requires daily re-arming | `BedtimeEnforcer.swift` |

### Dynamic Allowlist
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `taskSpecificRules` | Data (Codable) | `nil` | Task-specific app allow/block rules | `DynamicAllowlistManager.swift` |

### Focus Sessions (Legacy)
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `focus_session_history` | Data (Codable) | `nil` | Persisted focus session history | `FocusSessionManager.swift` |

### Onboarding & Feature Flags
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `focusLockOnboardingCompleted` | Bool | `false` | FocusLock onboarding status | `MainView.swift` (AppStorage) |

## Analytics & Privacy

### Analytics Configuration
| Key | Type | Default | Usage | Location |
|-----|------|---------|-------|----------|
| `analytics_opted_in` | Bool | `false` | User opt-in for analytics (PostHog) | `AnalyticsService.swift` |
| `sentry_opted_in` | Bool | `false` | User opt-in for crash reporting (Sentry) | `AppDelegate.swift` |

## Best Practices

### Key Naming Conventions
1. **Feature-Based Prefixes**: Use lowercase prefixes for related keys (e.g., `bedtime*`, `llm*`, `journal*`)
2. **Case Style**: Use camelCase for compound words (e.g., `bedtimeWarningMinutes`)
3. **Descriptive Names**: Keys should be self-documenting (e.g., `nuclearModeLastArmed` not `nmlArmed`)

### Adding New Keys
When adding a new UserDefaults key:
1. Add it to this documentation with type, default, and location
2. Use a unique, descriptive name
3. Consider using a namespace prefix to avoid conflicts
4. Always provide a default value when reading
5. Consider using @AppStorage for SwiftUI views when appropriate

### Data Migration
If changing a key name:
1. Read from old key
2. Write to new key
3. Delete old key
4. Document migration in migration log

## Security Notes

**Never store sensitive data in UserDefaults:**
- ❌ API keys → Use Keychain instead
- ❌ Passwords → Use Keychain instead
- ❌ User tokens → Use Keychain instead
- ✅ User preferences → OK for UserDefaults
- ✅ UI state → OK for UserDefaults
- ✅ Feature flags → OK for UserDefaults

## Testing

When testing features that use UserDefaults:
```swift
// Clear test data in setUp()
let defaults = UserDefaults.standard
defaults.removeObject(forKey: "testKey")

// Or use a separate suite for testing
let testDefaults = UserDefaults(suiteName: "com.dayflow.tests")
```

---

**Last Updated**: 2025-11-08
**Maintainer**: Development Team
**Total Keys Documented**: 28
