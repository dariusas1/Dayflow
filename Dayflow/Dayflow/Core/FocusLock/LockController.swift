//
//  LockController.swift
//  FocusLock
//
//  Manages OS-level app blocking using ManagedSettings
//

import Foundation
import AppKit

@MainActor
public final class LockController: ObservableObject {
    public static let shared = LockController()

    // MARK: - Private Properties
    private var blockingActive = false
    private var currentAllowedApps: [String] = []

    // MARK: - Public State
    public var isBlockingActive: Bool {
        blockingActive
    }

    // MARK: - Initialization
    private init() {
        // ⚠️ IMPORTANT: ManagedSettings framework is iOS-only
        // On macOS, actual app blocking is not available through ManagedSettings.
        // This implementation only tracks blocking state but does not enforce it.
        // For macOS app blocking, alternative approaches would be needed:
        // - Parental Controls API (requires admin privileges)
        // - AppleScript/System Events (limited effectiveness)
        // - Third-party blocking solutions integration
        print("[LockController] Initialized with simplified blocking (macOS compatible)")
        print("[LockController] ⚠️ NOTE: App blocking is not functional on macOS - state tracking only")
    }

    // MARK: - Public Methods
    public func applyBlocking(allowedApps: [String]) {
        print("[LockController] Applying app blocking for allowed apps: \(allowedApps)")

        currentAllowedApps = allowedApps
        blockingActive = true

        // Simplified blocking using NSWorkspace
        // ⚠️ LIMITATION: On macOS, this only tracks state but doesn't actually block apps
        // ManagedSettings framework is iOS-only, so actual blocking enforcement is not available
        print("[LockController] Simplified blocking applied for \(allowedApps.count) allowed apps")
        print("[LockController] ⚠️ WARNING: Actual app blocking is not functional on macOS")
        print("[LockController] Note: Full app blocking requires ManagedSettings framework which is iOS-only")
    }

    public func removeBlocking() {
        print("[LockController] Removing app blocking")

        // ManagedSettings is iOS-only, so we just clear the state on macOS
        currentAllowedApps = []
        blockingActive = false

        print("[LockController] Blocking removed")
    }

    public func isAppAllowed(bundleID: String) -> Bool {
        if !blockingActive {
            return true
        }
        return currentAllowedApps.contains(bundleID)
    }

    // MARK: - Private Methods

    private func getAllBundleIdentifiers() -> [String] {
        // Get running applications
        let runningApps = NSWorkspace.shared.runningApplications
        var bundleIDs: [String] = []

        for app in runningApps {
            if let bundleID = app.bundleIdentifier {
                bundleIDs.append(bundleID)
            }
        }

        // Add common system apps that might not be running
        let systemApps = [
            "com.apple.Safari",
            "com.apple.finder",
            "com.apple.mail",
            "com.apple.messages",
            "com.apple.calendar",
            "com.apple.reminders",
            "com.apple.notes",
            "com.apple.photo Booth",
            "com.apple.FaceTime",
            "com.apple.Maps",
            "com.apple.Music",
            "com.apple.Podcasts",
            "com.apple.TV",
            "com.apple.news",
            "com.apple.VoiceMemos",
            "com.apple.Home",
            "com.apple.shortcuts",
            "com.apple.ActivityMonitor",
            "com.apple.Console",
            "com.apple.systempreferences"
        ]

        bundleIDs.append(contentsOf: systemApps)

        // Remove duplicates
        return Array(Set(bundleIDs))
    }

    // MARK: - Helper Methods
    public func getAppName(for bundleID: String) -> String? {
        // Try to get the app name from NSWorkspace
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            return app.localizedName ?? app.bundleIdentifier
        }

        // Fallback to using the bundle ID
        return bundleID
    }

    public func getRunningApp() -> (name: String?, bundleID: String?) {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }

        let bundleID = frontmostApp.bundleIdentifier
        let appName = frontmostApp.localizedName

        return (appName, bundleID)
    }
}

// MARK: - ProcessInfo Helper
struct AppProcessInfo {
    let processIdentifier: pid_t
    let processName: String?
    let bundleIdentifier: String?

    static var runningProcesses: [AppProcessInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.compactMap { app in
            AppProcessInfo(
                pid: app.processIdentifier,
                name: app.localizedName,
                bundleID: app.bundleIdentifier
            )
        }
    }

    init(pid: pid_t, name: String?, bundleID: String?) {
        self.processIdentifier = pid
        self.processName = name
        self.bundleIdentifier = bundleID
    }
}