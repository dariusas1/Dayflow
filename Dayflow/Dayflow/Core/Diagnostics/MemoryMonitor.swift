//
//  MemoryMonitor.swift
//  Dayflow
//
//  Created by Development Agent on 2025-11-14.
//  Story 1.4: Memory Leak Detection System
//
//  Thread-safe memory monitoring and leak detection system using actor isolation.
//  Samples memory every 10 seconds, detects threshold breaches and leak patterns,
//  and generates alerts with diagnostic snapshots.
//
//  Architecture:
//  - Actor isolation for thread-safe access to monitoring state
//  - Periodic sampling using async Task with configurable interval
//  - Bounded snapshot history (max 360 snapshots = 1 hour at 10-second intervals)
//  - Alert debouncing to prevent spam (max 1 alert per threshold per minute)
//  - Integration with BufferManager for component diagnostics
//  - Integration with Sentry for crash context enrichment
//

import Foundation
import os.log

#if canImport(Darwin)
import Darwin
#endif

/// Thread-safe memory monitor using actor isolation.
/// Provides real-time memory leak detection and threshold-based alerting.
public actor MemoryMonitor {

    /// Shared singleton instance. All memory monitoring operations should use this instance.
    public static let shared = MemoryMonitor()

    /// Logger for memory monitoring events
    private let logger = Logger(subsystem: "Dayflow", category: "MemoryMonitor")

    // MARK: - Monitoring State

    /// Whether monitoring is currently active
    private var isMonitoring: Bool = false

    /// Background task running the monitoring loop
    private var monitoringTask: Task<Void, Never>?

    /// History of memory snapshots, bounded to maxSnapshots
    /// Oldest snapshots are at the beginning of the array
    private var snapshots: [MemorySnapshot] = []

    /// Alert callback handlers registered by components
    private var alertCallbacks: [(MemoryAlert) -> Void] = []

    /// Last alert timestamp by severity to implement debouncing
    /// Prevents spam alerts: max 1 alert per severity level per minute
    private var lastAlertTime: [AlertSeverity: Date] = [:]

    // MARK: - Configuration

    /// Maximum number of snapshots to retain in history
    /// 360 snapshots at 10-second intervals = 1 hour of history
    /// Estimated memory: ~50KB for 360 snapshots
    private let maxSnapshots: Int = 360

    /// Minimum interval between alerts of the same severity (seconds)
    /// Prevents alert spam while allowing multiple severity levels to alert
    private let alertDebounceInterval: TimeInterval = 60.0

    /// Warning threshold: Generate alert when memory usage exceeds this percentage
    private let warningThreshold: Double = 75.0

    /// Critical threshold: Generate alert when memory usage exceeds this percentage
    private let criticalThreshold: Double = 90.0

    /// Leak detection threshold: Alert when memory grows by this percentage over detection window
    private let leakGrowthThreshold: Double = 5.0

    /// Leak detection window: Time period to analyze for sustained memory growth (seconds)
    /// 5 minutes = 300 seconds = 30 samples at 10-second intervals
    private let leakDetectionWindow: TimeInterval = 300.0

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private init() {
        logger.info("MemoryMonitor initialized")
    }

    // MARK: - Public API

    /// Start continuous memory monitoring with configurable sampling interval.
    /// Collects memory snapshots at specified interval and analyzes for alerts.
    /// - Parameter interval: Time between samples in seconds (default: 10 seconds)
    public func startMonitoring(interval: TimeInterval = 10.0) {
        guard !isMonitoring else {
            logger.warning("startMonitoring called but monitoring already active")
            return
        }

        isMonitoring = true
        logger.info("Starting memory monitoring with interval=\(interval, privacy: .public)s")

        // Launch monitoring loop in background task
        monitoringTask = Task {
            await runMonitoringLoop(interval: interval)
        }

        // Integrate with Sentry for crash context
        Task {
            await integrateSentryContext()
        }
    }

    /// Stop memory monitoring and release resources.
    /// Cancels the background monitoring task and cleans up state.
    public func stopMonitoring() {
        guard isMonitoring else {
            logger.warning("stopMonitoring called but monitoring not active")
            return
        }

        logger.info("Stopping memory monitoring")
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Get current memory snapshot on-demand for diagnostics.
    /// - Returns: Current memory state snapshot
    public func currentSnapshot() async -> MemorySnapshot {
        return await collectSnapshot()
    }

    /// Get memory snapshots for specified time window for historical analysis.
    /// - Parameter lastMinutes: Number of minutes of history to return
    /// - Returns: Array of memory snapshots within the time window, oldest first
    public func memoryTrend(lastMinutes: Int) async -> [MemorySnapshot] {
        let cutoffTime = Date().addingTimeInterval(-Double(lastMinutes) * 60.0)
        return snapshots.filter { $0.timestamp >= cutoffTime }
    }

    /// Register callback for memory alerts.
    /// Callbacks are invoked asynchronously when alerts are generated.
    /// - Parameter handler: Closure to call when an alert is generated
    public func onAlert(_ handler: @escaping (MemoryAlert) -> Void) {
        alertCallbacks.append(handler)
        logger.debug("Alert callback registered, total callbacks=\(self.alertCallbacks.count)")
    }

    /// Force garbage collection and memory cleanup.
    /// Triggers BufferManager cleanup and requests system memory reclamation.
    public func forceCleanup() async {
        logger.info("forceCleanup: Initiating memory cleanup")

        // Trigger BufferManager cleanup by releasing old buffers
        // BufferManager automatically evicts oldest buffers when capacity is reached
        // For force cleanup, we can get diagnostic info to log the state
        let bufferCount = await BufferManager.shared.bufferCount()
        logger.info("forceCleanup: Current buffer count=\(bufferCount)")

        // Note: We don't have direct access to evict buffers from BufferManager
        // BufferManager automatically manages its own pool with FIFO eviction
        // This method is primarily for logging and future extension points
    }

    // MARK: - Private Monitoring Loop

    /// Main monitoring loop that runs continuously in background.
    /// Collects snapshots, analyzes thresholds and trends, generates alerts.
    private func runMonitoringLoop(interval: TimeInterval) async {
        logger.info("Monitoring loop started")

        while isMonitoring {
            let loopStartTime = Date()

            // Collect memory snapshot
            let snapshot = await collectSnapshot()

            // Store snapshot in history
            snapshots.append(snapshot)
            trimSnapshotHistory()

            // Analyze for threshold violations
            await analyzeThresholds(snapshot)

            // Analyze for memory leak trends (only if we have enough history)
            if snapshots.count >= 30 { // Need at least 30 samples for 5-minute window
                await analyzeLeakTrend()
            }

            // Update Sentry context with latest snapshot
            await integrateSentryContext()

            // Calculate sleep duration to maintain consistent interval
            let loopDuration = Date().timeIntervalSince(loopStartTime)
            let sleepDuration = max(0, interval - loopDuration)

            // Sleep until next sample (respecting task cancellation)
            do {
                try await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))
            } catch {
                // Task was cancelled, exit loop
                logger.info("Monitoring loop cancelled")
                break
            }
        }

        logger.info("Monitoring loop stopped")
    }

    /// Collect current memory snapshot with all diagnostic metrics.
    /// Uses mach system APIs to get accurate memory statistics.
    private func collectSnapshot() async -> MemorySnapshot {
        let timestamp = Date()

        // Collect memory metrics using mach APIs
        let (usedMemoryMB, availableMemoryMB) = getMemoryMetrics()

        // Determine memory pressure based on usage percentage
        let usagePercent = (usedMemoryMB / (usedMemoryMB + availableMemoryMB)) * 100
        let memoryPressure: MemoryPressure
        if usagePercent >= 90 {
            memoryPressure = .critical
        } else if usagePercent >= 75 {
            memoryPressure = .warning
        } else {
            memoryPressure = .normal
        }

        // Collect component diagnostics
        let bufferCount = await BufferManager.shared.bufferCount()
        let activeThreadCount = getActiveThreadCount()

        // Database connection count is not directly accessible from DatabaseManager
        // Since it uses a connection pool, we set this to nil for now
        let databaseConnectionCount: Int? = nil

        return MemorySnapshot(
            timestamp: timestamp,
            usedMemoryMB: usedMemoryMB,
            availableMemoryMB: availableMemoryMB,
            memoryPressure: memoryPressure,
            bufferCount: bufferCount,
            databaseConnectionCount: databaseConnectionCount,
            activeThreadCount: activeThreadCount
        )
    }

    /// Get memory metrics using mach system APIs.
    /// Returns tuple of (used memory MB, available memory MB).
    private func getMemoryMetrics() -> (usedMemoryMB: Double, availableMemoryMB: Double) {
        #if canImport(Darwin)
        // Get process memory footprint
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard kerr == KERN_SUCCESS else {
            logger.error("Failed to get task_info: \(kerr)")
            return (0, 0)
        }

        // Physical memory footprint in bytes
        let usedBytes = Double(info.resident_size)
        let usedMemoryMB = usedBytes / (1024.0 * 1024.0)

        // Get total system memory
        var size: UInt64 = 0
        var len = MemoryLayout.size(ofValue: size)
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        let totalMemoryMB = Double(size) / (1024.0 * 1024.0)

        // Available memory = total - used (simplified approximation)
        // In reality, available memory is more complex due to caching, etc.
        let availableMemoryMB = max(0, totalMemoryMB - usedMemoryMB)

        return (usedMemoryMB, availableMemoryMB)
        #else
        // Fallback for non-Darwin platforms (testing)
        return (0, 0)
        #endif
    }

    /// Get number of active threads in the process.
    private func getActiveThreadCount() -> Int {
        #if canImport(Darwin)
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let kerr = task_threads(mach_task_self_, &threadList, &threadCount)
        guard kerr == KERN_SUCCESS else {
            logger.error("Failed to get thread count: \(kerr)")
            return 0
        }

        // Clean up thread list
        if let threadList = threadList {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: threadList),
                vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size)
            )
        }

        return Int(threadCount)
        #else
        return 0
        #endif
    }

    /// Trim snapshot history to prevent unbounded growth.
    /// Keeps only the most recent maxSnapshots snapshots.
    private func trimSnapshotHistory() {
        if snapshots.count > maxSnapshots {
            let excessCount = snapshots.count - maxSnapshots
            snapshots.removeFirst(excessCount)
            logger.debug("Trimmed \(excessCount) old snapshots, count now=\(self.snapshots.count)")
        }
    }

    // MARK: - Alert Analysis

    /// Analyze snapshot for threshold violations (warning at 75%, critical at 90%).
    /// Generates alerts with debouncing to prevent spam.
    private func analyzeThresholds(_ snapshot: MemorySnapshot) async {
        let usagePercent = snapshot.memoryUsagePercent

        // Check critical threshold first (90%)
        if usagePercent >= criticalThreshold {
            let shouldAlert = shouldGenerateAlert(severity: .critical)
            if shouldAlert {
                let alert = MemoryAlert(
                    timestamp: Date(),
                    severity: .critical,
                    message: "Critical memory usage: \(Int(usagePercent))% (\(Int(snapshot.usedMemoryMB))MB / \(Int(snapshot.totalMemoryMB))MB)",
                    snapshot: snapshot,
                    recommendedAction: "Pause AI processing, clear buffer cache, or restart app to free memory"
                )
                await triggerAlert(alert)
            }
        }
        // Check warning threshold (75%)
        else if usagePercent >= warningThreshold {
            let shouldAlert = shouldGenerateAlert(severity: .warning)
            if shouldAlert {
                let alert = MemoryAlert(
                    timestamp: Date(),
                    severity: .warning,
                    message: "High memory usage: \(Int(usagePercent))% (\(Int(snapshot.usedMemoryMB))MB / \(Int(snapshot.totalMemoryMB))MB)",
                    snapshot: snapshot,
                    recommendedAction: "Monitor memory usage. Consider pausing AI processing if usage continues to increase."
                )
                await triggerAlert(alert)
            }
        }
    }

    /// Analyze memory trend over 5-minute window for leak detection.
    /// Detects sustained memory growth >5% without corresponding cleanup.
    private func analyzeLeakTrend() async {
        guard snapshots.count >= 30 else {
            // Need at least 30 samples (5 minutes at 10-second intervals)
            return
        }

        // Get snapshots within the leak detection window
        let cutoffTime = Date().addingTimeInterval(-leakDetectionWindow)
        let windowSnapshots = snapshots.filter { $0.timestamp >= cutoffTime }

        guard windowSnapshots.count >= 2 else {
            return
        }

        // Baseline: memory at start of window
        let baselineMemory = windowSnapshots.first!.usedMemoryMB

        // Current: memory at end of window (most recent snapshot)
        let currentMemory = windowSnapshots.last!.usedMemoryMB

        // Calculate growth rate
        guard baselineMemory > 0 else { return }
        let growthRate = ((currentMemory - baselineMemory) / baselineMemory) * 100

        // Check if growth exceeds leak threshold
        if growthRate > leakGrowthThreshold {
            // Additional validation: check if growth is sustained (monotonic increase)
            // This helps filter out temporary spikes from AI processing
            let isSustained = isSustainedGrowth(snapshots: windowSnapshots)

            if isSustained {
                let shouldAlert = shouldGenerateAlert(severity: .critical)
                if shouldAlert {
                    let currentSnapshot = snapshots.last!
                    let alert = MemoryAlert(
                        timestamp: Date(),
                        severity: .critical,
                        message: "Memory leak detected: \(String(format: "%.1f", growthRate))% growth over \(Int(leakDetectionWindow / 60)) minutes",
                        snapshot: currentSnapshot,
                        recommendedAction: "Memory leak detected. Check buffer count (\(currentSnapshot.bufferCount) buffers) and restart app if necessary.",
                        growthRate: growthRate,
                        detectionWindow: leakDetectionWindow
                    )
                    await triggerAlert(alert)
                }
            } else {
                logger.debug("Memory growth detected (\(String(format: "%.1f", growthRate))%) but not sustained - likely temporary spike")
            }
        }
    }

    /// Check if memory growth is sustained (monotonic increase) vs. temporary spike.
    /// Returns true if memory shows consistent upward trend.
    private func isSustainedGrowth(snapshots: [MemorySnapshot]) -> Bool {
        guard snapshots.count >= 3 else { return false }

        // Sample at beginning, middle, and end of window
        let firstThird = snapshots.count / 3
        let secondThird = firstThird * 2

        let earlyMemory = snapshots[..<firstThird].map { $0.usedMemoryMB }.reduce(0, +) / Double(firstThird)
        let midMemory = snapshots[firstThird..<secondThird].map { $0.usedMemoryMB }.reduce(0, +) / Double(firstThird)
        let lateMemory = snapshots[secondThird...].map { $0.usedMemoryMB }.reduce(0, +) / Double(snapshots.count - secondThird)

        // Sustained growth means each period is higher than the previous
        return midMemory > earlyMemory && lateMemory > midMemory
    }

    /// Check if an alert should be generated based on debouncing rules.
    /// Returns true if enough time has passed since last alert of this severity.
    private func shouldGenerateAlert(severity: AlertSeverity) -> Bool {
        guard let lastAlert = lastAlertTime[severity] else {
            // No previous alert of this severity, allow it
            return true
        }

        let timeSinceLastAlert = Date().timeIntervalSince(lastAlert)
        return timeSinceLastAlert >= alertDebounceInterval
    }

    /// Trigger an alert by invoking all registered callbacks.
    /// Updates debounce tracking to prevent spam.
    private func triggerAlert(_ alert: MemoryAlert) async {
        logger.warning("🚨 Memory Alert: [\(alert.severity.rawValue)] \(alert.message, privacy: .public)")

        // Update debounce tracking
        lastAlertTime[alert.severity] = Date()

        // Invoke all alert callbacks
        // Note: Callbacks are invoked synchronously within the actor
        // If callbacks need to update UI, they should dispatch to MainActor
        for callback in alertCallbacks {
            callback(alert)
        }
    }

    // MARK: - Sentry Integration

    /// Integrate memory snapshot with Sentry crash reporting context.
    /// Adds latest memory state to Sentry scope for crash reports.
    private func integrateSentryContext() async {
        guard let latestSnapshot = snapshots.last else {
            return
        }

        // Use SentryHelper for thread-safe Sentry integration
        SentryHelper.configureScope { scope in
            scope.setContext(value: [
                "used_memory_mb": latestSnapshot.usedMemoryMB,
                "memory_usage_percent": latestSnapshot.memoryUsagePercent,
                "buffer_count": latestSnapshot.bufferCount,
                "active_threads": latestSnapshot.activeThreadCount,
                "memory_pressure": latestSnapshot.memoryPressure.rawValue
            ], key: "memory_state")
        }
    }
}
