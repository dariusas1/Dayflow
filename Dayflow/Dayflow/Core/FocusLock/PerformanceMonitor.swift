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

// MARK: - Performance Monitor Main Class

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    // MARK: - Published Properties
    @Published var currentMetrics: PerformanceMetrics?
    @Published var systemHealth: SystemHealthScore = .excellent
    @Published var isOptimizationActive: Bool = false
    @Published var performanceAlerts: [PerformanceAlert] = []
    @Published var resourceBudgets: ResourceBudgets = .default
    @Published var batteryStatus: BatteryStatus?
    @Published var backgroundTaskSchedule: BackgroundTaskSchedule = .default

    // MARK: - Private Properties
    private var monitoringTimer: Timer?
    private var optimizationTimer: Timer?
    private var backgroundTaskTimer: Timer?
    private var metricsHistory: [PerformanceMetrics] = []
    private var componentMetrics: [String: ComponentMetrics] = [:]
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
        var metrics = componentMetrics[component.rawValue] ?? ComponentMetrics(component: component)
        metrics.recordOperation(operation, duration: duration, resources: resources)
        componentMetrics[component.rawValue] = metrics

        // Check for immediate performance issues
        checkComponentPerformance(component, metrics: metrics)
    }

    func requestResourceBudgetAdjustment(component: FocusLockComponent, proposedBudget: ResourceBudget) -> Bool {
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
        let metrics = PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            diskUsage: getCurrentDiskUsage(),
            networkUsage: getCurrentNetworkUsage(),
            batteryLevel: batteryStatus?.level,
            batteryState: batteryStatus?.state,
            thermalState: getCurrentThermalState(),
            componentMetrics: componentMetrics
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

        var optimizationsNeeded: [OptimizationAction] = []

        // CPU optimization
        if metrics.cpuUsage > activeCPUBudget {
            optimizationsNeeded.append(.reduceCPUFrequency)
        }

        // Memory optimization
        if metrics.memoryUsage > memoryBudget {
            optimizationsNeeded.append(.clearMemoryCache)
        }

        // Battery optimization
        if let battery = batteryStatus, battery.state == .unplugged && battery.level < 0.2 {
            optimizationsNeeded.append(.enterLowPowerMode)
        }

        // Thermal optimization
        if metrics.thermalState == .critical {
            optimizationsNeeded.append(.reduceProcessingIntensity)
        }

        if !optimizationsNeeded.isEmpty {
            executeOptimizations(optimizationsNeeded)
        }
    }

    private func executeOptimizations(_ optimizations: [OptimizationAction]) {
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
        if let metrics = currentMetrics, metrics.cpuUsage < idleCPUBudget && metrics.memoryUsage < memoryBudget * 0.7 {
            tasks.append(BackgroundTask(
                id: "memory_indexing",
                component: .memoryStore,
                priority: .low,
                estimatedDuration: 30.0,
                resourceBudget: ResourceBudget(cpuPercent: 0.05, memoryMB: 50, diskMB: 10),
                scheduleTime: Date().addingTimeInterval(60)
            ))
        }

        // OCR processing (medium priority)
        tasks.append(BackgroundTask(
            id: "ocr_processing",
            component: .ocrExtractor,
            priority: .medium,
            estimatedDuration: 15.0,
            resourceBudget: ResourceBudget(cpuPercent: 0.15, memoryMB: 100, diskMB: 5),
            scheduleTime: Date().addingTimeInterval(30)
        ))

        // AI model optimization (low priority, only when plugged in)
        if let battery = batteryStatus, battery.state == .plugged {
            tasks.append(BackgroundTask(
                id: "ai_optimization",
                component: .jarvisChat,
                priority: .low,
                estimatedDuration: 60.0,
                resourceBudget: ResourceBudget(cpuPercent: 0.08, memoryMB: 150, diskMB: 20),
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

    private func getCurrentDiskUsage() -> Double {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = resourceValues.volumeAvailableCapacityForImportantUsage {
                return Double(available) / (1024 * 1024) // Convert to MB
            }
        } catch {
            logger.error("Failed to get disk usage: \(error)")
        }

        return 0.0
    }

    private func getCurrentNetworkUsage() -> NetworkUsage {
        // Simplified network monitoring - would need more sophisticated implementation
        return NetworkUsage(
            bytesReceived: 0,
            bytesSent: 0,
            timestamp: Date()
        )
    }

    private func getCurrentThermalState() -> ThermalState {
        // This would need IOKit integration for actual thermal monitoring
        return .normal
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
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array

        for source in sources {
            let sourceDict = IOPSGetPowerSourceDescription(info, source).takeRetainedValue() as [String: Any]

            if let currentCapacity = sourceDict[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = sourceDict[kIOPSMaxCapacityKey] as? Int,
               let isCharging = sourceDict[kIOPSIsChargingKey] as? Bool,
               let isPowered = sourceDict[kIOPSPowerSourceStateKey] as? String {

                let level = Double(currentCapacity) / Double(maxCapacity)
                let state: BatteryState = isPowered == kIOPSACPowerValue ? .plugged : (isCharging ? .charging : .unplugged)

                batteryStatus = BatteryStatus(level: level, state: state, timeRemaining: nil)
                return
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
            componentMetrics[component.rawValue] = ComponentMetrics(component: component)
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
        if metrics.cpuUsage > activeCPUBudget * 2 {
            healthScore *= 0.3
        } else if metrics.cpuUsage > activeCPUBudget {
            healthScore *= 0.7
        }

        // Memory health
        if metrics.memoryUsage > memoryBudget * 2 {
            healthScore *= 0.3
        } else if metrics.memoryUsage > memoryBudget {
            healthScore *= 0.7
        }

        // Battery health
        if let battery = metrics.batteryLevel {
            if battery < 0.1 {
                healthScore *= 0.5
            } else if battery < 0.2 {
                healthScore *= 0.8
            }
        }

        // Thermal health
        if metrics.thermalState == .critical {
            healthScore *= 0.4
        } else if metrics.thermalState == .fair {
            healthScore *= 0.8
        }

        systemHealth = SystemHealthScore(score: healthScore)
    }

    private func checkForPerformanceAlerts() {
        guard let metrics = currentMetrics else { return }

        var newAlerts: [PerformanceAlert] = []

        // CPU alerts
        if metrics.cpuUsage > activeCPUBudget * 1.5 {
            newAlerts.append(PerformanceAlert(
                id: UUID(),
                type: .highCPUUsage,
                severity: .warning,
                message: "CPU usage (\(Int(metrics.cpuUsage * 100))%) exceeds recommended limit",
                timestamp: Date(),
                recommendations: ["Consider reducing background processing", "Check for runaway processes"]
            ))
        }

        // Memory alerts
        if metrics.memoryUsage > memoryBudget * 1.5 {
            newAlerts.append(PerformanceAlert(
                id: UUID(),
                type: .highMemoryUsage,
                severity: .critical,
                message: "Memory usage (\(Int(metrics.memoryUsage))MB) exceeds budget",
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

        performanceAlerts = newAlerts
    }

    private func checkComponentPerformance(_ component: FocusLockComponent, metrics: ComponentMetrics) {
        // Check if component is within performance budgets
        let recentOperations = metrics.recentOperations(prefix: 60) // Last minute

        for operation in recentOperations {
            if operation.duration > getExpectedDuration(for: operation.type, component: component) * 2 {
                logger.warning("Component \(component.rawValue) operation \(operation.type) took longer than expected: \(operation.duration)s")

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

            if currentMetrics.cpuUsage > idleCPUBudget || currentMetrics.memoryUsage > memoryBudget * 0.8 {
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

    private func calculateCPUImpact(for component: FocusLockComponent, budget: ResourceBudget) -> Double {
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
        resourceBudgets = ResourceBudgets(
            idleCPU: idleCPUBudget,
            activeCPU: activeCPUBudget,
            memory: memoryBudget
        )
    }
}

// MARK: - Performance Data Models

struct PerformanceMetrics: Codable {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let networkUsage: NetworkUsage
    let batteryLevel: Double?
    let batteryState: BatteryState?
    let thermalState: ThermalState
    let componentMetrics: [String: ComponentMetrics]

    var isWithinBudgets: Bool {
        return cpuUsage < 0.08 && memoryUsage < 250.0 // Basic budget check
    }

    var performanceScore: Double {
        var score: Double = 1.0

        if cpuUsage > 0.08 { score *= 0.7 }
        if memoryUsage > 250.0 { score *= 0.7 }
        if thermalState == .critical { score *= 0.5 }

        return score
    }
}

struct ComponentMetrics: Codable {
    let component: FocusLockComponent
    var operations: [ComponentOperationRecord] = []
    var currentResourceBudget: ResourceBudget = ResourceBudget(cpuPercent: 0.05, memoryMB: 50, diskMB: 10)

    init(component: FocusLockComponent) {
        self.component = component
    }

    mutating func recordOperation(_ operation: ComponentOperation, duration: TimeInterval, resources: ResourceUsage) {
        let record = ComponentOperationRecord(
            operation: operation,
            duration: duration,
            resources: resources,
            timestamp: Date()
        )

        operations.append(record)

        // Keep only last 100 operations
        if operations.count > 100 {
            operations.removeFirst(operations.count - 100)
        }
    }

    func recentOperations(prefix seconds: TimeInterval = 300) -> [ComponentOperationRecord] {
        let cutoff = Date().addingTimeInterval(-seconds)
        return operations.filter { $0.timestamp >= cutoff }
    }

    var averageResponseTime: TimeInterval {
        guard !operations.isEmpty else { return 0 }
        return operations.reduce(0) { $0 + $1.duration } / Double(operations.count)
    }

    var currentLoad: Double {
        recentOperations(prefix: 60).count / 60.0 // Operations per second
    }
}

struct ComponentOperationRecord: Codable {
    let operation: ComponentOperation
    let duration: TimeInterval
    let resources: ResourceUsage
    let timestamp: Date
}

struct ResourceUsage: Codable {
    let timestamp: Date
    let cpuPercent: Double
    let memoryMB: Double
    let diskUsageMB: Double
    let networkActivity: NetworkActivity

    var isOptimal: Bool {
        return cpuPercent < 50 && memoryMB < 200 && diskUsageMB < 100
    }
}

struct NetworkUsage: Codable {
    let bytesReceived: Int64
    let bytesSent: Int64
    let timestamp: Date
}

struct NetworkActivity: Codable {
    let incomingBytesPerSecond: Double
    let outgoingBytesPerSecond: Double
    let totalBytesPerSecond: Double
}

struct ResourceBudget: Codable {
    let cpuPercent: Double
    let memoryMB: Double
    let diskMB: Double
}

struct ResourceBudgets: Codable {
    let idleCPU: Double
    let activeCPU: Double
    let memory: Double

    static let `default` = ResourceBudgets(idleCPU: 0.015, activeCPU: 0.08, memory: 250.0)
}

struct BatteryStatus: Codable {
    let level: Double // 0.0 to 1.0
    let state: BatteryState
    let timeRemaining: TimeInterval? // in seconds, nil if calculating

    var levelPercentage: Int {
        return Int(level * 100)
    }

    var isLow: Bool {
        return level < 0.2
    }

    var isCritical: Bool {
        return level < 0.1
    }
}

enum BatteryState: String, Codable {
    case unplugged = "unplugged"
    case charging = "charging"
    case plugged = "plugged"
    case unknown = "unknown"
}

enum ThermalState: String, Codable {
    case normal = "normal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"
}

enum FocusLockComponent: String, CaseIterable, Codable {
    case memoryStore = "memory_store"
    case activityTap = "activity_tap"
    case ocrExtractor = "ocr_extractor"
    case axExtractor = "ax_extractor"
    case jarvisChat = "jarvis_chat"

    var displayName: String {
        switch self {
        case .memoryStore: return "Memory Store"
        case .activityTap: return "Activity Tap"
        case .ocrExtractor: return "OCR Extractor"
        case .axExtractor: return "AX Extractor"
        case .jarvisChat: return "Jarvis Chat"
        }
    }
}

enum ComponentOperation: String, CaseIterable, Codable {
    case search = "search"
    case index = "index"
    case embed = "embed"
    case extract = "extract"
    case process = "process"
    case other = "other"

    var displayName: String {
        switch self {
        case .search: return "Search"
        case .index: return "Index"
        case .embed: return "Embed"
        case .extract: return "Extract"
        case .process: return "Process"
        case .other: return "Other"
        }
    }
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

    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

enum OptimizationAction {
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
    let resourceBudget: ResourceBudget
    let scheduleTime: Date

    enum TaskPriority: Int, CaseIterable, Codable {
        case critical = 1
        case high = 2
        case medium = 3
        case low = 4

        var displayName: String {
            switch self {
            case .critical: return "Critical"
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryStoreOperationCompleted = Notification.Name("memoryStoreOperationCompleted")
    static let ocrOperationCompleted = Notification.Name("ocrOperationCompleted")
    static let performanceAlertTriggered = Notification.Name("performanceAlertTriggered")
    static let optimizationCompleted = Notification.Name("optimizationCompleted")
}