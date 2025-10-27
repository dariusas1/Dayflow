//
//  LaunchAgentManager.swift
//  FocusLock
//
//  Manages LaunchAgent for automatic app startup and background monitoring
//

import Foundation
import ServiceManagement
import os.log

class LaunchAgentManager: ObservableObject {
    static let shared = LaunchAgentManager()

    private let logger = Logger(subsystem: "FocusLock", category: "LaunchAgent")
    private let agentIdentifier = "com.focuslock.agent"
    private let agentLabel = "FocusLock Agent"

    // LaunchAgent configuration
    private let agentPlist: [String: Any] = [
        "Label": "FocusLock Agent",
        "ProgramArguments": [
            "--autostart",
            "--background"
        ],
        "RunAtLoad": true,
        "KeepAlive": true,
        "StandardOutPath": "/tmp/com.focuslock.agent.log",
        "StandardErrorPath": "/tmp/com.focuslock.agent.error.log",
        "ProcessType": "Background"
    ]

    // Published state
    @Published var isEnabled: Bool = false
    @Published var isInstalled: Bool = false
    @Published var lastCheckDate: Date?
    @Published var installationError: String?

    init() {
        checkAgentStatus()
    }

    // MARK: - Public Interface

    func installLaunchAgent() -> Bool {
        logger.info("Installing LaunchAgent for FocusLock")

        do {
            // Create the LaunchAgent plist file
            let plistPath = getLaunchAgentPlistPath()
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: agentPlist,
                format: .xml,
                options: 0
            )

            try plistData.write(to: plistPath)
            logger.info("LaunchAgent plist written to: \(plistPath)")

            // Load the agent using SMJobBless
            let result = SMJobBless(kSMDomainUserLaunchd, agentIdentifier as CFString, plistPath as CFString, true)

            if result {
                logger.info("LaunchAgent installed successfully")
                isInstalled = true
                installationError = nil
                return true
            } else {
                let error = "Failed to load LaunchAgent using SMJobBless"
                logger.error("\(error)")
                installationError = error
                return false
            }
        } catch {
            let errorMessage = "Failed to install LaunchAgent: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            installationError = errorMessage
            return false
        }
    }

    func uninstallLaunchAgent() -> Bool {
        logger.info("Uninstalling LaunchAgent for FocusLock")

        do {
            // Remove the agent using SMJobBless
            let result = SMJobBless(kSMDomainUserLaunchd, agentIdentifier as CFString, nil, false)

            if result {
                logger.info("LaunchAgent uninstalled successfully")

                // Remove the plist file
                try? FileManager.default.removeItem(at: getLaunchAgentPlistPath())

                isInstalled = false
                installationError = nil
                return true
            } else {
                let error = "Failed to unload LaunchAgent using SMJobBless"
                logger.error(error)
                installationError = error
                return false
            }
        } catch {
            let errorMessage = "Failed to uninstall LaunchAgent: \(error.localizedDescription)"
            logger.error(errorMessage)
            installationError = errorMessage
            return false
        }
    }

    func checkAgentStatus() {
        logger.info("Checking LaunchAgent status")

        // Check if the LaunchAgent plist exists
        let plistPath = getLaunchAgentPlistPath()
        let plistExists = FileManager.default.fileExists(atPath: plistPath)

        // Check if the job is loaded using SMJobBless
        let jobRef = SMJobCopy(kSMDomainUserLaunchd, agentIdentifier as CFString)
        let isLoaded = jobRef != nil

        if jobRef != nil {
            jobRef?.release()
        }

        isInstalled = plistExists && isLoaded
        lastCheckDate = Date()
        isEnabled = isInstalled

        logger.info("LaunchAgent status - Installed: \(isInstalled), Enabled: \(isEnabled)")
    }

    func toggleLaunchAgent() -> Bool {
        if isInstalled {
            return uninstallLaunchAgent()
        } else {
            return installLaunchAgent()
        }
    }

    // MARK: - Private Methods

    private func getLaunchAgentPlistPath() -> String {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let launchAgentsPath = libraryPath.appendingPathComponent("LaunchAgents")
        return launchAgentsPath.appendingPathComponent("\(agentIdentifier).plist")
    }

    // MARK: - Autostart Preference

    func setAutostartPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "FocusLockAutostartEnabled")
        logger.info("Autostart preference set to: \(enabled)")

        // If autostart is enabled and agent is not installed, install it
        if enabled && !isInstalled {
            _ = installLaunchAgent()
        } else if !enabled && isInstalled {
            _ = uninstallLaunchAgent()
        }
    }

    func getAutostartPreference() -> Bool {
        return UserDefaults.standard.bool(forKey: "FocusLockAutostartEnabled")
    }

    // MARK: - Background Operations

    func enableBackgroundMonitoring() {
        logger.info("Enabling background monitoring for FocusLock")

        // This would be called when the app starts
        // The actual monitoring logic would be handled by the main app
    }

    func disableBackgroundMonitoring() {
        logger.info("Disabling background monitoring for FocusLock")

        // This would be called when the app is explicitly closed
    }
}

// MARK: - Extensions

extension LaunchAgentManager {
    var statusDescription: String {
        if isInstalled {
            return "Installed and active"
        } else {
            return "Not installed"
        }
    }

    var nextActionText: String {
        return isInstalled ? "Disable Autostart" : "Enable Autostart"
    }
}

// MARK: - LaunchAgent Utilities

extension LaunchAgentManager {
    func createStartupScript() -> String {
        return """
        #!/bin/bash
        # FocusLock Autostart Script

        # Exit if FocusLock is already running
        if pgrep -x "FocusLock" > /dev/null; then
            echo "FocusLock is already running"
            exit 0
        fi

        # Wait a moment for the system to be ready
        sleep 2

        # Launch FocusLock with autostart flag
        open -a "FocusLock" --args --autostart

        echo "FocusLock launched at $(date)"
        """
    }

    func verifyAgentInstallation() -> LaunchAgentStatus {
        return LaunchAgentStatus(
            isInstalled: isInstalled,
            isEnabled: isEnabled,
            lastCheck: lastCheckDate,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            error: installationError
        )
    }
}

// MARK: - Status Data Model

struct LaunchAgentStatus {
    let isInstalled: Bool
    let isEnabled: Bool
    let lastCheck: Date?
    let version: String
    let error: String?

    var isValid: Bool {
        return isInstalled && error == nil
    }

    var statusIcon: String {
        if isValid {
            return "✅"
        } else {
            return "❌"
        }
    }
}