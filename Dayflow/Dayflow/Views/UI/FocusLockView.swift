//
//  FocusLockView.swift
//  FocusLock
//
//  FocusLock main interface for focus session management
//

import SwiftUI

struct FocusLockView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var currentTask: String = ""
    @State private var showingTaskSelection = false
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Focus Lock")
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(Color.black)

                Text("One task, one session, zero friction")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color.gray)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Current Session Status
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(sessionManager.isActive ? (sessionManager.isEmergencyBreakActive ? Color.orange : Color.red) : Color.green)
                        .frame(width: 12, height: 12)

                    Text(sessionManager.isEmergencyBreakActive ? "Emergency Break" : (sessionManager.isActive ? "Focusing" : "Idle"))
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)

                    Spacer()

                    if sessionManager.isActive && !sessionManager.isEmergencyBreakActive {
                        Text(sessionManager.sessionDurationFormatted)
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.gray)
                    }
                }

                // Emergency Break Countdown
                if sessionManager.isEmergencyBreakActive {
                    EmergencyBreakView()
                }

                if !currentTask.isEmpty && !sessionManager.isEmergencyBreakActive {
                    Text("Current Task: \(currentTask)")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(Color.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Control Buttons
            VStack(spacing: 12) {
                if !sessionManager.isActive {
                    Button(action: {
                        showingTaskSelection = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start Focus")
                        }
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(currentTask.isEmpty)
                } else {
                    HStack(spacing: 12) {
                        EmergencyBreakButton()

                        Button(action: {
                            sessionManager.endSession()
                        }) {
                            HStack {
                                Image(systemName: "stop.circle")
                                Text("End Session")
                            }
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Button(action: {
                    showingSettings = true
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Spacer()

            // Session Summary (if available)
            if let summary = sessionManager.lastSessionSummary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Session")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(Color.gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration: \(summary.durationFormatted)")
                        Text("Task: \(summary.taskName)")
                        Text("Completed: \(summary.isCompleted ? "✅ Yes" : "❌ No")")
                    }
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(Color.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingTaskSelection) {
            TaskSelectionView(
                selectedTask: $currentTask,
                isPresented: $showingTaskSelection
            )
        }
        .sheet(isPresented: $showingSettings) {
            FocusLockSettingsView(isPresented: $showingSettings)
        }
    }
}

// Task Selection View
struct TaskSelectionView: View {
    @Binding var selectedTask: String
    @Binding var isPresented: Bool
    @State private var customTask: String = ""

    private let recentTasks = [
        "Write documentation",
        "Code review",
        "Debug issue",
        "Design meeting prep",
        "Email processing"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Task")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color.black)

            VStack(spacing: 12) {
                Text("Recent Tasks")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(Color.gray)

                ForEach(recentTasks, id: \.self) { task in
                    Button(action: {
                        selectedTask = task
                        isPresented = false
                    }) {
                        HStack {
                            Text(task)
                                .font(.custom("Nunito", size: 14))
                                .foregroundColor(Color.black)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Task")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(Color.gray)

                    TextField("Enter task name", text: $customTask)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.custom("Nunito", size: 14))
                }

                Button(action: {
                    if !customTask.isEmpty {
                        selectedTask = customTask
                        isPresented = false
                    }
                }) {
                    Text("Start Custom Task")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(customTask.isEmpty)
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

// Settings View
struct FocusLockSettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var focusLockSettings = FocusLockSettingsManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Focus Lock Settings")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color.black)

            VStack(alignment: .leading, spacing: 16) {
                // Permissions Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permissions")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color.black)

                    PermissionStatusRow(
                        title: "Accessibility",
                        isGranted: permissionsManager.hasAccessibilityPermission
                    )

                    PermissionStatusRow(
                        title: "Screen Recording",
                        isGranted: permissionsManager.hasScreenRecordingPermission
                    )

                    PermissionStatusRow(
                        title: "Screen Time",
                        isGranted: permissionsManager.hasScreenTimePermission
                    )
                }

                // Quick Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Settings")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color.black)

                    HStack {
                        Text("Emergency Break Duration")
                        Spacer()
                        Text(focusLockSettings.emergencyBreakDurationFormatted)
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.gray)
                    }
                }

                // Autostart Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Autostart")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color.black)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch FocusLock automatically")
                                .font(.custom("Nunito", size: 14))
                                .foregroundColor(Color.primary)
                            Text(focusLockSettings.autostartStatusDescription)
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(Color.gray)
                        }

                        Spacer()

                        Button(action: {
                            let success = focusLockSettings.toggleAutostart()
                            if success {
                                focusLockSettings.refreshAutostartStatus()
                            }
                        }) {
                            Text(focusLockSettings.isAutostartEnabled ? "Disable" : "Enable")
                                .font(.custom("Nunito", size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(focusLockSettings.isAutostartEnabled ? Color.red : Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            Spacer()

            Button(action: {
                isPresented = false
            }) {
                Text("Done")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(Color.black)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isGranted ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(isGranted ? "Granted" : "Required")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(isGranted ? Color.green : Color.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    FocusLockView()
}