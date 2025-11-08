//
//  FocusSessionWidget.swift
//  FocusLock
//
//  Dashboard widget showing current focus session status, mode, and progress
//

import SwiftUI

struct FocusSessionWidget: View {
    @StateObject private var focusManager = FocusSessionManager.shared
    @StateObject private var proactiveEngine = ProactiveCoachEngine.shared
    @StateObject private var todoEngine = TodoExtractionEngine.shared
    
    @State private var contextSwitchCount: Int = 0
    @State private var recommendedAction: String = "Start an Anchor Block on your P0 task"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Focus Session")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                if focusManager.isInSession {
                    modeBadge
                }
            }
            
            if focusManager.isInSession, let session = $focusManager.currentSession.wrappedValue {
                // Active session view
                activeSessionView(session: session)
            } else {
                // No active session
                inactiveStateView
            }
            
            Divider()
            
            // Footer stats
            footerStats
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .task {
            await updateContextSwitches()
            await updateRecommendedAction()
        }
    }
    
    // MARK: - Subviews
    
    private var modeBadge: some View {
        Group {
            if let session = $focusManager.currentSession.wrappedValue {
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForMode(session.mode))
                        .frame(width: 8, height: 8)
                    Text(session.mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorForMode(session.mode))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(colorForMode(session.mode).opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
    
    private func activeSessionView(session: LegacyFocusSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Active task (if any)
            if let taskId = session.taskId,
               let task = todoEngine.extractedTodos.first(where: { $0.id == taskId }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Task")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForPriority(task.priority))
                            .frame(width: 8, height: 8)
                        Text(task.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                }
            } else if session.mode == .anchor {
                Text("No task assigned")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formatDuration(focusManager.elapsedTime))
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(formatDuration(focusManager.remainingTime))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: focusManager.sessionProgress)
                    .progressViewStyle(.linear)
                    .tint(colorForMode(session.mode))
            }
            
            // Quick actions
            HStack(spacing: 8) {
                Spacer()

                Button(action: {
                    focusManager.endSession()
                }) {
                    Label("End Session", systemImage: "stop.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var inactiveStateView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No active focus session")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // Recommended action
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommended:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(recommendedAction)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(Color(.systemBlue).opacity(0.1))
            .cornerRadius(8)
            
            // Quick start buttons
            HStack(spacing: 8) {
                Button(action: {
                    focusManager.startAnchorBlock(taskId: nil)
                }) {
                    Label("Anchor (60m)", systemImage: "target")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    focusManager.startTriageBlock()
                }) {
                    Label("Triage (30m)", systemImage: "tray")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    focusManager.startBreak()
                }) {
                    Label("Break (15m)", systemImage: "cup.and.saucer")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var footerStats: some View {
        HStack(spacing: 20) {
            // Context switches today
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(contextSwitchCount)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Switches today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // P0 tasks
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    let p0Count = todoEngine.getTodos(status: .pending, priority: .p0).count
                    Text("\(p0Count)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("P0 tasks")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForMode(_ mode: FocusMode) -> Color {
        switch mode {
        case .anchor:
            return .green
        case .triage:
            return .orange
        case .break_:
            return .blue
        }
    }
    
    private func colorForPriority(_ priority: TodoPriority) -> Color {
        switch priority {
        case .p0:
            return .red
        case .p1:
            return .orange
        case .p2:
            return .blue
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func updateContextSwitches() async {
        // Get context switches from last 8 hours
        let eightHoursAgo = Date().addingTimeInterval(-8 * 3600)
        do {
            let switches = try StorageManager.shared.fetchContextSwitches(since: eightHoursAgo)
            contextSwitchCount = switches.count
        } catch {
            contextSwitchCount = 0
        }
    }
    
    private func updateRecommendedAction() async {
        let p0Tasks = todoEngine.getTodos(status: .pending, priority: .p0)
        
        if !p0Tasks.isEmpty {
            let task = p0Tasks.first!
            recommendedAction = "Start Anchor Block on: \(task.title)"
        } else {
            let p1Tasks = todoEngine.getTodos(status: .pending, priority: .p1)
            if !p1Tasks.isEmpty {
                recommendedAction = "Start Anchor Block on: \(p1Tasks.first!.title)"
            } else {
                recommendedAction = "No urgent tasks. Consider planning your day or taking a break."
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FocusSessionWidget()
            .frame(width: 400)
        
        Divider()
        
        Text("Example widget for dashboard")
            .foregroundColor(.secondary)
    }
    .padding()
}

