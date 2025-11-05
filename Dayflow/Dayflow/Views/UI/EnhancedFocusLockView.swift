//
//  EnhancedFocusLockView.swift
//  Dayflow
//
//  Enhanced FocusLock interface with modern widget-based design
//

import SwiftUI

struct EnhancedFocusLockView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var currentTask: String = ""
    @State private var showingSettings = false
    @State private var showingSuggestedTasks = false
    @State private var windowWidth: CGFloat = 1200
    
    // Animation states
    @State private var widgetOpacities: [String: Double] = [:]
    @State private var widgetOffsets: [String: CGFloat] = [:]
    
    // Cached stats to avoid main thread I/O
    @State private var todayTotalTime: String = "0m"
    @State private var todaySessionCount: Int = 0
    @State private var todayBreakCount: Int = 0
    
    private var columns: [GridItem] {
        // Responsive breakpoints matching Dashboard
        if windowWidth > 1400 {
            return [GridItem(.adaptive(minimum: 350), spacing: 18)]
        } else if windowWidth > 1000 {
            return [GridItem(.adaptive(minimum: 300), spacing: 16)]
        } else {
            return [GridItem(.flexible(), spacing: 12)]
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Widget Grid
                    LazyVGrid(columns: columns, spacing: windowWidth > 1000 ? 18 : 12) {
                        // Current Session Widget (only when active)
                        if sessionManager.currentState != .idle {
                            currentSessionWidget
                                .id("session")
                        }
                        
                        // Quick Actions Widget
                        quickActionsWidget
                            .id("actions")
                        
                        // Real-time Task Detection
                        if let detectedTask = getDetectedTask() {
                            detectedTaskWidget(task: detectedTask)
                                .id("detected")
                        }
                        
                        // Performance Metrics Widget
                        performanceMetricsWidget
                            .id("performance")
                        
                        // Session History Widget
                        sessionHistoryWidget
                            .id("history")
                        
                        // Statistics Widget
                        statisticsWidget
                            .id("stats")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color.white
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "FFF1D3").opacity(0.1), location: 0.0),
                            .init(color: Color(hex: "FFE0A5").opacity(0.05), location: 0.5),
                            .init(color: .white, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .onAppear {
                windowWidth = geometry.size.width
                initializeAnimations()
                loadTodayStatsAsync()
            }
            .onChange(of: geometry.size.width) { oldValue, newValue in
                windowWidth = newValue
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Lock")
                .font(.custom("InstrumentSerif-Regular", size: 36))
                .foregroundColor(.black)
            
            Text("One task, one session, zero friction")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
        }
    }
    
    // MARK: - Current Session Widget
    
    private var currentSessionWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Widget header
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(sessionStateColor)
                
                Text("Active Session")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Spacer()
                
                // Session state badge
                Text(sessionStateText)
                    .font(.custom("Nunito", size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(sessionStateColor.opacity(0.2))
                    .foregroundColor(sessionStateColor)
                    .cornerRadius(6)
            }
            
            if let session = sessionManager.currentSession {
                // Task name
                if !session.taskName.isEmpty {
                    Text(session.taskName)
                        .font(.custom("InstrumentSerif-Regular", size: 22))
                        .foregroundColor(.black.opacity(0.9))
                        .lineLimit(2)
                }
                
                // Timer with gradient accent
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.6))
                        
                        Text(formatDuration(Date().timeIntervalSince(session.startTime)))
                            .font(.custom("Nunito", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.black.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // End session button with gradient
                    Button(action: endSession) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 14))
                            Text("End Session")
                                .font(.custom("Nunito", size: 14))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            // Orange gradient left accent
            HStack {
                LinearGradient(
                    colors: [
                        Color(hex: "FF8904"),
                        Color(hex: "FFE0A5")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 4)
                .cornerRadius(2, corners: [.topLeft, .bottomLeft])
                
                Spacer()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(angularGradientBorder, lineWidth: 1.5)
        )
        .opacity(widgetOpacities["session"] ?? 0)
        .offset(y: widgetOffsets["session"] ?? -20)
    }
    
    // MARK: - Quick Actions Widget
    
    private var quickActionsWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                
                Text("Quick Actions")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            
            VStack(spacing: 12) {
                // Start Focus Action
                QuickActionButton(
                    title: "Start Focus",
                    icon: "play.circle.fill",
                    gradientColors: [Color.green, Color.green.opacity(0.7)],
                    isDisabled: sessionManager.currentState != .idle,
                    action: startFocusSession
                )
                
                HStack(spacing: 12) {
                    // Take Break Action
                    QuickActionButton(
                        title: "Take Break",
                        icon: "pause.circle.fill",
                        gradientColors: [Color(hex: "FF8904"), Color(hex: "FFE0A5")],
                        isDisabled: sessionManager.currentState != .active,
                        action: takeBreak
                    )
                    
                    // View Todos Action
                    NavigationLink(destination: SmartTodoView()) {
                        QuickActionButtonContent(
                            title: "View Todos",
                            icon: "checklist",
                            gradientColors: [Color.purple, Color.purple.opacity(0.7)]
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Settings Action
                QuickActionButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    gradientColors: [Color(red: 0.62, green: 0.44, blue: 0.36), Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.7)],
                    isDisabled: false,
                    action: { showingSettings = true }
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(angularGradientBorder, lineWidth: 1.5)
        )
        .opacity(widgetOpacities["actions"] ?? 0)
        .offset(y: widgetOffsets["actions"] ?? -20)
    }
    
    // MARK: - Detected Task Widget
    
    private func detectedTaskWidget(task: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                
                Text("Detected Activity")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Spacer()
            }
            
            Text(task)
                .font(.custom("Nunito", size: 15))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(3)
            
            Button(action: { currentTask = task }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                    Text("Use This Task")
                        .font(.custom("Nunito", size: 13))
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.purple.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .opacity(widgetOpacities["detected"] ?? 0)
        .offset(y: widgetOffsets["detected"] ?? -20)
    }
    
    // MARK: - Performance Metrics Widget
    
    private var performanceMetricsWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gauge.high")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                
                Text("Performance")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            
            VStack(spacing: 14) {
                // CPU Usage
                MetricProgressBar(
                    label: "CPU",
                    value: getCPUUsage(),
                    maxValue: 100,
                    unit: "%",
                    color: Color.blue
                )
                
                // Memory Usage
                MetricProgressBar(
                    label: "Memory",
                    value: getMemoryUsage(),
                    maxValue: 1024,
                    unit: "MB",
                    color: Color.purple
                )
                
                // Focus Streak with gradient accent
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus Streak")
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.6))
                        
                        Text("\(getFocusStreak()) sessions")
                            .font(.custom("Nunito", size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(.black.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF8904"), Color(hex: "FFE0A5")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(angularGradientBorder, lineWidth: 1.5)
        )
        .opacity(widgetOpacities["performance"] ?? 0)
        .offset(y: widgetOffsets["performance"] ?? -20)
    }
    
    // MARK: - Session History Widget
    
    private var sessionHistoryWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                
                Text("Recent Sessions")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            
            VStack(spacing: 8) {
                ForEach(getRecentSessions(), id: \.id) { session in
                    SessionHistoryRowEnhanced(session: session)
                }
            }
            
            if getRecentSessions().isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No sessions yet")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(angularGradientBorder, lineWidth: 1.5)
        )
        .opacity(widgetOpacities["history"] ?? 0)
        .offset(y: widgetOffsets["history"] ?? -20)
    }
    
    // MARK: - Statistics Widget
    
    private var statisticsWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                
                Text("Today's Stats")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            
            VStack(spacing: 12) {
                StatMetricCard(
                    title: "Total Time",
                    value: todayTotalTime,
                    icon: "clock.fill",
                    gradientColors: [Color.blue, Color.blue.opacity(0.6)]
                )
                
                HStack(spacing: 12) {
                    StatMetricCard(
                        title: "Sessions",
                        value: "\(todaySessionCount)",
                        icon: "list.bullet",
                        gradientColors: [Color.green, Color.green.opacity(0.6)]
                    )
                    
                    StatMetricCard(
                        title: "Breaks",
                        value: "\(todayBreakCount)",
                        icon: "pause.fill",
                        gradientColors: [Color(hex: "FF8904"), Color(hex: "FFE0A5")]
                    )
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(angularGradientBorder, lineWidth: 1.5)
        )
        .opacity(widgetOpacities["stats"] ?? 0)
        .offset(y: widgetOffsets["stats"] ?? -20)
    }
    
    // MARK: - Helper Components
    
    private var angularGradientBorder: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Color(hex: "FFF1D3").opacity(0.3), location: 0.00),
                .init(color: Color(hex: "FF8904").opacity(0.4), location: 0.25),
                .init(color: .white.opacity(0.2), location: 0.50),
                .init(color: Color(hex: "FFE0A5").opacity(0.35), location: 0.75),
                .init(color: Color(hex: "FFF1D3").opacity(0.3), location: 1.00)
            ],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }
    
    // MARK: - Animation Setup
    
    private func initializeAnimations() {
        let widgetIds = ["session", "actions", "detected", "performance", "history", "stats"]
        
        for (index, id) in widgetIds.enumerated() {
            widgetOpacities[id] = 0
            widgetOffsets[id] = -20
            
            withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.1)) {
                widgetOpacities[id] = 1
                widgetOffsets[id] = 0
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var sessionStateColor: Color {
        switch sessionManager.currentState {
        case .idle: return .gray
        case .active: return .green
        case .arming: return .blue
        case .break: return Color(hex: "FF8904")
        case .ended: return .purple
        }
    }
    
    private var sessionStateText: String {
        switch sessionManager.currentState {
        case .idle: return "Idle"
        case .active: return "Active"
        case .arming: return "Starting"
        case .break: return "Break"
        case .ended: return "Ended"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func getDetectedTask() -> String? {
        if let task = DetectorFuser.shared.getStabilizedTask(), !task.isEmpty {
            return task
        }
        return nil
    }
    
    private func getCPUUsage() -> Double {
        return 12.5 // Placeholder
    }
    
    private func getMemoryUsage() -> Double {
        let processInfo = ProcessInfo.processInfo
        return Double(processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0 * 100
    }
    
    private func getFocusStreak() -> Int {
        return 5 // Placeholder
    }
    
    private func getRecentSessions() -> [FocusSession] {
        return Array(SessionLogger.shared.loadSessions().prefix(5))
    }
    
    /// Load today's stats asynchronously to avoid blocking the main thread
    private func loadTodayStatsAsync() {
        Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let sessions = SessionLogger.shared.loadSessions()
            
            let todaySessions = sessions.filter {
                calendar.isDate($0.startTime, inSameDayAs: today)
            }
            
            // Calculate total time
            let total = todaySessions.reduce(0.0) { $0 + $1.duration }
            let hours = Int(total) / 3600
            let minutes = (Int(total) % 3600) / 60
            
            let timeString: String
            if hours > 0 {
                timeString = "\(hours)h \(minutes)m"
            } else {
                timeString = "\(minutes)m"
            }
            
            // Calculate session count
            let sessionCount = todaySessions.count
            
            // Calculate break count (placeholder for now)
            let breakCount = 3
            
            // Update UI on main thread
            await MainActor.run {
                self.todayTotalTime = timeString
                self.todaySessionCount = sessionCount
                self.todayBreakCount = breakCount
            }
        }
    }
    
    // MARK: - Actions
    
    private func startFocusSession() {
        sessionManager.startSession(taskName: currentTask.isEmpty ? "Focus Session" : currentTask)
    }
    
    private func endSession() {
        sessionManager.endSession()
    }
    
    private func takeBreak() {
        if let session = sessionManager.currentSession {
            EmergencyBreakManager.shared.startEmergencyBreak(session: session)
        }
    }
}

// MARK: - Quick Action Button Components

struct QuickActionButton: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(title: title, icon: icon, gradientColors: gradientColors)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct QuickActionButtonContent: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.custom("Nunito", size: 15))
                .fontWeight(.medium)
                .foregroundColor(.black.opacity(0.9))
            
            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Metric Progress Bar

struct MetricProgressBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.6))
                
                Spacer()
                
                Text(String(format: "%.1f%@", value, unit))
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.9))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(min(value / maxValue, 1.0)), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Session History Row Enhanced

