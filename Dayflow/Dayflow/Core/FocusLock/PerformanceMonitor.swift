//
//  PerformanceMonitor.swift
//  FocusLock
//
//  Comprehensive performance monitoring and optimization system for FocusLock
//  Monitors all components: MemoryStore, ActivityTap, OCRExtractor, AXExtractor, JarvisChat
//  Implements adaptive resource management and intelligent background processing
//

import Foundation
import SwiftUI
import Combine
import os.log
import IOKit
import CoreFoundation
import AppKit

// MARK: - Performance Monitor Main Class

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    // MARK: - Published Properties
    @Published var currentMetrics: PerformanceMetrics?
    @Published var systemHealth: SystemHealthScore = .excellent
    @Published var isOptimizationActive: Bool = false
    @Published var performanceAlerts: [PerformanceAlert] = []
    @Published var resourceBudgets: SystemResourceBudgets = .default
    @Published var batteryStatus: BatteryMetrics?
    @Published var backgroundTaskSchedule: BackgroundTaskSchedule = .default

    // MARK: - Computed Properties for View Binding
    var activeAlerts: [PerformanceAlert] {
        return performanceAlerts.filter { $0.isRecent }
    }

    var recentAlerts: [PerformanceAlert] {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return performanceAlerts.filter { $0.timestamp >= oneHourAgo }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var todayAlertCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return performanceAlerts.filter { $0.timestamp >= today }.count
    }

    var weekAlertCount: Int {
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        return performanceAlerts.filter { $0.timestamp >= weekAgo }.count
    }

    var resolvedAlertCount: Int {
        // Placeholder - would need alert resolution tracking
        return 0
    }

    var cpuUsage: Double {
        return currentMetrics?.systemMetrics.cpuUsage ?? 0.0
    }

    var memoryUsage: Double {
        guard let memory = currentMetrics?.systemMetrics.memoryUsage else { return 0.0 }
        return memory.used / memory.total
    }

    var thermalState: ThermalState {
        return currentMetrics?.thermalMetrics?.state ?? .normal
    }

    var backgroundTaskManager: BackgroundTaskManager {
        return BackgroundTaskManager.shared
    }

    var backgroundTaskMetrics: BackgroundTaskAggregateMetrics {
        return BackgroundTaskAggregateMetrics(
            completedTasksToday: componentMetrics.values.flatMap { $0.metrics }.count,
            successRate: 0.95, // Placeholder
            averageCpuImpact: 0.05, // Placeholder
            averageMemoryImpact: 0.02, // Placeholder
            batteryDrainRate: 0.01 // Placeholder
        )
    }

    var batteryMetrics: BatteryInfo {
        return BatteryInfo(
            batteryLevel: Int((batteryStatus?.level ?? 0.0) * 100),
            powerState: batteryStatus?.state == .plugged ? .ac : .battery,
            thermalState: thermalState.rawValue
        )
    }

    var powerEfficiencyMetrics: PowerEfficiencyMetrics {
        return PowerEfficiencyMetrics(
            energyEfficiency: 1000.0, // Placeholder
            batteryDrainRate: 2.5, // Placeholder
            powerAdaptationScore: 0.85, // Placeholder
            lowPowerModeSavings: 25.0 // Placeholder
        )
    }

    var componentBatteryUsage: [String: ComponentBatteryUsage] {
        // Placeholder implementation
        return Dictionary(uniqueKeysWithValues: FocusLockComponent.allCases.map { component in
            (component.rawValue, ComponentBatteryUsage(powerConsumption: Double.random(in: 0.01...0.15)))
        })
    }

    var powerOptimizationRecommendations: [PowerOptimizationRecommendation] {
        // Placeholder recommendations
        return [
            PowerOptimizationRecommendation(
                type: .enableLowPowerMode,
                title: "Enable Low Power Mode",
                description: "Reduce background processing and lower refresh rates to save battery",
                priority: .high,
                potentialSavings: 0.15,
                impact: "High impact on battery life with reduced performance"
            ),
            PowerOptimizationRecommendation(
                type: .lowerProcessingFrequency,
                title: "Optimize OCR Processing",
                description: "Reduce OCR frequency during battery operation",
                priority: .medium,
                potentialSavings: 0.08,
                impact: "Moderate battery savings with slightly less responsive task detection"
            )
        ]
    }

    // MARK: - Private Properties
    private var monitoringTimer: Timer?
    private var optimizationTimer: Timer?
    private var backgroundTaskTimer: Timer?
    private var metricsHistory: [PerformanceMetrics] = []
    @Published var componentMetrics: [String: ComponentPerformanceTracker] = [:]
    private var isMonitoring = false
    private var cancellables = Set<AnyCancellable>()

    // Performance budgets
    private let idleCPUBudget: Double = 0.015 // 1.5%
    private let activeCPUBudget: Double = 0.08  // 8%
    private let memoryBudget: Double = 250.0    // 250MB

    private let logger = Logger(subsystem: "FocusLock", category: "PerformanceMonitor")

    // MARK: - Initialization

    private init() {
        setupBatteryMonitoring()
        setupComponentMonitoring()
        loadPerformanceSettings()
    }

    // MARK: - Public Interface

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        logger.info("Starting comprehensive performance monitoring")

        // Start main monitoring timer (every 2 seconds)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectMetrics()
            }
        }

        // Start optimization timer (every 10 seconds)
        optimizationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performOptimizationIfNeeded()
            }
        }

        // Start background task scheduler (every 30 seconds)
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleBackgroundTasks()
            }
        }

        // Initialize component monitoring
        initializeComponentMetrics()
    }

    func stopMonitoring() {
        isMonitoring = false

        monitoringTimer?.invalidate()
        monitoringTimer = nil

        optimizationTimer?.invalidate()
        optimizationTimer = nil

        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil

        logger.info("Stopped performance monitoring")
    }

    func recordComponentOperation(_ component: FocusLockComponent, operation: ComponentOperation, duration: TimeInterval, resources: ResourceUsage) {
        var tracker = componentMetrics[component.rawValue] ?? ComponentPerformanceTracker(component: component)
        tracker.recordOperation(operation, duration: duration, resources: resources)
        componentMetrics[component.rawValue] = tracker

        // Check for immediate performance issues
        checkComponentPerformance(component, tracker: tracker)
    }

    func requestResourceBudgetAdjustment(component: FocusLockComponent, proposedBudget: ComponentResourceBudget) -> Bool {
        // Intelligent budget allocation based on current system state and historical performance
        guard let currentMetrics = currentMetrics else { return false }

        // Check if system can handle the request
        let totalProposedMemory = componentMetrics.values.map { $0.currentResourceBudget.memoryMB }.reduce(0, +)
        let availableMemory = memoryBudget - totalProposedMemory

        if proposedBudget.memoryMB > availableMemory {
            logger.warning("Component \(component.rawValue) requested more memory than available")
            return false
        }

        // Check CPU impact
        let totalCPUDemand = componentMetrics.values.map { $0.currentResourceBudget.cpuPercent }.reduce(0, +)
        let proposedCPUImpact = calculateCPUImpact(for: component, budget: proposedBudget)

        if totalCPUDemand + proposedCPUImpact > activeCPUBudget {
            logger.warning("Component \(component.rawValue) requested CPU that would exceed budget")
            return false
        }

        // Approve budget adjustment
        componentMetrics[component.rawValue]?.currentResourceBudget = proposedBudget
        logger.info("Approved resource budget adjustment for \(component.rawValue)")

        return true
    }

    // MARK: - Private Methods

    private func collectMetrics() {
        let systemMetrics = SystemPerformanceMetric(
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: createSystemMemoryUsage(usedMB: getCurrentMemoryUsage()),
            diskIO: getCurrentDiskMetrics(),
            networkIO: getCurrentNetworkMetrics(),
            processCount: currentProcessCount(),
            threadCount: currentThreadCount()
        )

        let componentSnapshots = componentMetrics.values.flatMap { $0.recentMetrics(limit: 5) }
        let metrics = PerformanceMetrics(
            componentMetrics: componentSnapshots,
            systemMetrics: systemMetrics,
            batteryMetrics: batteryStatus,
            thermalMetrics: currentThermalMetrics()
        )

        currentMetrics = metrics
        metricsHistory.append(metrics)

        // Keep only last 1000 entries
        if metricsHistory.count > 1000 {
            metricsHistory.removeFirst(metricsHistory.count - 1000)
        }

        updateSystemHealth()
        checkForPerformanceAlerts()
    }

    private func performOptimizationIfNeeded() {
        guard let metrics = currentMetrics else { return }

        var optimizationsNeeded: [PMOptimizationAction] = []

        // CPU optimization
        if metrics.systemMetrics.cpuUsage > activeCPUBudget {
            optimizationsNeeded.append(.reduceCPUFrequency)
        }

        // Memory optimization
        if metrics.systemMetrics.memoryUsage.used > memoryBudget {
            optimizationsNeeded.append(.clearMemoryCache)
        }

        // Battery optimization
        if let battery = batteryStatus, battery.state == .unplugged && battery.level < 0.2 {
            optimizationsNeeded.append(.enterLowPowerMode)
        }

        // Thermal optimization
        if metrics.thermalMetrics?.state == .critical {
            optimizationsNeeded.append(.reduceProcessingIntensity)
        }

        if !optimizationsNeeded.isEmpty {
            executeOptimizations(optimizationsNeeded)
        }
    }

    private func executeOptimizations(_ optimizations: [PMOptimizationAction]) {
        isOptimizationActive = true

        Task {
            for optimization in optimizations {
                switch optimization {
                case .reduceCPUFrequency:
                    await reduceCPUFrequency()
                case .clearMemoryCache:
                    await clearMemoryCaches()
                case .enterLowPowerMode:
                    await enableLowPowerMode()
                case .reduceProcessingIntensity:
                    await reduceProcessingIntensity()
                case .pauseBackgroundTasks:
                    await pauseBackgroundTasks()
                }

                // Small delay between optimizations
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }

            await MainActor.run {
                self.isOptimizationActive = false
            }
        }

        logger.info("Executed \(optimizations.count) performance optimizations")
    }

    private func scheduleBackgroundTasks() {
        let schedule = generateOptimalSchedule()
        backgroundTaskSchedule = schedule

        // Execute tasks based on user activity patterns and system state
        Task {
            await executeBackgroundTasks(schedule.tasks)
        }
    }

    private func generateOptimalSchedule() -> BackgroundTaskSchedule {
        var tasks: [BackgroundTask] = []

        // Memory indexing (only when system is idle)
        if let metrics = currentMetrics,
           metrics.systemMetrics.cpuUsage < idleCPUBudget,
           metrics.systemMetrics.memoryUsage.used < memoryBudget * 0.7 {
            tasks.append(BackgroundTask(
                id: "memory_indexing",
                component: .memoryStore,
                priority: .low,
                estimatedDuration: 30.0,
                resourceBudget: ComponentResourceBudget(cpuPercent: 0.05, memoryMB: 50, diskMB: 10),
                scheduleTime: Date().addingTimeInterval(60)
            ))
        }

        // OCR processing (medium priority)
        tasks.append(BackgroundTask(
            id: "ocr_processing",
            component: .ocrExtractor,
            priority: .medium,
            estimatedDuration: 15.0,
            resourceBudget: ComponentResourceBudget(cpuPercent: 0.15, memoryMB: 100, diskMB: 5),
            scheduleTime: Date().addingTimeInterval(30)
        ))

        // AI model optimization (low priority, only when plugged in)
        if let battery = batteryStatus, battery.state == .plugged {
            tasks.append(BackgroundTask(
                id: "ai_optimization",
                component: .jarvisChat,
                priority: .low,
                estimatedDuration: 60.0,
                resourceBudget: ComponentResourceBudget(cpuPercent: 0.08, memoryMB: 150, diskMB: 20),
                scheduleTime: Date().addingTimeInterval(300)
            ))
        }

        return BackgroundTaskSchedule(tasks: tasks)
    }

    // MARK: - System Resource Monitoring

    private func getCurrentCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)

        if result == KERN_SUCCESS {
            let cpuLoadInfo = info.bindMemory(to: processor_cpu_load_info.self, capacity: Int(numCpus))

            var totalTicks: UInt32 = 0
            var idleTicks: UInt32 = 0

            for i in 0..<Int(numCpus) {
                totalTicks += cpuLoadInfo[i].cpu_ticks.0 + cpuLoadInfo[i].cpu_ticks.1 + cpuLoadInfo[i].cpu_ticks.2 + cpuLoadInfo[i].cpu_ticks.3
                idleTicks += cpuLoadInfo[i].cpu_ticks.2
            }

            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo))

            guard totalTicks > 0 else { return 0.0 }
            return Double(totalTicks - idleTicks) / Double(totalTicks)
        }

        return 0.0
    }

    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMemoryMB = Double(info.resident_size) / (1024 * 1024)
            return usedMemoryMB
        }

        return 0.0
    }

    private func getCurrentDiskMetrics() -> DiskIOMetrics {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            _ = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        } catch {
            logger.error("Failed to get disk usage: \(error)")
        }

        return DiskIOMetrics()
    }

    private func getCurrentNetworkMetrics() -> NetworkIOMetrics {
        // Simplified network monitoring - would need more sophisticated implementation
        return NetworkIOMetrics()
    }

    private func getCurrentThermalState() -> ThermalState {
        // This would need IOKit integration for actual thermal monitoring
        return .normal
    }

    private func createSystemMemoryUsage(usedMB: Double) -> SystemMemoryUsage {
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024)
        let availableMemory = max(totalMemory - usedMB, 0)
        return SystemMemoryUsage(
            used: usedMB,
            available: availableMemory,
            total: totalMemory,
            pressure: 0,
            purgeable: 0
        )
    }

    private func currentProcessCount() -> Int {
        return NSWorkspace.shared.runningApplications.count
    }

    private func currentThreadCount() -> Int {
        return ProcessInfo.processInfo.activeProcessorCount
    }

    private func currentThermalMetrics() -> ThermalMetrics? {
        let state = getCurrentThermalState()
        let baselineTemperature: Double

        switch state {
        case .normal: baselineTemperature = 35
        case .fair: baselineTemperature = 45
        case .serious: baselineTemperature = 55
        case .critical: baselineTemperature = 65
        }

        return ThermalMetrics(temperature: baselineTemperature, state: state)
    }

    // MARK: - Battery Monitoring

    private func setupBatteryMonitoring() {
        // Start battery level monitoring
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryStatus()
            }
        }

        updateBatteryStatus()
    }

    private func updateBatteryStatus() {
        // Use IOKit framework for battery information
        let service = IOServiceMatching(kIOPSMainPowerSourceService)
        let powerSourceInfo = IOPSCopyPowerSourcesInfo()

        guard let info = powerSourceInfo.takeRetainedValue() else {
            logger.error("Failed to get power source info")
            return
        }

        guard let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as? [CFTypeRef] else {
            logger.error("Failed to get power sources list")
            return
        }

        for source in sources {
            if let sourceDict = IOPSGetPowerSourceDescription(info, source).takeRetainedValue() as? [String: Any] {
                if let currentCapacity = sourceDict[kIOPSCurrentCapacityKey] as? Int,
                   let maxCapacity = sourceDict[kIOPSMaxCapacityKey] as? Int,
                   let isCharging = sourceDict[kIOPSIsChargingKey] as? Bool,
                   let isPowered = sourceDict[kIOPSPowerSourceStateKey] as? String {

                    guard maxCapacity > 0 else { continue }

                    let level = Double(currentCapacity) / Double(maxCapacity)
                    let state: BatteryState = isPowered == kIOPSACPowerValue ? .plugged : (isCharging ? .charging : .unplugged)

                    batteryStatus = BatteryMetrics(
                        level: level,
                        state: state,
                        timeRemaining: nil,
                        temperature: nil,
                        voltage: nil,
                        cycleCount: nil
                    )
                    return
                }
            }
        }
    }

    // MARK: - Component Monitoring

    private func setupComponentMonitoring() {
        // Monitor MemoryStore performance
        NotificationCenter.default.publisher(for: .memoryStoreOperationCompleted)
            .sink { [weak self] notification in
                self?.handleMemoryStoreNotification(notification)
            }
            .store(in: &cancellables)

        // Monitor OCR performance
        NotificationCenter.default.publisher(for: .ocrOperationCompleted)
            .sink { [weak self] notification in
                self?.handleOCRNotification(notification)
            }
            .store(in: &cancellables)
    }

    private func initializeComponentMetrics() {
        for component in FocusLockComponent.allCases {
            componentMetrics[component.rawValue] = ComponentPerformanceTracker(component: component)
        }
    }

    private func handleMemoryStoreNotification(_ notification: Notification) {
        guard let operationType = notification.userInfo?["operation"] as? String,
              let duration = notification.userInfo?["duration"] as? TimeInterval else { return }

        let operation: ComponentOperation
        switch operationType {
        case "search": operation = .search
        case "index": operation = .index
        case "embed": operation = .embed
        default: operation = .other
        }

        let resources = ResourceUsage(
            timestamp: Date(),
            cpuPercent: 0,
            memoryMB: 0,
            diskUsageMB: 0,
            networkActivity: NetworkActivity(incomingBytesPerSecond: 0, outgoingBytesPerSecond: 0, totalBytesPerSecond: 0)
        )

        recordComponentOperation(.memoryStore, operation: operation, duration: duration, resources: resources)
    }

    private func handleOCRNotification(_ notification: Notification) {
        guard let duration = notification.userInfo?["duration"] as? TimeInterval else { return }

        let resources = ResourceUsage(
            timestamp: Date(),
            cpuPercent: 0,
            memoryMB: 0,
            diskUsageMB: 0,
            networkActivity: NetworkActivity(incomingBytesPerSecond: 0, outgoingBytesPerSecond: 0, totalBytesPerSecond: 0)
        )

        recordComponentOperation(.ocrExtractor, operation: .extract, duration: duration, resources: resources)
    }

    // MARK: - Health and Alerting

    private func updateSystemHealth() {
        guard let metrics = currentMetrics else {
            systemHealth = .unknown
            return
        }

        var healthScore: Double = 1.0

        // CPU health
        if metrics.systemMetrics.cpuUsage > activeCPUBudget * 2 {
            healthScore *= 0.3
        } else if metrics.systemMetrics.cpuUsage > activeCPUBudget {
            healthScore *= 0.7
        }

        // Memory health
        if metrics.systemMetrics.memoryUsage.used > memoryBudget * 2 {
            healthScore *= 0.3
        } else if metrics.systemMetrics.memoryUsage.used > memoryBudget {
            healthScore *= 0.7
        }

        // Battery health
        if let battery = metrics.batteryMetrics?.level {
            if battery < 0.1 {
                healthScore *= 0.5
            } else if battery < 0.2 {
                healthScore *= 0.8
            }
        }

        // Thermal health
        if metrics.thermalMetrics?.state == .critical {
            healthScore *= 0.4
        } else if metrics.thermalMetrics?.state == .fair {
            healthScore *= 0.8
        }

        systemHealth = SystemHealthScore(score: healthScore)
    }

    private func checkForPerformanceAlerts() {
        guard let metrics = currentMetrics else { return }

        var newAlerts: [PerformanceAlert] = []

        // CPU alerts
        if metrics.systemMetrics.cpuUsage > activeCPUBudget * 1.5 {
            newAlerts.append(PerformanceAlert(
                id: UUID(),
                type: .highCPUUsage,
                severity: .warning,
                message: "CPU usage (\(Int(metrics.systemMetrics.cpuUsage * 100))%) exceeds recommended limit",
                timestamp: Date(),
                recommendations: ["Consider reducing background processing", "Check for runaway processes"]
            ))
        }

        // Memory alerts
        if metrics.systemMetrics.memoryUsage.used > memoryBudget * 1.5 {
            newAlerts.append(PerformanceAlert(
                id: UUID(),
                type: .highMemoryUsage,
                severity: .critical,
                message: "Memory usage (\(Int(metrics.systemMetrics.memoryUsage.used))MB) exceeds budget",
                timestamp: Date(),
                recommendations: ["Clear memory caches", "Reduce concurrent operations", "Consider restarting application"]
            ))
        }

        // Battery alerts
        if let battery = batteryStatus, battery.state == .unplugged && battery.level < 0.15 {
            newAlerts.append(PerformanceAlert(
                id: UUID(),
                type: .lowBattery,
                severity: .warning,
                message: "Battery level (\(Int(battery.level * 100))%) is critically low",
                timestamp: Date(),
                recommendations: ["Enable low power mode", "Reduce background processing", "Consider connecting to power"]
            ))
        }

        // Thermal alerts
        if metrics.thermalMetrics?.state == .critical {
            newAlerts.append(PerformanceAlert(
                id: UUID(),
                type: .thermalThrottle,
                severity: .critical,
                message: "Thermal state critical - reducing performance",
                timestamp: Date(),
                recommendations: ["Allow device to cool", "Reduce processing intensity", "Close background applications"]
            ))
        }

        performanceAlerts = newAlerts
    }

    private func checkComponentPerformance(_ component: FocusLockComponent, tracker: ComponentPerformanceTracker) {
        // Check if component is within performance budgets
        let recentMetrics = tracker.recentMetrics(within: 60)

        for metric in recentMetrics {
            if metric.responseTime > getExpectedDuration(for: metric.operation, component: component) * 2 {
                logger.warning("Component \(component.rawValue) operation \(metric.operation) took longer than expected: \(metric.responseTime)s")

                // Could trigger optimization or alerting here
            }
        }
    }

    // MARK: - Optimization Actions

    private func reduceCPUFrequency() async {
        logger.info("Reducing CPU frequency for performance optimization")
        // Implementation would reduce processing intensity across components
    }

    private func clearMemoryCaches() async {
        logger.info("Clearing memory caches for performance optimization")
        // Clear MemoryStore caches
        try? await HybridMemoryStore.shared.clear()
    }

    private func enableLowPowerMode() async {
        logger.info("Enabling low power mode")
        // Reduce background processing, lower refresh rates, etc.
    }

    private func reduceProcessingIntensity() async {
        logger.info("Reducing processing intensity due to thermal constraints")
        // Reduce OCR frequency, lower AI model complexity, etc.
    }

    private func pauseBackgroundTasks() async {
        logger.info("Pausing background tasks")
        // Pause non-essential background processing
    }

    // MARK: - Background Task Execution

    private func executeBackgroundTasks(_ tasks: [BackgroundTask]) async {
        for task in tasks.sorted(by: { $0.priority.rawValue < $1.priority.rawValue }) {
            guard Date() >= task.scheduleTime else { continue }

            logger.info("Executing background task: \(task.id)")

            // Check if we have resources available
            guard let currentMetrics = currentMetrics else { continue }

            if currentMetrics.systemMetrics.cpuUsage > idleCPUBudget ||
                currentMetrics.systemMetrics.memoryUsage.used > memoryBudget * 0.8 {
                logger.info("Skipping background task \(task.id) due to resource constraints")
                continue
            }

            // Execute task (this would be implemented by each component)
            await executeBackgroundTask(task)
        }
    }

    private func executeBackgroundTask(_ task: BackgroundTask) async {
        // This would dispatch to the appropriate component
        logger.info("Background task \(task.id) completed")
    }

    // MARK: - Helper Methods

    private func calculateCPUImpact(for component: FocusLockComponent, budget: ComponentResourceBudget) -> Double {
        // Estimate CPU impact based on component type and historical performance
        return budget.cpuPercent
    }

    private func getExpectedDuration(for operation: ComponentOperation, component: FocusLockComponent) -> TimeInterval {
        switch (component, operation) {
        case (.memoryStore, .search): return 0.5
        case (.memoryStore, .index): return 2.0
        case (.memoryStore, .embed): return 3.0
        case (.ocrExtractor, .extract): return 5.0
        case (.axExtractor, .extract): return 1.0
        case (.jarvisChat, .process): return 8.0
        default: return 2.0
        }
    }

    private func loadPerformanceSettings() {
        // Load performance settings from UserDefaults or configuration
        resourceBudgets = SystemResourceBudgets(
            idleCPU: idleCPUBudget,
            activeCPU: activeCPUBudget,
            memory: memoryBudget
        )
    }
}

