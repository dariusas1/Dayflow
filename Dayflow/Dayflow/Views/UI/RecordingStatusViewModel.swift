//
//  RecordingStatusViewModel.swift
//  Dayflow
//
//  Created for Story 2.3: Real-Time Recording Status
//

import Foundation
import SwiftUI
import Combine
import AppKit

/// ViewModel for recording status UI state management
/// Subscribes to ScreenRecorder.statusUpdates AsyncStream and transforms state to UI-friendly models
@MainActor
final class RecordingStatusViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentState: RecordingState = .idle
    @Published var statusColor: Color = .gray
    @Published var statusIcon: String = "circle.fill"
    @Published var statusText: String = "Idle"
    @Published var displayCount: Int = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorBanner: RecordingError?
    @Published var showErrorBanner: Bool = false

    // MARK: - Private Properties

    private let recorder: ScreenRecorder
    private var statusTask: Task<Void, Never>?
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Initialization

    init(recorder: ScreenRecorder) {
        self.recorder = recorder
        subscribeToStatusUpdates()
    }

    deinit {
        statusTask?.cancel()
        durationTimer?.invalidate()
    }

    // MARK: - Status Subscription

    private func subscribeToStatusUpdates() {
        statusTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            for await recorderState in self.recorder.statusUpdates {
                // Convert RecorderState to RecordingState
                let newState = RecordingState.from(recorderState: recorderState)
                self.updateState(newState)
            }
        }
    }

    // MARK: - State Updates

    private func updateState(_ newState: RecordingState) {
        currentState = newState
        updateUIProperties(for: newState)

        // Save state to persistence (Story 2.3: AC 2.3.4)
        saveCurrentState()

        // Handle recording duration tracking
        switch newState {
        case .recording:
            startDurationTracking()
        case .idle, .error, .stopping:
            stopDurationTracking()
        case .paused:
            pauseDurationTracking()
        case .initializing:
            break
        }
    }

    internal func updateUIProperties(for state: RecordingState) {
        switch state {
        case .idle:
            statusColor = .gray
            statusIcon = "circle.fill"
            statusText = "Idle"
            displayCount = 0
            errorBanner = nil
            showErrorBanner = false

        case .initializing:
            statusColor = .blue
            statusIcon = "circle.dotted"
            statusText = "Starting..."
            errorBanner = nil
            showErrorBanner = false

        case .recording(let count):
            statusColor = .green
            statusIcon = "record.circle.fill"
            statusText = count > 1 ? "Recording \(count) displays" : "Recording"
            displayCount = count
            errorBanner = nil
            showErrorBanner = false

        case .paused:
            statusColor = .yellow
            statusIcon = "pause.circle.fill"
            statusText = "Paused"
            // Keep display count and duration from before pause

        case .error(let error):
            statusColor = .red
            statusIcon = "exclamationmark.triangle.fill"
            statusText = "Error: \(error.code.displayName)"
            errorBanner = error
            showErrorBanner = true

        case .stopping:
            statusColor = .orange
            statusIcon = "stop.circle.fill"
            statusText = "Stopping..."
            errorBanner = nil
            showErrorBanner = false
        }
    }

    // MARK: - Duration Tracking

    private func startDurationTracking() {
        guard recordingStartTime == nil else { return }

        recordingStartTime = Date()
        recordingDuration = 0

        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDuration()
            }
        }
    }

    private func pauseDurationTracking() {
        durationTimer?.invalidate()
        durationTimer = nil
        // Keep recordingStartTime for resumption
    }

    private func stopDurationTracking() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartTime = nil
        recordingDuration = 0
    }

    private func updateDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }

    // MARK: - Formatted Duration

    var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Recovery Actions

    func requestPermissions() {
        // Open System Preferences to Screen Recording permissions
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func retryRecording() {
        // Dismiss error banner and attempt to restart recording
        dismissErrorBanner()

        Task { @MainActor in
            AppState.shared.isRecording = true
        }
    }

    func openSystemPreferences() {
        // Open main System Preferences
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Preferences.app"))
    }

    func dismissErrorBanner() {
        showErrorBanner = false
        errorBanner = nil
    }

    func executeRecoveryAction(_ action: RecoveryAction) {
        // Execute recovery action based on title
        // This is a simple string-based dispatch - could be enhanced with enum-based actions
        switch action.title.lowercased() {
        case let title where title.contains("system preferences"):
            requestPermissions()
        case let title where title.contains("retry"):
            retryRecording()
        case let title where title.contains("dismiss"):
            dismissErrorBanner()
        case let title where title.contains("free up space"):
            openSystemPreferences()
        default:
            dismissErrorBanner()
        }
    }
}
