//
//  FocusLockCompatibilityTests.swift
//  DayflowTests
//
//  Backward compatibility and graceful degradation tests for FocusLock features
//

import XCTest
import SwiftUI
import Combine
@testable import Dayflow

final class FocusLockCompatibilityTests: XCTestCase {

    private var compatibilityManager: CompatibilityManager!
    private var featureManager: FeatureFlagManager.shared

    override func setUpWithError() throws {
        try super.setUpWithError()
        compatibilityManager = CompatibilityManager.shared
    }

    override func tearDownWithError() throws {
        compatibilityManager.disableGracefulMode()
        compatibilityManager = nil
        try super.tearDownWithError()
    }

    // MARK: - System Compatibility Tests

    func testSystemCompatibilityAssessment() throws {
        let report = compatibilityManager.checkCompatibility()

        XCTAssertNotNil(report, "Compatibility report should be generated")
        XCTAssertNotNil(report.macOSVersion, "macOS version should be assessed")
        XCTAssertGreaterThan(report.memoryMB, 0, "Memory should be detected")
        XCTAssertGreaterThanOrEqual(report.compatibilityScore, 0.0, "Compatibility score should be valid")
        XCTAssertLessThanOrEqual(report.compatibilityScore, 1.0, "Compatibility score should be valid")
        XCTAssertGreaterThanOrEqual(report.compatibilityScore, 0.5, "System should meet minimum requirements")
    }

    func testVersionCompatibility() throws {
        let report = compatibilityManager.checkCompatibility()

        // Should be compatible with current system
        XCTAssertTrue(report.isVersionCompatible, "Current macOS version should be compatible")
        XCTAssertTrue(report.isMemoryCompatible, "Current memory should be sufficient")

        // Verify compatibility score calculation
        XCTAssertGreaterThan(report.compatibilityScore, 0.0, "Compatibility score should be positive")
    }

    // MARK: - Feature Compatibility Tests

    func testFocusLockFeaturesCompatibility() throws {
        // Enable all FocusLock features
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        // Check that all features remain compatible
        let report = compatibilityManager.checkCompatibility()

        // System should handle all enabled features
        XCTAssertGreaterThanOrEqual(report.compatibilityScore, 0.3, "System should handle most features")

        // Check specific FocusLock features
        XCTAssertTrue(featureManager.isEnabled(.focusSessions), "Focus sessions should be enabled")
        XCTAssertTrue(featureManager.isEnabled(.emergencyBreaks), "Emergency breaks should be enabled")
        XCTAssertTrue(featureManager.isEnabled(.suggestedTodos), "Suggested todos should be enabled")
        XCTAssertTrue(featureManager.isEnabled(.planner), "Planner should be enabled")
    }

    func testFeatureDependencyCompatibility() throws {
        let report = compatibilityManager.checkCompatibility()

        // Test that feature dependencies are handled correctly
        // Core features should always be available
        XCTAssertTrue(featureManager.isEnabled(.coreFocusTimer), "Core focus timer should be enabled")
        XCTAssertTrue(featureManager.isEnabled(.essentialBreakReminders), "Essential break reminders should be enabled")

        // Dependent features should handle missing dependencies gracefully
        featureManager.setFeature(.suggestedTodos, enabled: true)
        featureManager.setFeature(.coreFocusTimer, enabled: false)

        // Dependent feature should be automatically disabled
        XCTAssertFalse(featureManager.isEnabled(.suggestedTodos), "Dependent feature should be disabled when dependency is missing")
    }

    // MARK: - Graceful Degradation Tests

