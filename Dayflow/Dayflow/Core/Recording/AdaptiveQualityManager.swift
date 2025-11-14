//
//  AdaptiveQualityManager.swift
//  Dayflow
//
//  Adaptive quality adjustment algorithm for compression optimization.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation

/// Manager for adaptive quality adjustment based on storage targets
final class AdaptiveQualityManager {
    // MARK: - Properties

    /// Target storage per day in bytes (default: 2GB)
    var targetStoragePerDay: Int64 = 2 * 1024 * 1024 * 1024  // 2GB

    /// Target tolerance (default: 10%)
    var targetTolerance: Double = 0.10

    /// Current bitrate multiplier (1.0 = baseline)
    private(set) var currentBitrateMultiplier: Double = 1.0

    /// Minimum bitrate multiplier to prevent excessive quality degradation
    let minBitrateMultiplier: Double = 0.4  // 40% of baseline

    /// Maximum bitrate multiplier to prevent file bloat
    let maxBitrateMultiplier: Double = 2.0  // 200% of baseline

    /// History of adjustments for analytics
    private(set) var adjustmentHistory: [QualityAdjustment] = []

    /// Smoothing factor to prevent oscillation (0.0 to 1.0)
    let smoothingFactor: Double = 0.5

    /// Number of chunks to analyze before adjusting
    let analysisWindowSize: Int = 4  // 4 chunks = ~1 hour at 15-min chunks

    /// Recent chunk sizes for trend analysis
    private var recentChunkSizes: [Int64] = []

    // MARK: - Initialization

    init(targetStoragePerDay: Int64 = 2 * 1024 * 1024 * 1024) {
        self.targetStoragePerDay = targetStoragePerDay
    }

    // MARK: - Quality Adjustment

    /// Analyze a completed chunk and adjust quality if needed
    /// - Parameter chunk: Completed compressed chunk
    /// - Returns: New compression settings if adjustment needed, nil otherwise
    func analyzeAndAdjust(chunk: CompressedChunk) -> CompressionSettings? {
        // Add to recent chunks
        recentChunkSizes.append(chunk.size)
        if recentChunkSizes.count > analysisWindowSize {
            recentChunkSizes.removeFirst()
        }

        // Need enough data before adjusting
        guard recentChunkSizes.count >= analysisWindowSize else {
            print("📊 Adaptive Quality: Collecting data... (\(recentChunkSizes.count)/\(analysisWindowSize) chunks)")
            return nil
        }

        // Calculate target chunk size
        // Target: 2GB per 8-hour day = 256MB per hour = ~64MB per 15-minute chunk
        let secondsPerDay: Double = 8 * 60 * 60  // 8-hour recording day
        let chunkDuration = chunk.duration
        let targetChunkSize = Int64(Double(targetStoragePerDay) * (chunkDuration / secondsPerDay))

        // Calculate average recent chunk size
        let avgRecentSize = recentChunkSizes.reduce(0, +) / Int64(recentChunkSizes.count)

        // Calculate deviation from target
        let deviation = Double(avgRecentSize - targetChunkSize) / Double(targetChunkSize)

        // Check if within tolerance
        if abs(deviation) <= targetTolerance {
            print("📊 Adaptive Quality: Within target (\(String(format: "%.1f%%", deviation * 100)) deviation)")
            return nil
        }

        // Calculate adjustment
        let adjustment = calculateAdjustment(deviation: deviation)

        // Apply smoothing to prevent oscillation
        let smoothedAdjustment = adjustment * smoothingFactor

        // Calculate new multiplier with bounds
        let newMultiplier = (currentBitrateMultiplier * (1.0 + smoothedAdjustment))
            .clamped(to: minBitrateMultiplier...maxBitrateMultiplier)

        // Only adjust if change is significant (>2%)
        let changePercent = abs(newMultiplier - currentBitrateMultiplier) / currentBitrateMultiplier
        guard changePercent > 0.02 else {
            print("📊 Adaptive Quality: Change too small (\(String(format: "%.1f%%", changePercent * 100)))")
            return nil
        }

        // Record adjustment
        let qualityAdjustment = QualityAdjustment(
            timestamp: Date(),
            previousMultiplier: currentBitrateMultiplier,
            newMultiplier: newMultiplier,
            deviation: deviation,
            averageChunkSize: avgRecentSize,
            targetChunkSize: targetChunkSize,
            reason: deviation > 0 ? "Oversized chunks" : "Undersized chunks"
        )
        adjustmentHistory.append(qualityAdjustment)

        // Limit history size
        if adjustmentHistory.count > 100 {
            adjustmentHistory.removeFirst()
        }

        currentBitrateMultiplier = newMultiplier

        print("📊 Adaptive Quality: Adjusted bitrate multiplier: \(String(format: "%.2f", currentBitrateMultiplier)) (\(qualityAdjustment.reason))")
        print("   Deviation: \(String(format: "%.1f%%", deviation * 100)), Avg size: \(avgRecentSize / 1024 / 1024)MB, Target: \(targetChunkSize / 1024 / 1024)MB")

        // Create new settings with adjusted bitrate
        let newBitrate = Int(Double(chunk.settings.targetBitrate) * newMultiplier / currentBitrateMultiplier)
        return chunk.settings.withBitrate(newBitrate)
    }

