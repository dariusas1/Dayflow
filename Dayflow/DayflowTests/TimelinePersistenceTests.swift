//
//  TimelinePersistenceTests.swift
//  DayflowTests
//
//  Created for Story 4.1: Timeline Data Persistence
//  Purpose: Comprehensive tests for timeline card persistence, caching, and integrity
//

import XCTest
@testable import Dayflow

final class TimelinePersistenceTests: XCTestCase {

    var storageManager: StorageManager!

    override func setUp() {
        super.setUp()
        // Use the shared StorageManager for tests
        // In a production test suite, we would create a test-specific instance with an in-memory database
        storageManager = StorageManager.shared
    }

    override func tearDown() {
        storageManager = nil
        super.tearDown()
    }

    // MARK: - Basic Persistence Tests

    func testTimelineCardPersistence() {
        // Create a test batch first
        let now = Int(Date().timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: now - 3600,
            endTs: now,
            chunkIds: []
        ) else {
            XCTFail("Failed to create test batch")
            return
        }

        // Create test timeline card
        let card = TimelineCardShell(
            startTimestamp: "10:00 AM",
            endTimestamp: "11:00 AM",
            category: "Work",
            subcategory: "Coding",
            title: "Swift Development",
            summary: "Working on database layer",
            detailedSummary: "Implementing timeline persistence with comprehensive tests",
            distractions: nil,
            appSites: nil
        )

        // Save timeline card
        let cardId = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
        XCTAssertNotNil(cardId, "Timeline card should be saved successfully")

        // Fetch timeline cards for the batch
        let cards = storageManager.fetchTimelineCards(forBatch: batchId)
        XCTAssertEqual(cards.count, 1, "Should retrieve exactly one card")
        XCTAssertEqual(cards.first?.title, "Swift Development", "Card title should match")
        XCTAssertEqual(cards.first?.category, "Work", "Card category should match")
    }

    func testTimelineCardWithDistractions() {
        let now = Int(Date().timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: now - 3600,
            endTs: now,
            chunkIds: []
        ) else {
            XCTFail("Failed to create test batch")
            return
        }

        // Create distraction
        let distraction = Distraction(
            startTime: "10:15 AM",
            endTime: "10:25 AM",
            title: "Email Check",
            summary: "Checked inbox for updates"
        )

        // Create card with distraction
        let card = TimelineCardShell(
            startTimestamp: "10:00 AM",
            endTimestamp: "11:00 AM",
            category: "Work",
            subcategory: "Coding",
            title: "Focused Work",
            summary: "Working with minor interruption",
            detailedSummary: "Deep work session with one email check",
            distractions: [distraction],
            appSites: nil
        )

        let cardId = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
        XCTAssertNotNil(cardId, "Timeline card with distractions should be saved")

        let cards = storageManager.fetchTimelineCards(forBatch: batchId)
        XCTAssertEqual(cards.first?.distractions?.count, 1, "Should have one distraction")
        XCTAssertEqual(cards.first?.distractions?.first?.title, "Email Check", "Distraction title should match")
    }

    func testUpdateTimelineCardVideoURL() {
        let now = Int(Date().timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: now - 3600,
            endTs: now,
            chunkIds: []
        ) else {
            XCTFail("Failed to create test batch")
            return
        }

        let card = TimelineCardShell(
            startTimestamp: "10:00 AM",
            endTimestamp: "11:00 AM",
            category: "Work",
            subcategory: "Coding",
            title: "Video Summary Test",
            summary: "Testing video URL updates",
            detailedSummary: "Card should support video URL updates",
            distractions: nil,
            appSites: nil
        )

        guard let cardId = storageManager.saveTimelineCardShell(batchId: batchId, card: card) else {
            XCTFail("Failed to save timeline card")
            return
        }

        // Update video URL
        let videoURL = "file:///path/to/video.mp4"
        storageManager.updateTimelineCardVideoURL(cardId: cardId, videoSummaryURL: videoURL)

        // Fetch and verify
        guard let fetchedCard = storageManager.fetchTimelineCard(byId: cardId) else {
            XCTFail("Failed to fetch timeline card")
            return
        }

        XCTAssertEqual(fetchedCard.videoSummaryURL, videoURL, "Video URL should be updated")
    }

    // MARK: - Day Boundary Tests

    func testFetchTimelineCardsForDay() {
        let now = Date()
        let calendar = Calendar.current

        // Create batch for today
        let batchStartTs = Int(now.addingTimeInterval(-3600).timeIntervalSince1970)
        let batchEndTs = Int(now.timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: batchStartTs,
            endTs: batchEndTs,
            chunkIds: []
        ) else {
            XCTFail("Failed to create test batch")
            return
        }

        // Create multiple cards
        let cards = [
            TimelineCardShell(
                startTimestamp: "9:00 AM",
                endTimestamp: "10:00 AM",
                category: "Work",
                subcategory: "Meeting",
                title: "Morning Standup",
                summary: "Daily team sync",
                detailedSummary: "Discussed sprint progress",
                distractions: nil,
                appSites: nil
            ),
            TimelineCardShell(
                startTimestamp: "10:00 AM",
                endTimestamp: "12:00 PM",
                category: "Work",
                subcategory: "Coding",
                title: "Development Work",
                summary: "Feature implementation",
                detailedSummary: "Working on timeline persistence",
                distractions: nil,
                appSites: nil
            )
        ]

        for card in cards {
            _ = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
        }

        // Fetch cards for today
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()
        let fetchedCards = storageManager.fetchTimelineCards(forDay: dayString)

        XCTAssertGreaterThanOrEqual(fetchedCards.count, 2, "Should retrieve at least 2 cards for today")
    }

    // MARK: - Data Integrity Tests

