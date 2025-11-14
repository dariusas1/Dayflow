//
//  CompressedChunk.swift
//  Dayflow
//
//  Metadata for a finalized compressed video chunk.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation

/// Metadata for a compressed video chunk
struct CompressedChunk: Codable, Sendable, Equatable {
    /// URL of the compressed video file
    let fileURL: URL

    /// File size in bytes
    let size: Int64

    /// Duration of the chunk in seconds
    let duration: TimeInterval

    /// Compression ratio (original size / compressed size)
    let compressionRatio: Double

    /// Number of frames in the chunk
    let frameCount: Int

    /// Timestamp when chunk was created
    let createdAt: Date

    /// Compression settings used for this chunk
    let settings: CompressionSettings

    /// Average bytes per frame
    var averageBytesPerFrame: Int64 {
        guard frameCount > 0 else { return 0 }
        return size / Int64(frameCount)
    }

    /// Average bits per second
    var averageBitrate: Int {
        guard duration > 0 else { return 0 }
        return Int(Double(size * 8) / duration)
    }

    /// Check if chunk size is within target range
    /// - Parameter targetSize: Target size in bytes
    /// - Parameter tolerance: Acceptable deviation (default 10%)
    /// - Returns: True if within tolerance
    func isWithinTarget(size targetSize: Int64, tolerance: Double = 0.10) -> Bool {
        let lowerBound = Double(targetSize) * (1.0 - tolerance)
        let upperBound = Double(targetSize) * (1.0 + tolerance)
        return Double(size) >= lowerBound && Double(size) <= upperBound
    }
}
