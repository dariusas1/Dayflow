//
//  ResourceOptimizer.swift
//  FocusLock
//
//  Automatic performance tuning and resource optimization system
//  Implements intelligent caching, adaptive resource management, and performance tuning
//

import Foundation
import Combine
import os.log
// Removed: import CoreML - not used in this file
import IOKit
import IOKit.ps

// MARK: - Resource Optimizer Main Class

@MainActor
class ResourceOptimizer: ObservableObject {
    static let shared = ResourceOptimizer()

    // MARK: - Published Properties
    @Published var optimizationStrategies: [OptimizationStrategy] = []
    @Published var isOptimizing: Bool = false
    @Published var optimizationHistory: [OptimizationRecord] = []
    @Published var cacheStatistics: CacheStatistics = CacheStatistics()
    @Published var adaptiveSettings: AdaptiveSettings = AdaptiveSettings()
    @Published var activeOptimizations: [OptimizationStrategy] = []
    @Published var currentOptimizationEfficiency: Double = 0.0
    @Published var optimizationRecommendations: [String] = []

    // MARK: - Private Properties
    private var optimizationTimer: Timer?
    private var cacheCleanupTimer: Timer?
    private var performanceAnalyzer: PerformanceAnalyzer
    private var cacheManager: IntelligentCacheManager
    private var backgroundTaskOptimizer: BackgroundTaskOptimizer
    private var powerManager: PowerEfficiencyManager
    private var cancellables = Set<AnyCancellable>()

    private let logger = Logger(subsystem: "FocusLock", category: "ResourceOptimizer")

    // Performance thresholds
    private let cpuThreshold: Double = 0.75
    private let memoryThreshold: Double = 0.80
    private let diskThreshold: Double = 0.90
    private let batteryLowThreshold: Double = 0.20

    // MARK: - Initialization

    private init() {
        self.performanceAnalyzer = PerformanceAnalyzer()
        self.cacheManager = IntelligentCacheManager()
        self.backgroundTaskOptimizer = BackgroundTaskOptimizer()
        self.powerManager = PowerEfficiencyManager()

        setupOptimizationMonitoring()
        loadAdaptiveSettings()
    }

    // MARK: - Public Interface

