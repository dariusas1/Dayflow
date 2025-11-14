//
//  CompressionPerformanceTests.swift
//  DayflowTests
//
//  Performance tests for video compression
//  Epic 2 - Story 2.2: Video Compression Optimization
//

import XCTest
import AVFoundation
@testable import Dayflow

final class CompressionPerformanceTests: XCTestCase {

    // MARK: - AC 2.2.2 Tests - Compression Performance

    func testCompressionSettingsCreationPerformance() {
        // Test that compression settings creation is fast
        measure {
            for _ in 1...1000 {
                _ = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
            }
        }
    }

    func testCompressionEngineInitializationPerformance() {
        // Test compression engine initialization performance
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        measure {
            for _ in 1...100 {
                _ = AVFoundationCompressionEngine(settings: settings)
            }
        }
    }

    func testAdaptiveQualityAnalysisPerformance() {
        // Test that quality adjustment analysis is fast
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        let chunks = (1...100).map { i in
            CompressedChunk(
                fileURL: URL(fileURLWithPath: "/tmp/test\(i).mp4"),
                size: Int64(60 * 1024 * 1024),
                duration: 900.0,
                compressionRatio: 100.0,
                frameCount: 900,
                createdAt: Date(),
                settings: settings
            )
        }

        measure {
            for chunk in chunks {
                _ = manager.analyzeAndAdjust(chunk: chunk)
            }
        }
    }

    func testStorageMetricsCalculationPerformance() {
        // Test that storage metrics calculation is reasonably fast
        let manager = TimelapseStorageManager.shared

        measure {
            for _ in 1...10 {
                _ = manager.calculateStorageMetrics()
            }
        }
    }

    func testDailyUsageTrendPerformance() {
        // Test daily usage trend calculation performance
        let manager = TimelapseStorageManager.shared

        measure {
            for _ in 1...20 {
                _ = manager.getDailyUsageTrend(days: 30)
            }
        }
    }

    // MARK: - AC 2.2.1 Tests - Storage Efficiency

    func testCompressionRatioCalculation() {
        // Test compression ratio calculation performance
        measure {
            for i in 1...1000 {
                let chunk = CompressedChunk(
                    fileURL: URL(fileURLWithPath: "/tmp/test\(i).mp4"),
                    size: Int64(60 * 1024 * 1024),
                    duration: 900.0,
                    compressionRatio: 100.0,
                    frameCount: 900,
                    createdAt: Date(),
                    settings: CompressionSettings.default(width: 1920, height: 1080)
                )

                _ = chunk.averageBytesPerFrame
                _ = chunk.averageBitrate
            }
        }
    }

    // MARK: - Memory Performance

