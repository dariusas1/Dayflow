//
//  CompressionQuality.swift
//  Dayflow
//
//  Quality level selection for video compression.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation

/// Compression quality levels
enum CompressionQuality: String, Codable, Sendable {
    /// Low quality - maximum compression, smallest file size
    case low = "low"

    /// Medium quality - balanced compression and quality
    case medium = "medium"

    /// High quality - minimal compression, best visual quality
    case high = "high"

    /// Auto quality - adaptive compression based on storage target
    case auto = "auto"

    /// Get the quality multiplier for bitrate calculation
    /// - Returns: Multiplier (0.5 to 1.5) to apply to base bitrate
    var bitrateMultiplier: Double {
        switch self {
        case .low:
            return 0.5      // 50% of base bitrate
        case .medium:
            return 1.0      // 100% of base bitrate
        case .high:
            return 1.5      // 150% of base bitrate
        case .auto:
            return 1.0      // Start with medium, adjust adaptively
        }
    }

    /// Adjust quality level up (improve quality)
    /// - Parameter percent: Percentage to increase (default 5%)
    /// - Returns: New quality level or nil if already at maximum
    func increased(by percent: Double = 0.05) -> CompressionQuality? {
        switch self {
        case .low:
            return .medium
        case .medium:
            return .high
        case .high:
            return nil  // Already at maximum
        case .auto:
            return .auto  // Auto-quality manages its own adjustments
        }
    }

    /// Adjust quality level down (reduce quality)
    /// - Parameter percent: Percentage to decrease (default 10%)
    /// - Returns: New quality level or nil if already at minimum
    func decreased(by percent: Double = 0.10) -> CompressionQuality? {
        switch self {
        case .low:
            return nil  // Already at minimum
        case .medium:
            return .low
        case .high:
            return .medium
        case .auto:
            return .auto  // Auto-quality manages its own adjustments
        }
    }
}
