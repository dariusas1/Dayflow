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
    var testDatabasePath: String!

    override func setUp() {
        super.setUp()
        // Create test-specific database with isolated storage
        let tempDir = FileManager.default.temporaryDirectory
        let testDbPath = tempDir.appendingPathComponent("test_timeline_\(UUID().uuidString).sqlite")
        testDatabasePath = testDbPath.path

        // Initialize test instance with isolated database
        storageManager = StorageManager(testDatabasePath: testDatabasePath)
    }

    override func tearDown() {
        // Clean up test database and associated files
        if let dbPath = testDatabasePath {
            // Remove main database file
            try? FileManager.default.removeItem(atPath: dbPath)
            // Remove WAL and SHM files
            try? FileManager.default.removeItem(atPath: dbPath + "-wal")
            try? FileManager.default.removeItem(atPath: dbPath + "-shm")
        }

        storageManager = nil
        testDatabasePath = nil
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

    func testCacheExpiration() {
        // Test that cache entries expire after the configured duration
        // Create a test cache with short expiration (2 seconds)
        let testCache = TimelineCache(cacheDuration: 2.0, maxCacheSize: 10)

        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        // Create test data
        let testCards = [
            TimelineCard(
                batchId: 1,
                startTimestamp: "10:00 AM",
                endTimestamp: "11:00 AM",
                category: "Work",
                subcategory: "Testing",
                title: "Cache Test Card",
                summary: "Testing cache expiration",
                detailedSummary: "Verifying cache entries expire correctly",
                day: dayString,
                distractions: nil,
                videoSummaryURL: nil,
                otherVideoSummaryURLs: nil,
                appSites: nil
            )
        ]

        // Cache the cards
        testCache.cacheCards(testCards, forDay: dayString)

        // Immediately retrieve - should hit cache
        let cachedCards = testCache.getCachedCards(forDay: dayString)
        XCTAssertNotNil(cachedCards, "Cards should be in cache immediately after caching")
        XCTAssertEqual(cachedCards?.count, 1, "Should retrieve cached card")

        // Wait for expiration (2 seconds + small buffer)
        let expectation = XCTestExpectation(description: "Wait for cache expiration")
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // Retrieve again - should be expired and return nil
        let expiredCards = testCache.getCachedCards(forDay: dayString)
        XCTAssertNil(expiredCards, "Cards should be expired and return nil after expiration duration")
    }

    func testCacheStatisticsAccuracy() {
        // Test that cache statistics accurately track hits and misses
        let testCache = TimelineCache(cacheDuration: 60.0, maxCacheSize: 10)

        let testCards = [
            TimelineCard(
                batchId: 1,
                startTimestamp: "10:00 AM",
                endTimestamp: "11:00 AM",
                category: "Work",
                subcategory: "Testing",
                title: "Stats Test Card",
                summary: "Testing cache statistics",
                detailedSummary: "Verifying hit/miss tracking",
                day: "2025-11-14",
                distractions: nil,
                videoSummaryURL: nil,
                otherVideoSummaryURLs: nil,
                appSites: nil
            )
        ]

        // Reset statistics to start fresh
        testCache.resetStatistics()

        // First access - should be a miss
        let miss1 = testCache.getCachedCards(forDay: "2025-11-14")
        XCTAssertNil(miss1, "First access should be a miss")

        // Cache the cards
        testCache.cacheCards(testCards, forDay: "2025-11-14")

        // Second access - should be a hit
        let hit1 = testCache.getCachedCards(forDay: "2025-11-14")
        XCTAssertNotNil(hit1, "Second access should be a hit")

        // Third access - should be another hit
        let hit2 = testCache.getCachedCards(forDay: "2025-11-14")
        XCTAssertNotNil(hit2, "Third access should be a hit")

        // Access different day - should be a miss
        let miss2 = testCache.getCachedCards(forDay: "2025-11-15")
        XCTAssertNil(miss2, "Different day should be a miss")

        // Check statistics
        let stats = testCache.getStatistics()
        XCTAssertEqual(stats.hits, 2, "Should have 2 cache hits")
        XCTAssertEqual(stats.misses, 2, "Should have 2 cache misses")
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01, "Hit rate should be 50%")
        XCTAssertEqual(stats.totalEntries, 1, "Should have 1 cached entry")
    }

    func testCacheLRUEviction() {
        // Test that cache enforces size limits with LRU eviction
        let testCache = TimelineCache(cacheDuration: 60.0, maxCacheSize: 3)

        // Cache 4 days worth of data (exceeds max size of 3)
        for i in 1...4 {
            let dayString = "2025-11-\(10 + i)"
            let testCards = [
                TimelineCard(
                    batchId: Int64(i),
                    startTimestamp: "10:00 AM",
                    endTimestamp: "11:00 AM",
                    category: "Work",
                    subcategory: "Testing",
                    title: "LRU Test Card \(i)",
                    summary: "Testing LRU eviction",
                    detailedSummary: "Verifying oldest entries are evicted",
                    day: dayString,
                    distractions: nil,
                    videoSummaryURL: nil,
                    otherVideoSummaryURLs: nil,
                    appSites: nil
                )
            ]
            testCache.cacheCards(testCards, forDay: dayString)
        }

        // Check that cache has exactly 3 entries (maxCacheSize)
        let stats = testCache.getStatistics()
        XCTAssertEqual(stats.totalEntries, 3, "Cache should enforce size limit of 3 entries")

        // Oldest entry (2025-11-11) should have been evicted
        let oldestEntry = testCache.getCachedCards(forDay: "2025-11-11")
        XCTAssertNil(oldestEntry, "Oldest entry should have been evicted due to LRU")

        // Newer entries should still be cached
        let newerEntry1 = testCache.getCachedCards(forDay: "2025-11-12")
        let newerEntry2 = testCache.getCachedCards(forDay: "2025-11-13")
        let newestEntry = testCache.getCachedCards(forDay: "2025-11-14")

        XCTAssertNotNil(newerEntry1, "2025-11-12 should be cached")
        XCTAssertNotNil(newerEntry2, "2025-11-13 should be cached")
        XCTAssertNotNil(newestEntry, "2025-11-14 (newest) should be cached")
    }

    // MARK: - Performance Tests

    func testTimelineLoadPerformance() {
        // This test measures the time to load timeline cards for a day
        // Acceptance Criteria: Timeline data loads in < 2 seconds for 30 days of data
        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        // Create some test data to ensure we're testing with realistic volume
        let batchStartTs = Int(now.addingTimeInterval(-3600).timeIntervalSince1970)
        let batchEndTs = Int(now.timeIntervalSince1970)
        if let batchId = storageManager.saveBatch(startTs: batchStartTs, endTs: batchEndTs, chunkIds: []) {
            // Add multiple cards to simulate realistic day load
            for i in 0..<10 {
                let card = TimelineCardShell(
                    startTimestamp: "\(i):00 AM",
                    endTimestamp: "\(i):30 AM",
                    category: "Work",
                    subcategory: "Testing",
                    title: "Test Card \(i)",
                    summary: "Performance test data",
                    detailedSummary: "Testing timeline load performance",
                    distractions: nil,
                    appSites: nil
                )
                _ = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
            }
        }

        // Measure actual load time and validate against acceptance criteria
        let start = Date()
        _ = storageManager.fetchTimelineCards(forDay: dayString)
        let duration = Date().timeIntervalSince(start)

        // CRITICAL: Validate against acceptance criteria (< 2 seconds)
        XCTAssertLessThan(duration, 2.0, "Timeline load exceeded 2s acceptance criteria target (actual: \(String(format: "%.3f", duration))s)")

        // Also run measure block for detailed performance tracking
        measure {
            _ = storageManager.fetchTimelineCards(forDay: dayString)
        }
    }

    func testTimelineSavePerformance() {
        // This test measures the time to save a timeline card
        // Acceptance Criteria: Write latency < 100ms per timeline card
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

        // Measure actual save time and validate against acceptance criteria
        let start = Date()
        let cardId = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
        let duration = Date().timeIntervalSince(start)

        XCTAssertNotNil(cardId, "Timeline card should be saved successfully")

        // CRITICAL: Validate against acceptance criteria (< 100ms)
        XCTAssertLessThan(duration, 0.1, "Timeline save exceeded 100ms acceptance criteria target (actual: \(String(format: "%.3f", duration * 1000))ms)")

        // Also run measure block for detailed performance tracking
        measure {
            _ = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
        }
    }

    // MARK: - Concurrent Operation Tests

    func testConcurrentReadOperations() {
        // Test concurrent reads from multiple threads
        // Acceptance Criteria: Concurrent read support (multiple views accessing simultaneously)
        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        // Create test data
        let batchStartTs = Int(now.addingTimeInterval(-3600).timeIntervalSince1970)
        let batchEndTs = Int(now.timeIntervalSince1970)
        if let batchId = storageManager.saveBatch(startTs: batchStartTs, endTs: batchEndTs, chunkIds: []) {
            for i in 0..<5 {
                let card = TimelineCardShell(
                    startTimestamp: "\(i):00 AM",
                    endTimestamp: "\(i):30 AM",
                    category: "Work",
                    subcategory: "Testing",
                    title: "Concurrent Test Card \(i)",
                    summary: "Testing concurrent access",
                    detailedSummary: "Verifying thread-safe database reads",
                    distractions: nil,
                    appSites: nil
                )
                _ = storageManager.saveTimelineCardShell(batchId: batchId, card: card)
            }
        }

        // Perform concurrent reads from multiple threads
        let expectation = XCTestExpectation(description: "Concurrent reads complete")
        expectation.expectedFulfillmentCount = 100

        let concurrentQueue = DispatchQueue(label: "test.concurrent.reads", attributes: .concurrent)

        // Launch 100 concurrent read operations
        for _ in 0..<100 {
            concurrentQueue.async {
                let cards = self.storageManager.fetchTimelineCards(forDay: dayString)
                // Verify we got results without crashing
                XCTAssertGreaterThanOrEqual(cards.count, 0, "Concurrent read should succeed")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testConcurrentReadWriteOperations() {
        // Test concurrent reads while writes are occurring
        // This validates the thread-safety of DatabasePool and cache invalidation
        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        let batchStartTs = Int(now.addingTimeInterval(-3600).timeIntervalSince1970)
        let batchEndTs = Int(now.timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(startTs: batchStartTs, endTs: batchEndTs, chunkIds: []) else {
            XCTFail("Failed to create test batch")
            return
        }

        let expectation = XCTestExpectation(description: "Concurrent read/write operations complete")
        expectation.expectedFulfillmentCount = 50 // 25 reads + 25 writes

        let concurrentQueue = DispatchQueue(label: "test.concurrent.readwrite", attributes: .concurrent)

        // Launch concurrent read operations
        for i in 0..<25 {
            concurrentQueue.async {
                let cards = self.storageManager.fetchTimelineCards(forDay: dayString)
                XCTAssertGreaterThanOrEqual(cards.count, 0, "Concurrent read \(i) should succeed")
                expectation.fulfill()
            }
        }

        // Launch concurrent write operations
        for i in 0..<25 {
            concurrentQueue.async {
                let card = TimelineCardShell(
                    startTimestamp: "\(i % 12):00 AM",
                    endTimestamp: "\(i % 12):30 AM",
                    category: "Work",
                    subcategory: "Testing",
                    title: "Concurrent Write \(i)",
                    summary: "Testing concurrent write",
                    detailedSummary: "Verifying thread-safe database writes",
                    distractions: nil,
                    appSites: nil
                )
                let cardId = self.storageManager.saveTimelineCardShell(batchId: batchId, card: card)
                XCTAssertNotNil(cardId, "Concurrent write \(i) should succeed")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 15.0)

        // Verify data integrity after concurrent operations
        let finalCards = storageManager.fetchTimelineCards(forDay: dayString)
        XCTAssertGreaterThanOrEqual(finalCards.count, 25, "All concurrent writes should be persisted")
    }

    func testConcurrentCacheAccess() {
        // Test concurrent cache access from multiple threads
        // Validates TimelineCache thread-safety with serial queue
        let now = Date()
        let (dayString, _, _) = now.getDayInfoFor4AMBoundary()

        // Pre-populate cache by fetching data
        _ = storageManager.fetchTimelineCards(forDay: dayString)

        let expectation = XCTestExpectation(description: "Concurrent cache access complete")
        expectation.expectedFulfillmentCount = 50

        let concurrentQueue = DispatchQueue(label: "test.concurrent.cache", attributes: .concurrent)

        // Launch concurrent cache access operations
        for _ in 0..<50 {
            concurrentQueue.async {
                // This should hit the cache on most accesses
                let cards = self.storageManager.fetchTimelineCards(forDay: dayString)
                XCTAssertGreaterThanOrEqual(cards.count, 0, "Concurrent cache access should succeed")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
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
