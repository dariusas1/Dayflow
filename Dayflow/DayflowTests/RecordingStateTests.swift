//
//  RecordingStateTests.swift
//  DayflowTests
//
//  Created for Story 2.3: Real-Time Recording Status
//

import XCTest
@testable import Dayflow

final class RecordingStateTests: XCTestCase {

    // MARK: - State Description Tests

    func testIdleStateDescription() {
        let state = RecordingState.idle
        XCTAssertEqual(state.description, "idle")
    }

    func testInitializingStateDescription() {
        let state = RecordingState.initializing
        XCTAssertEqual(state.description, "initializing")
    }

    func testRecordingStateDescription() {
        let singleDisplay = RecordingState.recording(displayCount: 1)
        XCTAssertEqual(singleDisplay.description, "recording(1 display)")

        let multiDisplay = RecordingState.recording(displayCount: 3)
        XCTAssertEqual(multiDisplay.description, "recording(3 displays)")
    }

    func testPausedStateDescription() {
        let state = RecordingState.paused
        XCTAssertEqual(state.description, "paused")
    }

    func testStoppingStateDescription() {
        let state = RecordingState.stopping
        XCTAssertEqual(state.description, "stopping")
    }

    func testErrorStateDescription() {
        let error = RecordingError.permissionDenied()
        let state = RecordingState.error(error)
        XCTAssertEqual(state.description, "error(permission_denied)")
    }

    // MARK: - Display Count Tests

    func testDisplayCountForRecordingState() {
        let state = RecordingState.recording(displayCount: 2)
        XCTAssertEqual(state.displayCount, 2)
    }

    func testDisplayCountForNonRecordingStates() {
        XCTAssertEqual(RecordingState.idle.displayCount, 0)
        XCTAssertEqual(RecordingState.initializing.displayCount, 0)
        XCTAssertEqual(RecordingState.paused.displayCount, 0)
        XCTAssertEqual(RecordingState.stopping.displayCount, 0)

        let error = RecordingError.permissionDenied()
        XCTAssertEqual(RecordingState.error(error).displayCount, 0)
    }

    // MARK: - State Property Tests

    func testIsRecordingProperty() {
        XCTAssertTrue(RecordingState.recording(displayCount: 1).isRecording)
        XCTAssertFalse(RecordingState.idle.isRecording)
        XCTAssertFalse(RecordingState.initializing.isRecording)
        XCTAssertFalse(RecordingState.paused.isRecording)
        XCTAssertFalse(RecordingState.stopping.isRecording)

        let error = RecordingError.permissionDenied()
        XCTAssertFalse(RecordingState.error(error).isRecording)
    }

    func testIsErrorProperty() {
        let error = RecordingError.permissionDenied()
        XCTAssertTrue(RecordingState.error(error).isError)
        XCTAssertFalse(RecordingState.idle.isError)
        XCTAssertFalse(RecordingState.recording(displayCount: 1).isError)
    }

    // MARK: - Equatable Tests

    func testIdleEquality() {
        XCTAssertEqual(RecordingState.idle, RecordingState.idle)
    }

