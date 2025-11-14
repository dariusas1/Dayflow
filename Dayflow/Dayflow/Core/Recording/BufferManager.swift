//
//  BufferManager.swift
//  Dayflow
//
//  Created by Development Agent on 2025-11-14.
//  Story 1.2: Screen Recording Memory Cleanup
//
//  Thread-safe video frame buffer manager using actor isolation and bounded buffer pool.
//  Implements FIFO (First-In-First-Out) eviction strategy to prevent unbounded memory growth.
//  Manages CVPixelBuffer lifecycle with proper locking/unlocking to prevent memory leaks.
//

import Foundation
import AVFoundation
import os.log

/// Thread-safe buffer manager for video frame CVPixelBuffer instances.
/// Implements bounded buffer pool with automatic eviction when capacity (100 frames) is reached.
/// Actor isolation guarantees thread-safe access to buffer pool from multiple concurrent callers.
actor BufferManager: BufferManagerProtocol {

    /// Shared singleton instance. All buffer operations should use this instance.
    static let shared = BufferManager()

    /// Internal structure to track managed buffer metadata.
    /// Contains the CVPixelBuffer reference, creation timestamp, and unique identifier.
    private struct ManagedBuffer {
        let buffer: CVPixelBuffer
        let createdAt: Date
        let id: UUID

        /// Estimated memory size in bytes for this buffer.
        /// Calculated as: width × height × 4 bytes per pixel (BGRA format).
        var estimatedSizeBytes: Int {
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            return width * height * 4 // 4 bytes per pixel for BGRA
        }
    }

    /// Dictionary of managed buffers, keyed by UUID.
    /// Using dictionary for O(1) lookup by ID and deletion.
    private var buffers: [UUID: ManagedBuffer] = [:]

    /// Ordered list of buffer IDs for FIFO eviction.
    /// Oldest buffers are at the front of the array.
    private var bufferOrder: [UUID] = []

    /// Maximum number of buffers to retain before automatic eviction.
    /// 100 frames at 1 FPS = 100 seconds of video history.
    /// Target memory usage: ~800MB (1920x1080 × 4 bytes × 100 frames ≈ 8MB per frame × 100 = ~800MB).
    /// This bounded pool prevents unbounded memory growth during long recording sessions.
    private let maxBuffers: Int = 100

    /// Logger for buffer lifecycle events.
    private let logger = Logger(subsystem: "Dayflow", category: "BufferManager")

    /// Tracks total number of buffers allocated (for diagnostics).
    private var totalBuffersAllocated: Int = 0

    /// Tracks total number of buffers evicted (for diagnostics).
    private var totalBuffersEvicted: Int = 0

    /// Private initializer to enforce singleton pattern.
    private init() {
        logger.info("BufferManager initialized with maxBuffers=\(self.maxBuffers)")
    }

    /// Add a buffer to the managed pool, automatically evicting oldest if at capacity.
    /// Implements FIFO eviction: when buffer count exceeds maxBuffers, oldest buffer is released.
    /// - Parameter buffer: The CVPixelBuffer to add to the managed pool.
    /// - Returns: UUID identifier for the buffer, used for explicit release operations.
    func addBuffer(_ buffer: CVPixelBuffer) async -> UUID {
        let startTime = Date()
        let id = UUID()

        // Lock the buffer to increment its reference count and ensure it stays valid
        // Note: We don't lock for pixel data access here, just for lifecycle management
        CVPixelBufferRetain(buffer)

        let managedBuffer = ManagedBuffer(
            buffer: buffer,
            createdAt: Date(),
            id: id
        )

        // Add to buffers dictionary and order tracking
        buffers[id] = managedBuffer
        bufferOrder.append(id)

        totalBuffersAllocated += 1

        // Check if we've exceeded capacity and need to evict
        if buffers.count > maxBuffers {
            await evictOldestBuffer()
        }

        // Performance monitoring: log if allocation took >10ms
        let duration = Date().timeIntervalSince(startTime) * 1000
        if duration > 10 {
            logger.warning("Slow buffer allocation: \(duration, privacy: .public)ms (target <10ms)")
        }

        // Log buffer allocation (sampled at 10% to reduce overhead)
        if totalBuffersAllocated % 10 == 0 {
            logger.debug("Buffer allocated: id=\(id), count=\(self.buffers.count), total_allocated=\(self.totalBuffersAllocated)")
        }

        return id
    }

    /// Evict the oldest buffer from the pool (FIFO strategy).
    /// Called automatically when buffer count exceeds maxBuffers.
    /// Properly releases CVPixelBuffer to prevent memory leaks.
    private func evictOldestBuffer() async {
        guard let oldestId = bufferOrder.first else {
            logger.error("evictOldestBuffer called but bufferOrder is empty!")
            return
        }

        guard let managedBuffer = buffers[oldestId] else {
            logger.error("evictOldestBuffer: buffer \(oldestId) not found in buffers dictionary!")
            // Clean up order array even if buffer is missing
            bufferOrder.removeFirst()
            return
        }

        // Release the CVPixelBuffer
        CVPixelBufferRelease(managedBuffer.buffer)

        // Remove from tracking
        buffers.removeValue(forKey: oldestId)
        bufferOrder.removeFirst()

        totalBuffersEvicted += 1

        // Log eviction (sampled at 10% to reduce overhead)
        if totalBuffersEvicted % 10 == 0 {
            logger.debug("Buffer evicted (FIFO): id=\(oldestId), count=\(self.buffers.count), total_evicted=\(self.totalBuffersEvicted)")
        }

        // Diagnostic: Warn if buffer pool is consistently at capacity
        if totalBuffersEvicted > 1000 && totalBuffersEvicted % 100 == 0 {
            let evictionRate = Double(totalBuffersEvicted) / Double(totalBuffersAllocated)
            logger.info("Buffer eviction stats: evicted=\(self.totalBuffersEvicted), allocated=\(self.totalBuffersAllocated), eviction_rate=\(evictionRate, privacy: .public)")
        }
    }

    /// Remove and release a specific buffer from the managed pool.
    /// Properly releases the CVPixelBuffer to prevent memory leaks.
    /// - Parameter id: UUID of buffer to release.
    func releaseBuffer(_ id: UUID) async {
        guard let managedBuffer = buffers[id] else {
            logger.debug("releaseBuffer: buffer \(id) not found (may have already been evicted)")
            return
        }

        // Release the CVPixelBuffer
        CVPixelBufferRelease(managedBuffer.buffer)

        // Remove from tracking
        buffers.removeValue(forKey: id)
        if let index = bufferOrder.firstIndex(of: id) {
            bufferOrder.remove(at: index)
        }

        logger.debug("Buffer released explicitly: id=\(id), count=\(self.buffers.count)")
    }

    /// Get current buffer count for diagnostics and monitoring.
    /// - Returns: Number of buffers currently managed.
    func bufferCount() async -> Int {
        return buffers.count
    }

    /// Get estimated memory usage in megabytes for all managed buffers.
    /// Used for monitoring memory consumption against the <100MB target.
    /// - Returns: Estimated memory usage in MB.
    func estimatedMemoryUsageMB() async -> Double {
        let totalBytes = buffers.values.reduce(0) { $0 + $1.estimatedSizeBytes }
        return Double(totalBytes) / (1024.0 * 1024.0)
    }

    /// Release all buffers and clean up resources.
    /// Called during shutdown or when resetting the buffer pool.
    func releaseAll() async {
        let count = buffers.count
        logger.info("releaseAll: releasing \(count) buffers")

        // Release all CVPixelBuffers
        for (_, managedBuffer) in buffers {
            CVPixelBufferRelease(managedBuffer.buffer)
        }

        // Clear all tracking
        buffers.removeAll()
        bufferOrder.removeAll()

        logger.info("releaseAll: all buffers released")
    }

    /// Deinitializer to ensure all buffers are properly released on cleanup.
    /// This should rarely be called since BufferManager is a singleton, but provides safety net.
    deinit {
        // Note: deinit is not async, so we can't call async releaseAll()
        // Instead, we directly release all buffers synchronously
        logger.warning("BufferManager deinit called - releasing \(self.buffers.count) buffers")

        for (_, managedBuffer) in buffers {
            CVPixelBufferRelease(managedBuffer.buffer)
        }

        buffers.removeAll()
        bufferOrder.removeAll()
    }

    /// Get diagnostic information for monitoring and debugging.
    /// Returns a snapshot of current buffer pool state.
    func diagnosticInfo() async -> BufferDiagnosticInfo {
        let memoryMB = await estimatedMemoryUsageMB()

        return BufferDiagnosticInfo(
            currentCount: buffers.count,
            maxBuffers: maxBuffers,
            totalAllocated: totalBuffersAllocated,
            totalEvicted: totalBuffersEvicted,
            estimatedMemoryMB: memoryMB,
            oldestBufferAge: bufferOrder.first.flatMap { id in
                buffers[id]?.createdAt
            }.map { Date().timeIntervalSince($0) }
        )
    }
}

/// Diagnostic information snapshot for BufferManager.
/// Used for monitoring, logging, and alerting.
struct BufferDiagnosticInfo: Sendable {
    let currentCount: Int
    let maxBuffers: Int
    let totalAllocated: Int
    let totalEvicted: Int
    let estimatedMemoryMB: Double
    let oldestBufferAge: TimeInterval? // Age of oldest buffer in seconds, nil if no buffers
}
