//
//  RecordingState.swift
//  Dayflow
//
//  Created for Story 2.3: Real-Time Recording Status
//

import Foundation

/// Recording state for UI layer - extends RecorderState with error handling
/// Maps to ScreenRecorder.RecorderState with additional error and stopping states
enum RecordingState: Equatable, Sendable {
    case idle           // Not recording, no active resources
    case initializing   // Initiating stream creation (async operation in progress)
    case recording(displayCount: Int)  // Active stream + writer (with display count)
    case paused         // System event pause (sleep/lock), will auto-resume
    case error(RecordingError)  // Error condition with recovery options
    case stopping       // Cleaning up current segment

    var description: String {
        switch self {
        case .idle: return "idle"
        case .initializing: return "initializing"
        case .recording(let count): return "recording(\(count) display\(count == 1 ? "" : "s"))"
        case .paused: return "paused"
        case .error(let err): return "error(\(err.code.rawValue))"
        case .stopping: return "stopping"
        }
    }

    var displayCount: Int {
        if case .recording(let count) = self {
            return count
        }
        return 0
    }

    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Convert from ScreenRecorder.RecorderState to UI RecordingState
    static func from(recorderState: RecorderState) -> RecordingState {
        switch recorderState {
        case .idle:
            return .idle
        case .starting:
            return .initializing
        case .recording(let displayCount):
            return .recording(displayCount: displayCount)
        case .finishing:
            return .stopping
        case .paused:
            return .paused
        }
    }
}

// MARK: - Equatable Conformance
extension RecordingState {
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.initializing, .initializing),
             (.paused, .paused),
             (.stopping, .stopping):
            return true
        case let (.recording(lcount), .recording(rcount)):
            return lcount == rcount
        case let (.error(lerr), .error(rerr)):
            return lerr == rerr
        default:
            return false
        }
    }
}