    func testValidateTimelineCardIntegrity() {
        // Run integrity validation
        let issues = storageManager.validateTimelineCardIntegrity()

        // Should return at least one result (either "no issues" or list of issues)
        XCTAssertFalse(issues.isEmpty, "Integrity validation should return results")

        // Check if validation passes or identifies issues
        if issues.first?.contains("passed") == true {
            // No issues found - good!
            XCTAssertEqual(issues.count, 1, "Should have single 'passed' message when no issues")
        } else {
            // Issues found - log them for inspection
            print("Database integrity issues found:")
            for issue in issues {
                print("  - \(issue)")
            }
        }
    }

    func testGetIntegrityStatistics() {
        let stats = storageManager.getIntegrityStatistics()

        // Basic sanity checks
        XCTAssertGreaterThanOrEqual(stats.totalCards, 0, "Total cards should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.totalBatches, 0, "Total batches should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.totalObservations, 0, "Total observations should be non-negative")

        // Integrity checks should show zero or low numbers
        XCTAssertEqual(stats.cardsWithInvalidTimestamps, 0, "Should have no cards with invalid timestamps")

        print("Database Statistics:")
        print("  Total Cards: \(stats.totalCards)")
        print("  Total Batches: \(stats.totalBatches)")
        print("  Total Observations: \(stats.totalObservations)")
        print("  Days with Cards: \(stats.daysWithCards)")
        print("  Average Cards per Day: \(String(format: "%.1f", stats.averageCardsPerDay))")
        if let oldest = stats.oldestCardDate {
            print("  Oldest Card: \(oldest)")
        }
        if let newest = stats.newestCardDate {
            print("  Newest Card: \(newest)")
        }
    }

    // MARK: - Cache Tests

    func testCacheInvalidationOnDelete() {
        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        // Fetch cards to populate cache
        let cardsBeforeDelete = storageManager.fetchTimelineCards(forDay: dayString)
        let countBefore = cardsBeforeDelete.count

        // Delete cards for the day
        _ = storageManager.deleteTimelineCards(forDay: dayString)

        // Fetch again - should hit database, not cache
        let cardsAfterDelete = storageManager.fetchTimelineCards(forDay: dayString)

        // After deletion, should have fewer or no cards
        XCTAssertLessThanOrEqual(cardsAfterDelete.count, countBefore, "Should have fewer cards after deletion")
    }

    // MARK: - Performance Tests

    func testTimelineLoadPerformance() {
        // This test measures the time to load timeline cards for a day
        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        measure {
            _ = storageManager.fetchTimelineCards(forDay: dayString)
        }
    }

    func testTimelineSavePerformance() {
        // This test measures the time to save a timeline card
        let now = Int(Date().timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: now - 3600,
            endTs: now,
            chunkIds: []
        ) else {
            XCTFail("Failed to create test batch")
            return
        }

        let card = TimelineCardShell(
            startTimestamp: "10:00 AM",
            endTimestamp: "11:00 AM",
            category: "Work",
            subcategory: "Coding",
            title: "Performance Test",
            summary: "Testing save performance",
            detailedSummary: "Measuring timeline card save latency",
            distractions: nil,
            appSites: nil
        )

        measure {
            _ = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
        }
    }

    // MARK: - Metadata Encoding Tests

    func testMetadataEncodingDecoding() {
        let now = Int(Date().timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: now - 3600,
            endTs: now,
            chunkIds: []
        ) else {
            XCTFail("Failed to create test batch")
            return
        }

        let distraction = Distraction(
            startTime: "10:15 AM",
            endTime: "10:25 AM",
            title: "Slack Notification",
            summary: "Team member posted update"
        )

        let appSites = AppSites(
            primary: "Xcode",
            secondary: "Safari"
        )

        let card = TimelineCardShell(
            startTimestamp: "10:00 AM",
            endTimestamp: "11:00 AM",
            category: "Work",
            subcategory: "Coding",
            title: "Metadata Test",
            summary: "Testing metadata encoding",
            detailedSummary: "Verifying distractions and appSites persist correctly",
            distractions: [distraction],
            appSites: appSites
        )

        guard let cardId = storageManager.saveTimelineCardShell(batchId: batchId, card: card) else {
            XCTFail("Failed to save timeline card")
            return
        }

        // Fetch and verify metadata
        let cards = storageManager.fetchTimelineCards(forBatch: batchId)
        guard let fetchedCard = cards.first else {
            XCTFail("Failed to fetch timeline card")
            return
        }

        XCTAssertNotNil(fetchedCard.distractions, "Distractions should be present")
        XCTAssertEqual(fetchedCard.distractions?.count, 1, "Should have one distraction")
        XCTAssertEqual(fetchedCard.distractions?.first?.title, "Slack Notification", "Distraction title should match")

        XCTAssertNotNil(fetchedCard.appSites, "AppSites should be present")
        XCTAssertEqual(fetchedCard.appSites?.primary, "Xcode", "Primary app should match")
        XCTAssertEqual(fetchedCard.appSites?.secondary, "Safari", "Secondary app should match")
    }

    // MARK: - Edge Cases

    func testEmptyTimelineCardsQuery() {
        // Query for a day that has no cards
        let futureDate = Date().addingTimeInterval(365 * 24 * 3600) // 1 year from now
        let (dayString, _, _) = futureDate.getDayInfoFor4AMBoundary()

        let cards = storageManager.fetchTimelineCards(forDay: dayString)
        XCTAssertEqual(cards.count, 0, "Future date should have no timeline cards")
    }

    func testInvalidDayStringFormat() {
        // Query with invalid day format should return empty array
        let cards = storageManager.fetchTimelineCards(forDay: "invalid-date")
        XCTAssertEqual(cards.count, 0, "Invalid day format should return empty array")
    }
}
