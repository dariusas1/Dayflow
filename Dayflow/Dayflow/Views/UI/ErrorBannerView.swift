//
//  ErrorBannerView.swift
//  Dayflow
//
//  Created for Story 2.3: Real-Time Recording Status
//

import SwiftUI

/// Error banner component with recovery actions
/// Displays prominent error messages with actionable recovery options
struct ErrorBannerView: View {
    let error: RecordingError
    let onAction: (RecoveryAction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with error icon and dismiss button
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text(error.code.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(error.message)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            // Error metadata (timestamp and code)
            HStack(spacing: 8) {
                Text(formatTimestamp(error.timestamp))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))

                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))

                Text("Code: \(error.code.rawValue)")
                    .font(.system(size: 10, weight: .mono))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Recovery actions
            if !error.recoveryOptions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(error.recoveryOptions, id: \.id) { action in
                        Button(action: { onAction(action) }) {
                            Text(action.title)
                                .font(.system(size: 12, weight: action.isPrimary ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(action.isPrimary ? Color.white : Color.white.opacity(0.2))
                                )
                                .foregroundColor(action.isPrimary ? Color.red : Color.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.9),
                            Color.orange.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ErrorBannerView(
                error: RecordingError.permissionDenied(),
                onAction: { action in
                    print("Action: \(action.title)")
                },
                onDismiss: {
                    print("Dismissed")
                }
            )

            ErrorBannerView(
                error: RecordingError.storageSpaceLow(availableSpace: 50_000_000),
                onAction: { action in
                    print("Action: \(action.title)")
                },
                onDismiss: {
                    print("Dismissed")
                }
            )

            ErrorBannerView(
                error: RecordingError.compressionFailed(reason: "Encoder initialization failed"),
                onAction: { action in
                    print("Action: \(action.title)")
                },
                onDismiss: {
                    print("Dismissed")
                }
            )
        }
        .padding()
        .frame(width: 400)
        .background(Color(.windowBackgroundColor))
    }
}
#endif