    /// Calculate adjustment factor based on deviation
    /// - Parameter deviation: Deviation from target (-1.0 to 1.0+)
    /// - Returns: Adjustment factor to apply
    private func calculateAdjustment(deviation: Double) -> Double {
        // Oversized chunks: reduce bitrate more aggressively (10% per deviation unit)
        if deviation > 0 {
            return -0.10 * deviation
        }
        // Undersized chunks: increase bitrate more conservatively (5% per deviation unit)
        else {
            return -0.05 * deviation
        }
    }

    // MARK: - Analytics

    /// Get statistics about quality adjustments
    func getAdjustmentStatistics() -> AdjustmentStatistics {
        let totalAdjustments = adjustmentHistory.count
        let increasedCount = adjustmentHistory.filter { $0.newMultiplier > $0.previousMultiplier }.count
        let decreasedCount = adjustmentHistory.filter { $0.newMultiplier < $0.previousMultiplier }.count

        let avgMultiplier = adjustmentHistory.isEmpty ? currentBitrateMultiplier :
            adjustmentHistory.map { $0.newMultiplier }.reduce(0, +) / Double(adjustmentHistory.count)

        return AdjustmentStatistics(
            totalAdjustments: totalAdjustments,
            increasedCount: increasedCount,
            decreasedCount: decreasedCount,
            currentMultiplier: currentBitrateMultiplier,
            averageMultiplier: avgMultiplier,
            minMultiplier: adjustmentHistory.map { $0.newMultiplier }.min() ?? currentBitrateMultiplier,
            maxMultiplier: adjustmentHistory.map { $0.newMultiplier }.max() ?? currentBitrateMultiplier
        )
    }

    /// Reset quality adjustment state
    func reset() {
        currentBitrateMultiplier = 1.0
        recentChunkSizes = []
        // Keep history for analytics
    }
}

// MARK: - Supporting Types

/// Record of a quality adjustment
struct QualityAdjustment: Codable, Sendable {
    let timestamp: Date
    let previousMultiplier: Double
    let newMultiplier: Double
    let deviation: Double
    let averageChunkSize: Int64
    let targetChunkSize: Int64
    let reason: String

    var change: Double {
        newMultiplier - previousMultiplier
    }

    var changePercent: Double {
        (change / previousMultiplier) * 100
    }
}

/// Statistics about quality adjustments
struct AdjustmentStatistics: Codable, Sendable {
    let totalAdjustments: Int
    let increasedCount: Int
    let decreasedCount: Int
    let currentMultiplier: Double
    let averageMultiplier: Double
    let minMultiplier: Double
    let maxMultiplier: Double

    var stabilityScore: Double {
        // Score from 0.0 (unstable) to 1.0 (stable)
        // Based on how close current is to average
        guard averageMultiplier > 0 else { return 0.0 }
        let deviation = abs(currentMultiplier - averageMultiplier) / averageMultiplier
        return max(0.0, 1.0 - deviation)
    }
}

// MARK: - Extensions

extension Double {
    /// Clamp value to a range
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