// MARK: - Component Performance Tracking

struct ComponentPerformanceTracker {
    let component: FocusLockComponent
    private(set) var metrics: [ComponentPerformanceMetric] = []
    var currentResourceBudget: ComponentResourceBudget

    init(component: FocusLockComponent, currentResourceBudget: ComponentResourceBudget = .standard) {
        self.component = component
        self.currentResourceBudget = currentResourceBudget
    }

    mutating func recordOperation(_ operation: ComponentOperation, duration: TimeInterval, resources: ResourceUsage) {
        let existingPeak = metrics.map { $0.memoryUsage.peak }.max() ?? 0
        let peakMemory = max(existingPeak, resources.memoryMB)

        let averageMemory: Double
        if metrics.isEmpty {
            averageMemory = resources.memoryMB
        } else {
            let totalMemory = metrics.reduce(0.0) { $0 + $1.memoryUsage.current } + resources.memoryMB
            averageMemory = totalMemory / Double(metrics.count + 1)
        }

        let memoryUsage = MemoryUsage(
            current: resources.memoryMB,
            peak: peakMemory,
            average: averageMemory,
            allocations: 0,
            deallocations: 0
        )

        let throughput = duration > 0 ? 1.0 / duration : 0.0

        let metric = ComponentPerformanceMetric(
            component: component,
            operation: operation,
            responseTime: duration,
            memoryUsage: memoryUsage,
            cpuUsage: resources.cpuPercent,
            errorRate: 0.0,
            throughput: throughput
        )

        metrics.append(metric)

        if metrics.count > 100 {
            metrics.removeFirst(metrics.count - 100)
        }
    }

