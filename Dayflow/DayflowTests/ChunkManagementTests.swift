//
//  ChunkManagementTests.swift
//  DayflowTests
//
//  Created for Story 4.2: Recording Chunk Management
//  Purpose: Comprehensive tests for chunk lifecycle, cleanup, and retention policies
//

import XCTest
@testable import Dayflow

final class ChunkManagementTests: XCTestCase {

    var storageManager: StorageManager!
    var testDatabasePath: String!
    var testRecordingsDir: URL!

    override func setUp() {
        super.setUp()
        // Create test-specific database with isolated storage
        let tempDir = FileManager.default.temporaryDirectory
        let testDbPath = tempDir.appendingPathComponent("test_chunks_\(UUID().uuidString).sqlite")
        testDatabasePath = testDbPath.path

        // Create test recordings directory
        testRecordingsDir = tempDir.appendingPathComponent("test_recordings_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: testRecordingsDir, withIntermediateDirectories: true)

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

        // Clean up test recordings directory
        if let recordingsDir = testRecordingsDir {
            try? FileManager.default.removeItem(at: recordingsDir)
        }

        storageManager = nil
        testDatabasePath = nil
        testRecordingsDir = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Create a test chunk file and register it in database
    func createTestChunk(daysOld: Int = 0, sizeBytes: Int = 1024) async -> (url: URL, id: Int64?) {
        let timestamp = Int(Date().timeIntervalSince1970) - (daysOld * 24 * 60 * 60)
        let filename = "chunk_\(timestamp)_\(timestamp + 60).mp4"
        let fileURL = testRecordingsDir.appendingPathComponent(filename)

        // Create dummy file with specified size
        let data = Data(repeating: 0, count: sizeBytes)
        try? data.write(to: fileURL)

        // Register chunk in database
        storageManager.registerChunk(url: fileURL)

        // Wait briefly for async registration to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Get the chunk ID
        let chunks = storageManager.fetchUnprocessedChunks(olderThan: 0)
        let chunkId = chunks.first(where: { $0.fileUrl == fileURL.path })?.id

        return (fileURL, chunkId)
    }

    /// Create multiple test chunks
    func createTestChunks(count: Int, daysOld: Int = 0, sizeBytes: Int = 1024) async -> [(url: URL, id: Int64?)] {
        var chunks: [(url: URL, id: Int64?)] = []
        for i in 0..<count {
            // Stagger timestamps slightly to ensure uniqueness
            let chunk = await createTestChunk(daysOld: daysOld, sizeBytes: sizeBytes + i)
            chunks.append(chunk)
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds - Small delay to ensure unique timestamps
        }
        return chunks
    }

    /// Mark a chunk as completed
    func markChunkCompleted(url: URL) async {
        storageManager.markChunkCompleted(url: url)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds - Wait for async operation
    }

    // MARK: - Basic Chunk Lifecycle Tests

    func testChunkRegistration() async throws {
        // Create and register a chunk
        let (fileURL, chunkId) = await createTestChunk(daysOld: 0, sizeBytes: 10000)

        // Verify chunk exists in database
        XCTAssertNotNil(chunkId, "Chunk should be registered in database")

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Chunk file should exist")

        // Verify chunk properties
        let chunks = storageManager.fetchUnprocessedChunks(olderThan: 0)
        let registeredChunk = chunks.first(where: { $0.id == chunkId })
        XCTAssertNotNil(registeredChunk, "Should find registered chunk")
        XCTAssertEqual(registeredChunk?.fileUrl, fileURL.path, "File URL should match")
        XCTAssertEqual(registeredChunk?.status, "recording", "Initial status should be 'recording'")
    }

    func testChunkLifecycle() async throws {
        // Create chunk
        let (fileURL, chunkId) = await createTestChunk()
        XCTAssertNotNil(chunkId, "Chunk should be registered")

        // Mark completed
        await markChunkCompleted(url: fileURL)

        // Verify status updated
        let completedChunks = storageManager.fetchUnprocessedChunks(olderThan: 0)
        let chunk = completedChunks.first(where: { $0.id == chunkId })
        XCTAssertEqual(chunk?.status, "completed", "Status should be updated to 'completed'")
    }

    func testChunkFailure() async throws {
        // Create chunk
        let (fileURL, chunkId) = await createTestChunk()
        XCTAssertNotNil(chunkId, "Chunk should be registered")

        // Mark as failed
        storageManager.markChunkFailed(url: fileURL)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds - Wait for async deletion

        // Verify chunk deleted from database
        let chunks = storageManager.fetchUnprocessedChunks(olderThan: 0)
        let deletedChunk = chunks.first(where: { $0.id == chunkId })
        XCTAssertNil(deletedChunk, "Failed chunk should be deleted from database")

        // Verify file deleted from filesystem
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Failed chunk file should be deleted")
    }

    // MARK: - Automatic Cleanup Tests

    func testAutomaticCleanupWithOldChunks() async throws {
        // Create old chunks (4 days old)
        let oldChunks = await createTestChunks(count: 5, daysOld: 4, sizeBytes: 100000)

        // Mark all as completed
        for (url, _) in oldChunks {
            await markChunkCompleted(url: url)
        }

        // Run cleanup with 3-day retention
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // Verify cleanup stats
        XCTAssertEqual(stats.chunksFound, 5, "Should find 5 old chunks")
        XCTAssertEqual(stats.filesDeleted, 5, "Should delete 5 files")
        XCTAssertEqual(stats.recordsDeleted, 5, "Should delete 5 database records")
        XCTAssertGreaterThan(stats.bytesFreed, 0, "Should free some bytes")

        // Verify chunks are actually deleted
        let remainingChunks = storageManager.fetchUnprocessedChunks(olderThan: 0)
        XCTAssertEqual(remainingChunks.count, 0, "All old chunks should be deleted")

        // Verify files are deleted
        for (url, _) in oldChunks {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Chunk file should be deleted")
        }
    }

    func testRetentionPolicyRespected() async throws {
        // Create chunks: 2 recent (1 day old), 3 old (4 days old)
        let recentChunks = await createTestChunks(count: 2, daysOld: 1, sizeBytes: 50000)
        let oldChunks = await createTestChunks(count: 3, daysOld: 4, sizeBytes: 50000)

        // Mark all as completed
        for (url, _) in recentChunks + oldChunks {
            await markChunkCompleted(url: url)
        }

        // Run cleanup with 3-day retention
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // Verify only old chunks deleted
        XCTAssertEqual(stats.chunksFound, 3, "Should find only 3 old chunks")
        XCTAssertEqual(stats.filesDeleted, 3, "Should delete only 3 files")

        // Verify recent chunks still exist
        for (url, _) in recentChunks {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Recent chunk should still exist")
        }

        // Verify old chunks deleted
        for (url, _) in oldChunks {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Old chunk should be deleted")
        }
    }

    func testCleanupWithNoOldChunks() async throws {
        // Create only recent chunks (1 day old)
        let recentChunks = await createTestChunks(count: 3, daysOld: 1, sizeBytes: 50000)

        for (url, _) in recentChunks {
            await markChunkCompleted(url: url)
        }

        // Run cleanup with 3-day retention
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // Verify no chunks deleted
        XCTAssertEqual(stats.chunksFound, 0, "Should find no old chunks")
        XCTAssertEqual(stats.filesDeleted, 0, "Should delete no files")
        XCTAssertEqual(stats.recordsDeleted, 0, "Should delete no records")
        XCTAssertEqual(stats.bytesFreed, 0, "Should free no bytes")

        // Verify all chunks still exist
        for (url, _) in recentChunks {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Recent chunk should still exist")
        }
    }

    // MARK: - Timeline Data Preservation Tests

    func testTimelineDataPreservation() async throws {
        // Create old chunk
        let (chunkURL, chunkId) = await createTestChunk(daysOld: 4, sizeBytes: 100000)
        guard let unwrappedChunkId = chunkId else {
            XCTFail("Failed to create chunk")
            return
        }

        await markChunkCompleted(url: chunkURL)

        // Create batch with this chunk
        let now = Int(Date().timeIntervalSince1970)
        guard let batchId = storageManager.saveBatch(
            startTs: now - 3600,
            endTs: now,
            chunkIds: [unwrappedChunkId]
        ) else {
            XCTFail("Failed to create batch")
            return
        }

        // Create timeline card referencing the chunk
        let card = TimelineCardShell(
            startTimestamp: "10:00 AM",
            endTimestamp: "11:00 AM",
            category: "Work",
            subcategory: "Coding",
            title: "Test Activity",
            summary: "Testing timeline preservation",
            detailedSummary: "Verifying timeline data persists when chunks are deleted",
            distractions: nil,
            appSites: nil
        )

        guard let cardId = storageManager.saveTimelineCardShell(batchId: batchId, card: card) else {
            XCTFail("Failed to create timeline card")
            return
        }

        // Update timeline card with video URL
        storageManager.updateTimelineCardVideoURL(cardId: cardId, videoSummaryURL: chunkURL.path)

        // Verify video URL is set
        let cardBefore = storageManager.fetchTimelineCard(byId: cardId)
        XCTAssertNotNil(cardBefore?.videoSummaryURL, "Video URL should be set before cleanup")

        // Run cleanup - this will try to delete the chunk, but it's in a batch so it should be protected
        // However, the video URL should be cleared
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // The chunk is in a batch, so it might not be deleted due to foreign key constraints
        // But let's verify the timeline card still exists
        let cardAfter = storageManager.fetchTimelineCard(byId: cardId)
        XCTAssertNotNil(cardAfter, "Timeline card should still exist after cleanup")
        XCTAssertEqual(cardAfter?.title, "Test Activity", "Timeline card data should be preserved")

        // Note: Video URL may or may not be cleared depending on whether the chunk was actually deleted
        // This depends on the ON DELETE RESTRICT constraint on batch_chunks
    }

    // MARK: - Storage Usage Tests

    func testStorageUsageCalculation() async throws {
        // Create test chunks with known sizes
        let chunkSize = 100000 // 100KB
        let chunks = await createTestChunks(count: 5, daysOld: 0, sizeBytes: chunkSize)

        // Calculate storage
        let usage = try await storageManager.calculateStorageUsage()

        // Verify calculations
        XCTAssertGreaterThan(usage.databaseBytes, 0, "Database should have non-zero size")
        XCTAssertGreaterThanOrEqual(usage.recordingsBytes, Int64(5 * chunkSize), "Recordings should be at least 500KB")
        XCTAssertEqual(usage.totalBytes, usage.databaseBytes + usage.recordingsBytes, "Total should equal sum of parts")
        XCTAssertLessThan(usage.totalGB, 1.0, "Total should be less than 1GB")
    }

    func testStorageUsageAfterCleanup() async throws {
        // Create chunks
        let chunks = await createTestChunks(count: 10, daysOld: 4, sizeBytes: 200000)

        for (url, _) in chunks {
            await markChunkCompleted(url: url)
        }

        // Get usage before cleanup
        let usageBefore = try await storageManager.calculateStorageUsage()

        // Run cleanup
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // Get usage after cleanup
        let usageAfter = try await storageManager.calculateStorageUsage()

        // Verify storage decreased
        XCTAssertLessThan(usageAfter.recordingsBytes, usageBefore.recordingsBytes, "Storage should decrease after cleanup")
        XCTAssertEqual(usageBefore.recordingsBytes - usageAfter.recordingsBytes, stats.bytesFreed, accuracy: 1000, "Bytes freed should match storage decrease")
    }

    // MARK: - Performance Tests

    func testCleanupPerformance() async throws {
        // Create many old chunks (simulating large cleanup)
        let chunks = await createTestChunks(count: 100, daysOld: 4, sizeBytes: 10000)

        for (url, _) in chunks {
            await markChunkCompleted(url: url)
        }

        // Measure cleanup time
        let start = Date()
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)
        let duration = Date().timeIntervalSince(start)

        // Verify performance target (< 5 seconds)
        XCTAssertLessThan(duration, 5.0, "Cleanup exceeded 5s target (actual: \(String(format: "%.3f", duration))s)")

        // Verify all chunks deleted
        XCTAssertEqual(stats.filesDeleted, 100, "All 100 chunks should be deleted")
    }

    func testStorageCalculationPerformance() async throws {
        // Create many chunks
        let chunks = await createTestChunks(count: 100, daysOld: 0, sizeBytes: 50000)

        // Measure calculation time
        let start = Date()
        let usage = try await storageManager.calculateStorageUsage()
        let duration = Date().timeIntervalSince(start)

        // Verify performance (< 2 seconds)
        XCTAssertLessThan(duration, 2.0, "Storage calculation too slow (actual: \(String(format: "%.3f", duration))s)")
        XCTAssertGreaterThan(usage.totalBytes, 0, "Should calculate non-zero storage")
    }

    // MARK: - Retention Policy Tests

    func testRetentionPolicyValidation() {
        // Valid policy
        let validPolicy = RetentionPolicy(enabled: true, retentionDays: 7, maxStorageGB: 20, cleanupIntervalHours: 2)
        XCTAssertTrue(validPolicy.isValid, "Valid policy should pass validation")
        XCTAssertEqual(validPolicy.validate().count, 0, "Valid policy should have no errors")

        // Invalid retention days
        var invalidPolicy = RetentionPolicy(enabled: true, retentionDays: 0, maxStorageGB: 10, cleanupIntervalHours: 1)
        XCTAssertFalse(invalidPolicy.isValid, "Invalid retention days should fail validation")
        XCTAssertGreaterThan(invalidPolicy.validate().count, 0, "Should have validation errors")

        // Invalid max storage
        invalidPolicy = RetentionPolicy(enabled: true, retentionDays: 3, maxStorageGB: 0, cleanupIntervalHours: 1)
        XCTAssertFalse(invalidPolicy.isValid, "Invalid max storage should fail validation")

        // Invalid cleanup interval
        invalidPolicy = RetentionPolicy(enabled: true, retentionDays: 3, maxStorageGB: 10, cleanupIntervalHours: 0)
        XCTAssertFalse(invalidPolicy.isValid, "Invalid cleanup interval should fail validation")
    }

    func testRetentionManagerInitialization() async {
        let manager = await RetentionManager(storageManager: storageManager)
        let policy = await manager.getPolicy()

        // Should have default policy
        XCTAssertEqual(policy.retentionDays, 3, "Should have default retention days")
        XCTAssertEqual(policy.maxStorageGB, 10, "Should have default storage limit")
        XCTAssertTrue(policy.enabled, "Should be enabled by default")
    }

    func testRetentionManagerManualCleanup() async throws {
        // Create old chunks
        let chunks = await createTestChunks(count: 5, daysOld: 4, sizeBytes: 50000)

        for (url, _) in chunks {
            await markChunkCompleted(url: url)
        }

        // Create retention manager
        let manager = await RetentionManager(storageManager: storageManager)

        // Perform manual cleanup
        let stats = await manager.performManualCleanup()

        XCTAssertNotNil(stats, "Manual cleanup should return stats")
        XCTAssertEqual(stats?.chunksFound, 5, "Should find 5 old chunks")
        XCTAssertEqual(stats?.filesDeleted, 5, "Should delete 5 files")
    }

    // MARK: - Edge Cases

    func testCleanupWithMissingFiles() async throws {
        // Create chunks
        let chunks = await createTestChunks(count: 3, daysOld: 4, sizeBytes: 50000)

        for (url, _) in chunks {
            await markChunkCompleted(url: url)
        }

        // Delete one file manually (simulate missing file)
        if let (url, _) = chunks.first {
            try? FileManager.default.removeItem(at: url)
        }

        // Run cleanup - should handle missing file gracefully
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // Should still find all chunks in database
        XCTAssertEqual(stats.chunksFound, 3, "Should find all 3 chunks in database")
        // May delete fewer files if one was already missing
        XCTAssertGreaterThanOrEqual(stats.filesDeleted, 2, "Should delete at least 2 files")
        XCTAssertEqual(stats.recordsDeleted, 3, "Should delete all 3 database records")
    }

    func testCleanupWithEmptyDatabase() async throws {
        // Run cleanup on empty database
        let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)

        // Should handle gracefully
        XCTAssertEqual(stats.chunksFound, 0, "Should find no chunks")
        XCTAssertEqual(stats.filesDeleted, 0, "Should delete no files")
        XCTAssertEqual(stats.recordsDeleted, 0, "Should delete no records")
    }

    func testStorageUsageWithNoChunks() async throws {
        // Calculate storage with no chunks
        let usage = try await storageManager.calculateStorageUsage()

        // Should have database size but no recordings
        XCTAssertGreaterThan(usage.databaseBytes, 0, "Database file should exist")
        XCTAssertEqual(usage.recordingsBytes, 0, "No recordings should exist")
    }
}
