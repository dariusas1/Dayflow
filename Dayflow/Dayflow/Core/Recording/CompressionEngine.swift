//
//  CompressionEngine.swift
//  Dayflow
//
//  Protocol definition for video compression engines.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation
import AVFoundation
import CoreMedia

/// Protocol for video compression engine implementations
protocol CompressionEngine: AnyObject {
    /// Current compression settings
    var compressionSettings: CompressionSettings { get set }

    /// Current chunk size in bytes (accumulated since last finalize)
    var currentChunkSize: Int64 { get }

    /// Number of frames in current chunk
    var currentFrameCount: Int { get }

    /// Initialize the compression engine
    /// - Parameters:
    ///   - settings: Compression settings to use
    ///   - outputURL: URL where the compressed video will be saved
    /// - Throws: Compression errors
    func initialize(settings: CompressionSettings, outputURL: URL) async throws

    /// Compress a single frame
    /// - Parameters:
    ///   - frame: Pixel buffer to compress
    ///   - timestamp: Presentation timestamp for the frame
    /// - Throws: Compression errors
    func compress(frame: CVPixelBuffer, timestamp: CMTime) async throws

    /// Finalize the current chunk and return metadata
    /// - Returns: Compressed chunk metadata
    /// - Throws: Compression errors
    func finalizeChunk() async throws -> CompressedChunk

    /// Estimate the final size of a chunk given frame count
    /// - Parameter frameCount: Number of frames
    /// - Returns: Estimated size in bytes
    func estimateChunkSize(frameCount: Int) -> Int64

    /// Reset the engine for a new chunk
    func reset()

    /// Check if engine is ready to accept frames
    var isReadyForData: Bool { get }
}

/// Errors that can occur during compression
enum CompressionError: Error, LocalizedError {
    case writerNotInitialized
    case writerNotReady
    case failedToCreateWriter
    case failedToAddInput
    case failedToStartWriting
    case failedToAppendFrame
    case failedToFinishWriting
    case invalidSettings
    case codecNotAvailable
    case insufficientDiskSpace
    case frameTimestampInvalid

    var errorDescription: String? {
        switch self {
        case .writerNotInitialized:
            return "Compression writer has not been initialized"
        case .writerNotReady:
            return "Compression writer is not ready to accept frames"
        case .failedToCreateWriter:
            return "Failed to create AVAssetWriter"
        case .failedToAddInput:
            return "Failed to add input to AVAssetWriter"
        case .failedToStartWriting:
            return "Failed to start writing compressed video"
        case .failedToAppendFrame:
            return "Failed to append frame to compressed video"
        case .failedToFinishWriting:
            return "Failed to finalize compressed video"
        case .invalidSettings:
            return "Compression settings are invalid"
        case .codecNotAvailable:
            return "Requested codec is not available"
        case .insufficientDiskSpace:
            return "Insufficient disk space for compression"
        case .frameTimestampInvalid:
            return "Frame timestamp is invalid"
        }
    }
}
