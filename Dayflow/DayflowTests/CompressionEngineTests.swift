//
//  CompressionEngineTests.swift
//  DayflowTests
//
//  Unit tests for video compression engine
//  Epic 2 - Story 2.2: Video Compression Optimization
//

import XCTest
import AVFoundation
import CoreMedia
@testable import Dayflow

final class CompressionEngineTests: XCTestCase {

    // MARK: - AC 2.2.1 Tests - Storage Target Achievement

    func testCompressionSettingsDefaultValues() {
        // Test that default settings target ~70KB per frame for 2GB/8hrs
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        XCTAssertEqual(settings.width, 1920, "Width should match")
        XCTAssertEqual(settings.height, 1080, "Height should match")
        XCTAssertNotNil(settings.codec, "Codec should be set")
        XCTAssertNotNil(settings.quality, "Quality should be set")

        // Estimated bytes per frame should be around 70KB (560,000 bits / 8)
        let estimatedBytesPerFrame = settings.estimatedBytesPerFrame
        XCTAssertGreaterThan(estimatedBytesPerFrame, 50_000, "Should be at least 50KB per frame")
        XCTAssertLessThan(estimatedBytesPerFrame, 100_000, "Should be less than 100KB per frame")
    }

    func testCompressionSettingsScalesWithResolution() {
        // Test that bitrate scales with resolution
        let settings1080p = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let settings4K = CompressionSettings.default(width: 3840, height: 2160, fps: 1)

        // 4K should have approximately 4x the bitrate of 1080p (2x width * 2x height)
        let ratio = Double(settings4K.targetBitrate) / Double(settings1080p.targetBitrate)
        XCTAssertGreaterThan(ratio, 3.5, "4K bitrate should be ~4x 1080p")
        XCTAssertLessThan(ratio, 4.5, "4K bitrate should be ~4x 1080p")
    }

    func testVideoCodecRecommendation() {
        // Test that recommended codec is appropriate for architecture
        let codec = VideoCodec.recommended

        #if arch(arm64)
        XCTAssertEqual(codec, .hevc, "Apple Silicon should recommend H.265")
        #else
        XCTAssertEqual(codec, .h264, "Intel should recommend H.264")
        #endif
    }

    func testVideoCodecHardwareEncoding() {
        // Test hardware encoding availability detection
        let h264Available = VideoCodec.h264.isHardwareEncodingAvailable()
        let hevcAvailable = VideoCodec.hevc.isHardwareEncodingAvailable()

        XCTAssertTrue(h264Available, "H.264 hardware encoding should be available")

        #if arch(arm64)
        XCTAssertTrue(hevcAvailable, "H.265 hardware encoding should be available on Apple Silicon")
        #else
        // Intel Macs may not have H.265 hardware encoding
        // Test passes either way
        _ = hevcAvailable
        #endif
    }

    func testCompressionQualityMultipliers() {
        // Test quality level bitrate multipliers
        XCTAssertEqual(CompressionQuality.low.bitrateMultiplier, 0.5, "Low quality should be 50%")
        XCTAssertEqual(CompressionQuality.medium.bitrateMultiplier, 1.0, "Medium quality should be 100%")
        XCTAssertEqual(CompressionQuality.high.bitrateMultiplier, 1.5, "High quality should be 150%")
        XCTAssertEqual(CompressionQuality.auto.bitrateMultiplier, 1.0, "Auto quality should start at 100%")
    }

    func testCompressionQualityAdjustment() {
        // Test quality level adjustment methods
        let low = CompressionQuality.low
        let medium = CompressionQuality.medium
        let high = CompressionQuality.high

        XCTAssertEqual(low.increased(), .medium, "Low should increase to medium")
        XCTAssertEqual(medium.increased(), .high, "Medium should increase to high")
        XCTAssertNil(high.increased(), "High cannot increase further")

        XCTAssertNil(low.decreased(), "Low cannot decrease further")
        XCTAssertEqual(medium.decreased(), .low, "Medium should decrease to low")
        XCTAssertEqual(high.decreased(), .medium, "High should decrease to medium")
    }