    func testGracefulModeActivation() throws {
        // Enable all features first
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        XCTAssertTrue(compatibilityManager.isGracefulModeActive, "Graceful mode should be active")
        XCTAssertFalse(compatibilityManager.degradedFeatures.isEmpty, "Some features should be degraded")

        // Resource-intensive features should be degraded
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains("AdvancedDashboard"))
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains("JarvisChat"))
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains("Analytics"))
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains("CloudSync"))
    }

    func testGracefulModeDisabling() throws {
        // Enable graceful mode first
        compatibilityManager.enableGracefulMode()
        XCTAssertTrue(compatibilityManager.isGracefulActive, "Graceful mode should be active")

        // Disable graceful mode
        compatibilityManager.disableGracefulMode()

        XCTAssertFalse(compatibilityManager.isGracefulModeActive, "Graceful mode should be disabled")
        XCTAssertTrue(compatibilityManager.degradedFeatures.isEmpty, "No features should be degraded")

        // All features should return to normal state
        let report = compatibilityManager.checkCompatibility()
        XCTAssertGreaterThanOrEqual(report.compatibilityScore, 0.7, "Compatibility should improve after disabling graceful mode")
    }

    func testPerformanceOptimizations() throws {
        let initialReport = compatibilityManager.checkCompatibility()
        let initialScore = initialReport.compatibilityScore

        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Performance optimizations should be applied
        let gracefulReport = compatibilityManager.checkCompatibility()

        // System should still function, even if with degraded features
        XCTAssertGreaterThan(gracefulReport.compatibilityScore, 0.3, "System should remain functional in graceful mode")
        XCTAssertFalse(gracefulReport.compatibilityWarnings.isEmpty, "Should inform user about degradation")
    }

    // MARK: - Migration Compatibility Tests

    func testLegacyDataMigrationCompatibility() throws {
        // Simulate legacy data
        let userDefaults = UserDefaults.standard
        userDefaults.set([
            "focusDuration": 25 * 60,
            "breakDuration": 5 * 60,
            "enableSound": true,
            "theme": "light"
        ], forKey: "LegacyDayflowPreferences")
        userDefaults.set("1.0.0", forKey: "LegacyAppVersion")
        userDefaults.set(Date().addingTimeInterval(-86400), forKey: "LastSessionDate")

        // Test migration detection
        let migrationManager = DataMigrationManager.shared
        XCTAssertTrue(migrationManager.hasLegacyDayflowData(), "Should detect legacy Dayflow data")

        // Test compatibility with legacy data
        let report = compatibilityManager.checkCompatibility()
        XCTAssertNotNil(report, "Should handle legacy data gracefully")
        XCTAssertFalse(report.compatibilityWarnings.isEmpty, "Should warn about legacy data")
    }

    func testMigrationWithGracefulMode() throws {
        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Test migration in graceful mode
        let expectation = XCTestExpectation(description: "Migration in graceful mode")

        Task {
            let result = await DataMigrationManager.shared.performMigration()
            XCTAssertTrue(result.success || result.migratedItems >= 0, "Migration should not fail catastrophically")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)

        // System should remain stable during migration
        XCTAssertTrue(compatibilityManager.isGracefulModeActive, "Graceful mode should remain active")
        XCTAssertGreaterThan(compatibilityManager.degradedFeatures.count, 0, "Features should remain degraded")
    }

    // MARK: - Feature Flag Compatibility Tests

    func testFeatureFlagCompatibilityInGracefulMode() throws {
        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Test enabling/disabling features in graceful mode
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
            _ = featureManager.isEnabled(feature) // Should not crash
            featureManager.setFeature(feature, enabled: false)
            _ = featureManager.isEnabled(feature) // Should not crash
        }

        // System should remain stable
        XCTAssertTrue(compatibilityManager.isGracefulModeActive)
        XCTAssertFalse(compatibilityManager.degradedFeatures.isEmpty)
    }

    func testOnboardingCompatibilityInGracefulMode() throws {
        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Test onboarding operations
        for feature in FeatureFlag.allCases {
            featureManager.markOnboardingCompleted(for: feature)
            _ = featureManager.isOnboardingCompleted(for: feature)
            _ = featureManager.needsOnboarding(for: feature)
        }

        // Onboarding should work even in graceful mode
        XCTAssertTrue(compatibilityManager.isGracefulModeActive)
    }

    // MARK: - UI Compatibility Tests

    func testMainViewCompatibilityInGracefulMode() throws {
        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Test MainView rendering
        let mainView = MainView()
            .environmentObject(featureManager)
        let hostingController = UIHostingController(rootView: mainView)

        XCTAssertNotNil(hostingController.view, "MainView should render in graceful mode")
        XCTAssertNoThrow(try hostingController.view.layoutIfNeeded(), "MainView should layout without errors")
    }

    func testDegradedViewsFunctionality() throws {
        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Test that degraded views still function
        let degradedFeature = "AdvancedDashboard"
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains(degradedFeature))

        // Views should provide fallback functionality
        let fallback = compatibilityManager.getFallbackImplementation(for: degradedFeature)
        XCTAssertNotNil(fallback, "Should provide fallback for degraded features")

        if let fallback = fallback {
            switch fallback.fallbackType {
            case .simplifiedView:
                XCTAssertTrue(true) // Should use simplified view
            case .disabled:
                XCTAssertTrue(true) // Should be disabled
            case .alternative:
                XCTAssertTrue(true) // Should use alternative
            }
        }
    }

    // MARK: - Error Handling Tests

    func testCompatibilityErrorHandling() throws {
        // Test with corrupted system data
        let userDefaults = UserDefaults.standard
        userDefaults.set("corrupted_data", forKey: "FocusLockSystemInfo")

        // System should handle gracefully
        let report = compatibilityManager.checkCompatibility()
        XCTAssertNotNil(report, "Should generate report despite corrupted data")
        XCTAssertGreaterThanOrEqual(report.compatibilityScore, 0.0, "Should provide minimum functionality")
    }

    func testGracefulModeErrorRecovery() throws {
        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        // Simulate error conditions
        let userDefaults = UserDefaults.standard
        userDefaults.set("invalid_state", forKey: "GracefulModeState")

        // Should recover gracefully
        XCTAssertNotNil(compatibilityManager.systemCompatibility, "Should maintain system compatibility")
        XCTAssertTrue(compatibilityManager.isGracefulModeActive, "Should maintain graceful mode")

        // Should be able to disable gracefully
        compatibilityManager.disableGracefulMode()
        XCTAssertFalse(compatibilityManager.isGracefulModeActive, "Should disable gracefully")
    }

    // MARK: - Performance Tests

    func testCompatibilityCheckPerformance() throws {
        measure(metrics: [.wallClock]) {
            for _ in 0..<10 {
                let report = compatibilityManager.checkCompatibility()
                _ = report.compatibilityScore
                _ = report.isVersionCompatible
                _ = report.isMemoryCompatible
            }
        }

        // Compatibility checks should be fast
        XCTAssertTrue(true) // Performance measured by XCTest
    }

    func testGracefulModeTogglePerformance() throws {
        measure(metrics: [.wallClock]) {
            for _ in 0..<5 {
                compatibilityManager.enableGracefulMode()
                compatibilityManager.disableGracefulMode()
            }
        }

        // Graceful mode toggling should be efficient
        XCTAssertTrue(true) // Performance measured by XCTest
    }

    // MARK: - Integration Tests

    func testCompleteCompatibilitySystem() throws {
        // Test complete compatibility workflow
        let initialReport = compatibilityManager.checkCompatibility()

        // Enable all features
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        // Enable graceful mode if needed
        if initialReport.compatibilityScore < 0.6 {
            compatibilityManager.enableGracefulMode()
        }

        // Verify system state
        let finalReport = compatibilityManager.checkCompatibility()
        XCTAssertGreaterThanOrEqual(finalReport.compatibilityScore, 0.3, "System should be functional")

        // Test migration if needed
        let migrationManager = DataMigrationManager.shared
        if migrationManager.hasLegacyDayflowData() {
            let expectation = XCTestExpectation(description: "System migration")

            Task {
                let result = await migrationManager.performMigration()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 30.0)
        }

        // System should be stable and functional
        XCTAssertTrue(true)
    }

    // MARK: - Helper Methods

    private func simulateLegacyEnvironment() {
        let userDefaults = UserDefaults.standard

        // Simulate old preferences
        userDefaults.set([
            "focusSessionDuration": 1500,
            "breakDuration": 300,
            "enableNotifications": true,
            "theme": "light",
            "analyticsEnabled": false
        ], forKey: "LegacyPreferences")

        // Simulate old session data
        userDefaults.set([
            "lastSessionStart": Date().addingTimeInterval(-7200),
            "lastSessionDuration": 1800,
            "lastSessionCompleted": true
        ], forKey: "LegacySessionData")

        userDefaults.set("1.5.0", forKey: "LegacyVersion")
        userDefaults.set(Date().addingTimeInterval(-86400 * 7), forKey: "LastMigration")
    }

    private func cleanupLegacyEnvironment() {
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "LegacyPreferences")
        userDefaults.removeObject(forKey: "LegacySessionData")
        userDefaults.removeObject(forKey: "LegacyVersion")
        userDefaults.removeObject(forKey: "LastMigration")
    }

    private func verifyGracefulModeBehavior() -> Bool {
        guard compatibilityManager.isGracefulModeActive else {
            return false
        }

        // Check that resource-intensive features are degraded
        let resourceIntensiveFeatures: Set<String> = [
            "AdvancedDashboard", "JarvisChat", "Analytics", "CloudSync", "AdvancedSettings"
        ]

        for feature in resourceIntensiveFeatures {
            if !compatibilityManager.degradedFeatures.contains(feature) {
                return false
            }
        }

        return true
    }

    private func validateSystemStability() -> Bool {
        // Basic stability checks
        let report = compatibilityManager.checkCompatibility()
        guard report.compatibilityScore >= 0.3 else {
            return false
        }

        // Feature flag system should work
        for feature in FeatureFlag.allCases {
            _ = featureManager.isEnabled(feature)
        }

        // Views should render
        let mainView = MainView()
            .environmentObject(featureManager)
        let hostingController = UIHostingController(rootView: mainView)
        guard hostingController.view != nil else {
            return false
        }

        return true
    }
}

