//
//  BedtimeSettingsView.swift
//  FocusLock
//
//  Settings interface for Bedtime Enforcement
//

import SwiftUI

struct BedtimeSettingsView: View {
    @ObservedObject var enforcer = BedtimeEnforcer.shared

    @State private var selectedHour: Int
    @State private var selectedMinute: Int

    init() {
        let enforcer = BedtimeEnforcer.shared
        _selectedHour = State(initialValue: enforcer.bedtimeHour)
        _selectedMinute = State(initialValue: enforcer.bedtimeMinute)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)

                    Text("Bedtime Enforcement")
                        .font(.custom("Nunito", size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(.black.opacity(0.9))
                }

                Text("Help maintain healthy sleep habits with automated bedtime enforcement")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.bottom, 8)

            Divider()

            // Enable toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Bedtime Enforcement")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.9))

                    Text("Automatically enforce bedtime to ensure you get adequate rest")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $enforcer.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))
                    .onChange(of: enforcer.isEnabled) { _, _ in
                        enforcer.saveSettings()
                    }
            }
            .padding(.vertical, 8)

            if enforcer.isEnabled {
                VStack(alignment: .leading, spacing: 20) {
                    // Bedtime picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bedtime")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.8))

                        HStack(spacing: 16) {
                            // Hour picker
                            HStack(spacing: 8) {
                                Picker("Hour", selection: $selectedHour) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(String(format: "%02d", hour))
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)

                                Text(":")
                                    .font(.custom("Nunito", size: 18))
                                    .fontWeight(.semibold)

                                Picker("Minute", selection: $selectedMinute) {
                                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                                        Text(String(format: "%02d", minute))
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }

                            Text(formatTime(hour: selectedHour, minute: selectedMinute))
                                .font(.custom("Nunito", size: 16))
                                .foregroundColor(.black.opacity(0.7))
                                .padding(.leading, 8)
                        }
                        .onChange(of: selectedHour) { _, newHour in
                            enforcer.updateBedtime(hour: newHour, minute: selectedMinute)
                        }
                        .onChange(of: selectedMinute) { _, newMinute in
                            enforcer.updateBedtime(hour: selectedHour, minute: newMinute)
                        }
                    }

                    // Enforcement mode
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enforcement Mode")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.8))

                        ForEach(BedtimeEnforcer.EnforcementMode.allCases, id: \.self) { mode in
                            HStack {
                                Button(action: {
                                    enforcer.updateEnforcementMode(mode)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: enforcer.enforcementMode == mode ? "circle.fill" : "circle")
                                            .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                                            .font(.system(size: 14))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(mode.displayName)
                                                .font(.custom("Nunito", size: 14))
                                                .fontWeight(.medium)
                                                .foregroundColor(.black.opacity(0.9))

                                            Text(mode.description)
                                                .font(.custom("Nunito", size: 11))
                                                .foregroundColor(.black.opacity(0.6))
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                Spacer()
                            }
                            .padding(12)
                            .background(enforcer.enforcementMode == mode ? Color(hex: "FFE0A5").opacity(0.3) : Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }

                    // Warning time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Warning Time")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.8))

                        HStack {
                            Text("Warn me")
                                .font(.custom("Nunito", size: 13))

                            Picker("", selection: $enforcer.warningMinutes) {
                                Text("5 minutes").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                                Text("60 minutes").tag(60)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)

                            Text("before bedtime")
                                .font(.custom("Nunito", size: 13))
                        }
                        .onChange(of: enforcer.warningMinutes) { _, _ in
                            enforcer.saveSettings()
                        }
                    }

                    // Snooze settings (only for countdown mode)
                    if enforcer.enforcementMode == .countdown {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Snooze Options")
                                .font(.custom("Nunito", size: 14))
                                .fontWeight(.semibold)
                                .foregroundColor(.black.opacity(0.8))

                            Toggle("Allow snoozing", isOn: $enforcer.canSnooze)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))
                                .onChange(of: enforcer.canSnooze) { _, _ in
                                    enforcer.saveSettings()
                                }

                            if enforcer.canSnooze {
                                HStack {
                                    Text("Max snoozes:")
                                        .font(.custom("Nunito", size: 13))

                                    Picker("", selection: $enforcer.maxSnoozes) {
                                        Text("1 time").tag(1)
                                        Text("2 times").tag(2)
                                        Text("3 times").tag(3)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 200)
                                }
                                .onChange(of: enforcer.maxSnoozes) { _, _ in
                                    enforcer.saveSettings()
                                }

                                HStack {
                                    Text("Snooze duration:")
                                        .font(.custom("Nunito", size: 13))

                                    Picker("", selection: $enforcer.snoozeDuration) {
                                        Text("5 minutes").tag(5)
                                        Text("10 minutes").tag(10)
                                        Text("15 minutes").tag(15)
                                        Text("30 minutes").tag(30)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 150)
                                }
                                .onChange(of: enforcer.snoozeDuration) { _, _ in
                                    enforcer.saveSettings()
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Info box
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Why enforce bedtime?")
                                .font(.custom("Nunito", size: 12))
                                .fontWeight(.semibold)
                                .foregroundColor(.black.opacity(0.8))

                            Text("Quality sleep improves focus, memory, creativity, and overall productivity. By enforcing a consistent bedtime, you're investing in better performance and health.")
                                .font(.custom("Nunito", size: 11))
                                .foregroundColor(.black.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

// MARK: - Preview

#Preview {
    BedtimeSettingsView()
        .frame(width: 700, height: 600)
}
