//
//  StorageMetrics.swift
//  Dayflow
//
//  Storage usage metrics for monitoring and analytics.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation

/// Comprehensive storage usage metrics
struct StorageMetrics: Codable, Sendable, Equatable {
    /// Total storage used by all recordings (bytes)
    let totalStorageUsed: Int64

    /// Number of recording chunks stored
    let recordingCount: Int

    /// Date of oldest recording
    let oldestRecordingDate: Date?

    /// Date of newest recording
    let newestRecordingDate: Date?

    /// Average compression ratio across all recordings
    let compressionRatio: Double

    /// Average daily storage usage (bytes per day)
    let dailyAverageSize: Int64

    /// Configured retention period in days
    let retentionDays: Int

    /// Storage limit in bytes
    let storageLimit: Int64

    /// Timestamp when metrics were calculated
    let calculatedAt: Date

    /// Percentage of storage limit used (0.0 to 1.0)
    var usagePercentage: Double {
        guard storageLimit > 0 else { return 0.0 }
        return Double(totalStorageUsed) / Double(storageLimit)
    }

    /// Check if approaching storage limit
    /// - Parameter threshold: Warning threshold (default 0.8 = 80%)
    /// - Returns: True if usage exceeds threshold
    func isApproachingLimit(threshold: Double = 0.8) -> Bool {
        return usagePercentage >= threshold
    }

    /// Estimated days until storage limit reached
    /// - Returns: Number of days, or nil if not increasing or limit not set
    var estimatedDaysUntilFull: Int? {
        guard dailyAverageSize > 0, storageLimit < Int64.max else { return nil }

        let remainingBytes = storageLimit - totalStorageUsed
        guard remainingBytes > 0 else { return 0 }

        return Int(Double(remainingBytes) / Double(dailyAverageSize))
    }

    /// Format storage size as human-readable string
    /// - Parameter bytes: Size in bytes
    /// - Returns: Formatted string (e.g., "1.5 GB")
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Human-readable total storage used
    var formattedTotalStorage: String {
        Self.formatBytes(totalStorageUsed)
    }

    /// Human-readable daily average
    var formattedDailyAverage: String {
        Self.formatBytes(dailyAverageSize)
    }

    /// Human-readable storage limit
    var formattedStorageLimit: String {
        guard storageLimit < Int64.max else { return "Unlimited" }
        return Self.formatBytes(storageLimit)
    }
}
