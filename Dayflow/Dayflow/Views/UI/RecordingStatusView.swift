//
//  RecordingStatusView.swift
//  Dayflow
//
//  Created for Story 2.3: Real-Time Recording Status
//

import SwiftUI

/// Main status indicator SwiftUI component
/// Displays recording state with color-coded indicators, icons, and context
struct RecordingStatusView: View {
    @ObservedObject var viewModel: RecordingStatusViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator icon with color
            Image(systemName: viewModel.statusIcon)
                .foregroundColor(viewModel.statusColor)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .animation(.easeInOut(duration: 0.3), value: viewModel.statusIcon)

            VStack(alignment: .leading, spacing: 2) {
                // Status text
                Text(viewModel.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.statusText)

                // Additional context (duration for recording, display count)
                if viewModel.currentState.isRecording {
                    HStack(spacing: 6) {
                        // Duration
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .monospacedDigit()

                        if viewModel.displayCount > 1 {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            Text("\(viewModel.displayCount) displays")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(viewModel.statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Idle state
            RecordingStatusView(viewModel: makeViewModel(state: .idle))
                .previewDisplayName("Idle")

            // Recording single display
            RecordingStatusView(viewModel: makeViewModel(state: .recording(displayCount: 1)))
                .previewDisplayName("Recording (1 display)")

            // Recording multiple displays
            RecordingStatusView(viewModel: makeViewModel(state: .recording(displayCount: 3)))
                .previewDisplayName("Recording (3 displays)")

            // Paused state
            RecordingStatusView(viewModel: makeViewModel(state: .paused))
                .previewDisplayName("Paused")

            // Error state
            RecordingStatusView(viewModel: makeViewModel(
                state: .error(RecordingError.permissionDenied())
            ))
            .previewDisplayName("Error")
        }
        .padding()
        .frame(width: 300)
    }

    @MainActor
    static func makeViewModel(state: RecordingState) -> RecordingStatusViewModel {
        let recorder = ScreenRecorder(autoStart: false)
        let vm = RecordingStatusViewModel(recorder: recorder)
        // Manually set state for preview
        vm.currentState = state
        vm.updateUIProperties(for: state)
        if case .recording = state {
            vm.recordingDuration = 125 // 2:05 for preview
        }
        return vm
    }
}
#endif