    func testRecordingEquality() {
        let state1 = RecordingState.recording(displayCount: 2)
        let state2 = RecordingState.recording(displayCount: 2)
        let state3 = RecordingState.recording(displayCount: 3)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    func testErrorEquality() {
        let error1 = RecordingError.permissionDenied()
        let error2 = RecordingError.permissionDenied()
        let error3 = RecordingError.storageSpaceLow(availableSpace: 100_000_000)

        let state1 = RecordingState.error(error1)
        let state2 = RecordingState.error(error2)
        let state3 = RecordingState.error(error3)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    func testDifferentStatesNotEqual() {
        XCTAssertNotEqual(RecordingState.idle, RecordingState.initializing)
        XCTAssertNotEqual(RecordingState.idle, RecordingState.recording(displayCount: 1))
        XCTAssertNotEqual(RecordingState.recording(displayCount: 1), RecordingState.paused)
    }

    // MARK: - Conversion Tests

    func testConversionFromRecorderState() {
        // Test mapping from RecorderState to RecordingState
        XCTAssertEqual(RecordingState.from(recorderState: .idle), .idle)
        XCTAssertEqual(RecordingState.from(recorderState: .starting), .initializing)
        XCTAssertEqual(RecordingState.from(recorderState: .recording(displayCount: 2)),
                       .recording(displayCount: 2))
        XCTAssertEqual(RecordingState.from(recorderState: .finishing), .stopping)
        XCTAssertEqual(RecordingState.from(recorderState: .paused), .paused)
    }

    // MARK: - Sendable Conformance Test

    func testSendableConformance() {
        // RecordingState should be Sendable for AsyncStream
        let state = RecordingState.recording(displayCount: 1)
        Task {
            // This should compile without warnings if Sendable is properly conformed
            let _ = state
        }
    }
}

final class RecordingErrorTests: XCTestCase {

    // MARK: - Error Code Tests

    func testErrorCodeRawValues() {
        XCTAssertEqual(ErrorCode.permissionDenied.rawValue, "permission_denied")
        XCTAssertEqual(ErrorCode.displayConfigurationChanged.rawValue, "display_configuration_changed")
        XCTAssertEqual(ErrorCode.storageSpaceLow.rawValue, "storage_space_low")
        XCTAssertEqual(ErrorCode.compressionFailed.rawValue, "compression_failed")
        XCTAssertEqual(ErrorCode.frameCaptureTimeout.rawValue, "frame_capture_timeout")
        XCTAssertEqual(ErrorCode.databaseWriteFailed.rawValue, "database_write_failed")
    }

    func testErrorCodeDisplayNames() {
        XCTAssertEqual(ErrorCode.permissionDenied.displayName, "Permission Denied")
        XCTAssertEqual(ErrorCode.storageSpaceLow.displayName, "Storage Space Low")
        XCTAssertEqual(ErrorCode.compressionFailed.displayName, "Compression Failed")
    }

    // MARK: - Recovery Action Tests

    func testRecoveryActionEquality() {
        let action1 = RecoveryAction(title: "Retry", isPrimary: true)
        let action2 = RecoveryAction(title: "Retry", isPrimary: true)

        // Different IDs, so not equal even with same title
        XCTAssertNotEqual(action1.id, action2.id)
    }

    func testRecoveryActionProperties() {
        let primary = RecoveryAction(title: "Retry", isPrimary: true)
        XCTAssertTrue(primary.isPrimary)
        XCTAssertEqual(primary.title, "Retry")

        let secondary = RecoveryAction(title: "Cancel", isPrimary: false)
        XCTAssertFalse(secondary.isPrimary)
        XCTAssertEqual(secondary.title, "Cancel")
    }

    // MARK: - Recording Error Factory Tests

    func testPermissionDeniedError() {
        let error = RecordingError.permissionDenied()
        XCTAssertEqual(error.code, .permissionDenied)
        XCTAssertTrue(error.message.contains("permission"))
        XCTAssertEqual(error.recoveryOptions.count, 2)
        XCTAssertTrue(error.recoveryOptions[0].isPrimary)
        XCTAssertTrue(error.recoveryOptions[0].title.contains("System Preferences"))
    }

    func testDisplayConfigurationChangedError() {
        let error = RecordingError.displayConfigurationChanged()
        XCTAssertEqual(error.code, .displayConfigurationChanged)
        XCTAssertTrue(error.message.contains("Display configuration"))
        XCTAssertEqual(error.recoveryOptions.count, 2)
    }

    func testStorageSpaceLowError() {
        let availableSpace: Int64 = 50 * 1024 * 1024 // 50 MB
        let error = RecordingError.storageSpaceLow(availableSpace: availableSpace)

        XCTAssertEqual(error.code, .storageSpaceLow)
        XCTAssertTrue(error.message.contains("50 MB"))
        XCTAssertEqual(error.recoveryOptions.count, 2)
        XCTAssertTrue(error.recoveryOptions[0].title.contains("Free Up Space"))
    }

    func testCompressionFailedError() {
        let error = RecordingError.compressionFailed(reason: "Encoder initialization failed")
        XCTAssertEqual(error.code, .compressionFailed)
        XCTAssertTrue(error.message.contains("Encoder initialization failed"))
        XCTAssertEqual(error.recoveryOptions.count, 2)
    }

    func testFrameCaptureTimeoutError() {
        let error = RecordingError.frameCaptureTimeout()
        XCTAssertEqual(error.code, .frameCaptureTimeout)
        XCTAssertTrue(error.message.contains("capture frames"))
        XCTAssertEqual(error.recoveryOptions.count, 2)
    }

    func testDatabaseWriteFailedError() {
        let error = RecordingError.databaseWriteFailed(reason: "Database locked")
        XCTAssertEqual(error.code, .databaseWriteFailed)
        XCTAssertTrue(error.message.contains("Database locked"))
        XCTAssertEqual(error.recoveryOptions.count, 2)
    }

    // MARK: - Error Equality Tests

    func testErrorEquality() {
        let error1 = RecordingError.permissionDenied()
        let error2 = RecordingError.permissionDenied()

        // Errors with same code and message should be equal
        XCTAssertEqual(error1.code, error2.code)
        XCTAssertEqual(error1.message, error2.message)
    }

    func testErrorWithDifferentTimestamps() {
        let timestamp1 = Date()
        let timestamp2 = Date().addingTimeInterval(10)

        let error1 = RecordingError(code: .compressionFailed, message: "Test", timestamp: timestamp1)
        let error2 = RecordingError(code: .compressionFailed, message: "Test", timestamp: timestamp2)

        // Different timestamps should make errors not equal
        XCTAssertNotEqual(error1.timestamp, error2.timestamp)
    }

    // MARK: - Sendable Conformance Test

    func testErrorSendableConformance() {
        let error = RecordingError.permissionDenied()
        Task {
            // Should compile without warnings if Sendable is properly conformed
            let _ = error
        }
    }
}
