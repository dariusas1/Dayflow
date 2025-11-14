//
//  CompressionSettings.swift
//  Dayflow
//
//  Configuration settings for video compression engine.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation

/// Configuration for video compression
struct CompressionSettings: Codable, Sendable, Equatable {
    /// Video codec to use for compression
    let codec: VideoCodec

    /// Quality level for compression
    let quality: CompressionQuality

    /// Target bitrate in bits per second
    let targetBitrate: Int

    /// Interval between keyframes (frames)
    let keyFrameInterval: Int

    /// Target resolution width
    let width: Int

    /// Target resolution height
    let height: Int

    /// Create default compression settings for the current system
    /// - Parameters:
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    ///   - fps: Frames per second (default 1)
    /// - Returns: Optimized compression settings
    static func `default`(width: Int, height: Int, fps: Int = 1) -> CompressionSettings {
        let codec = VideoCodec.recommended
        let quality = CompressionQuality.auto

        // Target: ~70KB per frame for 2GB/8hrs at 1 FPS
        // 2GB / (8 hours * 3600 seconds * 1 fps) = ~70KB per frame
        // 70KB * 8 bits = 560,000 bits per frame
        // At 1 FPS: 560,000 bits per frame = 560,000 bps

        let pixelArea = width * height
        let baseTargetBitsPerFrame = 560_000  // ~70KB per frame

        // Scale bitrate with resolution (1920x1080 is baseline)
        let baselinePixels = 1920 * 1080
        let scalingFactor = Double(pixelArea) / Double(baselinePixels)

        let targetBitrate = Int(Double(baseTargetBitsPerFrame) * fps * scalingFactor * quality.bitrateMultiplier)

        // Keyframe interval: one keyframe every 30 frames (30 seconds at 1 FPS)
        let keyFrameInterval = 30

        return CompressionSettings(
            codec: codec,
            quality: quality,
            targetBitrate: targetBitrate,
            keyFrameInterval: keyFrameInterval,
            width: width,
            height: height
        )
    }

    /// Create settings with adjusted quality
    /// - Parameter newQuality: New quality level
    /// - Returns: New settings with updated quality and recalculated bitrate
    func withQuality(_ newQuality: CompressionQuality) -> CompressionSettings {
        let baseBitrate = Double(targetBitrate) / quality.bitrateMultiplier
        let newBitrate = Int(baseBitrate * newQuality.bitrateMultiplier)

        return CompressionSettings(
            codec: codec,
            quality: newQuality,
            targetBitrate: newBitrate,
            keyFrameInterval: keyFrameInterval,
            width: width,
            height: height
        )
    }

    /// Create settings with adjusted bitrate
    /// - Parameter bitrate: New target bitrate
    /// - Returns: New settings with updated bitrate
    func withBitrate(_ bitrate: Int) -> CompressionSettings {
        return CompressionSettings(
            codec: codec,
            quality: quality,
            targetBitrate: bitrate,
            keyFrameInterval: keyFrameInterval,
            width: width,
            height: height
        )
    }

    /// Estimated bytes per frame at current settings
    var estimatedBytesPerFrame: Int64 {
        // bitrate is bits per second, convert to bytes per frame
        // At 1 FPS: bitrate / 8 = bytes per frame
        return Int64(targetBitrate / 8)
    }
}
