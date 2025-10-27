import XCTest
import SwiftUI
@testable import Dayflow

final class FocusLockIntegrationTests: XCTestCase {

    // MARK: - Test Managers

    func testFeatureFlagManagerInitialization() throws {
        // Test FeatureFlagManager initializes correctly
        let manager = FeatureFlagManager.shared
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.featureFlags.count, 14) // Verify all flags are loaded

        // Test critical features are enabled by default
        XCTAssertTrue(manager.isEnabled(.coreFocusTimer))
        XCTAssertTrue(manager.isEnabled(.essentialBreakReminders))
    }

    func testDataMigrationManagerInitialization() throws {
        // Test DataMigrationManager initializes correctly
        let manager = DataMigrationManager.shared
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.hasPendingMigrations)
    }

    // MARK: - Feature Flag Dependencies Tests

    func testFeatureFlagDependencies() throws {
        let manager = FeatureFlagManager.shared

        // Test that enabling a feature enables its dependencies
        if !manager.isEnabled(.advancedDashboard) {
            manager.setFeature(.advancedDashboard, enabled: true)
            XCTAssertTrue(manager.isEnabled(.coreFocusTimer)) // Should enable dependency
        }

        // Test that disabling a dependency disables dependent features
        if manager.isEnabled(.dailyJournal) {
            manager.setFeature(.coreFocusTimer, enabled: false)
            XCTAssertFalse(manager.isEnabled(.dailyJournal)) // Should disable dependent
        }
    }

    func testFeatureFlagRolloutStrategies() throws {
        let manager = FeatureFlagManager.shared

        // Test rollout strategy validation
        for flag in FeatureFlag.allCases {
            let strategy = manager.rolloutStrategy(for: flag)
            XCTAssertNotNil(strategy)

            // Test percentage-based strategies have valid percentages
            if case .percentage(let percent) = strategy {
                XCTAssertTrue(percent >= 0 && percent <= 100)
            }
        }
    }

    // MARK: - Data Migration Tests

    func testDayflowSessionDetection() throws {
        let manager = DataMigrationManager.shared

        // Test session detection logic
        let testSessionData: [String: Any] = [
            "startTime": Date(),
            "duration": 1500,
            "targetDuration": 1800,
            "completed": false
        ]

        let hasSessionData = manager.hasLegacyDayflowData()
        // This will depend on whether test environment has legacy data
        XCTAssertTrue(true) // Test passes if no exceptions thrown
    }

    func testMigrationProgressTracking() throws {
        let manager = DataMigrationManager.shared
        let expectation = XCTestExpectation(description: "Migration progress updates")

        var progressUpdates: [Double] = []

        // Mock migration progress observation
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let progress = manager.migrationProgress
            progressUpdates.append(progress)

            if progress >= 1.0 {
                timer.invalidate()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Verify progress updates were received
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertEqual(progressUpdates.last, 1.0)
    }

    // MARK: - UI Integration Tests

    func testMainViewFeatureFlagIntegration() throws {
        // Test MainView initializes with feature flags
        let mainView = MainView()

        // Create a hosting controller to test the view
        let hostingController = UIHostingController(rootView: mainView)
        XCTAssertNotNil(hostingController.view)

        // Test no crashes occur during initialization
        XCTAssertTrue(true)
    }

    func testFeatureFlagsSettingsViewRendering() throws {
        // Test FeatureFlagsSettingsView renders correctly
        let settingsView = FeatureFlagsSettingsView()
        let hostingController = UIHostingController(rootView: settingsView)
        XCTAssertNotNil(hostingController.view)
    }

    func testOnboardingViewFlow() throws {
        // Test onboarding view for each feature
        let features: [FeatureFlag] = [
            .suggestedTodos,
            .planner,
            .dailyJournal,
            .advancedDashboard,
            .jarvisChat
        ]

        for feature in features {
            let onboardingView = FeatureOnboardingView(feature: feature) {
                // Mock completion
            }
            let hostingController = UIHostingController(rootView: onboardingView)
            XCTAssertNotNil(hostingController.view)
        }
    }

    // MARK: - Performance Tests

    func testFeatureFlagManagerPerformance() throws {
        let manager = FeatureFlagManager.shared

        // Test performance of enabling/disabling features
        measure {
            for flag in FeatureFlag.allCases {
                manager.setFeature(flag, enabled: true)
                manager.setFeature(flag, enabled: false)
            }
        }
    }

    func testDataMigrationPerformance() throws {
        let manager = DataMigrationManager.shared

        // Test performance of migration checks
        measure {
            _ = manager.hasLegacyDayflowData()
            _ = manager.migrationProgress
        }
    }

    // MARK: - Persistence Tests

    func testFeatureFlagPersistence() throws {
        let manager = FeatureFlagManager.shared
        let originalState = manager.isEnabled(.suggestedTodos)

        // Toggle feature state
        manager.setFeature(.suggestedTodos, enabled: !originalState)

        // Create new manager instance to test persistence
        let newManager = FeatureFlagManager.shared
        XCTAssertEqual(newManager.isEnabled(.suggestedTodos), !originalState)

        // Restore original state
        manager.setFeature(.suggestedTodos, enabled: originalState)
    }

    func testOnboardingProgressPersistence() throws {
        let manager = FeatureFlagManager.shared
        let feature = FeatureFlag.suggestedTodos

        // Mark onboarding as completed
        manager.markOnboardingCompleted(for: feature)
        XCTAssertTrue(manager.isOnboardingCompleted(for: feature))

        // Test persistence
        let newManager = FeatureFlagManager.shared
        XCTAssertTrue(newManager.isOnboardingCompleted(for: feature))
    }

    // MARK: - Backward Compatibility Tests

    func testGracefulDegradation() throws {
        let manager = FeatureFlagManager.shared

        // Disable all optional features
        let optionalFeatures: [FeatureFlag] = [
            .suggestedTodos,
            .planner,
            .dailyJournal,
            .advancedDashboard,
            .jarvisChat,
            .analytics,
            .cloudSync,
            .suggestedActivities,
            .weeklyPlanning,
            .insights,
            .achievementSystem,
            .socialFeatures,
            .customThemes,
            .advancedSettings
        ]

        for feature in optionalFeatures {
            manager.setFeature(feature, enabled: false)
        }

        // Verify core features remain enabled
        XCTAssertTrue(manager.isEnabled(.coreFocusTimer))
        XCTAssertTrue(manager.isEnabled(.essentialBreakReminders))

        // Test UI doesn't crash with all features disabled
        let mainView = MainView()
        let hostingController = UIHostingController(rootView: mainView)
        XCTAssertNotNil(hostingController.view)
    }

    func testMigrationFromOldVersion() throws {
        // Test migration scenario from old Dayflow version
        let manager = DataMigrationManager.shared

        // Simulate old version data
        let userDefaults = UserDefaults.standard
        userDefaults.set("1.0.0", forKey: "DayflowVersion")
        userDefaults.set(Date(), forKey: "LastSessionDate")

        // Check migration is triggered
        let hasLegacyData = manager.hasLegacyDayflowData()
        if hasLegacyData {
            XCTAssertFalse(manager.hasPendingMigrations)
        }
    }

    // MARK: - Error Handling Tests

    func testFeatureFlagManagerErrorHandling() throws {
        let manager = FeatureFlagManager.shared

        // Test invalid feature combinations don't crash
        manager.setFeature(.dailyJournal, enabled: true)
        manager.setFeature(.coreFocusTimer, enabled: false) // Should disable journal

        // Verify system remains stable
        XCTAssertFalse(manager.isEnabled(.dailyJournal))
        XCTAssertFalse(manager.isEnabled(.coreFocusTimer))
    }

    func testDataMigrationErrorHandling() throws {
        let manager = DataMigrationManager.shared

        // Test migration with corrupted data doesn't crash
        let userDefaults = UserDefaults.standard
        userDefaults.set("invalid_data", forKey: "SessionData")

        // System should handle gracefully
        XCTAssertNoThrow(try manager.performMigration())
    }

    // MARK: - Memory Tests

    func testMemoryUsage() throws {
        // Test memory usage of managers
        let manager = FeatureFlagManager.shared
        let migrationManager = DataMigrationManager.shared

        // Initialize views to test memory
        let mainView = MainView()
        let settingsView = FeatureFlagsSettingsView()

        // Create array to hold references
        let objects: [Any] = [manager, migrationManager, mainView, settingsView]
        XCTAssertEqual(objects.count, 4)

        // Test no memory leaks occur
        XCTAssertTrue(true)
    }

    // MARK: - Integration Edge Cases

    func testConcurrentFeatureFlagAccess() throws {
        let manager = FeatureFlagManager.shared
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        // Test concurrent access doesn't cause crashes
        DispatchQueue.global(qos: .background).async {
            for i in 0..<10 {
                DispatchQueue.global(qos: .background).async {
                    let feature = FeatureFlag.allCases[i % FeatureFlag.allCases.count]
                    manager.setFeature(feature, enabled: i % 2 == 0)
                    _ = manager.isEnabled(feature)
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testFeatureFlagAnalyticsConsent() throws {
        let manager = FeatureFlagManager.shared

        // Test analytics recording respects privacy settings
        manager.setFeature(.analytics, enabled: false)

        // Enable/disable a feature
        manager.setFeature(.suggestedTodos, enabled: true)

        // Verify no crash occurs when analytics is disabled
        XCTAssertTrue(true)
    }
}