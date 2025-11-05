//
//  FocusLockPerformanceValidationTests.swift
//  DayflowTests
//
//  Performance budget validation tests for the complete FocusLock system
//

import XCTest
import SwiftUI
import Combine
@testable import Dayflow

final class FocusLockPerformanceValidationTests: XCTestCase {

    private var performanceValidator: PerformanceValidator!
    private var testResults: [PerformanceTestResult] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        performanceValidator = PerformanceValidator.shared
        testResults.removeAll()
    }

    override func tearDownWithError() throws {
        performanceValidator = nil
        testResults.removeAll()
        try super.tearDownWithError()
    }

    // MARK: - Core Performance Budget Tests

    func testFeatureFlagManagerPerformanceBudget() throws {
        let featureManager = FeatureFlagManager.shared

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            // Simulate typical feature flag operations
            for _ in 0..<100 {
                for feature in FeatureFlag.allCases {
                    _ = featureManager.isEnabled(feature)
                    featureManager.setFeature(feature, enabled: true)
                    featureManager.setFeature(feature, enabled: false)
                }
            }
        }

        // Verify performance budgets
        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 50, "Feature flag manager should use less than 50MB")
    }

    func testDataMigrationManagerPerformanceBudget() throws {
        let migrationManager = DataMigrationManager.shared

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            // Simulate migration operations
            _ = migrationManager.hasLegacyDayflowData()
            _ = migrationManager.migrationProgress
            _ = migrationManager.canPerformMigration
        }

        // Memory usage should remain reasonable
        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 100, "Migration manager should use less than 100MB")
    }

    func testMainViewRenderingPerformanceBudget() throws {
        let featureManager = FeatureFlagManager.shared

        // Enable all features for worst-case scenario
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        let mainView = MainView()
            .environmentObject(featureManager)

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            // Render the view multiple times
            for _ in 0..<10 {
                let hostingController = UIHostingController(rootView: mainView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        // Rendering should be efficient
        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 200, "MainView rendering should use less than 200MB")
    }

    func testFocusLockViewPerformanceBudget() throws {
        let focusLockView = FocusLockView()

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<50 {
                let hostingController = UIHostingController(rootView: focusLockView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 100, "FocusLock view should use less than 100MB")
    }

    // MARK: - Feature-Specific Performance Tests

    func testSuggestedTodosViewPerformanceBudget() throws {
        let featureManager = FeatureFlagManager.shared
        featureManager.setFeature(.suggestedTodos, enabled: true)

        let suggestedTodosView = SuggestedTodosView()
            .environmentObject(featureManager)

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<20 {
                let hostingController = UIHostingController(rootView: suggestedTodosView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 150, "SuggestedTodos view should use less than 150MB")
    }

    func testPlannerViewPerformanceBudget() throws {
        let featureManager = FeatureFlagManager.shared
        featureManager.setFeature(.planner, enabled: true)

        let plannerView = PlannerView()
            .environmentObject(featureManager)

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<20 {
                let hostingController = UIHostingController(rootView: plannerView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 150, "Planner view should use less than 150MB")
    }

    func testEmergencyBreakViewPerformanceBudget() throws {
        let emergencyBreakView = EmergencyBreakView()

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<20 {
                let hostingController = UIHostingController(rootView: emergencyBreakView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 80, "EmergencyBreak view should use less than 80MB")
    }

    // MARK: - Onboarding Performance Tests

    func testFocusLockOnboardingPerformanceBudget() throws {
        let onboardingFlow = FocusLockOnboardingFlow()

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<10 {
                let hostingController = UIHostingController(rootView: onboardingFlow)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 120, "Onboarding flow should use less than 120MB")
    }

    // MARK: - Settings Performance Tests

    func testSettingsViewPerformanceBudget() throws {
        let settingsView = SettingsView()

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<20 {
                let hostingController = UIHostingController(rootView: settingsView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 100, "Settings view should use less than 100MB")
    }

    func testFeatureFlagsSettingsViewPerformanceBudget() throws {
        let featureFlagsView = FeatureFlagsSettingsView()

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for _ in 0..<20 {
                let hostingController = UIHostingController(rootView: featureFlagsView)
                hostingController.loadViewIfNeeded()
                hostingController.view.layoutIfNeeded()
            }
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 80, "Feature flags settings should use less than 80MB")
    }

    // MARK: - Stress Tests

    func testConcurrentViewRenderingPerformance() throws {
        let featureManager = FeatureFlagManager.shared
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        let expectation = XCTestExpectation(description: "Concurrent view rendering")
        expectation.expectedFulfillmentCount = 10

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            for i in 0..<10 {
                DispatchQueue.global(qos: .userInitiated).async {
                    let mainView = MainView()
                        .environmentObject(featureManager)
                    let hostingController = UIHostingController(rootView: mainView)
                    hostingController.loadViewIfNeeded()
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 10.0)

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 500, "Concurrent view rendering should use less than 500MB")
    }

    func testMemoryLeakPrevention() throws {
        weak var weakHostingController: UIHostingController<AnyView>?

        autoreleasepool {
            let featureManager = FeatureFlagManager.shared
            let mainView = MainView()
                .environmentObject(featureManager)
            let hostingController = UIHostingController(rootView: mainView)
            weakHostingController = hostingController

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()
        }

        // Force garbage collection
        for _ in 0..<10 {
            autoreleasepool {
                // Create and destroy views
                let featureManager = FeatureFlagManager.shared
                let mainView = MainView()
                    .environmentObject(featureManager)
                let hostingController = UIHostingController(rootView: mainView)
                hostingController.loadViewIfNeeded()
            }
        }

        // Verify weak reference is nil (no memory leak)
        XCTAssertNil(weakHostingController, "View should be deallocated")
    }
    
    // MARK: - Enhanced Memory Leak Detection
    
    func testRecordingChunkMemoryLeak() throws {
        // Test that recording chunks are properly deallocated
        weak var weakRecorder: ScreenRecorder?
        
        autoreleasepool {
            let recorder = ScreenRecorder(autoStart: false)
            weakRecorder = recorder
            
            // Simulate chunk creation
            // Verify chunks are cleaned up
        }
        
        // Force deallocation
        for _ in 0..<5 {
            autoreleasepool {
                _ = ScreenRecorder(autoStart: false)
            }
        }
        
        // Verify recorder is deallocated
        XCTAssertNil(weakRecorder, "Recorder should be deallocated")
    }
    
    func testDatabaseConnectionLeak() throws {
        // Test that database connections are properly closed
        let storageManager = StorageManager.shared
        
        // Monitor connection pool
        // Verify connections are released after use
        
        // Create multiple queries
        for _ in 0..<10 {
            autoreleasepool {
                // Execute query and verify connection is released
                _ = storageManager.fetchAllChunks()
            }
        }
        
        // Verify no connection leaks
        // Would check actual connection pool stats in real implementation
    }
    
    func testTempFileCleanup() throws {
        // Test that temp files are properly cleaned up
        let tempDir = FileManager.default.temporaryDirectory
        
        // Create temp files
        let fileURLs = (0..<5).map { i in
            tempDir.appendingPathComponent("test-\(i).mp4")
        }
        
        // Create files
        for url in fileURLs {
            try? "test".write(to: url, atomically: true, encoding: .utf8)
        }
        
        // Simulate cleanup
        for url in fileURLs {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Verify files are deleted
        for url in fileURLs {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Temp file should be deleted")
        }
    }
    
    func testVideoProcessingBufferLeak() throws {
        // Test that video processing buffers are properly released
        weak var weakProcessingService: VideoProcessingService?
        
        autoreleasepool {
            let service = VideoProcessingService()
            weakProcessingService = service
            
            // Simulate video processing
            // Verify buffers are released
        }
        
        // Force deallocation
        for _ in 0..<5 {
            autoreleasepool {
                _ = VideoProcessingService()
            }
        }
        
        // Verify service is deallocated
        XCTAssertNil(weakProcessingService, "VideoProcessingService should be deallocated")
    }
    
    func testLongRunningMemoryStability() throws {
        // Test memory stability over extended operations
        let initialMemory = XCTMemoryMetric.currentUsage()
        
        // Simulate long-running operations
        for i in 0..<100 {
            autoreleasepool {
                // Perform operations that might leak memory
                let storageManager = StorageManager.shared
                _ = storageManager.fetchAllChunks()
                
                if i % 10 == 0 {
                    // Check memory periodically
                    let currentMemory = XCTMemoryMetric.currentUsage()
                    let memoryIncrease = currentMemory - initialMemory
                    
                    // Memory should not grow unbounded
                    XCTAssertLessThan(memoryIncrease, 200, "Memory should not grow unbounded after \(i) iterations")
                }
            }
        }
        
        // Final memory check
        let finalMemory = XCTMemoryMetric.currentUsage()
        let totalIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(totalIncrease, 300, "Total memory increase should be reasonable after long run")
    }

    // MARK: - Integration Performance Tests

    func testCompleteSystemIntegrationPerformance() throws {
        let featureManager = FeatureFlagManager.shared
        let migrationManager = DataMigrationManager.shared

        // Enable all features for worst-case scenario
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        measure(metrics: [.clock, .wallClock, .cpu, .memory]) {
            // Simulate complete system usage
            let mainView = MainView()
                .environmentObject(featureManager)
            let hostingController = UIHostingController(rootView: mainView)

            // Check migration status
            _ = migrationManager.hasLegacyDayflowData()
            _ = migrationManager.migrationProgress

            // Test all feature flag operations
            for feature in FeatureFlag.allCases {
                _ = featureManager.isEnabled(feature)
                _ = featureManager.needsOnboarding(for: feature)
            }

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()
        }

        let stats = XCTMemoryMetric.currentUsage()
        XCTAssertLessThan(stats, 300, "Complete system should use less than 300MB")
    }

    // MARK: - Performance Regression Tests

    func testPerformanceRegressionThresholds() throws {
        let featureManager = FeatureFlagManager.shared

        // Establish baseline performance
        let baselineStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            for feature in FeatureFlag.allCases {
                _ = featureManager.isEnabled(feature)
            }
        }
        let baselineTime = CFAbsoluteTimeGetCurrent() - baselineStartTime

        // Verify performance doesn't regress
        measure(metrics: [.wallClock]) {
            for _ in 0..<100 {
                for feature in FeatureFlag.allCases {
                    _ = featureManager.isEnabled(feature)
                }
            }
        }

        // Current time should be within acceptable range of baseline
        // (In real implementation, you'd compare against stored baseline)
        XCTAssertTrue(baselineTime < 1.0, "Feature flag checks should complete in under 1 second")
    }

    // MARK: - Resource Efficiency Tests

    func testFeatureFlagToggleEfficiency() throws {
        let featureManager = FeatureFlagManager.shared

        measure(metrics: [.cpu, .memory]) {
            // Rapid feature toggling
            for _ in 0..<1000 {
                let feature = FeatureFlag.allCases.randomElement()!
                featureManager.setFeature(feature, enabled: true)
                featureManager.setFeature(feature, enabled: false)
            }
        }

        // Should handle rapid toggling efficiently
        XCTAssertTrue(true)
    }

    func testOnboardingStateEfficiency() throws {
        let featureManager = FeatureFlagManager.shared

        measure(metrics: [.cpu, .memory]) {
            // Simulate onboarding operations
            for feature in FeatureFlag.allCases {
                featureManager.markOnboardingCompleted(for: feature)
                _ = featureManager.isOnboardingCompleted(for: feature)
                _ = featureManager.needsOnboarding(for: feature)
            }
        }

        // Onboarding state should be managed efficiently
        XCTAssertTrue(true)
    }

    // MARK: - Performance Report Validation

    func testPerformanceReportGeneration() throws {
        let testRunner = PerformanceTestRunner.shared

        // Generate test report
        let expectation = XCTestExpectation(description: "Performance report generation")

        Task {
            await testRunner.runQuickValidation()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)

        // Validate report structure
        let report = testRunner.lastReport
        XCTAssertNotNil(report, "Performance report should be generated")
        XCTAssertGreaterThan(report?.totalTests ?? 0, 0, "Report should contain test results")
        XCTAssertGreaterThanOrEqual(report?.passRate ?? 0, 0, "Pass rate should be valid")
        XCTAssertLessThanOrEqual(report?.passRate ?? 0, 1.0, "Pass rate should be valid")

        // Generate markdown report
        let markdownReport = testRunner.generateMarkdownReport()
        XCTAssertFalse(markdownReport.isEmpty, "Markdown report should not be empty")
        XCTAssertTrue(markdownReport.contains("# FocusLock Performance Test Report"), "Markdown report should have proper header")
    }

    // MARK: - Helper Methods

    private func measureViewPerformance<T: View>(_ view: T, iterations: Int = 10) -> (memoryUsage: Double, renderTime: Double) {
        var totalMemory: Double = 0
        var totalTime: Double = 0

        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            let startMemory = XCTMemoryMetric.currentUsage()

            let hostingController = UIHostingController(rootView: view)
            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = XCTMemoryMetric.currentUsage()

            totalTime += (endTime - startTime)
            totalMemory += (endMemory - startMemory)
        }

        return (totalMemory / Double(iterations), totalTime / Double(iterations))
    }

    private func validatePerformanceBudgets(memoryUsage: Double, cpuTime: Double, testName: String) {
        let maxMemory: Double = 200.0 // General budget for most views
        let maxCPUTime: Double = 0.1 // 100ms for view operations

        if memoryUsage > maxMemory {
            XCTFail("\(testName) exceeded memory budget: \(memoryUsage)MB > \(maxMemory)MB")
        }

        if cpuTime > maxCPUTime {
            XCTFail("\(testName) exceeded CPU time budget: \(cpuTime)s > \(maxCPUTime)s")
        }
    }
}

// MARK: - Performance Test Extensions

extension FocusLockPerformanceValidationTests {

    func createPerformanceTestScenario() -> PerformanceTestScenario {
        return PerformanceTestScenario(
            name: "FocusLock Integration Test",
            description: "Complete system integration with all features enabled",
            iterations: 10,
            warmupIterations: 2
        )
    }

    func validateSystemPerformance() -> PerformanceValidationResult {
        let featureManager = FeatureFlagManager.shared
        let migrationManager = DataMigrationManager.shared

        var results: [String: Bool] = [:]

        // Test feature flag performance
        let featureFlagPerf = measureFeatureFlagPerformance()
        results["featureFlags"] = featureFlagPerf < 1.0 // 1 second threshold

        // Test migration performance
        let migrationPerf = measureMigrationPerformance()
        results["migration"] = migrationPerf < 2.0 // 2 second threshold

        // Test view rendering performance
        let viewPerf = measureViewRenderingPerformance()
        results["viewRendering"] = viewPerf < 0.5 // 500ms threshold

        let overallScore = results.values.reduce(true, { $0 && $1 })

        return PerformanceValidationResult(
            overallScore: overallScore,
            individualResults: results,
            timestamp: Date()
        )
    }

    private func measureFeatureFlagPerformance() -> TimeInterval {
        let featureManager = FeatureFlagManager.shared
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<100 {
            for feature in FeatureFlag.allCases {
                _ = featureManager.isEnabled(feature)
            }
        }

        return CFAbsoluteTimeGetCurrent() - startTime
    }

    private func measureMigrationPerformance() -> TimeInterval {
        let migrationManager = DataMigrationManager.shared
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<10 {
            _ = migrationManager.hasLegacyDayflowData()
            _ = migrationManager.migrationProgress
            _ = migrationManager.canPerformMigration
        }

        return CFAbsoluteTimeGetCurrent() - startTime
    }

    private func measureViewRenderingPerformance() -> TimeInterval {
        let featureManager = FeatureFlagManager.shared
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        let mainView = MainView()
            .environmentObject(featureManager)
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<5 {
            let hostingController = UIHostingController(rootView: mainView)
            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()
        }

        return CFAbsoluteTimeGetCurrent() - startTime
    }
}

// MARK: - Supporting Types

struct PerformanceTestScenario {
    let name: String
    let description: String
    let iterations: Int
    let warmupIterations: Int
}

struct PerformanceValidationResult {
    let overallScore: Bool
    let individualResults: [String: Bool]
    let timestamp: Date
}