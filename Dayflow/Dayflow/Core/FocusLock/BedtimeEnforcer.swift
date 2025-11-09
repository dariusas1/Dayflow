//
//  BedtimeEnforcer.swift
//  FocusLock
//
//  Enforces bedtime by shutting down or warning the user
//  Helps maintain healthy sleep habits
//

import Foundation
import SwiftUI
import AppKit
import UserNotifications
import os.log

@MainActor
class BedtimeEnforcer: ObservableObject {
    static let shared = BedtimeEnforcer()

    private let logger = Logger(subsystem: "FocusLock", category: "BedtimeEnforcer")

    // Published state
    @Published var isEnabled: Bool = false
    @Published var bedtimeHour: Int = 23 // 11 PM default
    @Published var bedtimeMinute: Int = 0
    @Published var warningMinutes: Int = 15 // Warn 15 minutes before
    @Published var enforcementMode: EnforcementMode = .countdown
    @Published var isCountdownActive: Bool = false
    @Published var countdownSeconds: Int = 0
    @Published var canSnooze: Bool = true
    @Published var maxSnoozes: Int = 1
    @Published var snoozeDuration: Int = 10 // minutes

    // Nuclear mode specific
    @Published var nuclearModeLastArmed: Date?
    @Published var nuclearModeConfirmedAt: Date?
    @Published var requiresDailyArming: Bool = true

    // Private state
    private var timer: Timer?
    private var countdownTimer: Timer?
    var currentSnoozeCount: Int = 0 // Internal for BedtimeCountdownView access
    private var lastBedtimeDate: Date?
    private let killSwitchManager = KillSwitchManager.shared

    // UserDefaults keys
    private let enabledKey = "bedtimeEnforcerEnabled"
    private let bedtimeHourKey = "bedtimeHour"
    private let bedtimeMinuteKey = "bedtimeMinute"
    private let warningMinutesKey = "bedtimeWarningMinutes"
    private let enforcementModeKey = "bedtimeEnforcementMode"
    private let canSnoozeKey = "bedtimeCanSnooze"
    private let maxSnoozesKey = "bedtimeMaxSnoozes"
    private let snoozeDurationKey = "bedtimeSnoozeDuration"
    private let nuclearLastArmedKey = "nuclearModeLastArmed"
    private let nuclearConfirmedAtKey = "nuclearModeConfirmedAt"
    private let requiresDailyArmingKey = "nuclearRequiresDailyArming"

    private init() {
        loadSettings()
        setupTimer()
    }

    enum EnforcementMode: String, Codable, CaseIterable {
        case countdown = "countdown"           // Unstoppable countdown
        case forceShutdown = "force_shutdown"  // Immediate shutdown
        case gentleReminder = "gentle_reminder" // Just notifications
        case nuclear = "nuclear"               // NUCLEAR: No escape except Kill Switch

        var displayName: String {
            switch self {
            case .countdown: return "Countdown to Shutdown"
            case .forceShutdown: return "Immediate Shutdown"
            case .gentleReminder: return "Gentle Reminder Only"
            case .nuclear: return "🔴 Nuclear Mode"
            }
        }

        var description: String {
            switch self {
            case .countdown: return "Shows unstoppable countdown, then shuts down"
            case .forceShutdown: return "Immediately shuts down at bedtime"
            case .gentleReminder: return "Shows notifications but doesn't force shutdown"
            case .nuclear: return "No in-app escape. Only Kill Switch (⌘⌥⇧Z + passphrase) can disable"
            }
        }

        var requiresDoubleOptIn: Bool {
            return self == .nuclear
        }

        var allowsSnooze: Bool {
            return self == .countdown
        }
    }

    // MARK: - Settings

