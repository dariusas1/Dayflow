import Foundation
import SwiftUI
import Combine

/// Comprehensive user preferences management system with persistence and privacy controls
class UserPreferencesManager: ObservableObject {
    static let shared = UserPreferencesManager()

    // MARK: - Published Properties
    @Published var generalPreferences: GeneralPreferences
    @Published var focusPreferences: FocusPreferences
    @Published var privacyPreferences: PrivacyPreferences
    @Published var appearancePreferences: AppearancePreferences
    @Published var notificationPreferences: NotificationPreferences
    @Published var accessibilityPreferences: AccessibilityPreferences

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "FocusLockUserPreferences"
    private let privacyConsentKey = "FocusLockPrivacyConsent"
    private let lastSyncKey = "FocusLockLastSync"

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        self.generalPreferences = Self.loadGeneralPreferences()
        self.focusPreferences = Self.loadFocusPreferences()
        self.privacyPreferences = Self.loadPrivacyPreferences()
        self.appearancePreferences = Self.loadAppearancePreferences()
        self.notificationPreferences = Self.loadNotificationPreferences()
        self.accessibilityPreferences = Self.loadAccessibilityPreferences()

        setupAutoSave()
        loadPreferences()
    }

    // MARK: - Public Interface

    func savePreferences() {
        let preferences = UserPreferences(
            general: generalPreferences,
            focus: focusPreferences,
            privacy: privacyPreferences,
            appearance: appearancePreferences,
            notifications: notificationPreferences,
            accessibility: accessibilityPreferences,
            lastUpdated: Date()
        )

        do {
            let data = try JSONEncoder().encode(preferences)
            userDefaults.set(data, forKey: preferencesKey)
            userDefaults.set(Date(), forKey: lastSyncKey)

            // Trigger sync if enabled
            if privacyPreferences.allowDataSync {
                syncPreferencesToCloud(preferences)
            }
        } catch {
            print("Failed to save preferences: \(error)")
        }
    }

    func resetToDefaults() {
        generalPreferences = GeneralPreferences.default
        focusPreferences = FocusPreferences.default
        privacyPreferences = PrivacyPreferences.default
        appearancePreferences = AppearancePreferences.default
        notificationPreferences = NotificationPreferences.default
        accessibilityPreferences = AccessibilityPreferences.default

        savePreferences()
    }

    func exportPreferences() -> URL? {
        let preferences = UserPreferences(
            general: generalPreferences,
            focus: focusPreferences,
            privacy: privacyPreferences,
            appearance: appearancePreferences,
            notifications: notificationPreferences,
            accessibility: accessibilityPreferences,
            lastUpdated: Date()
        )

        do {
            let data = try JSONEncoder().encode(preferences)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsPath.appendingPathComponent("FocusLockPreferences_\(Date().timeIntervalSince1970).json")

            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export preferences: \(error)")
            return nil
        }
    }

    func importPreferences(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let importedPreferences = try JSONDecoder().decode(UserPreferences.self, from: data)

            // Validate imported preferences
            guard validateImportedPreferences(importedPreferences) else {
                return false
            }

            // Apply imported preferences
            generalPreferences = importedPreferences.general
            focusPreferences = importedPreferences.focus
            privacyPreferences = importedPreferences.privacy
            appearancePreferences = importedPreferences.appearance
            notificationPreferences = importedPreferences.notifications
            accessibilityPreferences = importedPreferences.accessibility

            savePreferences()
            return true
        } catch {
            print("Failed to import preferences: \(error)")
            return false
        }
    }

    func updatePrivacyConsent(_ consent: PrivacyConsent) {
        privacyPreferences.consent = consent
        savePreferences()

        // If consent is denied, clear any collected data
        if consent == .denied {
            clearCollectedData()
        }
    }

    // MARK: - Private Methods

    private func loadPreferences() {
        guard let data = userDefaults.data(forKey: preferencesKey) else { return }

        do {
            let loadedPreferences = try JSONDecoder().decode(UserPreferences.self, from: data)

            generalPreferences = loadedPreferences.general
            focusPreferences = loadedPreferences.focus
            privacyPreferences = loadedPreferences.privacy
            appearancePreferences = loadedPreferences.appearance
            notificationPreferences = loadedPreferences.notifications
            accessibilityPreferences = loadedPreferences.accessibility
        } catch {
            print("Failed to load preferences: \(error)")
            // Use defaults if loading fails
            resetToDefaults()
        }
    }

    private func setupAutoSave() {
        // Auto-save when any preference changes
        $generalPreferences
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)

        $focusPreferences
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)

        $privacyPreferences
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)

        $appearancePreferences
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)

        $notificationPreferences
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)

        $accessibilityPreferences
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePreferences()
            }
            .store(in: &cancellables)
    }

    private func syncPreferencesToCloud(_ preferences: UserPreferences) {
        // Implementation for cloud sync would go here
        // This would use iCloud, CloudKit, or custom sync service
    }

    private func clearCollectedData() {
        // Clear analytics data, usage history, etc.
        userDefaults.removeObject(forKey: "FocusLockAnalytics")
        userDefaults.removeObject(forKey: "FocusLockUsageHistory")

        // Clear performance monitor history
        if let performanceMonitor = PerformanceMonitor.self as AnyObject? as? NSObject {
            performanceMonitor.perform(NSSelectorFromString("clearHistory"), with: nil)
        }
    }

    private func validateImportedPreferences(_ preferences: UserPreferences) -> Bool {
        // Validate that imported preferences are safe and compatible
        return preferences.general.firstLaunchDate != nil &&
               preferences.focus.defaultSessionDuration > 0 &&
               preferences.focus.defaultSessionDuration <= 8 * 3600 // Max 8 hours
    }

    // MARK: - Static Loading Methods

    private static func loadGeneralPreferences() -> GeneralPreferences {
        guard let data = UserDefaults.standard.data(forKey: "GeneralPreferences"),
              let preferences = try? JSONDecoder().decode(GeneralPreferences.self, from: data) else {
            return GeneralPreferences.default
        }
        return preferences
    }

    private static func loadFocusPreferences() -> FocusPreferences {
        guard let data = UserDefaults.standard.data(forKey: "FocusPreferences"),
              let preferences = try? JSONDecoder().decode(FocusPreferences.self, from: data) else {
            return FocusPreferences.default
        }
        return preferences
    }

    private static func loadPrivacyPreferences() -> PrivacyPreferences {
        guard let data = UserDefaults.standard.data(forKey: "PrivacyPreferences"),
              let preferences = try? JSONDecoder().decode(PrivacyPreferences.self, from: data) else {
            return PrivacyPreferences.default
        }
        return preferences
    }

    private static func loadAppearancePreferences() -> AppearancePreferences {
        guard let data = UserDefaults.standard.data(forKey: "AppearancePreferences"),
              let preferences = try? JSONDecoder().decode(AppearancePreferences.self, from: data) else {
            return AppearancePreferences.default
        }
        return preferences
    }

    private static func loadNotificationPreferences() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: "NotificationPreferences"),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return NotificationPreferences.default
        }
        return preferences
    }

    private static func loadAccessibilityPreferences() -> AccessibilityPreferences {
        guard let data = UserDefaults.standard.data(forKey: "AccessibilityPreferences"),
              let preferences = try? JSONDecoder().decode(AccessibilityPreferences.self, from: data) else {
            return AccessibilityPreferences.default
        }
        return preferences
    }
}

