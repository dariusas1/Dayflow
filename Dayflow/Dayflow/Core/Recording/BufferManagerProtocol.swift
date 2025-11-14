//
//  BufferManagerProtocol.swift
//  Dayflow
//
//  Created by Development Agent on 2025-11-14.
//  Story 1.2: Screen Recording Memory Cleanup
//
//  Protocol defining buffer lifecycle operations for managing CVPixelBuffer instances.
//  All implementations must conform to Sendable to guarantee safe cross-actor usage.
//

import Foundation
import AVFoundation

/// Protocol defining thread-safe video frame buffer lifecycle operations.
/// Implementations manage CVPixelBuffer instances with bounded retention and automatic eviction.
protocol BufferManagerProtocol: Sendable {

    /// Add a buffer to the managed pool, automatically evicting oldest if at capacity.
    /// This operation is non-blocking and completes in <10ms for P99 latency.
    /// - Parameter buffer: The CVPixelBuffer to add to the managed pool.
    /// - Returns: UUID identifier for the buffer, used for explicit release operations.
    func addBuffer(_ buffer: CVPixelBuffer) async -> UUID

    /// Remove and release a specific buffer from the managed pool.
    /// Properly unlocks and releases the CVPixelBuffer to prevent memory leaks.
    /// - Parameter id: UUID of buffer to release.
    func releaseBuffer(_ id: UUID) async

    /// Get current buffer count for diagnostics and monitoring.
    /// - Returns: Number of buffers currently managed.
    func bufferCount() async -> Int

    /// Get estimated memory usage in megabytes for all managed buffers.
    /// Used for monitoring memory consumption against the <100MB target.
    /// - Returns: Estimated memory usage in MB.
    func estimatedMemoryUsageMB() async -> Double

    /// Release all buffers and clean up resources.
    /// Called during shutdown to ensure proper cleanup.
    func releaseAll() async
}
