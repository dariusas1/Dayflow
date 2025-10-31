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

        if #available(macOS 13.0, *) {
            let loginItem = SMAppService.loginItem(identifier: agentIdentifier)

            do {
                try loginItem.register()
                logger.info("LaunchAgent installed successfully via SMAppService")
                installationError = nil
                checkAgentStatus()
                return true
            } catch {
                let errorMessage = "Failed to register LaunchAgent: \(error.localizedDescription)"
                logger.error("\(errorMessage)")
                installationError = errorMessage
                return false
            }
        } else {
            let success = SMLoginItemSetEnabled(agentIdentifier as CFString, true)

            if success {
                logger.info("LaunchAgent enabled successfully via SMLoginItemSetEnabled")
                installationError = nil
                checkAgentStatus()
            } else {
                let errorMessage = "Failed to enable LaunchAgent using SMLoginItemSetEnabled"
                logger.error("\(errorMessage)")
                installationError = errorMessage
            }

            return success
        }
    }

    func uninstallLaunchAgent() -> Bool {
        logger.info("Uninstalling LaunchAgent for FocusLock")

        if #available(macOS 13.0, *) {
            let loginItem = SMAppService.loginItem(identifier: agentIdentifier)

            do {
                try loginItem.unregister()
                logger.info("LaunchAgent unregistered successfully via SMAppService")
                installationError = nil
                checkAgentStatus()
                return true
            } catch {
                let errorMessage = "Failed to unregister LaunchAgent: \(error.localizedDescription)"
                logger.error("\(errorMessage)")
                installationError = errorMessage
                return false
            }
        } else {
            let success = SMLoginItemSetEnabled(agentIdentifier as CFString, false)

            if success {
                logger.info("LaunchAgent disabled successfully via SMLoginItemSetEnabled")
                installationError = nil
                checkAgentStatus()
            } else {
                let errorMessage = "Failed to disable LaunchAgent using SMLoginItemSetEnabled"
                logger.error("\(errorMessage)")
                installationError = errorMessage
            }

            return success
        }
    }

    func checkAgentStatus() {
        logger.info("Checking LaunchAgent status")

        if #available(macOS 13.0, *) {
            let loginItem = SMAppService.loginItem(identifier: agentIdentifier)
            switch loginItem.status {
            case .enabled:
                isInstalled = true
                isEnabled = true
                installationError = nil
            case .requiresApproval:
                isInstalled = false
                isEnabled = false
                installationError = "Login item requires user approval"
            case .notRegistered, .notFound:
                fallthrough
            @unknown default:
                isInstalled = false
                isEnabled = false
                installationError = nil
            }
        } else {
            if let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: Any]] {
                let isLoaded = jobs.contains { job in
                    guard let label = job["Label"] as? String else { return false }
                    return label == agentLabel || label == agentIdentifier
                }

                isInstalled = isLoaded
                isEnabled = isLoaded
                installationError = nil
            } else {
                isInstalled = false
                isEnabled = false
                installationError = nil
            }
        }

        lastCheckDate = Date()

        logger.info("LaunchAgent status - Installed: \(self.isInstalled), Enabled: \(self.isEnabled)")
    }

    func toggleLaunchAgent() -> Bool {
        if isInstalled {
            return uninstallLaunchAgent()
        } else {
            return installLaunchAgent()
        }
    }

    // MARK: - Private Methods

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
        if let error = installationError, !error.isEmpty {
            return error
        }

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