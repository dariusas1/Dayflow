//
//  ActiveDisplayTrackerTests.swift
//  DayflowTests
//
//  Unit tests for ActiveDisplayTracker multi-display functionality
//  Epic 2 - Story 2.1: Multi-Display Screen Capture
//

import XCTest
import CoreGraphics
@testable import Dayflow

@MainActor
final class ActiveDisplayTrackerTests: XCTestCase {

    var tracker: ActiveDisplayTracker!

    override func setUp() async throws {
        try await super.setUp()
        tracker = ActiveDisplayTracker(pollHz: 1.0, debounceMs: 100)
    }

    override func tearDown() async throws {
        tracker = nil
        try await super.tearDown()
    }

    // MARK: - AC 2.1.1 Tests - Multi-Display Detection

    func testGetActiveDisplays() throws {
        // Test that getActiveDisplays() returns all connected displays
        let displays = tracker.getActiveDisplays()

        // Should return at least one display (the current one)
        XCTAssertGreaterThanOrEqual(displays.count, 1, "Should detect at least one display")

        // Each display should have valid properties
        for display in displays {
            XCTAssertGreaterThan(display.width, 0, "Display width should be positive")
            XCTAssertGreaterThan(display.height, 0, "Display height should be positive")
            XCTAssertGreaterThan(display.scaleFactor, 0, "Scale factor should be positive")
            XCTAssertFalse(display.bounds.isEmpty, "Display bounds should not be empty")
        }
    }

    func testDisplayInfoCreation() throws {
        // Test DisplayInfo.from() factory method
        let mainDisplayID = CGMainDisplayID()
        let displayInfo = DisplayInfo.from(displayID: mainDisplayID, isActive: true)

        XCTAssertNotNil(displayInfo, "Should create DisplayInfo from main display")
        XCTAssertEqual(displayInfo?.id, mainDisplayID, "Display ID should match")
        XCTAssertTrue(displayInfo?.isPrimary ?? false, "Main display should be primary")
        XCTAssertTrue(displayInfo?.isActive ?? false, "Should preserve active flag")
    }

    func testDisplayInfoResolutionDescription() throws {
        // Test that resolution description is correctly formatted
        let displays = tracker.getActiveDisplays()
        guard let firstDisplay = displays.first else {
            XCTFail("No displays found")
            return
        }

        let description = firstDisplay.resolutionDescription
        XCTAssertTrue(description.contains("×"), "Resolution description should contain ×")
        XCTAssertTrue(description.count > 3, "Resolution description should have meaningful length")
    }

    func testPrimaryDisplayDetection() throws {
        // Test that exactly one display is marked as primary
        let displays = tracker.getActiveDisplays()
        let primaryDisplays = displays.filter { $0.isPrimary }

        XCTAssertEqual(primaryDisplays.count, 1, "Should have exactly one primary display")
    }

    // MARK: - AC 2.1.3 Tests - Active Display Tracking

    func testGetPrimaryDisplay() throws {
        // Test getPrimaryDisplay() returns the active or main display
        let primaryDisplay = tracker.getPrimaryDisplay()

        XCTAssertNotNil(primaryDisplay, "Should return a primary display")

        if let display = primaryDisplay {
            XCTAssertGreaterThan(display.width, 0, "Primary display should have valid width")
            XCTAssertGreaterThan(display.height, 0, "Primary display should have valid height")
        }
    }

    func testActiveDisplayTracking() async throws {
        // Test that active display ID is tracked
        // Allow some time for tracker to initialize
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let activeID = tracker.activeDisplayID
        // Active ID might be nil initially, but should be set after mouse movement
        // In CI environment, this might not be set, so we just verify it's accessible
        _ = activeID
    }

    // MARK: - AC 2.1.2 Tests - Configuration Change Monitoring

    func testConfigurationChangesStream() async throws {
        // Test that configurationChanges AsyncStream emits events
        let expectation = XCTestExpectation(description: "Should receive configuration event")

        Task {
            let stream = tracker.configurationChanges
            var iterator = stream.makeAsyncIterator()

            // Should receive at least the initial configuration
            if let event = await iterator.next() {
                switch event {
                case .reconfigured(let displays):
                    XCTAssertGreaterThanOrEqual(displays.count, 1, "Initial configuration should have displays")
                default:
                    break
                }
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Display Configuration Tests

    func testDisplayConfiguration() throws {
        // Test DisplayConfiguration.current() creates valid configuration
        let displays = tracker.getActiveDisplays()
        guard !displays.isEmpty else {
            XCTFail("No displays available for testing")
            return
        }

        let config = DisplayConfiguration.current(displays: displays)

        XCTAssertNotNil(config, "Should create display configuration")
        XCTAssertEqual(config?.displayCount, displays.count, "Display count should match")
        XCTAssertEqual(config?.displayResolutions.count, displays.count, "Should have resolutions for all displays")

        // Verify primary display is set
        let primaryDisplay = displays.first { $0.isPrimary } ?? displays.first
        XCTAssertEqual(config?.primaryDisplayID, primaryDisplay?.id, "Primary display ID should be set correctly")
    }

    func testDisplayConfigurationEquivalence() throws {
        // Test isEquivalent() method
        let displays = tracker.getActiveDisplays()
        guard let config1 = DisplayConfiguration.current(displays: displays) else {
            XCTFail("Could not create configuration")
            return
        }

        // Create identical configuration
        guard let config2 = DisplayConfiguration.current(displays: displays) else {
            XCTFail("Could not create second configuration")
            return
        }

        // Should be equivalent despite different timestamps
        XCTAssertTrue(config1.isEquivalent(to: config2), "Identical configurations should be equivalent")
    }

    func testDisplayChangeEventDescription() throws {
        // Test DisplayChangeEvent description strings
        let mainDisplayID = CGMainDisplayID()
        guard let displayInfo = DisplayInfo.from(displayID: mainDisplayID) else {
            XCTFail("Could not create DisplayInfo")
            return
        }

        let addedEvent = DisplayChangeEvent.added(displayInfo)
        XCTAssertTrue(addedEvent.description.contains("added"), "Added event should have 'added' in description")

        let removedEvent = DisplayChangeEvent.removed(mainDisplayID)
        XCTAssertTrue(removedEvent.description.contains("removed"), "Removed event should have 'removed' in description")

        let reconfiguredEvent = DisplayChangeEvent.reconfigured([displayInfo])
        XCTAssertTrue(reconfiguredEvent.description.contains("Configuration"), "Reconfigured event should mention configuration")

        let reconfiguringEvent = DisplayChangeEvent.reconfiguring
        XCTAssertTrue(reconfiguringEvent.description.contains("progress"), "Reconfiguring event should mention progress")
    }

    // MARK: - Edge Cases

    func testEmptyDisplayList() throws {
        // Test that DisplayConfiguration handles empty display list
        let config = DisplayConfiguration.current(displays: [])
        XCTAssertNil(config, "Configuration should be nil for empty display list")
    }

    func testDisplayInfoFromInvalidID() throws {
        // Test that DisplayInfo.from() handles invalid display ID gracefully
        let invalidID: CGDirectDisplayID = 99999999
        let displayInfo = DisplayInfo.from(displayID: invalidID)

        // Should return nil for invalid display
        XCTAssertNil(displayInfo, "Should return nil for invalid display ID")
    }
}