    func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)

        if let savedHour = UserDefaults.standard.object(forKey: bedtimeHourKey) as? Int {
            bedtimeHour = savedHour
        }
        if let savedMinute = UserDefaults.standard.object(forKey: bedtimeMinuteKey) as? Int {
            bedtimeMinute = savedMinute
        }
        if let savedWarning = UserDefaults.standard.object(forKey: warningMinutesKey) as? Int {
            warningMinutes = savedWarning
        }
        if let savedModeString = UserDefaults.standard.string(forKey: enforcementModeKey),
           let savedMode = EnforcementMode(rawValue: savedModeString) {
            enforcementMode = savedMode
        }
        canSnooze = UserDefaults.standard.object(forKey: canSnoozeKey) as? Bool ?? true
        maxSnoozes = UserDefaults.standard.object(forKey: maxSnoozesKey) as? Int ?? 1
        snoozeDuration = UserDefaults.standard.object(forKey: snoozeDurationKey) as? Int ?? 10

        // Nuclear mode settings
        if let savedArmed = UserDefaults.standard.object(forKey: nuclearLastArmedKey) as? Date {
            nuclearModeLastArmed = savedArmed
        }
        if let savedConfirmed = UserDefaults.standard.object(forKey: nuclearConfirmedAtKey) as? Date {
            nuclearModeConfirmedAt = savedConfirmed
        }
        requiresDailyArming = UserDefaults.standard.object(forKey: requiresDailyArmingKey) as? Bool ?? true
    }

    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        UserDefaults.standard.set(bedtimeHour, forKey: bedtimeHourKey)
        UserDefaults.standard.set(bedtimeMinute, forKey: bedtimeMinuteKey)
        UserDefaults.standard.set(warningMinutes, forKey: warningMinutesKey)
        UserDefaults.standard.set(enforcementMode.rawValue, forKey: enforcementModeKey)
        UserDefaults.standard.set(canSnooze, forKey: canSnoozeKey)
        UserDefaults.standard.set(maxSnoozes, forKey: maxSnoozesKey)
        UserDefaults.standard.set(snoozeDuration, forKey: snoozeDurationKey)

        // Nuclear mode settings
        if let armed = nuclearModeLastArmed {
            UserDefaults.standard.set(armed, forKey: nuclearLastArmedKey)
        }
        if let confirmed = nuclearModeConfirmedAt {
            UserDefaults.standard.set(confirmed, forKey: nuclearConfirmedAtKey)
        }
        UserDefaults.standard.set(requiresDailyArming, forKey: requiresDailyArmingKey)

        // Restart timer with new settings
        setupTimer()

        logger.info("Bedtime enforcer settings saved: enabled=\(self.isEnabled), time=\(self.bedtimeHour):\(self.bedtimeMinute), mode=\(self.enforcementMode.rawValue)")
    }

    func updateBedtime(hour: Int, minute: Int) {
        bedtimeHour = hour
        bedtimeMinute = minute
        saveSettings()
    }

    func updateEnforcementMode(_ mode: EnforcementMode) {
        enforcementMode = mode
        saveSettings()
    }

    func toggleEnabled() {
        isEnabled.toggle()
        saveSettings()
    }

    // MARK: - Timer Management

    private func setupTimer() {
        timer?.invalidate()

        guard isEnabled else {
            logger.info("Bedtime enforcer disabled, timer not started")
            return
        }

        // Check every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkBedtime()
            }
        }

        // Check immediately
        checkBedtime()

        logger.info("Bedtime enforcer timer started")
    }

    private func checkBedtime() {
        guard isEnabled else { return }

        // Check Nuclear mode daily arming requirement
        checkDailyArming()

        let now = Date()
        let calendar = Calendar.current

        // Get today's bedtime
        guard let todayBedtime = calendar.date(bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: now) else {
            logger.error("Failed to calculate bedtime")
            return
        }

        // Check if we've already processed today's bedtime
        if let lastBedtime = lastBedtimeDate,
           calendar.isDate(lastBedtime, inSameDayAs: todayBedtime) {
            // Already processed today
            return
        }

        let timeUntilBedtime = todayBedtime.timeIntervalSince(now)
        let warningTime = TimeInterval(warningMinutes * 60)

        // Check if it's warning time
        if timeUntilBedtime > 0 && timeUntilBedtime <= warningTime {
            showWarningNotification(minutesUntilBedtime: Int(ceil(timeUntilBedtime / 60)))
        }

        // Check if it's bedtime
        if now >= todayBedtime {
            triggerBedtimeEnforcement()
        }
    }

    // MARK: - Enforcement

    private func triggerBedtimeEnforcement() {
        lastBedtimeDate = Date()
        currentSnoozeCount = 0

        logger.info("Bedtime reached, triggering enforcement mode: \(self.enforcementMode.rawValue)")

        switch enforcementMode {
        case .forceShutdown:
            performShutdown()

        case .countdown:
            startCountdown()

        case .gentleReminder:
            showBedtimeNotification()

        case .nuclear:
            // Nuclear mode: unstoppable countdown, no snooze, only Kill Switch can stop
            startCountdown()
        }

        // Analytics
        AnalyticsService.shared.capture("bedtime_enforced", [
            "mode": enforcementMode.rawValue,
            "hour": bedtimeHour,
            "minute": bedtimeMinute
        ])
    }

    private func showWarningNotification(minutesUntilBedtime: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Bedtime Approaching"
        content.body = "Your bedtime is in \(minutesUntilBedtime) minute\(minutesUntilBedtime == 1 ? "" : "s"). Start wrapping up!"
        content.sound = .default
        content.categoryIdentifier = "BEDTIME_WARNING"

        let request = UNNotificationRequest(
            identifier: "bedtime_warning_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to show warning notification: \(error.localizedDescription)")
            }
        }

        logger.info("Warning notification sent: \(minutesUntilBedtime) minutes until bedtime")
    }

    private func showBedtimeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🌙 Bedtime!"
        content.body = "It's time to wind down and get some rest. Your health and productivity depend on good sleep!"
        content.sound = .default
        content.categoryIdentifier = "BEDTIME_REMINDER"

        let request = UNNotificationRequest(
            identifier: "bedtime_reminder_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to show bedtime notification: \(error.localizedDescription)")
            }
        }
    }

    private func startCountdown() {
        guard !isCountdownActive else { return }

        isCountdownActive = true
        countdownSeconds = 5 * 60 // 5 minute countdown

        // Show countdown window
        showCountdownWindow()

        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdown()
            }
        }

        logger.info("Countdown started: \(self.countdownSeconds) seconds")
    }

    private func updateCountdown() {
        countdownSeconds -= 1

        if countdownSeconds <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            isCountdownActive = false
            performShutdown()
        }
    }

    func snooze() {
        guard canSnooze && currentSnoozeCount < maxSnoozes else {
            logger.warning("Snooze attempted but not allowed or limit reached")
            return
        }

        currentSnoozeCount += 1

        // Stop countdown
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false

        // Dismiss countdown window
        dismissCountdownWindow()

        // Schedule new bedtime
        let newBedtime = Date().addingTimeInterval(TimeInterval(snoozeDuration * 60))
        logger.info("Snoozed until \(newBedtime) (snooze \(self.currentSnoozeCount) of \(self.maxSnoozes))")

        // Show notification
        let content = UNMutableNotificationContent()
        content.title = "Bedtime Snoozed"
        content.body = "You have \(snoozeDuration) more minutes. Snoozes remaining: \(maxSnoozes - currentSnoozeCount)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "bedtime_snooze_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)

        // Schedule check for snoozed time
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(snoozeDuration * 60)) { [weak self] in
            self?.triggerBedtimeEnforcement()
        }

        AnalyticsService.shared.capture("bedtime_snoozed", [
            "snooze_count": currentSnoozeCount,
            "duration_minutes": snoozeDuration
        ])
    }

    private func performShutdown() {
        logger.warning("Performing system shutdown due to bedtime enforcement")

        // Check for unsaved work - downgrade to sleep if detected
        if detectUnsavedWork() {
            logger.info("Unsaved work detected - performing sleep instead of shutdown")
            performSleep()
            return
        }

        // Show final warning
        let alert = NSAlert()
        alert.messageText = "Shutting Down"
        alert.informativeText = "Your bedtime has arrived. The system will shut down now to help you maintain healthy sleep habits."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()

        // Analytics
        AnalyticsService.shared.capture("bedtime_shutdown_executed", [
            "mode": enforcementMode.rawValue
        ])

        // Execute shutdown
        // Using AppleScript for macOS shutdown
        let script = "tell application \"System Events\" to shut down"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                logger.error("Shutdown failed: \(error)")

                // Fallback: quit all apps and show persistent alert
                fallbackEnforcement()
            }
        }
    }

    private func fallbackEnforcement() {
        // If shutdown fails, show a persistent full-screen alert
        let alert = NSAlert()
        alert.messageText = "Bedtime Enforcement"
        alert.informativeText = "System shutdown requires administrator privileges. Please shut down manually or you will continue to see this reminder."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Shut Down Manually")

        // Show modal and block interaction
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User acknowledged, show again in 5 minutes if still awake
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                self?.fallbackEnforcement()
            }
        }
    }

    // MARK: - Countdown Window

    private var countdownWindow: NSWindow?

    private func showCountdownWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.level = .modalPanel
            window.isOpaque = false
            window.backgroundColor = .clear
            window.center()

            let hostingView = NSHostingView(rootView: BedtimeCountdownView(enforcer: self))
            window.contentView = hostingView

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            self.countdownWindow = window
        }
    }

    private func dismissCountdownWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.countdownWindow?.close()
            self?.countdownWindow = nil
        }
    }

    // MARK: - Nuclear Mode

    /// Arm Nuclear mode for today
    func armNuclearMode() {
        guard enforcementMode == .nuclear else {
            logger.warning("Attempted to arm Nuclear mode but enforcement mode is \(self.enforcementMode.rawValue)")
            return
        }

        nuclearModeLastArmed = Date()
        saveSettings()

        logger.info("Nuclear mode armed for today")

        // Show confirmation notification
        let content = UNMutableNotificationContent()
        content.title = "🔴 Nuclear Bedtime Armed"
        content.body = "Bedtime enforcement is active. Only the Kill Switch (⌘⌥⇧Z + passphrase) can disable it."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "nuclear_armed_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)

        AnalyticsService.shared.capture("nuclear_mode_armed", [:])
    }

    /// Check if Nuclear mode needs re-arming
    func checkDailyArming() {
        guard enforcementMode == .nuclear && requiresDailyArming else { return }

        guard let lastArmed = nuclearModeLastArmed,
              Calendar.current.isDateInToday(lastArmed) else {
            // Not armed today - downgrade to countdown mode
            logger.warning("Nuclear mode not armed today, downgrading to countdown mode")
            enforcementMode = .countdown
            saveSettings()

            // Show notification
            let content = UNMutableNotificationContent()
            content.title = "Nuclear Mode Disarmed"
            content.body = "Nuclear mode was not re-armed today. Downgraded to Countdown mode."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "nuclear_disarmed_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request)

            AnalyticsService.shared.capture("nuclear_mode_disarmed_no_arming", [:])
            return
        }
    }

    /// Disable enforcement via Kill Switch
    func disableViaKillSwitch() {
        logger.warning("Bedtime enforcement disabled via Kill Switch")

        // Stop countdown if active
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false

        // Dismiss countdown window
        dismissCountdownWindow()

        // Disable enforcement
        isEnabled = false
        saveSettings()

        // Show notification
        let content = UNMutableNotificationContent()
        content.title = "Kill Switch Activated"
        content.body = "Bedtime enforcement has been disabled via Kill Switch."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "killswitch_activated_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)

        AnalyticsService.shared.capture("killswitch_used", [:])
    }

    // MARK: - Unsaved Work Detection

    /// Detect if any apps have unsaved work
    private func detectUnsavedWork() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            // Skip system apps and our own app
            guard let bundleID = app.bundleIdentifier,
                  !bundleID.starts(with: "com.apple."),
                  bundleID != "com.dayflow.FocusLock" else {
                continue
            }

            // Check for common unsaved work indicators in app name
            // macOS convention: apps with unsaved changes often show " • " or have "*" in window title
            if let name = app.localizedName {
                if name.contains("•") || name.contains("*") {
                    logger.info("Detected unsaved work in app: \(name)")
                    return true
                }
            }

            // Check specific known apps
            if let bundleID = app.bundleIdentifier {
                switch bundleID {
                case "com.apple.TextEdit",
                     "com.microsoft.Word",
                     "com.microsoft.Excel",
                     "com.microsoft.PowerPoint",
                     "com.apple.iWork.Pages",
                     "com.apple.iWork.Numbers",
                     "com.apple.iWork.Keynote",
                     "com.sublimetext.3",
                     "com.sublimetext.4",
                     "com.microsoft.VSCode",
                     "com.jetbrains.intellij",
                     "com.apple.dt.Xcode":
                    // These apps commonly have unsaved work
                    // In a production version, we'd use Accessibility API to check window titles
                    logger.info("Detected productivity app running: \(bundleID)")
                    return true
                default:
                    break
                }
            }
        }

        return false
    }

    /// Sleep the Mac instead of shutting down
    private func performSleep() {
        logger.info("Performing system sleep (unsaved work detected)")

        let script = "tell application \"System Events\" to sleep"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                logger.error("Sleep failed: \(error)")
                fallbackEnforcement()
            } else {
                // Show notification explaining why sleep instead of shutdown
                let content = UNMutableNotificationContent()
                content.title = "Bedtime: Sleep Mode"
                content.body = "Unsaved work detected. Your Mac will sleep instead of shutting down. Please save your work."
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "bedtime_sleep_\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request)

                AnalyticsService.shared.capture("bedtime_sleep_unsaved_work", [:])
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        timer?.invalidate()
        countdownTimer?.invalidate()
    }
}

