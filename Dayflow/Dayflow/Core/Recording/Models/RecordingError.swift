//
//  RecordingError.swift
//  Dayflow
//
//  Created for Story 2.3: Real-Time Recording Status
//

import Foundation

/// Error code types for recording failures
enum ErrorCode: String, Sendable, Equatable {
    case permissionDenied = "permission_denied"
    case displayConfigurationChanged = "display_configuration_changed"
    case storageSpaceLow = "storage_space_low"
    case compressionFailed = "compression_failed"
    case frameCaptureTimeout = "frame_capture_timeout"
    case databaseWriteFailed = "database_write_failed"

    var displayName: String {
        switch self {
        case .permissionDenied:
            return "Permission Denied"
        case .displayConfigurationChanged:
            return "Display Configuration Changed"
        case .storageSpaceLow:
            return "Storage Space Low"
        case .compressionFailed:
            return "Compression Failed"
        case .frameCaptureTimeout:
            return "Frame Capture Timeout"
        case .databaseWriteFailed:
            return "Database Write Failed"
        }
    }
}

/// Recovery action for error states
struct RecoveryAction: Equatable, Sendable {
    let id: UUID
    let title: String
    let isPrimary: Bool

    init(title: String, isPrimary: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isPrimary = isPrimary
    }

    static func == (lhs: RecoveryAction, rhs: RecoveryAction) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.isPrimary == rhs.isPrimary
    }
}

/// Recording error with typed error codes and actionable recovery options
struct RecordingError: Equatable, Sendable {
    let code: ErrorCode
    let message: String
    let recoveryOptions: [RecoveryAction]
    let timestamp: Date

    init(code: ErrorCode, message: String, recoveryOptions: [RecoveryAction] = [], timestamp: Date = Date()) {
        self.code = code
        self.message = message
        self.recoveryOptions = recoveryOptions
        self.timestamp = timestamp
    }

    // MARK: - Factory methods for common errors

    static func permissionDenied() -> RecordingError {
        RecordingError(
            code: .permissionDenied,
            message: "Screen recording permission is required to capture your screen.",
            recoveryOptions: [
                RecoveryAction(title: "Open System Preferences", isPrimary: true),
                RecoveryAction(title: "Learn More", isPrimary: false)
            ]
        )
    }

    static func displayConfigurationChanged() -> RecordingError {
        RecordingError(
            code: .displayConfigurationChanged,
            message: "Display configuration changed. Recording will restart automatically.",
            recoveryOptions: [
                RecoveryAction(title: "Retry Now", isPrimary: true),
                RecoveryAction(title: "Dismiss", isPrimary: false)
            ]
        )
    }

    static func storageSpaceLow(availableSpace: Int64) -> RecordingError {
        let availableMB = availableSpace / (1024 * 1024)
        RecordingError(
            code: .storageSpaceLow,
            message: "Low disk space (\(availableMB) MB available). Recording may stop soon.",
            recoveryOptions: [
                RecoveryAction(title: "Free Up Space", isPrimary: true),
                RecoveryAction(title: "Continue Anyway", isPrimary: false)
            ]
        )
    }

    static func compressionFailed(reason: String) -> RecordingError {
        RecordingError(
            code: .compressionFailed,
            message: "Video compression failed: \(reason)",
            recoveryOptions: [
                RecoveryAction(title: "Retry", isPrimary: true),
                RecoveryAction(title: "Use Lower Quality", isPrimary: false)
            ]
        )
    }

    static func frameCaptureTimeout() -> RecordingError {
        RecordingError(
            code: .frameCaptureTimeout,
            message: "Failed to capture frames within expected time. System may be under heavy load.",
            recoveryOptions: [
                RecoveryAction(title: "Retry", isPrimary: true),
                RecoveryAction(title: "Stop Recording", isPrimary: false)
            ]
        )
    }

    static func databaseWriteFailed(reason: String) -> RecordingError {
        RecordingError(
            code: .databaseWriteFailed,
            message: "Failed to save recording metadata: \(reason)",
            recoveryOptions: [
                RecoveryAction(title: "Retry", isPrimary: true),
                RecoveryAction(title: "Continue Without Metadata", isPrimary: false)
            ]
        )
    }
}