struct SessionHistoryRowEnhanced: View {
    let session: FocusSession
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Gradient dot indicator
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.taskName.isEmpty ? "Focus Session" : session.taskName)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.9))
                    .lineLimit(1)
                
                Text(formatSessionTime(session))
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
            
            Text(formatSessionDuration(session))
                .font(.custom("Nunito", size: 13))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isHovered ? Color.black.opacity(0.03) : Color.black.opacity(0.01))
        .cornerRadius(10)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatSessionTime(_ session: FocusSession) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }
    
    private func formatSessionDuration(_ session: FocusSession) -> String {
        let minutes = Int(session.duration) / 60
        if minutes > 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Metric Card

struct StatMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .fontWeight(.bold)
                .foregroundColor(.black.opacity(0.9))
            
            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: gradientColors.map { $0.opacity(0.08) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.2) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - RoundedCorner Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        self.init()
        
        let topLeft = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        
        if corners.contains(.topLeft) {
            move(to: CGPoint(x: topLeft.x + cornerRadii.width, y: topLeft.y))
        } else {
            move(to: topLeft)
        }
        
        if corners.contains(.topRight) {
            line(to: CGPoint(x: topRight.x - cornerRadii.width, y: topRight.y))
            curve(to: CGPoint(x: topRight.x, y: topRight.y + cornerRadii.height),
                  controlPoint1: topRight,
                  controlPoint2: topRight)
        } else {
            line(to: topRight)
        }
        
        if corners.contains(.bottomRight) {
            line(to: CGPoint(x: bottomRight.x, y: bottomRight.y - cornerRadii.height))
            curve(to: CGPoint(x: bottomRight.x - cornerRadii.width, y: bottomRight.y),
                  controlPoint1: bottomRight,
                  controlPoint2: bottomRight)
        } else {
            line(to: bottomRight)
        }
        
        if corners.contains(.bottomLeft) {
            line(to: CGPoint(x: bottomLeft.x + cornerRadii.width, y: bottomLeft.y))
            curve(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y - cornerRadii.height),
                  controlPoint1: bottomLeft,
                  controlPoint2: bottomLeft)
        } else {
            line(to: bottomLeft)
        }
        
        if corners.contains(.topLeft) {
            line(to: CGPoint(x: topLeft.x, y: topLeft.y + cornerRadii.height))
            curve(to: CGPoint(x: topLeft.x + cornerRadii.width, y: topLeft.y),
                  controlPoint1: topLeft,
                  controlPoint2: topLeft)
        } else {
            close()
        }
    }
    
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}

// UIRectCorner compatibility for macOS
struct UIRectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

// MARK: - Preview

#Preview {
    EnhancedFocusLockView()
        .frame(width: 1200, height: 800)
}
