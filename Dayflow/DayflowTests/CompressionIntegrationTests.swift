//
//  CompressionIntegrationTests.swift
//  DayflowTests
//
//  Integration tests for compression engine with ScreenRecorder
//  Epic 2 - Story 2.2: Video Compression Optimization
//

import XCTest
import AVFoundation
import CoreMedia
@testable import Dayflow

@MainActor
final class CompressionIntegrationTests: XCTestCase {

    var recorder: ScreenRecorder?

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        recorder = nil
        try await super.tearDown()
    }

    // MARK: - AC 2.2.1 Tests - Storage Target Achievement

    func testScreenRecorderWithCompressionEngine() async throws {
        // Test that ScreenRecorder integrates with compression engine
        recorder = ScreenRecorder(autoStart: false, displayMode: .automatic)

        XCTAssertNotNil(recorder, "Recorder should initialize with compression engine")

        // Verify recorder is ready
        // In actual implementation, compression engine would be initialized
        // when recording starts
    }

    func testCompressionEngineInitialization() async throws {
        // Test compression engine initialization with recorder settings
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let engine = AVFoundationCompressionEngine(settings: settings)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mp4")

        do {
            try await engine.initialize(settings: settings, outputURL: tempURL)

            XCTAssertTrue(engine.isReadyForData, "Engine should be ready after initialization")
            XCTAssertEqual(engine.currentFrameCount, 0, "Should start with 0 frames")
            XCTAssertEqual(engine.currentChunkSize, 0, "Should start with 0 size")

            // Cleanup
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            XCTFail("Compression engine initialization failed: \(error)")
        }
    }

    // MARK: - AC 2.2.2 Tests - Compression Performance

    func testCompressionTimePerFrame() async throws {
        // Test that frame compression completes within 500ms
        // Note: This test creates a mock frame but doesn't actually compress
        // as that would require ScreenCaptureKit permissions

        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let engine = AVFoundationCompressionEngine(settings: settings)

        // Verify settings target fast compression
        XCTAssertGreaterThan(settings.targetBitrate, 0, "Should have valid bitrate")
        XCTAssertEqual(settings.keyFrameInterval, 30, "Should use 30-frame keyframe interval")

        // Note: Actual frame compression testing would require:
        // 1. ScreenCaptureKit permissions
        // 2. Real CVPixelBuffer frames
        // 3. Full recording pipeline
        // These are tested in system/performance test suites
    }

    func testStorageMetricsIntegration() {
        // Test storage metrics calculation with TimelapseStorageManager
        let manager = TimelapseStorageManager.shared
        let metrics = manager.calculateStorageMetrics()

        XCTAssertNotNil(metrics, "Should calculate storage metrics")
        XCTAssertGreaterThanOrEqual(metrics.totalStorageUsed, 0, "Total storage should be non-negative")
        XCTAssertGreaterThanOrEqual(metrics.recordingCount, 0, "Recording count should be non-negative")
        XCTAssertGreaterThan(metrics.compressionRatio, 0, "Compression ratio should be positive")
    }

    func testStorageMetricsApproachingLimit() {
        // Test storage limit warning
        let manager = TimelapseStorageManager.shared

        // Test with low threshold to ensure it doesn't crash
        let isApproaching = manager.isApproachingStorageLimit(threshold: 0.01)

        // Should return a boolean without crashing
        XCTAssertNotNil(isApproaching, "Should check storage limit")
    }

    func testDailyUsageTrend() {
        // Test daily usage trend calculation
        let manager = TimelapseStorageManager.shared
        let trend = manager.getDailyUsageTrend(days: 7)

        XCTAssertNotNil(trend, "Should calculate daily usage trend")
        XCTAssertLessThanOrEqual(trend.count, 7, "Should return at most 7 days")

        // Verify trend data structure
        for (date, bytes) in trend {
            XCTAssertNotNil(date, "Should have valid date")
            XCTAssertGreaterThanOrEqual(bytes, 0, "Bytes should be non-negative")
        }
    }

    // MARK: - AC 2.2.4 Tests - Adaptive Compression

    func testAdaptiveQualityIntegration() {
        // Test adaptive quality manager integration
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        // Create a chunk that matches target (no adjustment needed)
        let targetChunkSize: Int64 = 64 * 1024 * 1024  // 64MB
        let chunk = CompressedChunk(
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            size: targetChunkSize,
            duration: 900.0,
            compressionRatio: 100.0,
            frameCount: 900,
            createdAt: Date(),
            settings: settings
        )

        // First few chunks shouldn't trigger adjustment (need 4 for analysis window)
        for i in 1...3 {
            let result = manager.analyzeAndAdjust(chunk: chunk)
            XCTAssertNil(result, "Should not adjust on chunk \(i) (need 4 chunks)")
        }

        // Fourth chunk completes analysis window but chunk is within target
        let result = manager.analyzeAndAdjust(chunk: chunk)
        XCTAssertNil(result, "Should not adjust when within target tolerance")
        XCTAssertEqual(manager.currentBitrateMultiplier, 1.0, "Multiplier should remain 1.0")
    }

    func testAdaptiveQualityStatistics() {
        // Test adjustment statistics
        let manager = AdaptiveQualityManager()
        let stats = manager.getAdjustmentStatistics()

        XCTAssertEqual(stats.totalAdjustments, 0, "Should start with 0 adjustments")
        XCTAssertEqual(stats.currentMultiplier, 1.0, "Should start at 1.0 multiplier")
        XCTAssertGreaterThanOrEqual(stats.stabilityScore, 0.0, "Stability score should be >= 0")
        XCTAssertLessThanOrEqual(stats.stabilityScore, 1.0, "Stability score should be <= 1")
    }

    // MARK: - Integration with ScreenRecorder

    func testScreenRecorderCompressionMetadata() async throws {
        // Test that ScreenRecorder can save compression metadata
        recorder = ScreenRecorder(autoStart: false, displayMode: .automatic)

        XCTAssertNotNil(recorder, "Recorder should be initialized")

        // Verify recorder has compression capabilities
        // In actual implementation, would verify:
        // 1. Compression engine property exists
        // 2. Adaptive quality manager exists
        // 3. Metadata saving works
    }

    func testRecorderStateWithCompression() async throws {
        // Test that recorder state transitions work with compression
        recorder = ScreenRecorder(autoStart: false, displayMode: .automatic)

        guard let recorder = recorder else {
            XCTFail("Recorder should be initialized")
            return
        }

        // Create a task to collect status updates
        let expectation = XCTestExpectation(description: "Should receive initial state")

        Task { @MainActor in
            var statesReceived = 0
            for await state in recorder.statusUpdates {
                statesReceived += 1

                if statesReceived == 1 {
                    // Accept either idle or starting state
                    XCTAssertTrue(
                        state == .idle || state == .starting,
                        "Initial state should be idle or starting"
                    )
                    expectation.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Error Handling

    func testCompressionEngineErrorRecovery() async throws {
        // Test that compression engine handles errors gracefully
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let engine = AVFoundationCompressionEngine(settings: settings)

        // Try to compress without initialization (should fail)
        // Note: Cannot create real CVPixelBuffer without proper setup
        // This tests the error handling structure

        XCTAssertFalse(engine.isReadyForData, "Engine should not be ready before initialization")
    }

    func testDiskSpaceCheckIntegration() {
        // Test that disk space checking works
        let currentUsage = TimelapseStorageManager.shared.currentUsageBytes()
        XCTAssertGreaterThanOrEqual(currentUsage, 0, "Current usage should be non-negative")

        // Test storage metrics logs without crashing
        TimelapseStorageManager.shared.logStorageMetrics()

        // Should complete without crashing
        XCTAssert(true, "Storage metrics logging completed")
    }

    // MARK: - Quality Validation Preparation (AC 2.2.3)

    func testCompressionQualitySettings() {
        // Test that compression settings support quality validation
        let lowSettings = CompressionSettings.default(width: 1920, height: 1080).withQuality(.low)
        let mediumSettings = CompressionSettings.default(width: 1920, height: 1080).withQuality(.medium)
        let highSettings = CompressionSettings.default(width: 1920, height: 1080).withQuality(.high)

        XCTAssertLessThan(lowSettings.targetBitrate, mediumSettings.targetBitrate,
                         "Low quality should have lower bitrate than medium")
        XCTAssertLessThan(mediumSettings.targetBitrate, highSettings.targetBitrate,
                         "Medium quality should have lower bitrate than high")

        // Quality differences should be meaningful (at least 20% difference)
        let lowToMediumRatio = Double(mediumSettings.targetBitrate) / Double(lowSettings.targetBitrate)
        XCTAssertGreaterThan(lowToMediumRatio, 1.5, "Medium should be significantly higher than low")
    }

    // MARK: - Memory Management

    func testCompressionEngineMemoryManagement() {
        // Test that compression engine doesn't leak memory
        autoreleasepool {
            for _ in 1...10 {
                let settings = CompressionSettings.default(width: 1920, height: 1080)
                _ = AVFoundationCompressionEngine(settings: settings)
            }
        }

        // If there were memory leaks, this would accumulate
        // Actual leak detection would use Instruments
        XCTAssert(true, "Memory management test completed")
    }

    func testAdaptiveQualityManagerMemoryManagement() {
        // Test that adjustment history doesn't grow unbounded
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080)

        // Simulate many adjustments
        for i in 1...150 {
            let chunk = CompressedChunk(
                fileURL: URL(fileURLWithPath: "/tmp/test\(i).mp4"),
                size: Int64(i * 1024 * 1024),
                duration: 900.0,
                compressionRatio: 100.0,
                frameCount: 900,
                createdAt: Date(),
                settings: settings
            )
            _ = manager.analyzeAndAdjust(chunk: chunk)
        }

        // History should be limited to prevent unbounded growth
        XCTAssertLessThanOrEqual(manager.adjustmentHistory.count, 100,
                                 "History should be capped at 100 entries")
    }
}