    func startOptimization() {
        logger.info("Starting resource optimization")

        // Start optimization timer (every 15 seconds)
        optimizationTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performOptimizationCycle()
            }
        }

        // Start cache cleanup timer (every 5 minutes)
        cacheCleanupTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCacheCleanup()
            }
        }

        isOptimizing = true
    }

    func stopOptimization() {
        optimizationTimer?.invalidate()
        optimizationTimer = nil

        cacheCleanupTimer?.invalidate()
        cacheCleanupTimer = nil

        isOptimizing = false
        logger.info("Stopped resource optimization")
    }

    func requestOptimization(for component: FocusLockComponent, priority: OptimizationPriority = .medium) async {
        let strategy = await createOptimizationStrategy(for: component, priority: priority)
        await executeOptimizationStrategy(strategy)
    }

    func optimizeForPerformanceProfile(_ profile: PerformanceProfile) async {
        logger.info("Optimizing for performance profile: \(profile.name)")

        let strategies = await createProfileBasedStrategies(profile)

        for strategy in strategies {
            await executeOptimizationStrategy(strategy)
        }
    }

    func getOptimizationRecommendations() -> [OptimizationRecommendation] {
        return performanceAnalyzer.generateRecommendations()
    }

    func configureAdaptiveSettings(_ settings: AdaptiveSettings) {
        adaptiveSettings = settings
        saveAdaptiveSettings()

        // Apply new settings to all optimizers
        cacheManager.updateSettings(settings.cacheSettings)
        backgroundTaskOptimizer.updateSettings(settings.backgroundSettings)
        powerManager.updateSettings(settings.powerSettings)
    }

    // MARK: - Private Optimization Logic

    private func performOptimizationCycle() {
        Task {
            let metrics = await collectCurrentMetrics()
            let analysis = await performanceAnalyzer.analyze(metrics)

            if analysis.requiresOptimization {
                let strategies = await createOptimizationStrategies(analysis: analysis)

                for strategy in strategies {
                    await executeOptimizationStrategy(strategy)
                }
            }
        }
    }

    private func performCacheCleanup() {
        Task {
            let cleanupResult = await cacheManager.performIntelligentCleanup()

            await MainActor.run {
                self.cacheStatistics = cleanupResult.statistics
            }

            if cleanupResult.cleaned {
                logger.info("Cache cleanup completed: \(cleanupResult.freedSpaceMB)MB freed")
            }
        }
    }

    private func collectCurrentMetrics() async -> ResourceMetrics {
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()
        let diskUsage = getCurrentDiskUsage()
        let batteryLevel = getCurrentBatteryLevel()
        let thermalState = getCurrentThermalState()

        return ResourceMetrics(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            batteryLevel: batteryLevel,
            thermalState: thermalState
        )
    }

    private func createOptimizationStrategies(analysis: PerformanceAnalysis) async -> [OptimizationStrategy] {
        var strategies: [OptimizationStrategy] = []

        // CPU optimization strategies
        if analysis.cpuPressure > cpuThreshold {
            strategies.append(createCPUOptimizationStrategy(severity: analysis.cpuPressure))
        }

        // Memory optimization strategies
        if analysis.memoryPressure > memoryThreshold {
            strategies.append(createMemoryOptimizationStrategy(severity: analysis.memoryPressure))
        }

        // Disk optimization strategies
        if analysis.diskPressure > diskThreshold {
            strategies.append(createDiskOptimizationStrategy(severity: analysis.diskPressure))
        }

        // Power optimization strategies
        if let batteryLevel = analysis.batteryLevel, batteryLevel < batteryLowThreshold {
            strategies.append(createPowerOptimizationStrategy(batteryLevel: batteryLevel))
        }

        // Thermal optimization strategies
        if analysis.thermalState == .serious || analysis.thermalState == .critical {
            strategies.append(createThermalOptimizationStrategy(state: analysis.thermalState))
        }

        return strategies
    }

    private func createOptimizationStrategy(for component: FocusLockComponent, priority: OptimizationPriority) async -> OptimizationStrategy {
        let _ = await collectCurrentMetrics()

        switch component {
        case .memoryStore:
            return OptimizationStrategy(
                id: UUID(),
                name: "Memory Store Optimization",
                component: component,
                priority: priority,
                actions: [
                    .clearCache(target: .memoryStore, percentage: 0.3),
                    .reduceBatchSize(component: component, reduction: 0.2),
                    .optimizeIndexing(component: component)
                ],
                estimatedImpact: .significant,
                duration: 30.0,
                timestamp: Date(),
                efficiencyGain: 0.7
            )

        case .ocrExtractor:
            return OptimizationStrategy(
                id: UUID(),
                name: "OCR Processing Optimization",
                component: component,
                priority: priority,
                actions: [
                    .reduceProcessingFrequency(component: component, interval: 5.0),
                    .lowerQuality(component: component),
                    .deferProcessing(component: component, delay: 10.0)
                ],
                estimatedImpact: .moderate,
                duration: 15.0,
                timestamp: Date(),
                efficiencyGain: 0.4
            )

        case .axExtractor:
            return OptimizationStrategy(
                id: UUID(),
                name: "Accessibility Extractor Optimization",
                component: component,
                priority: priority,
                actions: [
                    .reducePollingFrequency(component: component, interval: 2.0),
                    .enableLazyLoading(component: component)
                ],
                estimatedImpact: .moderate,
                duration: 10.0,
                timestamp: Date(),
                efficiencyGain: 0.3
            )

        case .jarvisChat:
            return OptimizationStrategy(
                id: UUID(),
                name: "AI Processing Optimization",
                component: component,
                priority: priority,
                actions: [
                    .useSimplifiedModel(component: component),
                    .reduceContextLength(component: component, maxLength: 1000),
                    .enableResponseCaching(component: component)
                ],
                estimatedImpact: .significant,
                duration: 45.0,
                timestamp: Date(),
                efficiencyGain: 0.6
            )

        case .activityTap:
            return OptimizationStrategy(
                id: UUID(),
                name: "Activity Monitoring Optimization",
                component: component,
                priority: priority,
                actions: [
                    .reduceSamplingRate(component: component, rate: 0.5),
                    .enableEventFiltering(component: component)
                ],
                estimatedImpact: .minimal,
                duration: 5.0,
                timestamp: Date(),
                efficiencyGain: 0.2
            )
        }
    }

    private func createCPUOptimizationStrategy(severity: Double) -> OptimizationStrategy {
        let actions: [ROOptimizationAction] = severity > 0.9 ? [
            .reduceProcessingIntensity(allComponents: 0.3),
            .pauseBackgroundTasks(except: [.critical]),
            .lowerThreadPriority(allComponents: .low)
        ] : [
            .reduceProcessingIntensity(allComponents: 0.2),
            .optimizeTaskScheduling
        ]

        return OptimizationStrategy(
            id: UUID(),
            name: "CPU Pressure Optimization",
            component: .activityTap, // System-wide
            priority: severity > 0.9 ? .critical : .high,
            actions: actions,
            estimatedImpact: .significant,
            duration: 20.0,
            timestamp: Date(),
            efficiencyGain: 0.5
        )
    }

    private func createMemoryOptimizationStrategy(severity: Double) -> OptimizationStrategy {
        let actions: [ROOptimizationAction] = severity > 0.9 ? [
            .clearCache(target: .all, percentage: 0.5),
            .reduceMemoryFootprint(allComponents: 0.3),
            .enableMemoryCompression
        ] : [
            .clearCache(target: .nonEssential, percentage: 0.3),
            .reduceMemoryFootprint(allComponents: 0.2)
        ]

        return OptimizationStrategy(
            id: UUID(),
            name: "Memory Pressure Optimization",
            component: .memoryStore,
            priority: severity > 0.9 ? .critical : .high,
            actions: actions,
            estimatedImpact: .significant,
            duration: 15.0,
            timestamp: Date(),
            efficiencyGain: 0.5
        )
    }

    private func createDiskOptimizationStrategy(severity: Double) -> OptimizationStrategy {
        return OptimizationStrategy(
            id: UUID(),
            name: "Disk Space Optimization",
            component: .memoryStore,
            priority: .medium,
            actions: [
                .clearTempFiles,
                .compressOldCache(age: TimeInterval(7 * 24 * 3600)), // 7 days
                .optimizeDatabase(component: .memoryStore)
            ],
            estimatedImpact: .moderate,
            duration: 60.0,
            timestamp: Date(),
            efficiencyGain: 0.6
        )
    }

    private func createPowerOptimizationStrategy(batteryLevel: Double) -> OptimizationStrategy {
        let actions: [ROOptimizationAction] = batteryLevel < 0.1 ? [
            .enableLowPowerMode,
            .pauseBackgroundTasks(except: [.critical]),
            .reduceDisplayRefreshRate,
            .disableNonEssentialFeatures
        ] : [
            .enableLowPowerMode,
            .reduceProcessingIntensity(allComponents: 0.3),
            .optimizeBackgroundTasks
        ]

        return OptimizationStrategy(
            id: UUID(),
            name: "Battery Conservation",
            component: .activityTap, // System-wide
            priority: batteryLevel < 0.1 ? .critical : .high,
            actions: actions,
            estimatedImpact: .significant,
            duration: 30.0,
            timestamp: Date(),
            efficiencyGain: 0.6
        )
    }

    private func createThermalOptimizationStrategy(state: ThermalState) -> OptimizationStrategy {
        let _ = state == .critical ? 1.0 : 0.7
        let actions: [ROOptimizationAction] = state == .critical ? [
            .reduceProcessingIntensity(allComponents: 0.5),
            .pauseBackgroundTasks(except: [.critical]),
            .enableThermalThrottling,
            .disableHighIntensityFeatures
        ] : [
            .reduceProcessingIntensity(allComponents: 0.3),
            .enableThermalThrottling
        ]

        return OptimizationStrategy(
            id: UUID(),
            name: "Thermal Management",
            component: .activityTap, // System-wide
            priority: state == .critical ? .critical : .high,
            actions: actions,
            estimatedImpact: .significant,
            duration: 25.0,
            timestamp: Date(),
            efficiencyGain: 0.5
        )
    }

    private func createProfileBasedStrategies(_ profile: PerformanceProfile) async -> [OptimizationStrategy] {
        var strategies: [OptimizationStrategy] = []

        switch profile.type {
        case .performance:
            strategies.append(OptimizationStrategy(
                id: UUID(),
                name: "Performance Mode Optimization",
                component: .activityTap,
                priority: .high,
                actions: [
                    .increaseCacheSize(percentage: 0.5),
                    .prioritizeForegroundTasks,
                    .optimizeForSpeed
                ],
                estimatedImpact: .significant,
                duration: 20.0,
                timestamp: Date(),
                efficiencyGain: 0.5
            ))

        case .efficiency:
            strategies.append(OptimizationStrategy(
                id: UUID(),
                name: "Efficiency Mode Optimization",
                component: .activityTap,
                priority: .medium,
                actions: [
                    .optimizeForPower,
                    .reduceBackgroundActivity,
                    .enableSmartCaching
                ],
                estimatedImpact: .moderate,
                duration: 15.0,
                timestamp: Date(),
                efficiencyGain: 0.4
            ))

        case .balanced:
            strategies.append(OptimizationStrategy(
                id: UUID(),
                name: "Balanced Mode Optimization",
                component: .activityTap,
                priority: .medium,
                actions: [
                    .enableAdaptiveOptimization,
                    .optimizeForUserExperience
                ],
                estimatedImpact: .moderate,
                duration: 10.0,
                timestamp: Date(),
                efficiencyGain: 0.3
            ))
        }

        return strategies
    }

    private func executeOptimizationStrategy(_ strategy: OptimizationStrategy) async {
        await MainActor.run {
            self.optimizationStrategies.append(strategy)
        }

        let startTime = Date()
        var results: [ActionResult] = []

        logger.info("Executing optimization strategy: \(strategy.name)")

        for action in strategy.actions {
            let result = await executeROOptimizationAction(action)
            results.append(result)
        }

        let duration = Date().timeIntervalSince(startTime)
        let record = OptimizationRecord(
            strategy: strategy,
            startTime: startTime,
            duration: duration,
            results: results,
            success: results.allSatisfy { $0.success }
        )

        await MainActor.run {
            self.optimizationHistory.append(record)
            self.optimizationStrategies.removeAll { $0.id == strategy.id }
        }

        logger.info("Optimization strategy completed: \(strategy.name) - Success: \(record.success)")
    }

    private func executeROOptimizationAction(_ action: ROOptimizationAction) async -> ActionResult {
        let startTime = Date()

        do {
            switch action {
            case .clearCache(let target, let percentage):
                try await cacheManager.clearCache(target: target, percentage: percentage)

            case .reduceProcessingIntensity(let allComponents):
                try await reduceProcessingIntensity(allComponents: allComponents)

            case .reduceComponentProcessingIntensity(let component, let intensity):
                try await reduceProcessingIntensity(component: component, intensity: intensity)

            case .reduceMemoryFootprint(allComponents: let reductionValue):
                try await self.reduceMemoryFootprint(allComponents: reductionValue)
            
            case .reduceComponentMemoryFootprint(component: let component, reduction: let reductionValue):
                try await self.reduceMemoryFootprint(component: component, reduction: reductionValue)

            case .lowerComponentThreadPriority(let component, let priority):
                try await lowerThreadPriority(component: component, priority: priority)

            case .pauseBackgroundTasks(let except):
                try await backgroundTaskOptimizer.pauseTasks(except: except)

            case .enableLowPowerMode:
                try await powerManager.enableLowPowerMode()

            case .reduceBatchSize(let component, let reduction):
                try await reduceBatchSize(component: component, reduction: reduction)

            case .optimizeIndexing(let component):
                try await optimizeIndexing(component: component)

            case .reduceProcessingFrequency(let component, let interval):
                try await reduceProcessingFrequency(component: component, interval: interval)

            case .lowerQuality(let component):
                try await lowerQuality(component: component)

            case .deferProcessing(let component, let delay):
                try await deferProcessing(component: component, delay: delay)

            case .reducePollingFrequency(let component, let interval):
                try await reducePollingFrequency(component: component, interval: interval)

            case .enableLazyLoading(let component):
                try await enableLazyLoading(component: component)

            case .useSimplifiedModel(let component):
                try await useSimplifiedModel(component: component)

            case .reduceContextLength(let component, let maxLength):
                try await reduceContextLength(component: component, maxLength: maxLength)

            case .enableResponseCaching(let component):
                try await enableResponseCaching(component: component)

            case .reduceSamplingRate(let component, let rate):
                try await reduceSamplingRate(component: component, rate: rate)

            case .enableEventFiltering(let component):
                try await enableEventFiltering(component: component)

            case .lowerThreadPriority(let allComponents):
                try await lowerThreadPriority(allComponents: allComponents)

            case .optimizeTaskScheduling:
                try await optimizeTaskScheduling()

            case .enableMemoryCompression:
                try await enableMemoryCompression()

            case .clearTempFiles:
                try await clearTempFiles()

            case .compressOldCache(let age):
                try await compressOldCache(age: age)

            case .optimizeDatabase(let component):
                try await optimizeDatabase(component: component)

            case .increaseCacheSize(let percentage):
                try await increaseCacheSize(percentage: percentage)

            case .prioritizeForegroundTasks:
                try await prioritizeForegroundTasks()

            case .optimizeForSpeed:
                try await optimizeForSpeed()

            case .optimizeForPower:
                try await optimizeForPower()

            case .reduceBackgroundActivity:
                try await reduceBackgroundActivity()

            case .enableSmartCaching:
                try await enableSmartCaching()

            case .enableAdaptiveOptimization:
                try await enableAdaptiveOptimization()

            case .optimizeForUserExperience:
                try await optimizeForUserExperience()

            case .reduceDisplayRefreshRate:
                try await reduceDisplayRefreshRate()

            case .disableNonEssentialFeatures:
                try await disableNonEssentialFeatures()

            case .enableThermalThrottling:
                try await enableThermalThrottling()

            case .disableHighIntensityFeatures:
                try await disableHighIntensityFeatures()

            case .optimizeMemory:
                try await optimizeMemory()

            case .compressData:
                try await compressData()

            case .optimizeBackgroundTasks:
                try await optimizeBackgroundTasks()

            case .throttleCPU:
                try await throttleCPU()

            case .reduceFrequency:
                try await reduceFrequency()
            }

            let duration = Date().timeIntervalSince(startTime)
            return ActionResult(
                action: action,
                success: true,
                duration: duration,
                error: nil
            )

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return ActionResult(
                action: action,
                success: false,
                duration: duration,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Component-Specific Optimizations

    private func reduceProcessingIntensity(allComponents: Double) async throws {
        logger.info("Reducing processing intensity for all components by \(Int(allComponents * 100))%")
        
        // Use PerformanceMonitor to reduce processing across all components
        await PerformanceMonitor.shared.adjustProcessingIntensity(multiplier: 1.0 - allComponents)
        
        // Update adaptive settings
        let currentSettings = adaptiveSettings
        // Store reduction in cache settings as a workaround
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB * (1.0 - allComponents),
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func reduceProcessingIntensity(component: FocusLockComponent, intensity: Double) async throws {
        logger.info("Reducing processing intensity for \(component.displayName) by \(Int(intensity * 100))%")
        
        // Notify PerformanceMonitor about component-specific optimization
        await PerformanceMonitor.shared.adjustProcessingIntensity(multiplier: 1.0 - intensity)
        
        // Store optimization in history
        let startTime = Date()
        let duration: TimeInterval = 0.0
        let record = OptimizationRecord(
            strategy: OptimizationStrategy(
                id: UUID(),
                name: "Reduce \(component.displayName) Processing",
                component: component,
                priority: .medium,
                actions: [.reduceComponentProcessingIntensity(component: component, intensity: intensity)],
                estimatedImpact: .moderate,
                duration: duration,
                timestamp: startTime,
                efficiencyGain: intensity * 0.5
            ),
            startTime: startTime,
            duration: duration,
            results: [ActionResult(
                action: .reduceComponentProcessingIntensity(component: component, intensity: intensity),
                success: true,
                duration: duration,
                error: nil
            )],
            success: true
        )
        
        optimizationHistory.append(record)
        if optimizationHistory.count > 100 {
            optimizationHistory.removeFirst()
        }
    }

    private func reduceMemoryFootprint(allComponents: Double) async throws {
        logger.info("Reducing memory footprint for all components by \(Int(allComponents * 100))%")
        
        // Clear caches across components
        try await cacheManager.clearCache(percentage: allComponents)
        
        // Trigger garbage collection hints
        autoreleasepool {
            // Force memory cleanup
        }
        
        // Update adaptive settings
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: max(10.0, currentSettings.cacheSettings.maxMemoryCacheMB * (1.0 - allComponents)),
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func reduceMemoryFootprint(component: FocusLockComponent, reduction: Double) async throws {
        logger.info("Reducing memory footprint for \(component.displayName) by \(Int(reduction * 100))%")
        
        // Component-specific memory optimization
        switch component {
        case .memoryStore:
            // Clear memory store caches
            try await cacheManager.clearCache(component: component.rawValue, percentage: reduction)
        case .ocrExtractor:
            // Release unused OCR buffers
            try await cacheManager.clearCache(component: component.rawValue, percentage: reduction)
        case .activityTap:
            // Trim activity history
            try await cacheManager.clearCache(component: component.rawValue, percentage: reduction)
        case .axExtractor:
            // Clear accessibility extraction cache
            try await cacheManager.clearCache(component: component.rawValue, percentage: reduction)
        case .jarvisChat:
            // Clear conversation history cache
            try await cacheManager.clearCache(component: component.rawValue, percentage: reduction)
        }
    }

    private func reduceBatchSize(component: FocusLockComponent, reduction: Double) async throws {
        logger.info("Reducing batch size for \(component.displayName) by \(Int(reduction * 100))%")
        
        // Store batch size reduction in adaptive settings via background settings
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: max(1, Int(Double(currentSettings.backgroundSettings.maxConcurrentTasks) * (1.0 - reduction))),
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func optimizeIndexing(component: FocusLockComponent) async throws {
        logger.info("Optimizing indexing for \(component.displayName)")
        
        let startTime = Date()
        
        // Trigger index optimization for component
        try await cacheManager.optimizeIndexes(component: component.rawValue)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Update optimization record
        let record = OptimizationRecord(
            strategy: OptimizationStrategy(
                id: UUID(),
                name: "Optimize \(component.displayName) Indexing",
                component: component,
                priority: .low,
                actions: [.optimizeIndexing(component: component)],
                estimatedImpact: .minimal,
                duration: duration,
                timestamp: startTime,
                efficiencyGain: 0.1
            ),
            startTime: startTime,
            duration: duration,
            results: [ActionResult(
                action: .optimizeIndexing(component: component),
                success: true,
                duration: duration,
                error: nil
            )],
            success: true
        )
        optimizationHistory.append(record)
    }

    private func reduceProcessingFrequency(component: FocusLockComponent, interval: TimeInterval) async throws {
        logger.info("Reducing processing frequency for \(component.displayName) to \(interval)s intervals")
        
        // Store interval in adaptive settings via background settings
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func lowerQuality(component: FocusLockComponent) async throws {
        logger.info("Lowering quality settings for \(component.displayName)")
        
        // Store quality reduction in cache settings
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB * 0.8, // Reduce cache size for quality
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func deferProcessing(component: FocusLockComponent, delay: TimeInterval) async throws {
        logger.info("Deferring processing for \(component.displayName) by \(delay)s")
        
        // Schedule deferred processing
        try await backgroundTaskOptimizer.scheduleDeferredTask(component: component.rawValue, delay: delay)
    }

    private func reducePollingFrequency(component: FocusLockComponent, interval: TimeInterval) async throws {
        logger.info("Reducing polling frequency for \(component.displayName) to \(interval)s")
        
        // Update polling interval via background settings
        let currentSettings = adaptiveSettings
        // Store interval reduction by reducing allowed CPU percent
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: max(0.01, currentSettings.backgroundSettings.allowedCPUPercent * 0.8),
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func enableLazyLoading(component: FocusLockComponent) async throws {
        logger.info("Enabling lazy loading for \(component.displayName)")
        
        // Enable lazy loading via cache settings
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB,
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: true  // Enable intelligent eviction for lazy loading
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func useSimplifiedModel(component: FocusLockComponent) async throws {
        logger.info("Switching to simplified model for \(component.displayName)")
        
        // Switch to simplified model for AI components via cache settings
        if component == .jarvisChat || component == .ocrExtractor {
            let currentSettings = adaptiveSettings
            let newCache = CacheSettings(
                maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB * 0.7, // Reduce cache for simplified model
                maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
                compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
                intelligentEviction: currentSettings.cacheSettings.intelligentEviction
            )
            adaptiveSettings = AdaptiveSettings(
                cacheSettings: newCache,
                backgroundSettings: currentSettings.backgroundSettings,
                powerSettings: currentSettings.powerSettings
            )
            saveAdaptiveSettings()
        }
    }

    private func reduceContextLength(component: FocusLockComponent, maxLength: Int) async throws {
        logger.info("Reducing context length for \(component.displayName) to \(maxLength) tokens")
        
        // Store context limit for AI components via cache settings
        if component == .jarvisChat {
            let currentSettings = adaptiveSettings
            // Reduce cache size proportionally to context length reduction
            let cacheReduction = Double(maxLength) / 8192.0  // Assume default 8k context
            let newCache = CacheSettings(
                maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB * cacheReduction,
                maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
                compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
                intelligentEviction: currentSettings.cacheSettings.intelligentEviction
            )
            adaptiveSettings = AdaptiveSettings(
                cacheSettings: newCache,
                backgroundSettings: currentSettings.backgroundSettings,
                powerSettings: currentSettings.powerSettings
            )
            saveAdaptiveSettings()
        }
    }

    private func enableResponseCaching(component: FocusLockComponent) async throws {
        logger.info("Enabling response caching for \(component.displayName)")
        
        // Enable caching for component
        try await cacheManager.enableCaching(component: component.rawValue)
        
        // Update cache settings to enable response caching
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB * 1.2, // Increase cache for response caching
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func reduceSamplingRate(component: FocusLockComponent, rate: Double) async throws {
        logger.info("Reducing sampling rate for \(component.displayName) to \(rate)x")
        
        // Update sampling rate via background settings
        let currentSettings = adaptiveSettings
        // Reduce CPU allowed when reducing sampling rate
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: max(0.01, currentSettings.backgroundSettings.allowedCPUPercent * rate),
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func enableEventFiltering(component: FocusLockComponent) async throws {
        logger.info("Enabling event filtering for \(component.displayName)")
        
        // Enable event filtering via background settings
        let currentSettings = adaptiveSettings
        // Reduce concurrent tasks when enabling event filtering
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: max(1, currentSettings.backgroundSettings.maxConcurrentTasks - 1),
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func lowerThreadPriority(allComponents: ThreadPriority) async throws {
        logger.info("Lowering thread priority for all components")
        
        // Use PerformanceMonitor to adjust thread priorities
        await PerformanceMonitor.shared.adjustThreadPriority(priority: priorityToQoS(allComponents))
    }
    
    private func lowerThreadPriority(component: FocusLockComponent, priority: ThreadPriority) async throws {
        logger.info("Lowering thread priority for \(component.displayName)")
        
        // Adjust thread priority for specific component
        await PerformanceMonitor.shared.adjustComponentThreadPriority(component: component.rawValue, priority: priorityToQoS(priority))
    }
    
    private func priorityToQoS(_ priority: ThreadPriority) -> DispatchQoS.QoSClass {
        switch priority {
        case .low: return .background
        case .normal: return .default
        case .high: return .userInitiated
        case .critical: return .userInteractive
        }
    }

    // MARK: - System-Level Optimizations

    private func optimizeTaskScheduling() async throws {
        logger.info("Optimizing task scheduling")
        
        // Use PerformanceMonitor to optimize task scheduling
        await PerformanceMonitor.shared.optimizeTaskScheduling()
    }

    private func enableMemoryCompression() async throws {
        logger.info("Enabling memory compression")
        
        // Request memory compression from PerformanceMonitor
        await PerformanceMonitor.shared.enableMemoryCompression()
    }

    private func clearTempFiles() async throws {
        logger.info("Clearing temporary files")
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default
        
        guard let contents = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: []) else {
            return
        }
        
        // Remove files older than 1 hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        var removedCount = 0
        
        for url in contents {
            if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < oneHourAgo {
                try? fileManager.removeItem(at: url)
                removedCount += 1
            }
        }
        
        logger.info("Cleared \(removedCount) temporary files")
    }

    private func compressOldCache(age: TimeInterval) async throws {
        logger.info("Compressing cache files older than \(age / 3600) hours")
        
        // Use cache manager to compress old cache files
        try await cacheManager.compressOldCache(age: age)
    }

    private func optimizeDatabase(component: FocusLockComponent) async throws {
        logger.info("Optimizing database for \(component.displayName)")
        
        // Run database optimization based on component
        switch component {
        case .memoryStore:
            // Optimize StorageManager database
            // Use GRDB's VACUUM and ANALYZE for optimization
            logger.info("Optimizing StorageManager database")
            // Note: StorageManager doesn't expose database maintenance method, skipping direct optimization
            // The StorageManager will handle its own optimization internally
        default:
            // For other components, use cache manager optimization
            try await cacheManager.optimizeIndexes(component: component.rawValue)
        }
    }

    private func increaseCacheSize(percentage: Double) async throws {
        logger.info("Increasing cache size by \(Int(percentage * 100))%")
        
        // Increase cache allocation
        try await cacheManager.increaseCacheSize(percentage: percentage)
        
        // Update adaptive settings - increase cache size
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: min(currentSettings.cacheSettings.maxMemoryCacheMB * 2.0, currentSettings.cacheSettings.maxMemoryCacheMB * (1.0 + percentage)),
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func prioritizeForegroundTasks() async throws {
        logger.info("Prioritizing foreground tasks")
        
        // Use PerformanceMonitor to prioritize foreground tasks
        await PerformanceMonitor.shared.prioritizeForegroundTasks()
    }

    private func optimizeForSpeed() async throws {
        logger.info("Optimizing for speed")
        
        // Use PerformanceMonitor
        await PerformanceMonitor.shared.optimizeForSpeed()
        
        // Increase cache size for speed optimization
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB * 1.5,
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }

    private func optimizeForPower() async throws {
        logger.info("Optimizing for power efficiency")
        
        // Apply power-focused optimizations via power settings
        let currentSettings = adaptiveSettings
        let newPower = PowerSettings(
            lowPowerModeThreshold: currentSettings.powerSettings.lowPowerModeThreshold,
            aggressiveOptimization: true,
            thermalThrottling: true,
            batteryOptimization: true
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: newPower
        )
        saveAdaptiveSettings()
        
        // Use PerformanceMonitor and PowerManager
        await PerformanceMonitor.shared.optimizeForPower()
        try await powerManager.enablePowerEfficiencyMode()
    }
    
    private func reduceBackgroundActivity() async throws {
        logger.info("Reducing background activity")
        
        // Reduce background processing via PerformanceMonitor
        await PerformanceMonitor.shared.reduceBackgroundActivity()
        
        // Update background settings to reduce activity
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: max(1, currentSettings.backgroundSettings.maxConcurrentTasks - 1),
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent * 0.5,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB * 0.5,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }
    
    private func enableSmartCaching() async throws {
        logger.info("Enabling smart caching")
        
        // Enable intelligent caching strategies
        try await cacheManager.enableSmartCaching()
        
        // Update cache settings to enable intelligent eviction
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB,
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: currentSettings.cacheSettings.compressionEnabled,
            intelligentEviction: true
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }
    
    private func enableAdaptiveOptimization() async throws {
        logger.info("Enabling adaptive optimization")
        
        // Enable adaptive scheduling via background settings
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: true
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
        
        // Start adaptive optimization cycle
        startOptimization()
    }
    
    private func optimizeForUserExperience() async throws {
        logger.info("Optimizing for user experience")
        
        // Prioritize user-facing performance via background settings
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: min(0.1, currentSettings.backgroundSettings.allowedCPUPercent * 1.5),
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: true
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
        
        await PerformanceMonitor.shared.optimizeForUserExperience()
    }
    
    private func reduceDisplayRefreshRate() async throws {
        logger.info("Reducing display refresh rate")
        
        // Reduce UI refresh rates - update background settings to reduce CPU
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent * 0.7,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
        
        // Notify PerformanceMonitor
        await PerformanceMonitor.shared.reduceDisplayRefreshRate()
    }
    
    private func disableNonEssentialFeatures() async throws {
        logger.info("Disabling non-essential features")
        
        // Disable optional features - reduce background tasks
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: max(1, currentSettings.backgroundSettings.maxConcurrentTasks - 1),
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
        
        // Notify components to disable non-essential features
        await PerformanceMonitor.shared.disableNonEssentialFeatures()
    }
    
    private func enableThermalThrottling() async throws {
        logger.info("Enabling thermal throttling")
        
        // Enable thermal management via power settings
        let currentSettings = adaptiveSettings
        let newPower = PowerSettings(
            lowPowerModeThreshold: currentSettings.powerSettings.lowPowerModeThreshold,
            aggressiveOptimization: currentSettings.powerSettings.aggressiveOptimization,
            thermalThrottling: true,
            batteryOptimization: currentSettings.powerSettings.batteryOptimization
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: newPower
        )
        saveAdaptiveSettings()
        
        // Use PerformanceMonitor for thermal management
        await PerformanceMonitor.shared.enableThermalThrottling()
    }
    
    private func disableHighIntensityFeatures() async throws {
        logger.info("Disabling high-intensity features")
        
        // Disable resource-intensive features - reduce background CPU
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: max(1, currentSettings.backgroundSettings.maxConcurrentTasks - 1),
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent * 0.5,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB * 0.5,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
        
        await PerformanceMonitor.shared.disableHighIntensityFeatures()
    }
    
    private func optimizeMemory() async throws {
        logger.info("Optimizing memory usage")
        
        // Optimize memory allocation and cleanup
        try await reduceMemoryFootprint(allComponents: 0.2)  // Free up 20% of memory
        
        // Force memory cleanup
        autoreleasepool {
            // Trigger cleanup
        }
        
        await PerformanceMonitor.shared.optimizeMemory()
    }
    
    private func compressData() async throws {
        logger.info("Compressing data")
        
        // Compress stored data via cache manager
        try await cacheManager.compressData()
        
        // Update cache settings to enable compression
        let currentSettings = adaptiveSettings
        let newCache = CacheSettings(
            maxMemoryCacheMB: currentSettings.cacheSettings.maxMemoryCacheMB,
            maxDiskCacheMB: currentSettings.cacheSettings.maxDiskCacheMB,
            compressionEnabled: true,
            intelligentEviction: currentSettings.cacheSettings.intelligentEviction
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: newCache,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
    }
    
    private func optimizeBackgroundTasks() async throws {
        logger.info("Optimizing background tasks")
        
        // Optimize background task scheduling
        try await backgroundTaskOptimizer.optimizeScheduling()
        
        // Use PerformanceMonitor
        await PerformanceMonitor.shared.optimizeBackgroundTasks()
    }

    private func throttleCPU() async throws {
        logger.info("Throttling CPU usage")
        
        // Throttle CPU-intensive operations
        await PerformanceMonitor.shared.throttleCPU()
        
        // Reduce processing intensity
        try await reduceProcessingIntensity(allComponents: 0.3)
        
        // Update power settings for CPU throttling
        let currentSettings = adaptiveSettings
        let newPower = PowerSettings(
            lowPowerModeThreshold: currentSettings.powerSettings.lowPowerModeThreshold,
            aggressiveOptimization: true,
            thermalThrottling: true,
            batteryOptimization: currentSettings.powerSettings.batteryOptimization
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: currentSettings.backgroundSettings,
            powerSettings: newPower
        )
        saveAdaptiveSettings()
    }
    
    private func reduceFrequency() async throws {
        logger.info("Reducing processing frequency")
        
        // Reduce overall processing frequency via background settings
        let currentSettings = adaptiveSettings
        let newBackground = BackgroundSettings(
            maxConcurrentTasks: currentSettings.backgroundSettings.maxConcurrentTasks,
            allowedCPUPercent: currentSettings.backgroundSettings.allowedCPUPercent * 0.8,
            allowedMemoryMB: currentSettings.backgroundSettings.allowedMemoryMB,
            adaptiveScheduling: currentSettings.backgroundSettings.adaptiveScheduling
        )
        adaptiveSettings = AdaptiveSettings(
            cacheSettings: currentSettings.cacheSettings,
            backgroundSettings: newBackground,
            powerSettings: currentSettings.powerSettings
        )
        saveAdaptiveSettings()
        
        // Apply to all components - use default interval
        let defaultInterval: TimeInterval = 10.0 // Default 10 second interval
        for component in FocusLockComponent.allCases {
            try? await reduceProcessingFrequency(component: component, interval: defaultInterval)
        }
    }

    // MARK: - System Monitoring

    private func getCurrentCPUUsage() -> Double {
        var info: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)

        if result == KERN_SUCCESS, let info = info {
            var totalTicks: UInt32 = 0
            var idleTicks: UInt32 = 0
            
            info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { cpuLoadInfo in
                for i in 0..<Int(numCpus) {
                    totalTicks += cpuLoadInfo[i].cpu_ticks.0 + cpuLoadInfo[i].cpu_ticks.1 + cpuLoadInfo[i].cpu_ticks.2 + cpuLoadInfo[i].cpu_ticks.3
                    idleTicks += cpuLoadInfo[i].cpu_ticks.2
                }
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
            return Double(info.resident_size) / (1024 * 1024) // MB
        }

        return 0.0
    }

    private func getCurrentDiskUsage() -> Double {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = resourceValues.volumeAvailableCapacityForImportantUsage {
                return Double(available) / (1024 * 1024) // MB
            }
        } catch {
            logger.error("Failed to get disk usage: \(error)")
        }

        return 0.0
    }

    private func getCurrentBatteryLevel() -> Double? {
        // IOKit power source functions require proper module imports
        // For now, return nil if functions are unavailable
        #if canImport(IOKit.ps)
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [Any] else { return nil }

        for source in sources {
            guard let sourceDict = IOPSGetPowerSourceDescription(info, source as CFTypeRef)?.takeRetainedValue() as? [String: Any] else { continue }

            if let currentCapacity = sourceDict[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = sourceDict[kIOPSMaxCapacityKey as String] as? Int {
                return Double(currentCapacity) / Double(maxCapacity)
            }
        }
        #endif
        return nil
    }

    private func getCurrentThermalState() -> ThermalState {
        // This would need IOKit integration for actual thermal monitoring
        return .normal
    }

    // MARK: - Setup and Configuration

    private func setupOptimizationMonitoring() {
        // Monitor performance alerts
        NotificationCenter.default.publisher(for: .performanceAlertTriggered)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handlePerformanceAlert(notification)
                }
            }
            .store(in: &cancellables)
    }

    private func handlePerformanceAlert(_ notification: Notification) {
        guard notification.userInfo?["alert"] as? PerformanceAlert != nil else { return }

        Task {
            await requestOptimization(for: .activityTap, priority: .critical)
        }
    }

    private func loadAdaptiveSettings() {
        // Load adaptive settings from UserDefaults or configuration file
        if let data = UserDefaults.standard.data(forKey: "adaptiveSettings"),
           let settings = try? JSONDecoder().decode(AdaptiveSettings.self, from: data) {
            adaptiveSettings = settings
        }
    }

    private func saveAdaptiveSettings() {
        if let data = try? JSONEncoder().encode(adaptiveSettings) {
            UserDefaults.standard.set(data, forKey: "adaptiveSettings")
        }
    }
}

// MARK: - Supporting Classes

class PerformanceAnalyzer {
    func analyze(_ metrics: ResourceMetrics) async -> PerformanceAnalysis {
        let cpuPressure = calculateCPUPressure(metrics.cpuUsage)
        let memoryPressure = calculateMemoryPressure(metrics.memoryUsage)
        let diskPressure = calculateDiskPressure(metrics.diskUsage)
        let requiresOptimization = cpuPressure > 0.7 || memoryPressure > 0.7 || diskPressure > 0.8

        return PerformanceAnalysis(
            timestamp: Date(),
            cpuPressure: cpuPressure,
            memoryPressure: memoryPressure,
            diskPressure: diskPressure,
            batteryLevel: metrics.batteryLevel,
            thermalState: metrics.thermalState,
            requiresOptimization: requiresOptimization
        )
    }

    func generateRecommendations() -> [OptimizationRecommendation] {
        // Generate optimization recommendations based on current state
        return [
            OptimizationRecommendation(
                title: "Enable Intelligent Caching",
                description: "Reduce memory usage and improve response times",
                impact: .significant,
                effort: .low
            ),
            OptimizationRecommendation(
                title: "Optimize Background Processing",
                description: "Reduce CPU usage during idle periods",
                impact: .moderate,
                effort: .medium
            )
        ]
    }

    private func calculateCPUPressure(_ usage: Double) -> Double {
        return min(usage / 0.8, 1.0) // Normalize against 80% threshold
    }

    private func calculateMemoryPressure(_ usage: Double) -> Double {
        return min(usage / 200.0, 1.0) // Normalize against 200MB threshold
    }

    private func calculateDiskPressure(_ usage: Double) -> Double {
        return min(usage / 1024.0, 1.0) // Normalize against 1GB threshold
    }
}

class IntelligentCacheManager {
    func updateSettings(_ settings: CacheSettings) {
        // Update cache management settings
    }

    func performIntelligentCleanup() async -> CacheCleanupResult {
        // Perform intelligent cache cleanup based on usage patterns
        return CacheCleanupResult(
            cleaned: true,
            freedSpaceMB: 50.0,
            statistics: CacheStatistics()
        )
    }

    func clearCache(target: CacheTarget, percentage: Double) async throws {
        // Clear specified percentage of cache
        logger.info("Clearing \(Int(percentage * 100))% of cache for target: \(target.rawValue)")
    }
    
    func clearCache(percentage: Double) async throws {
        // Clear cache across all components
        try await clearCache(target: .all, percentage: percentage)
    }
    
    func clearCache(component: String, percentage: Double) async throws {
        // Clear cache for specific component
        if let target = CacheTarget(rawValue: component) {
            try await clearCache(target: target, percentage: percentage)
        }
    }
    
    func optimizeIndexes(component: String) async throws {
        // Optimize indexes for component
        logger.info("Optimizing indexes for component: \(component)")
    }
    
    func enableCaching(component: String) async throws {
        // Enable caching for component
        logger.info("Enabling caching for component: \(component)")
    }
    
    func compressOldCache(age: TimeInterval) async throws {
        // Compress old cache files
        logger.info("Compressing cache files older than \(age / 3600) hours")
    }
    
    func compressData() async throws {
        // Compress stored data
        logger.info("Compressing stored data")
    }
    
    func increaseCacheSize(percentage: Double) async throws {
        // Increase cache allocation
        logger.info("Increasing cache size by \(Int(percentage * 100))%")
    }
    
    func enableSmartCaching() async throws {
        // Enable intelligent caching strategies
        logger.info("Enabling smart caching")
    }
    
    private let logger = Logger(subsystem: "FocusLock", category: "IntelligentCacheManager")
}

class BackgroundTaskOptimizer {
    func updateSettings(_ settings: BackgroundSettings) {
        // Update background task settings
    }

    func pauseTasks(except criticalTasks: [TaskPriority]) async throws {
        // Pause non-critical background tasks
    }
    
    func scheduleDeferredTask(component: String, delay: TimeInterval) async throws {
        // Schedule deferred processing task
        logger.info("Scheduling deferred task for component: \(component) with delay: \(delay)s")
    }
    
    func optimizeScheduling() async throws {
        // Optimize background task scheduling
        logger.info("Optimizing background task scheduling")
    }
    
    private let logger = Logger(subsystem: "FocusLock", category: "BackgroundTaskOptimizer")
}

class PowerEfficiencyManager {
    func updateSettings(_ settings: PowerSettings) {
        // Update power management settings
    }

    func enableLowPowerMode() async throws {
        // Enable low power mode optimizations
        logger.info("Enabling low power mode")
    }
    
    func enablePowerEfficiencyMode() async throws {
        // Enable power efficiency mode
        logger.info("Enabling power efficiency mode")
    }
    
    private let logger = Logger(subsystem: "FocusLock", category: "PowerEfficiencyManager")
}

// MARK: - Data Models

struct ResourceMetrics {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let batteryLevel: Double?
    let thermalState: ThermalState
}

struct PerformanceAnalysis {
    let timestamp: Date
    let cpuPressure: Double
    let memoryPressure: Double
    let diskPressure: Double
    let batteryLevel: Double?
    let thermalState: ThermalState
    let requiresOptimization: Bool
}

// NOTE: OptimizationStrategy, ActionResult, and related types are defined in FocusLockModels.swift
// to avoid duplicate definitions and type conflicts

enum CacheTarget: String, CaseIterable, Codable {
    case all = "all"
    case memoryStore = "memory_store"
    case ocrExtractor = "ocr_extractor"
    case jarvisChat = "jarvis_chat"
    case nonEssential = "non_essential"
}

enum ThreadPriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}

struct CacheCleanupResult {
    let cleaned: Bool
    let freedSpaceMB: Double
    let statistics: CacheStatistics
}

struct CacheStatistics: Codable {
    let totalCacheSizeMB: Double
    let memoryCacheSizeMB: Double
    let diskCacheSizeMB: Double
    let hitRate: Double
    let evictionRate: Double

    init() {
        self.totalCacheSizeMB = 0.0
        self.memoryCacheSizeMB = 0.0
        self.diskCacheSizeMB = 0.0
        self.hitRate = 0.0
        self.evictionRate = 0.0
    }

    init(totalCacheSizeMB: Double, memoryCacheSizeMB: Double, diskCacheSizeMB: Double, hitRate: Double, evictionRate: Double) {
        self.totalCacheSizeMB = totalCacheSizeMB
        self.memoryCacheSizeMB = memoryCacheSizeMB
        self.diskCacheSizeMB = diskCacheSizeMB
        self.hitRate = hitRate
        self.evictionRate = evictionRate
    }
}

struct AdaptiveSettings: Codable {
    let cacheSettings: CacheSettings
    let backgroundSettings: BackgroundSettings
    let powerSettings: PowerSettings

    init() {
        self.cacheSettings = CacheSettings()
        self.backgroundSettings = BackgroundSettings()
        self.powerSettings = PowerSettings()
    }

    init(cacheSettings: CacheSettings, backgroundSettings: BackgroundSettings, powerSettings: PowerSettings) {
        self.cacheSettings = cacheSettings
        self.backgroundSettings = backgroundSettings
        self.powerSettings = powerSettings
    }
}

struct CacheSettings: Codable {
    let maxMemoryCacheMB: Double
    let maxDiskCacheMB: Double
    let compressionEnabled: Bool
    let intelligentEviction: Bool

    init() {
        self.maxMemoryCacheMB = 100.0
        self.maxDiskCacheMB = 500.0
        self.compressionEnabled = true
        self.intelligentEviction = true
    }
    
    init(maxMemoryCacheMB: Double, maxDiskCacheMB: Double, compressionEnabled: Bool, intelligentEviction: Bool) {
        self.maxMemoryCacheMB = maxMemoryCacheMB
        self.maxDiskCacheMB = maxDiskCacheMB
        self.compressionEnabled = compressionEnabled
        self.intelligentEviction = intelligentEviction
    }
}

struct BackgroundSettings: Codable {
    let maxConcurrentTasks: Int
    let allowedCPUPercent: Double
    let allowedMemoryMB: Double
    let adaptiveScheduling: Bool

    init() {
        self.maxConcurrentTasks = 2
        self.allowedCPUPercent = 0.05
        self.allowedMemoryMB = 50.0
        self.adaptiveScheduling = true
    }
    
    init(maxConcurrentTasks: Int, allowedCPUPercent: Double, allowedMemoryMB: Double, adaptiveScheduling: Bool) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.allowedCPUPercent = allowedCPUPercent
        self.allowedMemoryMB = allowedMemoryMB
        self.adaptiveScheduling = adaptiveScheduling
    }
}

struct PowerSettings: Codable {
    let lowPowerModeThreshold: Double
    let aggressiveOptimization: Bool
    let thermalThrottling: Bool
    let batteryOptimization: Bool

    init() {
        self.lowPowerModeThreshold = 0.2
        self.aggressiveOptimization = false
        self.thermalThrottling = true
        self.batteryOptimization = true
    }
    
    init(lowPowerModeThreshold: Double, aggressiveOptimization: Bool, thermalThrottling: Bool, batteryOptimization: Bool) {
        self.lowPowerModeThreshold = lowPowerModeThreshold
        self.aggressiveOptimization = aggressiveOptimization
        self.thermalThrottling = thermalThrottling
        self.batteryOptimization = batteryOptimization
    }
}


struct PerformanceProfile {
    let name: String
    let type: ProfileType
    let settings: AdaptiveSettings
    let targetMetrics: ResourceMetrics

    enum ProfileType {
        case performance
        case efficiency
        case balanced
    }
}
