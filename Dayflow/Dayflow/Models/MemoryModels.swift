//
//  MemoryModels.swift
//  Dayflow
//
//  Created by Development Agent on 2025-11-14.
//  Story 1.4: Memory Leak Detection System
//
//  Data models for memory monitoring and leak detection.
//  All models conform to Sendable protocol for safe cross-actor boundary passing.
//

import Foundation

/// Memory pressure level as reported by the system.
/// Used to track overall memory health and trigger appropriate alerts.
public enum MemoryPressure: String, Codable, Sendable {
    case normal     // System has adequate available memory
    case warning    // System is experiencing memory pressure (>75% usage)
    case critical   // System is critically low on memory (>90% usage)
}

/// Severity level for memory alerts.
/// Warning alerts are informational; critical alerts require immediate action.
public enum AlertSeverity: String, Codable, Sendable {
    case warning    // Memory usage >75% or concerning trend detected
    case critical   // Memory usage >90% or leak pattern confirmed
}

/// Snapshot of memory state at a specific point in time.
/// Contains system memory metrics and component-specific diagnostic counts.
/// All properties are value types to ensure Sendable conformance.
public struct MemorySnapshot: Codable, Sendable {
    /// Timestamp when this snapshot was collected
    public let timestamp: Date

    /// Physical memory footprint in megabytes (resident set size)
    public let usedMemoryMB: Double

    /// Available system memory in megabytes
    public let availableMemoryMB: Double

    /// System memory pressure level at time of snapshot
    public let memoryPressure: MemoryPressure

    // Component-specific diagnostics

    /// Number of active CVPixelBuffer instances managed by BufferManager
    public let bufferCount: Int

    /// Number of active database connections (if accessible)
    /// Nil if database metrics unavailable
    public let databaseConnectionCount: Int?

    /// Number of active threads in the process
    public let activeThreadCount: Int

    /// Calculated memory usage percentage: (used / total) * 100
    public var memoryUsagePercent: Double {
        let totalMemory = usedMemoryMB + availableMemoryMB
        guard totalMemory > 0 else { return 0 }
        return (usedMemoryMB / totalMemory) * 100
    }

    /// Total system memory in megabytes
    public var totalMemoryMB: Double {
        return usedMemoryMB + availableMemoryMB
    }

    public init(
        timestamp: Date,
        usedMemoryMB: Double,
        availableMemoryMB: Double,
        memoryPressure: MemoryPressure,
        bufferCount: Int,
        databaseConnectionCount: Int?,
        activeThreadCount: Int
    ) {
        self.timestamp = timestamp
        self.usedMemoryMB = usedMemoryMB
        self.availableMemoryMB = availableMemoryMB
        self.memoryPressure = memoryPressure
        self.bufferCount = bufferCount
        self.databaseConnectionCount = databaseConnectionCount
        self.activeThreadCount = activeThreadCount
    }
}

/// Alert generated when memory threshold is exceeded or leak pattern is detected.
/// Includes diagnostic snapshot, severity level, and recommended actions.
public struct MemoryAlert: Codable, Sendable {
    /// Unique identifier for this alert
    public let id: UUID

    /// Timestamp when alert was generated
    public let timestamp: Date

    /// Severity level: warning (>75%) or critical (>90% or leak)
    public let severity: AlertSeverity

    /// Human-readable alert message
    public let message: String

    /// Memory snapshot at time of alert generation
    public let snapshot: MemorySnapshot

    /// Recommended action to address the alert
    /// Examples: "Pause AI processing", "Clear buffer cache", "Restart app"
    public let recommendedAction: String

    // Leak detection specific fields (nil for threshold-based alerts)

    /// Memory growth rate as percentage over detection window
    /// Example: 7.5 means memory grew 7.5% over 5 minutes
    public let growthRate: Double?

    /// Duration of monitoring window for leak detection (typically 5 minutes = 300 seconds)
    public let detectionWindow: TimeInterval?

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        severity: AlertSeverity,
        message: String,
        snapshot: MemorySnapshot,
        recommendedAction: String,
        growthRate: Double? = nil,
        detectionWindow: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.message = message
        self.snapshot = snapshot
        self.recommendedAction = recommendedAction
        self.growthRate = growthRate
        self.detectionWindow = detectionWindow
    }
}

/// Memory status for UI display.
/// Simplified version of memory state for app-wide status indication.
public enum MemoryStatus: String, Codable, Sendable {
    case normal     // Memory usage healthy (<75%)
    case warning    // Memory usage elevated (75-90%)
    case critical   // Memory usage critical (>90%)

    /// Create status from memory usage percentage
    public init(memoryUsagePercent: Double) {
        if memoryUsagePercent >= 90 {
            self = .critical
        } else if memoryUsagePercent >= 75 {
            self = .warning
        } else {
            self = .normal
        }
    }
}
