//
//  KillSwitchPassphraseView.swift
//  FocusLock
//
//  Passphrase entry modal for Kill Switch activation
//

import SwiftUI

struct KillSwitchPassphraseView: View {
    @ObservedObject var killSwitchManager = KillSwitchManager.shared
    @ObservedObject var bedtimeEnforcer = BedtimeEnforcer.shared

    @State private var passphraseInput: String = ""
    @State private var errorMessage: String?
    @State private var isValidating: Bool = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Dark semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)

                    Text("Kill Switch Activated")
                        .font(.custom("Nunito", size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Enter your passphrase to disable Bedtime Enforcement")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // Passphrase field
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Passphrase", text: $passphraseInput)
                        .textFieldStyle(.plain)
                        .font(.custom("Nunito", size: 16))
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .onSubmit {
                            validatePassphrase()
                        }

                    if let error = errorMessage {
                        Text(error)
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.red)
                    }
                }
                .frame(width: 300)

                // Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)

                    Button(action: validatePassphrase) {
                        if isValidating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Disable Enforcement")
                                .font(.custom("Nunito", size: 14))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(passphraseInput.isEmpty || isValidating)
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(passphraseInput.isEmpty ? Color.gray : Color.red)
                    .cornerRadius(8)
                }
            }
            .padding(40)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.95))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }

    private func validatePassphrase() {
        guard !passphraseInput.isEmpty else { return }

        isValidating = true
        errorMessage = nil

        // Validate passphrase
        if killSwitchManager.validatePassphrase(passphraseInput) {
            // Success! Disable bedtime enforcement
            bedtimeEnforcer.disableViaKillSwitch()

            // Close modal
            dismiss()

            // Show success notification
            let notification = NSUserNotification()
            notification.title = "Kill Switch Activated"
            notification.informativeText = "Bedtime enforcement has been disabled."
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        } else {
            // Invalid passphrase
            errorMessage = "Incorrect passphrase. Please try again."
            passphraseInput = ""
            isValidating = false

            // Shake effect or error feedback could go here
        }
    }
}

#Preview {
    KillSwitchPassphraseView()
}
