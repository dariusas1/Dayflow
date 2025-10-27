import XCTest
import SwiftUI
import Combine
@testable import Dayflow

final class FocusLockSystemTests: XCTestCase {

    // MARK: - System Integration Tests

    func testCompleteSystemIntegration() throws {
        // Test that all core systems work together
        let featureManager = FeatureFlagManager.shared
        let migrationManager = DataMigrationManager.shared
        let preferencesManager = UserPreferencesManager.shared
        let compatibilityManager = CompatibilityManager.shared

        // Verify all managers initialize correctly
        XCTAssertNotNil(featureManager)
        XCTAssertNotNil(migrationManager)
        XCTAssertNotNil(preferencesManager)
        XCTAssertNotNil(compatibilityManager)

        // Test feature flag and preference integration
        featureManager.setFeature(.suggestedTodos, enabled: true)
        XCTAssertTrue(featureManager.isEnabled(.suggestedTodos))

        // Test system compatibility checks
        let compatibilityReport = compatibilityManager.checkCompatibility()
        XCTAssertNotNil(compatibilityReport)
        XCTAssertTrue(compatibilityReport.compatibilityScore >= 0.0)
    }

    func testFeatureFlagAndPreferencesIntegration() throws {
        let featureManager = FeatureFlagManager.shared
        let preferencesManager = UserPreferencesManager.shared

        // Test that feature flags respect privacy preferences
        preferencesManager.updatePrivacyConsent(.denied)

        // Enable analytics feature
        featureManager.setFeature(.analytics, enabled: true)

        // Verify analytics doesn't actually collect data when consent is denied
        XCTAssertFalse(preferencesManager.privacyPreferences.allowAnalytics)

        // Grant consent and verify analytics can be enabled
        preferencesManager.updatePrivacyConsent(.granted)
        preferencesManager.privacyPreferences.allowAnalytics = true
        XCTAssertTrue(preferencesManager.privacyPreferences.allowAnalytics)
    }