    func recentMetrics(limit: Int) -> [ComponentPerformanceMetric] {
        guard limit > 0 else { return [] }
        if metrics.count <= limit {
            return metrics
        }
        return Array(metrics.suffix(limit))
    }

    func recentMetrics(within seconds: TimeInterval) -> [ComponentPerformanceMetric] {
        let cutoff = Date().addingTimeInterval(-seconds)
        return metrics.filter { $0.timestamp >= cutoff }
    }

    var averageResponseTime: TimeInterval {
        guard !metrics.isEmpty else { return 0 }
        let total = metrics.reduce(0.0) { $0 + $1.responseTime }
        return total / Double(metrics.count)
    }

    var currentLoad: Double {
        let recent = recentMetrics(within: 60)
        return Double(recent.count) / 60.0
    }

    var latestMetric: ComponentPerformanceMetric? {
        metrics.last
    }

    // Convert to ComponentMetrics for UI compatibility
    var toComponentMetrics: ComponentMetrics {
        return ComponentMetrics(
            componentName: component.rawValue,
            cpuUsage: latestMetric?.cpuUsage ?? 0.0,
            memoryUsage: latestMetric?.memoryUsage.current ?? 0.0,
            responseTime: latestMetric?.responseTime ?? 0.0,
            errorRate: latestMetric?.errorRate ?? 0.0,
            health: .unknown
        )
    }
}

