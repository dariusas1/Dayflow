//
//  BackgroundMonitor.swift
//  FocusLock
//
//  Background monitoring service for session integrity and app state
//

import Foundation
import Combine
import AppKit
import os.log

@MainActor
class BackgroundMonitor: ObservableObject {
    static let shared = BackgroundMonitor()

    private let logger = Logger(subsystem: "FocusLock", category: "BackgroundMonitor")
    private let sessionManager = SessionManager.shared
    private let lockController = LockController.shared

    // Monitoring state
    @Published var isMonitoring: Bool = false
    @Published var lastIntegrityCheck: Date?
    @Published var integrityIssues: [String] = []

    // Timers (consolidated for performance)
    private var consolidatedTimer: Timer?
    private var uptimeTimer: Timer?

    // Adaptive timing
    private var lastHealthCheckTime: Date?
    private var lastIntegrityCheckTime: Date?
    private var consecutiveHealthyChecks: Int = 0

    // Combine support
    private var cancellables = Set<AnyCancellable>()

    // Settings (adaptive intervals for better performance)
    private var monitoringInterval: TimeInterval = 60.0 // Start with 60 seconds, adaptive
    private var integrityCheckInterval: TimeInterval = 120.0 // Start with 2 minutes, adaptive
    private let baseMonitoringInterval: TimeInterval = 60.0
    private let baseIntegrityCheckInterval: TimeInterval = 120.0
    private let maxMonitoringInterval: TimeInterval = 300.0 // 5 minutes max
    private let maxIntegrityCheckInterval: TimeInterval = 600.0 // 10 minutes max

    // Published metrics
    @Published var uptime: TimeInterval = 0.0
    @Published var sessionHealth: SessionHealth = .healthy