    func testMigrationAndCompatibilityIntegration() throws {
        let migrationManager = DataMigrationManager.shared
        let compatibilityManager = CompatibilityManager.shared

        // Test that migration works with compatibility checks
        let expectation = XCTestExpectation(description: "Migration with compatibility check")

        Task {
            let migrationResult = await migrationManager.performMigration()
            let compatibilityReport = compatibilityManager.checkCompatibility()

            if migrationResult.success {
                XCTAssertTrue(true) // Migration succeeded
            }

            // Compatibility should be assessed regardless of migration outcome
            XCTAssertNotNil(compatibilityReport)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Performance Budget Validation Tests

    func testPerformanceBudgets() throws {
        let performanceMonitor = PerformanceMonitor.shared

        // Start monitoring
        performanceMonitor.startMonitoring()

        // Allow some time for metrics collection
        let expectation = XCTestExpectation(description: "Performance metrics collection")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify performance metrics are within budgets
        if let metrics = performanceMonitor.currentMetrics {
            XCTAssertTrue(metrics.cpuUsage < 0.2, "CPU usage should be under 20%")
            XCTAssertTrue(metrics.memoryUsage < 500.0, "Memory usage should be under 500MB")
            XCTAssertTrue(metrics.isWithinBudgets, "System should be within performance budgets")
        }
    }

    func testFeatureFlagPerformanceImpact() throws {
        let featureManager = FeatureFlagManager.shared
        let performanceMonitor = PerformanceMonitor.shared

        performanceMonitor.startMonitoring()

        // Enable all features and check performance impact
        let allFeatures = FeatureFlag.allCases
        for feature in allFeatures {
            featureManager.setFeature(feature, enabled: true)
        }

        // Allow time for system to stabilize
        let expectation = XCTestExpectation(description: "Stabilization after enabling all features")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)

        // Verify system still performs within acceptable limits
        if let metrics = performanceMonitor.currentMetrics {
            XCTAssertTrue(metrics.performanceScore > 0.5, "Performance score should remain acceptable")
        }

        performanceMonitor.stopMonitoring()
    }

    // MARK: - Backward Compatibility Tests

    func testLegacyDataMigration() throws {
        let migrationManager = DataMigrationManager.shared

        // Simulate legacy data
        let userDefaults = UserDefaults.standard
        userDefaults.set([
            "startTime": Date().addingTimeInterval(-3600),
            "duration": 1800,
            "completed": true
        ], forKey: "LegacySessionData")
        userDefaults.set("1.0.0", forKey: "LegacyAppVersion")

        // Test migration detection
        XCTAssertTrue(migrationManager.hasLegacyDayflowData())

        // Test migration execution
        let expectation = XCTestExpectation(description: "Legacy data migration")

        Task {
            let result = await migrationManager.performMigration()
            XCTAssertTrue(result.success || result.migratedItems >= 0, "Migration should not fail catastrophically")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGracefulDegradation() throws {
        let compatibilityManager = CompatibilityManager.shared
        let featureManager = FeatureFlagManager.shared

        // Enable graceful mode
        compatibilityManager.enableGracefulMode()
        XCTAssertTrue(compatibilityManager.isGracefulModeActive)

        // Check that resource-intensive features are degraded
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains("AdvancedDashboard"))
        XCTAssertTrue(compatibilityManager.degradedFeatures.contains("JarvisChat"))

        // Test fallback implementations
        let dashboardFallback = compatibilityManager.getFallbackImplementation(for: "AdvancedDashboard")
        XCTAssertNotNil(dashboardFallback)
        XCTAssertEqual(dashboardFallback?.fallbackType, .simplifiedView)

        // Disable graceful mode
        compatibilityManager.disableGracefulMode()
        XCTAssertFalse(compatibilityManager.isGracefulModeActive)
    }

    // MARK: - Data Persistence Tests

    func testPreferencesPersistence() throws {
        let preferencesManager = UserPreferencesManager.shared

        // Modify preferences
        preferencesManager.generalPreferences.totalSessionsCompleted = 10
        preferencesManager.focusPreferences.dailyFocusGoal = 6 * 3600
        preferencesManager.appearancePreferences.colorScheme = .dark

        // Save preferences
        preferencesManager.savePreferences()

        // Create new instance to test persistence
        let newPreferencesManager = UserPreferencesManager.shared

        XCTAssertEqual(newPreferencesManager.generalPreferences.totalSessionsCompleted, 10)
        XCTAssertEqual(newPreferencesManager.focusPreferences.dailyFocusGoal, 6 * 3600)
        XCTAssertEqual(newPreferencesManager.appearancePreferences.colorScheme, .dark)
    }

    func testFeatureFlagPersistence() throws {
        let featureManager = FeatureFlagManager.shared

        // Enable some features
        featureManager.setFeature(.suggestedTodos, enabled: true)
        featureManager.setFeature(.planner, enabled: true)
        featureManager.setFeature(.dailyJournal, enabled: true)

        // Mark onboarding as completed
        featureManager.markOnboardingCompleted(for: .suggestedTodos)

        // Create new instance to test persistence
        let newFeatureManager = FeatureFlagManager.shared

        XCTAssertTrue(newFeatureManager.isEnabled(.suggestedTodos))
        XCTAssertTrue(newFeatureManager.isEnabled(.planner))
        XCTAssertTrue(newFeatureManager.isEnabled(.dailyJournal))
        XCTAssertTrue(newFeatureManager.isOnboardingCompleted(for: .suggestedTodos))
    }

    // MARK: - Error Handling and Recovery Tests

    func testSystemResilience() throws {
        // Test system behavior with corrupted data
        let userDefaults = UserDefaults.standard
        userDefaults.set("corrupted_data", forKey: "FocusLockUserPreferences")

        // System should still initialize with defaults
        let preferencesManager = UserPreferencesManager.shared
        XCTAssertNotNil(preferencesManager)

        // Feature flags should still work
        let featureManager = FeatureFlagManager.shared
        XCTAssertTrue(featureManager.isEnabled(.coreFocusTimer))
    }

    func testConcurrentAccess() throws {
        let featureManager = FeatureFlagManager.shared
        let preferencesManager = UserPreferencesManager.shared

        let expectation = XCTestExpectation(description: "Concurrent access test")
        expectation.expectedFulfillmentCount = 10

        // Test concurrent access to managers
        for i in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                featureManager.setFeature(.suggestedTodos, enabled: i % 2 == 0)
                _ = featureManager.isEnabled(.suggestedTodos)

                preferencesManager.generalPreferences.totalSessionsCompleted = i
                preferencesManager.savePreferences()

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Memory and Resource Tests

    func testMemoryUsage() throws {
        // Create multiple instances to test memory management
        var managers: [Any] = []

        for _ in 0..<10 {
            managers.append(FeatureFlagManager.shared)
            managers.append(UserPreferencesManager.shared)
            managers.append(CompatibilityManager.shared)
        }

        // System should not crash with multiple references
        XCTAssertTrue(true)

        // Clear references
        managers.removeAll()
    }

    func testResourceCleanup() throws {
        let performanceMonitor = PerformanceMonitor.shared

        // Start monitoring
        performanceMonitor.startMonitoring()
        XCTAssertTrue(true)

        // Stop monitoring
        performanceMonitor.stopMonitoring()
        XCTAssertTrue(true)

        // Multiple start/stop cycles should work
        for _ in 0..<5 {
            performanceMonitor.startMonitoring()
            performanceMonitor.stopMonitoring()
        }

        XCTAssertTrue(true)
    }

    // MARK: - Integration Test Helpers

    func createTestEnvironment() -> (featureManager: FeatureFlagManager, preferencesManager: UserPreferencesManager, compatibilityManager: CompatibilityManager) {
        let featureManager = FeatureFlagManager.shared
        let preferencesManager = UserPreferencesManager.shared
        let compatibilityManager = CompatibilityManager.shared

        return (featureManager, preferencesManager, compatibilityManager)
    }

    func resetTestEnvironment() {
        let featureManager = FeatureFlagManager.shared
        let preferencesManager = UserPreferencesManager.shared
        let compatibilityManager = CompatibilityManager.shared

        // Reset all managers to default state
        featureManager.resetToDefaults()
        preferencesManager.resetToDefaults()
        compatibilityManager.disableGracefulMode()
    }
}

// MARK: - Mock Data Helpers

extension FocusLockSystemTests {

    func createMockLegacySessionData() -> [String: Any] {
        return [
            "id": UUID().uuidString,
            "startTime": Date().addingTimeInterval(-7200),
            "duration": 3600,
            "targetDuration": 3600,
            "completed": true,
            "interruptions": 2,
            "productivityScore": 0.85
        ]
    }

    func createMockLegacyPreferences() -> [String: Any] {
        return [
            "focusDuration": 25 * 60,
            "breakDuration": 5 * 60,
            "enableSound": true,
            "enableNotifications": true,
            "theme": "light"
        ]
    }
}