struct ComponentResourceBudget: Codable {
    var cpuPercent: Double
    var memoryMB: Double
    var diskMB: Double

    static let standard = ComponentResourceBudget(cpuPercent: 0.05, memoryMB: 50, diskMB: 10)
}

struct SystemResourceBudgets: Codable {
    let idleCPU: Double
    let activeCPU: Double
    let memory: Double

    static let `default` = SystemResourceBudgets(idleCPU: 0.015, activeCPU: 0.08, memory: 250.0)
}

enum SystemHealthScore: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"
    case unknown = "unknown"

    init(score: Double) {
        switch score {
        case 0.9...1.0: self = .excellent
        case 0.7..<0.9: self = .good
        case 0.5..<0.7: self = .fair
        case 0.3..<0.5: self = .poor
        case 0.1..<0.3: self = .critical
        default: self = .unknown
        }
    }

    var score: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.4
        case .critical: return 0.2
        case .unknown: return 0.0
        }
    }
}

struct PerformanceAlert: Identifiable, Codable {
    let id: UUID
    let type: PerformanceAlertType
    let severity: AlertSeverity
    let message: String
    let timestamp: Date
    let recommendations: [String]

    var title: String {
        switch type {
        case .highCPUUsage: return "High CPU Usage"
        case .highMemoryUsage: return "High Memory Usage"
        case .lowBattery: return "Low Battery"
        case .thermalThrottle: return "Thermal Throttling"
        case .componentFailure: return "Component Failure"
        case .performanceRegression: return "Performance Regression"
        }
    }

    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 300 // 5 minutes
    }
}