    init() {
        setupNotifications()
    }

    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
    }

    // MARK: - Public Interface

    func startMonitoring() {
        guard !isMonitoring else { return }

        logger.info("Starting background monitoring")
        isMonitoring = true

        // Reset adaptive timing
        monitoringInterval = baseMonitoringInterval
        integrityCheckInterval = baseIntegrityCheckInterval
        consecutiveHealthyChecks = 0
        lastHealthCheckTime = nil
        lastIntegrityCheckTime = nil

        startUptimeTimer()
        startConsolidatedTimer()

        // Perform initial checks
        performIntegrityCheck()
        performBasicHealthCheck()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        logger.info("Stopping background monitoring")
        isMonitoring = false

        stopUptimeTimer()
        stopConsolidatedTimer()
    }

    func performIntegrityCheck() {
        guard isMonitoring else { return }

        logger.info("Performing session integrity check")
        lastIntegrityCheck = Date()
        integrityIssues.removeAll()

        // Check session state consistency
        checkSessionState()
        checkBlockingState()
        checkPermissionsState()
        checkResourceUsage()

        // Update health status
        updateSessionHealth()

        logger.info("Integrity check completed with \(self.integrityIssues.count) issues")
    }

    // MARK: - Private Methods

    @MainActor
    private func setupNotifications() {
        // Observe session state changes
        sessionManager.$currentState
            .sink { _ in
                self.handleSessionStateChange()
            }
            .store(in: &cancellables)

        // Observe app lifecycle
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { _ in
                self.handleAppBecameActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { _ in
                self.handleAppResignedActive()
            }
            .store(in: &cancellables)
    }

    private func startUptimeTimer() {
        let startTime = Date()
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.uptime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopUptimeTimer() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
        uptime = 0.0
    }

    private func startConsolidatedTimer() {
        // Use the shorter interval for consolidated checks
        consolidatedTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Perform both basic health and integrity checks in one timer
            Task { @MainActor in
                self.performBasicHealthCheck()

                // Perform integrity check less frequently
                let now = Date()
                if let lastCheck = self.lastIntegrityCheckTime {
                    if now.timeIntervalSince(lastCheck) >= self.integrityCheckInterval {
                        self.performIntegrityCheck()
                        self.lastIntegrityCheckTime = now
                    }
                } else {
                    self.lastIntegrityCheckTime = now
                    self.performIntegrityCheck()
                }

                // Adaptively adjust intervals based on health
                self.adaptMonitoringIntervals()
            }
        }
    }

    private func stopConsolidatedTimer() {
        consolidatedTimer?.invalidate()
        consolidatedTimer = nil
    }

    private func adaptMonitoringIntervals() {
        guard isMonitoring else { return }

        let hasIssues = !integrityIssues.isEmpty
        let isHealthy = sessionHealth == .healthy

        if isHealthy && !hasIssues {
            consecutiveHealthyChecks += 1
            // Increase intervals gradually when healthy
            if consecutiveHealthyChecks > 5 {
                monitoringInterval = min(monitoringInterval * 1.2, maxMonitoringInterval)
                integrityCheckInterval = min(integrityCheckInterval * 1.2, maxIntegrityCheckInterval)
            }
        } else {
            consecutiveHealthyChecks = 0
            // Decrease intervals when there are issues
            monitoringInterval = max(monitoringInterval * 0.8, baseMonitoringInterval)
            integrityCheckInterval = max(integrityCheckInterval * 0.8, baseIntegrityCheckInterval)
        }

        logger.debug("Adapted intervals - Monitoring: \(Int(self.monitoringInterval))s, Integrity: \(Int(self.integrityCheckInterval))s")
    }

    // MARK: - Health Checks

    private func performBasicHealthCheck() {
        guard isMonitoring else { return }

        // Check memory usage
        let memoryUsage = getCurrentMemoryUsage()
        if memoryUsage > 0.8 { // 80% threshold
            logger.warning("High memory usage detected: \(Int(memoryUsage * 100))%")
        }

        // Check CPU usage
        let cpuUsage = getCurrentCPUUsage()
        if cpuUsage > 0.9 { // 90% threshold
            logger.warning("High CPU usage detected: \(Int(cpuUsage * 100))%")
        }
    }

    private func checkSessionState() {
        guard let session = sessionManager.currentSession else {
            if sessionManager.currentState != .idle {
                integrityIssues.append("Session state inconsistency: no active session but not idle")
            }
            return
        }

        // Check if session is in valid state
        switch session.state {
        case .active, .break:
            // Check if blocking is applied
            if !lockController.isBlockingActive {
                integrityIssues.append("Session active but blocking not applied")
            }
        case .arming:
            // Arming should be temporary
            let armingDuration = Date().timeIntervalSince(session.startTime)
            if armingDuration > 30.0 { // 30 seconds max arming
                integrityIssues.append("Session stuck in arming state for too long")
            }
        case .idle, .ended:
            // These should not have active sessions
            break
        }
    }

    private func checkBlockingState() {
        if sessionManager.currentState == .active {
            if !lockController.isBlockingActive {
                integrityIssues.append("Focus session active but blocking not applied")
            }
        } else {
            if lockController.isBlockingActive {
                integrityIssues.append("Blocking active but no focus session")
            }
        }
    }

    private func checkPermissionsState() {
        // Check critical permissions
        let permissionsManager = PermissionsManager.shared

        if sessionManager.currentState != .idle {
            if !permissionsManager.hasAccessibilityPermission {
                integrityIssues.append("Accessibility permission missing during active session")
            }

            if !permissionsManager.hasScreenTimePermission {
                integrityIssues.append("Screen Time permission missing during active session")
            }
        }
    }

    private func checkResourceUsage() {
        // Check if the app is consuming excessive resources
        let memoryUsage = getCurrentMemoryUsage()
        if memoryUsage > 0.7 {
            integrityIssues.append("High memory usage: \(Int(memoryUsage * 100))%")
        }

        // Check disk space for logs
        let logPath = getLogPath()
        if let freeSpace = getFreeDiskSpace(at: logPath) {
            if freeSpace < 100 * 1024 * 1024 { // 100MB minimum
                integrityIssues.append("Low disk space for logs: \(freeSpace / 1024 / 1024)MB")
            }
        }
    }

    // MARK: - State Handlers

    private func handleSessionStateChange() {
        // React to session state changes
        if sessionManager.currentState == .active {
            // Ensure monitoring is active during sessions
            if !isMonitoring {
                startMonitoring()
            }
        }
    }

    private func handleAppBecameActive() {
        // App became active - resume monitoring if needed
        if sessionManager.currentState != .idle && !isMonitoring {
            startMonitoring()
        }
    }

    private func handleAppResignedActive() {
        // App resigned active - pause intensive monitoring
        if isMonitoring {
            // Keep basic monitoring but reduce frequency
            stopIntegrityCheckTimer()
        }
    }

    private func updateSessionHealth() {
        if integrityIssues.isEmpty {
            sessionHealth = .healthy
        } else if integrityIssues.count <= 2 {
            sessionHealth = .warning
        } else {
            sessionHealth = .critical
        }
    }

    // MARK: - System Information

    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         mach_task_basic_info_t,
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }

        return 0.0
    }

    private func getCurrentCPUUsage() -> Double {
        // This would require more complex CPU monitoring
        // For now, return a placeholder
        return 0.0
    }

    private func getLogPath() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryPath.appendingPathComponent("Logs/FocusLock")
    }

    private func getFreeDiskSpace(at path: URL) -> Int64? {
        do {
            let resourceValues = try path.resourceValues(forKeys: [.availableCapacityKey])
            return resourceValues.availableCapacity
        } catch {
            logger.error("Failed to get disk space: \(error)")
            return nil
        }
    }

// MARK: - Session Health

enum SessionHealth: String, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.circle"
        }
    }
}

// MARK: - Monitoring Report

struct MonitoringReport {
    let timestamp: Date
    let uptime: TimeInterval
    let sessionHealth: SessionHealth
    let integrityIssues: [String]
    let lastCheck: Date?

    var isHealthy: Bool {
        return sessionHealth == .healthy && integrityIssues.isEmpty
    }

    var summary: String {
        if isHealthy {
            return "All systems operating normally"
        } else {
            return "\(integrityIssues.count) issues detected"
        }
    }
}

@MainActor
extension BackgroundMonitor {
    var monitoringReport: MonitoringReport {
        return MonitoringReport(
            timestamp: Date(),
            uptime: uptime,
            sessionHealth: sessionHealth,
            integrityIssues: integrityIssues,
            lastCheck: lastIntegrityCheck
        )
    }
}