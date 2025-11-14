//
//  AnalysisModels.swift
//  Dayflow
//
//  Created on 5/1/2025.
//

import Foundation

/// Represents a video recording chunk stored in the database
///
/// A recording chunk is a segment of screen recording video, typically 15-60 seconds in duration.
/// Chunks are created during active recording sessions and stored both as video files on disk
/// and as database records for tracking and analysis.
///
/// ## Lifecycle
/// 1. Created during screen recording with status "recording"
/// 2. Marked "completed" when recording segment finishes successfully
/// 3. Grouped into analysis batches for AI processing
/// 4. Eventually deleted by retention policy (default: 3 days)
///
/// ## Database Mapping
/// This struct maps to the `chunks` table in the database:
/// - `id`: Primary key (auto-increment)
/// - `startTs`: Unix timestamp (seconds) when recording started
/// - `endTs`: Unix timestamp (seconds) when recording ended
/// - `fileUrl`: Absolute file path to the .mp4 video file
/// - `status`: Current state - "recording", "completed", or "failed"
///
/// ## Usage
/// ```swift
/// let chunk = RecordingChunk(
///     id: 123,
///     startTs: 1699900000,
///     endTs: 1699900900,
///     fileUrl: "/path/to/chunk_1699900000_1699900900.mp4",
///     status: "completed"
/// )
/// print("Chunk duration: \(chunk.duration) seconds")
/// ```
struct RecordingChunk: Codable {
    /// Unique identifier from database (primary key)
    let id: Int64

    /// Unix timestamp (seconds since epoch) when recording started
    let startTs: Int

    /// Unix timestamp (seconds since epoch) when recording ended
    let endTs: Int

    /// Absolute file path to the video file on disk
    let fileUrl: String

    /// Current status: "recording", "completed", or "failed"
    let status: String

    /// Duration of the recording chunk in seconds
    ///
    /// Calculated as the difference between end and start timestamps.
    var duration: TimeInterval {
        TimeInterval(endTs - startTs)
    }
}

/// Statistics collected during automatic chunk cleanup operations
///
/// This struct provides detailed metrics about chunk cleanup operations, tracking
/// both database operations and file system changes. It's returned by
/// `StorageManager.cleanupOldChunks()` to provide feedback on cleanup effectiveness.
///
/// ## Purpose
/// - Monitor cleanup operation success and efficiency
/// - Track storage space reclaimed
/// - Debug cleanup issues (e.g., file deletion failures)
/// - Log cleanup history for analytics
///
/// ## Typical Values
/// For a successful cleanup of 10 old chunks (~100MB total):
/// - `chunksFound`: 10 (chunks older than retention period)
/// - `filesDeleted`: 10 (video files removed from disk)
/// - `recordsDeleted`: 10 (database records removed)
/// - `bytesFreed`: ~100,000,000 (bytes reclaimed)
///
/// If some files are missing or deletions fail, `filesDeleted` may be less than `chunksFound`.
///
/// ## Example
/// ```swift
/// let stats = try await storageManager.cleanupOldChunks(retentionDays: 3)
/// print("Cleanup Summary:")
/// print("  Found: \(stats.chunksFound) old chunks")
/// print("  Deleted: \(stats.filesDeleted) files")
/// print("  Freed: \(stats.bytesFreed / 1_000_000) MB")
/// ```
struct CleanupStats: Sendable {
    /// Number of chunks identified as older than retention period
    ///
    /// This represents chunks that met the deletion criteria (age-based) and were
    /// not protected by foreign key constraints (e.g., chunks in batches).
    var chunksFound: Int = 0

    /// Number of chunk video files successfully deleted from filesystem
    ///
    /// May be less than `chunksFound` if some files are already missing or
    /// file deletion fails due to permissions or locks.
    var filesDeleted: Int = 0

    /// Number of chunk database records successfully deleted
    ///
    /// Should typically equal `chunksFound` unless database errors occur.
    var recordsDeleted: Int = 0

    /// Total bytes freed from filesystem by deleting chunk files
    ///
    /// Calculated by summing file sizes before deletion. Useful for tracking
    /// storage reclamation and verifying cleanup effectiveness.
    var bytesFreed: Int64 = 0
}

/// Detailed breakdown of storage usage for database and video recordings
///
/// This struct provides comprehensive storage metrics for the Dayflow application,
/// separating database overhead from video recording storage. It's returned by
/// `StorageManager.calculateStorageUsage()` for quota monitoring and storage analytics.
///
/// ## Storage Components
///
/// **Database Storage:**
/// - Main SQLite database file (chunks.sqlite)
/// - Write-Ahead Log file (chunks.sqlite-wal)
/// - Shared memory file (chunks.sqlite-shm)
///
/// **Recording Storage:**
/// - All video chunk files (.mp4) referenced in the chunks table
/// - Calculated by querying database for chunk paths and summing file sizes
/// - Missing or deleted files are gracefully skipped
///
/// ## Use Cases
/// - Monitor storage quota usage (compare `totalGB` to configured limit)
/// - Display storage breakdown in settings UI
/// - Trigger cleanup when approaching quota (e.g., > 90%)
/// - Track storage growth over time
///
/// ## Performance
/// Calculation completes in < 2 seconds for 1000+ chunks, making it suitable
/// for periodic checks (e.g., every hour) without impacting app performance.
///
/// ## Example
/// ```swift
/// let usage = try await storageManager.calculateStorageUsage()
/// print("Total: \(usage.totalGB) GB")
/// print("Database: \(usage.databaseGB) GB (\(usage.databasePercentage)%)")
/// print("Recordings: \(usage.recordingsGB) GB (\(usage.recordingsPercentage)%)")
///
/// // Check quota
/// let quotaGB = 10.0
/// if usage.totalGB > quotaGB * 0.9 {
///     print("Warning: Approaching storage quota!")
/// }
/// ```
struct StorageUsage: Sendable {
    /// Total size of database files in bytes
    ///
    /// Includes main database file, WAL, and shared memory files.
    /// Typically represents < 1% of total storage for video-heavy applications.
    let databaseBytes: Int64

    /// Total size of all recording chunk files in bytes
    ///
    /// Calculated by summing file sizes for all chunks in the database.
    /// This is typically the dominant storage component (> 99% of total).
    let recordingsBytes: Int64

    /// Combined size of database and recording files in bytes
    ///
    /// Equals `databaseBytes + recordingsBytes`. Use this to compare
    /// against storage quotas and limits.
    let totalBytes: Int64

    /// Total storage usage in gigabytes
    ///
    /// Convenience property for human-readable display.
    /// Calculated as `totalBytes / (1024³)`.
    var totalGB: Double {
        return Double(totalBytes) / (1024 * 1024 * 1024)
    }

    /// Database storage usage in gigabytes
    ///
    /// Convenience property for showing database overhead.
    /// Calculated as `databaseBytes / (1024³)`.
    var databaseGB: Double {
        return Double(databaseBytes) / (1024 * 1024 * 1024)
    }

    /// Recording storage usage in gigabytes
    ///
    /// Convenience property for showing video storage consumption.
    /// Calculated as `recordingsBytes / (1024³)`.
    var recordingsGB: Double {
        return Double(recordingsBytes) / (1024 * 1024 * 1024)
    }
}