// MARK: - Countdown View

struct BedtimeCountdownView: View {
    @ObservedObject var enforcer: BedtimeEnforcer
    @ObservedObject var killSwitchManager = KillSwitchManager.shared

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Moon icon
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)

                // Title
                Text("Bedtime Enforcement")
                    .font(.custom("Nunito", size: 36))
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Countdown
                Text(formatCountdown(enforcer.countdownSeconds))
                    .font(.custom("Nunito", size: 72))
                    .fontWeight(.heavy)
                    .foregroundColor(.red)
                    .monospacedDigit()

                // Message
                Text("Your Mac will shut down when the timer reaches zero")
                    .font(.custom("Nunito", size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Snooze button (if allowed) - NOT available in Nuclear mode
                if enforcer.enforcementMode.allowsSnooze && enforcer.canSnooze && enforcer.currentSnoozeCount < enforcer.maxSnoozes {
                    Button(action: {
                        enforcer.snooze()
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Snooze \(enforcer.snoozeDuration) Minutes")
                        }
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("Snoozes remaining: \(enforcer.maxSnoozes - enforcer.currentSnoozeCount)")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if enforcer.currentSnoozeCount >= enforcer.maxSnoozes {
                    Text("No more snoozes available")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.red)
                        .padding(.top)
                }

                // Nuclear mode message
                if enforcer.enforcementMode == .nuclear {
                    VStack(spacing: 8) {
                        Text("🔴 NUCLEAR MODE")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(.red)

                        Text("Only Kill Switch (⌘⌥⇧Z + passphrase) can stop this countdown")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                }

                // Health message
                VStack(spacing: 8) {
                    Text("💤 Get your rest!")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Quality sleep improves focus, memory, and productivity")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
            }
            .padding(40)

            // Kill Switch passphrase modal
            if killSwitchManager.showPassphraseEntry {
                KillSwitchPassphraseView()
            }
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