    func testCompressionSettingsWithQuality() {
        // Test creating settings with different quality levels
        let baseSettings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let lowSettings = baseSettings.withQuality(.low)
        let highSettings = baseSettings.withQuality(.high)

        XCTAssertLessThan(lowSettings.targetBitrate, baseSettings.targetBitrate, "Low quality should have lower bitrate")
        XCTAssertGreaterThan(highSettings.targetBitrate, baseSettings.targetBitrate, "High quality should have higher bitrate")
    }

    // MARK: - AC 2.2.2 Tests - Compression Performance

    func testCompressionEngineEstimateChunkSize() {
        // Test chunk size estimation
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let engine = AVFoundationCompressionEngine(settings: settings)

        // 15 minutes at 1 FPS = 900 frames
        let estimatedSize = engine.estimateChunkSize(frameCount: 900)

        // Should estimate around 63MB for 15-minute chunk (70KB * 900 frames)
        XCTAssertGreaterThan(estimatedSize, 50_000_000, "Should be at least 50MB")
        XCTAssertLessThan(estimatedSize, 100_000_000, "Should be less than 100MB")
    }

    // MARK: - AC 2.2.4 Tests - Adaptive Compression

    func testAdaptiveQualityManagerInitialization() {
        // Test adaptive quality manager initialization
        let manager = AdaptiveQualityManager(targetStoragePerDay: 2 * 1024 * 1024 * 1024)

        XCTAssertEqual(manager.currentBitrateMultiplier, 1.0, "Should start at 1.0 multiplier")
        XCTAssertEqual(manager.targetStoragePerDay, 2 * 1024 * 1024 * 1024, "Should store target")
        XCTAssertEqual(manager.targetTolerance, 0.10, "Should have 10% tolerance")
    }

    func testAdaptiveQualityOversizedChunks() {
        // Test that oversized chunks trigger quality reduction
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        // Create oversized chunks (20% over target)
        let targetChunkSize: Int64 = 64 * 1024 * 1024  // 64MB target
        let oversizedChunkSize: Int64 = targetChunkSize + (targetChunkSize * 20 / 100)  // 20% over

        // Simulate 4 oversized chunks
        for _ in 1...4 {
            let chunk = CompressedChunk(
                fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                size: oversizedChunkSize,
                duration: 900.0,  // 15 minutes
                compressionRatio: 100.0,
                frameCount: 900,
                createdAt: Date(),
                settings: settings
            )

            let adjustedSettings = manager.analyzeAndAdjust(chunk: chunk)

            // After 4 chunks, should trigger adjustment
            if adjustedSettings != nil {
                XCTAssertLessThan(
                    manager.currentBitrateMultiplier,
                    1.0,
                    "Oversized chunks should reduce bitrate multiplier"
                )
                return  // Test passed
            }
        }

        // Should have triggered adjustment by now
        XCTAssertLessThan(manager.currentBitrateMultiplier, 1.0, "Should have adjusted after 4 oversized chunks")
    }

    func testAdaptiveQualityUndersizedChunks() {
        // Test that undersized chunks trigger quality increase
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        // Create undersized chunks (20% under target)
        let targetChunkSize: Int64 = 64 * 1024 * 1024  // 64MB target
        let undersizedChunkSize: Int64 = targetChunkSize - (targetChunkSize * 20 / 100)  // 20% under

        // Simulate 4 undersized chunks
        for _ in 1...4 {
            let chunk = CompressedChunk(
                fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
                size: undersizedChunkSize,
                duration: 900.0,  // 15 minutes
                compressionRatio: 100.0,
                frameCount: 900,
                createdAt: Date(),
                settings: settings
            )

            let adjustedSettings = manager.analyzeAndAdjust(chunk: chunk)

            // After 4 chunks, should trigger adjustment
            if adjustedSettings != nil {
                XCTAssertGreaterThan(
                    manager.currentBitrateMultiplier,
                    1.0,
                    "Undersized chunks should increase bitrate multiplier"
                )
                return  // Test passed
            }
        }

        // Should have triggered adjustment by now
        XCTAssertGreaterThan(manager.currentBitrateMultiplier, 1.0, "Should have adjusted after 4 undersized chunks")
    }

