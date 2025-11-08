//
//  NuclearModeSetupView.swift
//  FocusLock
//
//  Double opt-in confirmation and passphrase setup for Nuclear Bedtime mode
//

import SwiftUI

struct NuclearModeSetupView: View {
    @ObservedObject var bedtimeEnforcer = BedtimeEnforcer.shared
    @ObservedObject var killSwitchManager = KillSwitchManager.shared

    @State private var step: SetupStep = .warning
    @State private var understands Consequences = false
    @State private var secondConfirmation = false
    @State private var passphrase: String = ""
    @State private var passphraseConfirm: String = ""
    @State private var errorMessage: String?

    @Environment(\.dismiss) var dismiss

    enum SetupStep {
        case warning
        case confirmation
        case passphraseSetup
        case complete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)

                Text("⚠️ Nuclear Bedtime Mode")
                    .font(.custom("Nunito", size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.black.opacity(0.9))

                Text("This is the most strict enforcement mode")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // Content based on step
            ScrollView {
                switch step {
                case .warning:
                    warningView
                case .confirmation:
                    confirmationView
                case .passphraseSetup:
                    passphraseSetupView
                case .complete:
                    completeView
                }
            }
            .frame(maxHeight: 500)

            Divider()

            // Bottom buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Spacer()

                if step != .complete {
                    Button(step == .passphraseSetup ? "Save & Enable" : "I Understand, Continue") {
                        advanceStep()
                    }
                    .disabled(!canAdvance)
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(canAdvance ? Color.red : Color.gray)
                    .cornerRadius(8)
                }
            }
            .padding(20)
        }
        .frame(width: 600, height: 700)
        .background(Color(hex: "FFF5E6"))
    }

    private var warningView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What Nuclear Mode Does:")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.bold)
                .foregroundColor(.black.opacity(0.9))

            VStack(alignment: .leading, spacing: 12) {
                WarningItem(icon: "🔴", text: "Starts unstoppable countdown at bedtime")
                WarningItem(icon: "🚫", text: "NO in-app cancellation or snooze")
                WarningItem(icon: "🔑", text: "ONLY Kill Switch (⌘⌥⇧Z + passphrase) can stop it")
                WarningItem(icon: "📅", text: "Requires daily re-arming confirmation")
                WarningItem(icon: "💾", text: "Detects unsaved work and sleeps instead of shutting down")
                WarningItem(icon: "⏰", text: "Shuts down your Mac when countdown reaches zero")
            }

            Divider()
                .padding(.vertical, 8)

            Text("⚠️ Important Warnings:")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.bold)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 12) {
                WarningItem(icon: "⚠️", text: "This mode cannot be cancelled from within the app", isWarning: true)
                WarningItem(icon: "⚠️", text: "You must remember your Kill Switch passphrase", isWarning: true)
                WarningItem(icon: "⚠️", text: "Lost passphrase = force restart to bypass", isWarning: true)
                WarningItem(icon: "⚠️", text: "Mode requires daily re-arming to stay active", isWarning: true)
            }

            Toggle("I understand these consequences", isOn: $understandsConsequences)
                .toggleStyle(CheckboxToggleStyle())
                .padding(.top, 16)
        }
        .padding(32)
    }

    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Final Confirmation")
                .font(.custom("Nunito", size: 22))
                .fontWeight(.bold)
                .foregroundColor(.black.opacity(0.9))

            VStack(alignment: .leading, spacing: 16) {
                Text("By enabling Nuclear Mode, you confirm that:")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.7))

                VStack(alignment: .leading, spacing: 10) {
                    ConfirmationItem(text: "You cannot cancel or snooze from within the app")
                    ConfirmationItem(text: "Only the Kill Switch (global hotkey + passphrase) can disable it")
                    ConfirmationItem(text: "You will set a passphrase and are responsible for remembering it")
                    ConfirmationItem(text: "You must re-arm this mode daily for it to stay active")
                    ConfirmationItem(text: "Your Mac will shut down at the scheduled bedtime")
                }

                Divider()
                    .padding(.vertical, 8)

                Text("This is a serious commitment to your sleep health. Are you absolutely sure?")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.top, 8)

                Toggle("Yes, I am absolutely sure and ready to commit", isOn: $secondConfirmation)
                    .toggleStyle(CheckboxToggleStyle())
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }

    private var passphraseSetupView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set Kill Switch Passphrase")
                .font(.custom("Nunito", size: 22))
                .fontWeight(.bold)
                .foregroundColor(.black.opacity(0.9))

            Text("This passphrase is the ONLY way to disable Nuclear Mode once activated. Choose something memorable but secure.")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.7))

            VStack(alignment: .leading, spacing: 12) {
                Text("Passphrase")
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.8))

                SecureField("Enter passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Nunito", size: 14))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Confirm Passphrase")
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.8))

                SecureField("Enter passphrase again", text: $passphraseConfirm)
                    .textFieldStyle(.roundedBorder)
                    .font(.custom("Nunito", size: 14))
            }

            if let error = errorMessage {
                Text(error)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Passphrase Tips:")
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.8))

                Text("• Make it memorable but not too simple")
                Text("• At least 8 characters recommended")
                Text("• Store it securely (not in plain text)")
                Text("• You'll need to type it during countdown to disable")
            }
            .font(.custom("Nunito", size: 12))
            .foregroundColor(.black.opacity(0.6))
            .padding(.top, 8)
        }
        .padding(32)
    }

    private var completeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Nuclear Mode Enabled!")
                .font(.custom("Nunito", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black.opacity(0.9))

            VStack(alignment: .leading, spacing: 16) {
                Text("Next Steps:")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.8))

                VStack(alignment: .leading, spacing: 10) {
                    CompleteItem(icon: "✅", text: "Nuclear Mode is now active")
                    CompleteItem(icon: "🔑", text: "Kill Switch hotkey: ⌘⌥⇧Z + passphrase")
                    CompleteItem(icon: "📅", text: "You'll need to re-arm daily at 9 AM")
                    CompleteItem(icon: "⏰", text: "Bedtime: \(formattedBedtime)")
                }
            }
            .padding(24)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(8)
        }
        .padding(32)
    }

    private var canAdvance: Bool {
        switch step {
        case .warning:
            return understandsConsequences
        case .confirmation:
            return secondConfirmation
        case .passphraseSetup:
            return !passphrase.isEmpty && passphrase == passphraseConfirm && passphrase.count >= 8
        case .complete:
            return false
        }
    }

    private func advanceStep() {
        errorMessage = nil

        switch step {
        case .warning:
            step = .confirmation

        case .confirmation:
            step = .passphraseSetup

        case .passphraseSetup:
            // Validate passphrase
            guard passphrase == passphraseConfirm else {
                errorMessage = "Passphrases do not match"
                return
            }

            guard passphrase.count >= 8 else {
                errorMessage = "Passphrase must be at least 8 characters"
                return
            }

            // Save passphrase to Keychain
            killSwitchManager.setPassphrase(passphrase)

            // Enable Nuclear mode
            bedtimeEnforcer.enforcementMode = .nuclear
            bedtimeEnforcer.nuclearModeConfirmedAt = Date()
            bedtimeEnforcer.saveSettings()

            // Arm for today
            bedtimeEnforcer.armNuclearMode()

            step = .complete

        case .complete:
            break
        }
    }

    private var formattedBedtime: String {
        let hour = bedtimeEnforcer.bedtimeHour
        let minute = bedtimeEnforcer.bedtimeMinute
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

// MARK: - Helper Views

struct WarningItem: View {
    let icon: String
    let text: String
    var isWarning: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 20))

            Text(text)
                .font(.custom("Nunito", size: 13))
                .foregroundColor(isWarning ? .red : .black.opacity(0.8))
        }
    }
}

struct ConfirmationItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))

            Text(text)
                .font(.custom("Nunito", size: 13))
                .foregroundColor(.black.opacity(0.8))
        }
    }
}

struct CompleteItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 16))

            Text(text)
                .font(.custom("Nunito", size: 13))
                .foregroundColor(.black.opacity(0.8))
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? Color.red : Color.gray)
                    .font(.system(size: 18))

                configuration.label
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NuclearModeSetupView()
}