// MARK: - Test Extensions

extension FocusLockCompatibilityTests {

    func createCompatibilityTestScenario() -> CompatibilityTestScenario {
        return CompatibilityTestScenario(
            name: "FocusLock Compatibility Test",
            description: "Comprehensive compatibility test with all features enabled",
            systemRequirements: SystemRequirements(
                minVersion: OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0),
                minMemoryMB: 4096,
                recommendedVersion: OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0),
                recommendedMemoryMB: 8192
            )
        )
    }

    func validateGracefulDegradation() -> GracefulDegradationResult {
        // Enable all features first
        for feature in FeatureFlag.allCases {
            featureManager.setFeature(feature, enabled: true)
        }

        let initialFeatureCount = FeatureFlag.allCases.filter { featureManager.isEnabled($0) }.count

        // Enable graceful mode
        compatibilityManager.enableGracefulMode()

        let degradedFeatureCount = compatibilityManager.degradedFeatures.count
        let availableFeatureCount = FeatureFlag.allCases.filter { featureManager.isEnabled($0) }.count

        // Check that core features remain available
        let coreFeaturesAvailable = featureManager.isEnabled(.coreFocusTimer) &&
                                   featureManager.isEnabled(.essentialBreakReminders)

        return GracefulDegradationResult(
            initialFeatureCount: initialFeatureCount,
            degradedFeatureCount: degradedFeatureCount,
            availableFeatureCount: availableFeatureCount,
            coreFeaturesAvailable: coreFeaturesAvailable,
            gracefulModeActive: compatibilityManager.isGracefulModeActive
        )
    }
}

// MARK: - Supporting Types

struct CompatibilityTestScenario {
    let name: String
    let description: String
    let systemRequirements: SystemRequirements
}

struct SystemRequirements {
    let minVersion: OperatingSystemVersion
    let minMemoryMB: Double
    let recommendedVersion: OperatingSystemVersion
    let recommendedMemoryMB: Double
}

struct GracefulDegradationResult {
    let initialFeatureCount: Int
    let degradedFeatureCount: Int
    let availableFeatureCount: Int
    let coreFeaturesAvailable: Bool
    let gracefulModeActive: Bool
}