// MARK: - Preference Data Models

struct UserPreferences: Codable {
    let general: GeneralPreferences
    let focus: FocusPreferences
    let privacy: PrivacyPreferences
    let appearance: AppearancePreferences
    let notifications: NotificationPreferences
    let accessibility: AccessibilityPreferences
    let lastUpdated: Date
}

struct GeneralPreferences: Codable {
    let firstLaunchDate: Date
    let totalSessionsCompleted: Int
    let totalFocusTime: TimeInterval
    let preferredLanguage: String
    let autoStartBreaks: Bool
    let showWelcomeScreen: Bool
    let enableHapticFeedback: Bool
    let enableSoundEffects: Bool

    static let `default` = GeneralPreferences(
        firstLaunchDate: Date(),
        totalSessionsCompleted: 0,
        totalFocusTime: 0,
        preferredLanguage: "en",
        autoStartBreaks: true,
        showWelcomeScreen: true,
        enableHapticFeedback: true,
        enableSoundEffects: true
    )
}

struct FocusPreferences: Codable {
    let defaultSessionDuration: TimeInterval
    let defaultBreakDuration: TimeInterval
    let longBreakInterval: Int
    let enableAutoStartSessions: Bool
    let enableBreakReminders: Bool
    let dailyFocusGoal: TimeInterval
    let weeklyFocusGoal: TimeInterval
    let enablePomodoroTechnique: Bool
    let sessionNotifications: Bool
    let breakNotifications: Bool
    let goalAchievementNotifications: Bool

