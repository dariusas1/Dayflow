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
        FlowingGradientBackground()
            .overlay(
                VStack(spacing: 0) {
                    // Header with glassmorphism
                    GlassmorphismContainer(style: .main) {
                        VStack(spacing: DesignSpacing.sm) {
                            Text("Focus Lock")
                                .font(.custom(DesignTypography.headingFont, size: DesignTypography.title1))
                                .foregroundColor(DesignColors.primaryText)

                            Text("One task, one session, zero friction")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                .foregroundColor(DesignColors.secondaryText)
                        }
                        .padding(DesignSpacing.lg)
                    }

            // Current Session Status
                    GlassmorphismContainer(style: .card) {
                        VStack(spacing: DesignSpacing.md) {
                            HStack {
                                Circle()
                                    .fill(sessionManager.isActive ? (sessionManager.isEmergencyBreakActive ? DesignColors.warningYellow : DesignColors.errorRed) : DesignColors.successGreen)
                                    .frame(width: 12, height: 12)

                                Text(sessionManager.isEmergencyBreakActive ? "Emergency Break" : (sessionManager.isActive ? "Focusing" : "Idle"))
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColors.primaryText)

                                Spacer()

                                if sessionManager.isActive && !sessionManager.isEmergencyBreakActive {
                                    Text(sessionManager.sessionDurationFormatted)
                                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                        .foregroundColor(DesignColors.secondaryText)
                                }
                            }

                            // Emergency Break Countdown
                            if sessionManager.isEmergencyBreakActive {
                                EmergencyBreakView()
                            }

                            if !currentTask.isEmpty && !sessionManager.isEmergencyBreakActive {
                                Text("Current Task: \(currentTask)")
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                    .foregroundColor(DesignColors.secondaryText)
                                    .padding(.horizontal, DesignSpacing.md)
                                    .padding(.vertical, DesignSpacing.sm)
                                    .background(DesignColors.glassBackground)
                                    .cornerRadius(DesignRadius.medium)
                            }
                        }
                        .padding(DesignSpacing.lg)
                    }
                    .padding(.horizontal, DesignSpacing.lg)
                    .padding(.bottom, DesignSpacing.lg)

            // Control Buttons
            VStack(spacing: DesignSpacing.md) {
                if !sessionManager.isActive {
                    UnifiedButton.primary(
                        "Start Focus",
                        size: .large,
                        disabled: currentTask.isEmpty,
                        action: {
                            showingTaskSelection = true
                        }
                    )
                    .opacity(currentTask.isEmpty ? 0.6 : 1.0)
                } else {
                    HStack(spacing: DesignSpacing.md) {
                        EmergencyBreakButton()

                        UnifiedButton.secondary(
                            "End Session",
                            size: .medium,
                            action: {
                                sessionManager.endSession()
                            }
                        )
                    }
                }

                UnifiedButton.ghost(
                    "Settings",
                    size: .medium,
                    action: {
                        showingSettings = true
                    }
                )
            }
            .padding(.horizontal, DesignSpacing.lg)
            .padding(.bottom, DesignSpacing.lg)

            Spacer()

            // Session Summary (if available)
            if let summary = sessionManager.lastSessionSummary {
                UnifiedCard(style: .minimal, size: .medium) {
                    VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                        Text("Last Session")
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                            .fontWeight(.medium)
                            .foregroundColor(DesignColors.secondaryText)

                        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                            Text("Duration: \(summary.durationFormatted)")
                            Text("Task: \(summary.taskName)")
                            Text("Completed: \(summary.isCompleted ? "✅ Yes" : "❌ No")")
                        }
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.secondaryText)
                    }
                }
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.bottom, DesignSpacing.lg)
            }
        }
        )
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
        FlowingGradientBackground()
            .overlay(
                VStack(spacing: DesignSpacing.xl) {
                    // Header
                    GlassmorphismContainer(style: .main) {
                        Text("Select Task")
                            .font(.custom(DesignTypography.headingFont, size: DesignTypography.title2))
                            .foregroundColor(DesignColors.primaryText)
                    }
                    .padding(.horizontal, DesignSpacing.xl)
                    .padding(.top, DesignSpacing.xl)

                    VStack(spacing: DesignSpacing.lg) {
                        // Recent Tasks Section
                        UnifiedCard(style: .standard, size: .large) {
                            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                                Text("Recent Tasks")
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColors.primaryText)

                                VStack(spacing: DesignSpacing.sm) {
                                    ForEach(recentTasks, id: \.self) { task in
                                        Button(action: {
                                            selectedTask = task
                                            isPresented = false
                                        }) {
                                            HStack {
                                                Text(task)
                                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                                    .foregroundColor(DesignColors.primaryText)
                                                Spacer()
                                                Image(systemName: "arrow.right.circle")
                                                    .foregroundColor(DesignColors.primaryOrange)
                                            }
                                            .padding(DesignSpacing.md)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }

                        // Custom Task Section
                        UnifiedCard(style: .standard, size: .large) {
                            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                                Text("Custom Task")
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColors.primaryText)

                                UnifiedTextField(
                                    "Enter task name",
                                    text: $customTask,
                                    style: .standard
                                )

                                UnifiedButton.primary(
                                    "Start Custom Task",
                                    size: .medium,
                                    disabled: customTask.isEmpty,
                                    action: {
                                        selectedTask = customTask
                                        isPresented = false
                                    }
                                )
                                .opacity(customTask.isEmpty ? 0.6 : 1.0)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(DesignSpacing.lg)
            )
            .frame(width: 450, height: 600)
    }
}

// Settings View
struct FocusLockSettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var focusLockSettings = FocusLockSettingsManager.shared

    var body: some View {
        FlowingGradientBackground()
            .overlay(
                VStack(spacing: DesignSpacing.xl) {
                    // Header
                    GlassmorphismContainer(style: .main) {
                        Text("Focus Lock Settings")
                            .font(.custom(DesignTypography.headingFont, size: DesignTypography.title2))
                            .foregroundColor(DesignColors.primaryText)
                    }
                    .padding(.horizontal, DesignSpacing.xl)
                    .padding(.top, DesignSpacing.xl)

                    VStack(spacing: DesignSpacing.lg) {
                        // Permissions Status
                        UnifiedCard(style: .standard, size: .large) {
                            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                                Text("Permissions")
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColors.primaryText)

                                VStack(spacing: DesignSpacing.sm) {
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
                            }
                        }

                        // Quick Settings
                        UnifiedCard(style: .standard, size: .medium) {
                            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                                Text("Quick Settings")
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColors.primaryText)

                                HStack {
                                    Text("Emergency Break Duration")
                                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                        .foregroundColor(DesignColors.primaryText)
                                    Spacer()
                                    Text(focusLockSettings.emergencyBreakDurationFormatted)
                                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                        .foregroundColor(DesignColors.secondaryText)
                                }
                            }
                        }

                        // Autostart Settings
                        UnifiedCard(style: .standard, size: .large) {
                            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                                Text("Autostart")
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignColors.primaryText)

                                HStack {
                                    VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                                        Text("Launch FocusLock automatically")
                                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                            .foregroundColor(DesignColors.primaryText)
                                        Text(focusLockSettings.autostartStatusDescription)
                                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                            .foregroundColor(DesignColors.secondaryText)
                                    }

                                    Spacer()

                                    UnifiedButton.secondary(
                                        focusLockSettings.isAutostartEnabled ? "Disable" : "Enable",
                                        size: .small,
                                        action: {
                                            let success = focusLockSettings.toggleAutostart()
                                            if success {
                                                focusLockSettings.refreshAutostartStatus()
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }

                    Spacer()

                    UnifiedButton.primary(
                        "Done",
                        size: .medium,
                        action: {
                            isPresented = false
                        }
                    )
                    .padding(.horizontal, DesignSpacing.xl)
                    .padding(.bottom, DesignSpacing.xl)
                }
            )
            .frame(width: 450, height: 600)
    }
}

struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                .foregroundColor(DesignColors.primaryText)

            Spacer()

            HStack(spacing: DesignSpacing.xs) {
                Circle()
                    .fill(isGranted ? DesignColors.successGreen : DesignColors.errorRed)
                    .frame(width: 8, height: 8)

                Text(isGranted ? "Granted" : "Required")
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .fontWeight(.medium)
                    .foregroundColor(isGranted ? DesignColors.successGreen : DesignColors.errorRed)
            }
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.vertical, DesignSpacing.sm)
        .background(DesignColors.glassBackground)
        .cornerRadius(DesignRadius.medium)
    }
}

#Preview {
    FocusLockView()
}