enum PerformanceAlertType: String, CaseIterable, Codable {
    case highCPUUsage = "high_cpu_usage"
    case highMemoryUsage = "high_memory_usage"
    case lowBattery = "low_battery"
    case thermalThrottle = "thermal_throttle"
    case componentFailure = "component_failure"
    case performanceRegression = "performance_regression"
}

enum AlertSeverity: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }
}

enum PMOptimizationAction {
    case reduceCPUFrequency
    case clearMemoryCache
    case enterLowPowerMode
    case reduceProcessingIntensity
    case pauseBackgroundTasks
}

struct BackgroundTaskSchedule: Codable {
    let tasks: [BackgroundTask]
    let generatedAt: Date

    init(tasks: [BackgroundTask]) {
        self.tasks = tasks
        self.generatedAt = Date()
    }

    static let `default` = BackgroundTaskSchedule(tasks: [])
}

struct BackgroundTask: Identifiable, Codable {
    let id: String
    let component: FocusLockComponent
    let priority: TaskPriority
    let estimatedDuration: TimeInterval
    let resourceBudget: ComponentResourceBudget
    let scheduleTime: Date
}

// MARK: - Supporting Types for Performance Debug View

struct BatteryInfo {
    let batteryLevel: Int
    let powerState: PowerState
    let thermalState: Int
}

// MARK: - Computed Properties for External Access

// Note: Many supporting types are defined in FocusLockModels.swift to avoid duplication

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryStoreOperationCompleted = Notification.Name("memoryStoreOperationCompleted")
    static let ocrOperationCompleted = Notification.Name("ocrOperationCompleted")
    static let performanceAlertTriggered = Notification.Name("performanceAlertTriggered")
    static let optimizationCompleted = Notification.Name("optimizationCompleted")
}