    static let `default` = FocusPreferences(
        defaultSessionDuration: 25 * 60, // 25 minutes
        defaultBreakDuration: 5 * 60,   // 5 minutes
        longBreakInterval: 4,
        enableAutoStartSessions: false,
        enableBreakReminders: true,
        dailyFocusGoal: 4 * 3600, // 4 hours
        weeklyFocusGoal: 20 * 3600, // 20 hours
        enablePomodoroTechnique: true,
        sessionNotifications: true,
        breakNotifications: true,
        goalAchievementNotifications: true
    )
}

struct PrivacyPreferences: Codable {
    var consent: PrivacyConsent
    let allowAnalytics: Bool
    let allowDataSync: Bool
    let shareUsageStatistics: Bool
    let shareCrashReports: Bool
    let retentionPeriod: DataRetentionPeriod
    let anonymizeData: Bool
    let allowPersonalization: Bool

    static let `default` = PrivacyPreferences(
        consent: .pending,
        allowAnalytics: false,
        allowDataSync: false,
        shareUsageStatistics: false,
        shareCrashReports: true,
        retentionPeriod: .thirtyDays,
        anonymizeData: true,
        allowPersonalization: false
    )
}

struct AppearancePreferences: Codable {
    let colorScheme: ColorScheme
    let accentColor: String
    let fontSize: FontSize
    let enableAnimations: Bool
    let reduceMotion: Bool
    let showMenuBarIcon: Bool
    let compactMode: Bool
    let themeVariant: ThemeVariant

    static let `default` = AppearancePreferences(
        colorScheme: .system,
        accentColor: "blue",
        fontSize: .medium,
        enableAnimations: true,
        reduceMotion: false,
        showMenuBarIcon: true,
        compactMode: false,
        themeVariant: .default
    )
}

struct NotificationPreferences: Codable {
    let enableSessionReminders: Bool
    let enableBreakAlerts: Bool
    let enableGoalReminders: Bool
    let enableWeeklyReports: Bool
    let quietHours: QuietHours
    let soundVolume: Double
    let enablePersistentNotifications: Bool
    let enableCriticalAlerts: Bool

    static let `default` = NotificationPreferences(
        enableSessionReminders: true,
        enableBreakAlerts: true,
        enableGoalReminders: true,
        enableWeeklyReports: false,
        quietHours: QuietHours(enabled: false, startTime: "22:00", endTime: "08:00"),
        soundVolume: 0.7,
        enablePersistentNotifications: false,
        enableCriticalAlerts: true
    )
}

struct AccessibilityPreferences: Codable {
    let enableVoiceOver: Bool
    let enableHighContrast: Bool
    let enableLargeText: Bool
    let enableClosedCaptions: Bool
    let screenReaderSupport: Bool
    let keyboardNavigation: Bool
    let reducedTransparency: Bool
    let buttonSize: ButtonSize

    static let `default` = AccessibilityPreferences(
        enableVoiceOver: false,
        enableHighContrast: false,
        enableLargeText: false,
        enableClosedCaptions: true,
        screenReaderSupport: true,
        keyboardNavigation: true,
        reducedTransparency: false,
        buttonSize: .medium
    )
}

// MARK: - Supporting Enums

enum PrivacyConsent: String, Codable, CaseIterable {
    case pending = "pending"
    case granted = "granted"
    case denied = "denied"
    case partial = "partial"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .partial: return "Partial"
        }
    }
}

enum DataRetentionPeriod: String, Codable, CaseIterable {
    case sevenDays = "7_days"
    case thirtyDays = "30_days"
    case ninetyDays = "90_days"
    case oneYear = "1_year"
    case forever = "forever"

    var displayName: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        case .oneYear: return "1 Year"
        case .forever: return "Forever"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .sevenDays: return 7 * 24 * 3600
        case .thirtyDays: return 30 * 24 * 3600
        case .ninetyDays: return 90 * 24 * 3600
        case .oneYear: return 365 * 24 * 3600
        case .forever: return .infinity
        }
    }
}

enum ColorScheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum FontSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    var scale: Double {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}

enum ThemeVariant: String, Codable, CaseIterable {
    case `default` = "default"
    case minimal = "minimal"
    case colorful = "colorful"
    case professional = "professional"

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .minimal: return "Minimal"
        case .colorful: return "Colorful"
        case .professional: return "Professional"
        }
    }
}

enum ButtonSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var scale: Double {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        }
    }
}

struct QuietHours: Codable {
    let enabled: Bool
    let startTime: String
    let endTime: String

    static let `default` = QuietHours(
        enabled: false,
        startTime: "22:00",
        endTime: "08:00"
    )
}