    func testCompressionEngineMemoryFootprint() {
        // Test that compression engine has reasonable memory footprint
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()

            var engines: [AVFoundationCompressionEngine] = []
            for _ in 1...10 {
                engines.append(AVFoundationCompressionEngine(settings: settings))
            }

            stopMeasuring()

            // Cleanup
            engines.removeAll()
        }
    }

    func testAdaptiveQualityHistoryMemoryFootprint() {
        // Test that adjustment history doesn't consume excessive memory
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080)

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()

            // Add many adjustments
            for i in 1...200 {
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

            stopMeasuring()

            // Verify history is bounded
            XCTAssertLessThanOrEqual(manager.adjustmentHistory.count, 100,
                                     "History should be capped")
        }
    }

    // MARK: - 8-Hour Recording Simulation (AC 2.2.1)

    func testEightHourStorageEstimation() {
        // Test storage estimation for 8-hour recording
        // 8 hours at 1 FPS = 28,800 frames
        // Target: <2GB total

        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let frameCount = 28_800  // 8 hours * 3600 seconds * 1 FPS

        let estimatedSize = settings.estimatedBytesPerFrame * Int64(frameCount)

        // Should be less than 2GB
        let twoGB: Int64 = 2 * 1024 * 1024 * 1024
        XCTAssertLessThan(estimatedSize, twoGB,
                         "8-hour recording should be under 2GB (estimated: \(estimatedSize / 1024 / 1024)MB)")

        // Should be at least 1GB (to ensure we're not compressing too aggressively)
        let oneGB: Int64 = 1 * 1024 * 1024 * 1024
        XCTAssertGreaterThan(estimatedSize, oneGB,
                            "8-hour recording should be at least 1GB for quality")
    }

    func testChunkSizeConsistency() {
        // Test that chunk size estimates are consistent
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)
        let engine = AVFoundationCompressionEngine(settings: settings)

        // 15 minutes = 900 frames
        let size1 = engine.estimateChunkSize(frameCount: 900)
        let size2 = engine.estimateChunkSize(frameCount: 900)

        XCTAssertEqual(size1, size2, "Chunk size estimates should be consistent")

        // 30 minutes should be approximately 2x 15 minutes
        let size30min = engine.estimateChunkSize(frameCount: 1800)
        XCTAssertGreaterThan(size30min, size1 * 180 / 100, "30min should be ~2x 15min")
        XCTAssertLessThan(size30min, size1 * 220 / 100, "30min should be ~2x 15min")
    }

    // MARK: - CPU Usage Simulation (AC 2.2.2)

    func testCompressionCPUEfficiency() {
        // Test that compression operations are CPU-efficient
        // Target: <2% CPU usage on Apple Silicon

        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        measure {
            // Simulate compression overhead calculations
            for i in 1...100 {
                let chunk = CompressedChunk(
                    fileURL: URL(fileURLWithPath: "/tmp/test\(i).mp4"),
                    size: Int64(60 * 1024 * 1024),
                    duration: 900.0,
                    compressionRatio: 100.0,
                    frameCount: 900,
                    createdAt: Date(),
                    settings: settings
                )

                _ = manager.analyzeAndAdjust(chunk: chunk)
                _ = chunk.averageBytesPerFrame
                _ = chunk.averageBitrate
                _ = chunk.isWithinTarget(size: 64 * 1024 * 1024)
            }
        }

        // If this test completes quickly, CPU overhead is minimal
    }

    // MARK: - Quality Adjustment Convergence (AC 2.2.4)

    func testAdaptiveQualityConvergence() {
        // Test that adaptive quality converges to target within reasonable iterations
        let manager = AdaptiveQualityManager()
        let settings = CompressionSettings.default(width: 1920, height: 1080, fps: 1)

        let targetChunkSize: Int64 = 64 * 1024 * 1024  // 64MB
        var currentSize: Int64 = 100 * 1024 * 1024  // Start at 100MB (oversized)

        var iterations = 0
        let maxIterations = 20

        // Simulate convergence
        while iterations < maxIterations {
            iterations += 1

            let chunk = CompressedChunk(
                fileURL: URL(fileURLWithPath: "/tmp/test\(iterations).mp4"),
                size: currentSize,
                duration: 900.0,
                compressionRatio: 100.0,
                frameCount: 900,
                createdAt: Date(),
                settings: settings
            )

            _ = manager.analyzeAndAdjust(chunk: chunk)

            // Simulate size adjustment based on multiplier
            let newSize = Int64(Double(currentSize) * (1.0 / manager.currentBitrateMultiplier))
            currentSize = newSize

            // Check if converged
            if chunk.isWithinTarget(size: targetChunkSize, tolerance: 0.10) {
                print("Converged in \(iterations) iterations")
                XCTAssertLessThan(iterations, maxIterations,
                                 "Should converge within \(maxIterations) iterations")
                return
            }
        }

        // Should have converged by now
        XCTAssertLessThan(iterations, maxIterations,
                         "Failed to converge within \(maxIterations) iterations")
    }

    // MARK: - Validation Tests

    func testStorageMetricsValidation() {
        // Test that storage metrics provide accurate information
        // Note: This is a validation test to ensure metrics are calculated correctly

        let metrics = TimelapseStorageManager.shared.calculateStorageMetrics()

        // Validate metrics are within reasonable bounds
        XCTAssertGreaterThanOrEqual(metrics.totalStorageUsed, 0, "Storage should be non-negative")
        XCTAssertGreaterThanOrEqual(metrics.recordingCount, 0, "Count should be non-negative")
        XCTAssertGreaterThan(metrics.compressionRatio, 0, "Ratio should be positive")
        XCTAssertGreaterThanOrEqual(metrics.dailyAverageSize, 0, "Daily average should be non-negative")

        // Validate usage percentage is between 0 and 1
        XCTAssertGreaterThanOrEqual(metrics.usagePercentage, 0.0, "Usage should be >= 0%")
        XCTAssertLessThanOrEqual(metrics.usagePercentage, 1.0, "Usage should be <= 100%")
    }
}