    func testAdaptiveQualityBounds() {
        // Test that quality adjustment respects min/max bounds
        let manager = AdaptiveQualityManager()

        XCTAssertEqual(manager.minBitrateMultiplier, 0.4, "Min multiplier should be 0.4")
        XCTAssertEqual(manager.maxBitrateMultiplier, 2.0, "Max multiplier should be 2.0")

        // Test clamping
        let clamped = 0.3.clamped(to: manager.minBitrateMultiplier...manager.maxBitrateMultiplier)
        XCTAssertEqual(clamped, 0.4, "Should clamp to minimum")

        let clampedHigh = 3.0.clamped(to: manager.minBitrateMultiplier...manager.maxBitrateMultiplier)
        XCTAssertEqual(clampedHigh, 2.0, "Should clamp to maximum")
    }

    func testAdaptiveQualityAdjustmentHistory() {
        // Test that adjustment history is tracked
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        XCTAssertEqual(manager.adjustmentHistory.count, 0, "Should start with empty history")

        // Simulate adjustments
        let oversizedChunk = CompressedChunk(
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            size: 100 * 1024 * 1024,  // 100MB (oversized)
            duration: 900.0,
            compressionRatio: 100.0,
            frameCount: 900,
            createdAt: Date(),
            settings: settings
        )

        // Generate enough chunks to trigger adjustment
        for _ in 1...4 {
            _ = manager.analyzeAndAdjust(chunk: oversizedChunk)
        }

        // Should have at least one adjustment in history
        XCTAssertGreaterThan(manager.adjustmentHistory.count, 0, "Should track adjustments")
    }

    func testStorageMetricsCalculation() {
        // Test StorageMetrics data model
        let metrics = StorageMetrics(
            totalStorageUsed: 1_500_000_000,  // 1.5GB
            recordingCount: 24,
            oldestRecordingDate: Date().addingTimeInterval(-86400),  // 1 day ago
            newestRecordingDate: Date(),
            compressionRatio: 120.0,
            dailyAverageSize: 1_500_000_000,  // 1.5GB/day
            retentionDays: 30,
            storageLimit: 2_000_000_000,  // 2GB limit
            calculatedAt: Date()
        )

        XCTAssertEqual(metrics.usagePercentage, 0.75, accuracy: 0.01, "Should be 75% usage")
        XCTAssertTrue(metrics.isApproachingLimit(threshold: 0.7), "Should be approaching limit")
        XCTAssertFalse(metrics.isApproachingLimit(threshold: 0.8), "Should not be at 80% threshold yet")

        // Test formatted strings
        XCTAssertFalse(metrics.formattedTotalStorage.isEmpty, "Should format total storage")
        XCTAssertFalse(metrics.formattedDailyAverage.isEmpty, "Should format daily average")
    }

    func testCompressedChunkMetadata() {
        // Test CompressedChunk data model
        let chunk = CompressedChunk(
            fileURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            size: 60 * 1024 * 1024,  // 60MB
            duration: 900.0,  // 15 minutes
            compressionRatio: 100.0,
            frameCount: 900,
            createdAt: Date(),
            settings: CompressionSettings.default(width: 1920, height: 1080)
        )

        // Test calculated properties
        XCTAssertGreaterThan(chunk.averageBytesPerFrame, 0, "Should calculate average bytes per frame")
        XCTAssertGreaterThan(chunk.averageBitrate, 0, "Should calculate average bitrate")

        // Test target checking
        let targetSize: Int64 = 64 * 1024 * 1024  // 64MB
        XCTAssertTrue(chunk.isWithinTarget(size: targetSize, tolerance: 0.10), "Should be within 10% of 64MB")
    }

    // MARK: - Error Handling Tests

    func testCompressionErrorDescriptions() {
        // Test that compression errors have proper descriptions
        let errors: [CompressionError] = [
            .writerNotInitialized,
            .writerNotReady,
            .failedToCreateWriter,
            .failedToAppendFrame,
            .failedToFinishWriting,
            .invalidSettings,
            .codecNotAvailable,
            .insufficientDiskSpace
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
}
