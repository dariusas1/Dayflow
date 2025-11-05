//
//  FeatureFlagsSettingsView.swift
//  FocusLock
//
//  Settings view for managing FocusLock feature flags
//

import SwiftUI

struct FeatureFlagsSettingsView: View {
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager
    @State private var selectedCategory: FeatureCategory = .core
    @State private var showRecommended = false
    @State private var searchTerm = ""

    init() {
        // EnvironmentObject is injected via environment, not initializer
    }

    private var filteredFeatures: [FeatureFlag] {
        let allFeatures = showRecommended ? featureFlagManager.getRecommendedFeatures() : FeatureFlag.allCases

        return allFeatures
            .filter { $0.category == selectedCategory }
            .filter { searchTerm.isEmpty || $0.displayName.lowercased().contains(searchTerm.lowercased()) }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header - Fixed height section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FocusLock Features")
                        .font(.custom("InstrumentSerif-Regular", size: 28))
                        .foregroundColor(.black.opacity(0.9))

                    Spacer()

                    Button(action: { showRecommended.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text(showRecommended ? "All" : "Recommended")
                                .font(.custom("Nunito", size: 12))
                        }
                        .foregroundColor(showRecommended ? Color(red: 0.25, green: 0.17, blue: 0) : .black.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showRecommended ? Color(red: 0.25, green: 0.17, blue: 0).opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("Manage FocusLock capabilities and personalize your experience")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }
            .fixedSize(horizontal: false, vertical: true)

            // Search and Categories - Fixed height section
            VStack(alignment: .leading, spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black.opacity(0.4))
                        .font(.system(size: 14))

                    TextField("Search features...", text: $searchTerm)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.custom("Nunito", size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.6))
                .cornerRadius(8)

                // Category Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FeatureCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Text(category.displayName)
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedCategory == category ? .white : .black.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            // Feature Cards - Expandable scrollable container
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    ForEach(filteredFeatures, id: \.self) { feature in
                        FeatureFlagCard(flag: feature)
                            .onTapGesture {
                                featureFlagManager.recordFeatureUsage(feature, action: .viewed)
                            }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(minHeight: 300, maxHeight: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Enhanced Views (these would be implemented as separate files)

struct EnhancedDashboardView: View {
    @ObservedObject var featureFlagManager: FeatureFlagManager
    @State private var selectedTab: DashboardTab = .overview

    enum DashboardTab: String, CaseIterable {
        case overview = "overview"
        case productivity = "productivity"
        case analytics = "analytics"
        case insights = "insights"

        var displayName: String {
            switch self {
            case .overview: return "Overview"
            case .productivity: return "Productivity"
            case .analytics: return "Analytics"
            case .insights: return "Insights"
            }
        }

        var icon: String {
            switch self {
            case .overview: return "chart.pie.fill"
            case .productivity: return "target"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .insights: return "lightbulb"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Dashboard Header
            VStack(spacing: 16) {
                HStack {
                    Text("Enhanced Dashboard")
                        .font(.custom("InstrumentSerif-Regular", size: 24))
                        .foregroundColor(.black.opacity(0.9))

                    Spacer()

                    // Tab Navigation
                    HStack(spacing: 1) {
                        ForEach(DashboardTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 14))
                                    Text(tab.displayName)
                                        .font(.custom("Nunito", size: 13))
                                }
                                .foregroundColor(selectedTab == tab ? .white : .black.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Tab-specific content
                dashboardTabContent
            }
            .padding(20)
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)

            // Main content area would go here
            Spacer()
        }
    }

    @ViewBuilder
    private var dashboardTabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .productivity:
            productivityContent
        case .analytics:
            analyticsContent
        case .insights:
            insightsContent
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Overview")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            // Real-time metrics from DashboardEngine
            if let focusMetric = DashboardEngine.shared.metrics.first(where: { $0.category == .focusTime }) {
                DashboardMetricCard(
                    title: "Focus Time",
                    value: formatDuration(focusMetric.value),
                    change: nil, // Trend calculation would need historical data
                    icon: "clock.fill",
                    color: .blue
                )
            }
            
            // Current activity from ActivityTap
            if let currentActivity = ActivityTap.shared.currentActivity {
                CurrentActivityCard(activity: currentActivity)
            }
            
            // Active sessions from SessionManager
            let sessionManager = SessionManager.shared
            if let currentSession = sessionManager.currentSession {
                ActiveSessionCard(session: currentSession, state: sessionManager.currentState)
            }
            
            Text("Enhanced insights powered by AI analysis")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.5))
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    @ViewBuilder
    private var productivityContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Productivity Metrics")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            // Display productivity metrics from DashboardEngine
            ForEach(DashboardEngine.shared.productivityMetrics.prefix(5), id: \.id) { metric in
                ProductivityMetricRow(metric: metric)
            }
            
            if featureFlagManager.isEnabled(.suggestedTodos) {
                Divider()
                SuggestedTodosPreview()
            }

            if featureFlagManager.isEnabled(.planner) {
                Divider()
                PlannerPreview()
            }
        }
    }

    @ViewBuilder
    private var analyticsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Analytics")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            // Display trend data from DashboardEngine
            ForEach(DashboardEngine.shared.trends.prefix(3), id: \.id) { trend in
                TrendDataCard(trend: trend)
            }
            
            // Performance metrics from PerformanceMonitor
            if let performanceMetrics = getPerformanceMetrics() {
                DashboardPerformanceMetricsCard(metrics: performanceMetrics)
            }
            
            if featureFlagManager.isEnabled(.performanceAnalytics) {
                Divider()
                PerformanceAnalyticsPreview()
            }
        }
    }
    
    private func getPerformanceMetrics() -> DashboardPerformanceMetrics? {
        // Get current performance data
        let processInfo = ProcessInfo.processInfo
        return DashboardPerformanceMetrics(
            cpuUsage: 0.0, // Would need to calculate from system
            memoryUsage: Double(processInfo.physicalMemory) / 1024.0 / 1024.0,
            diskUsage: 0.0
        )
    }

    @ViewBuilder
    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            // Display AI insights from DashboardEngine
            ForEach(DashboardEngine.shared.insights.prefix(5), id: \.id) { insight in
                DashboardInsightCard(insight: insight)
            }
            
            // Display recommendations
            if !DashboardEngine.shared.recommendations.isEmpty {
                Divider()
                Text("Recommendations")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.7))
                
                ForEach(DashboardEngine.shared.recommendations.prefix(3), id: \.id) { recommendation in
                    DashboardRecommendationCard(recommendation: recommendation)
                }
            }
            
            if featureFlagManager.isEnabled(.dataInsights) {
                Divider()
                DataInsightsPreview()
            }
        }
    }
}

// MARK: - Supporting View Components

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.6))
                
                HStack(spacing: 6) {
                    Text(value)
                        .font(.custom("Nunito", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.9))
                    
                    if let change = change {
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10))
                            Text(String(format: "%.1f%%", abs(change)))
                                .font(.custom("Nunito", size: 11))
                        }
                        .foregroundColor(change >= 0 ? .green : .red)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CurrentActivityCard: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "app.badge")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                
                Text("Current Activity")
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            
            Text(activity.windowInfo.bundleIdentifier.components(separatedBy: ".").last ?? "Unknown App")
                .font(.custom("Nunito", size: 15))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.9))
            
            if !activity.windowInfo.title.isEmpty {
                Text(activity.windowInfo.title)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ActiveSessionCard: View {
    let session: FocusSession
    let state: FocusSessionState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundColor(stateColor)
                
                Text("Focus Session")
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
                
                Text(stateText)
                    .font(.custom("Nunito", size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(stateColor)
            }
            
            if !session.taskName.isEmpty {
                Text(session.taskName)
                    .font(.custom("Nunito", size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
            }
            
            Text(formatSessionDuration(session))
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(12)
        .background(stateColor.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(stateColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var stateColor: Color {
        switch state {
        case .idle: return .gray
        case .active: return .green
        case .arming: return .blue
        case .break: return .orange
        case .ended: return .purple
        }
    }
    
    private var stateText: String {
        switch state {
        case .idle: return "Idle"
        case .active: return "Active"
        case .arming: return "Starting"
        case .break: return "Break"
        case .ended: return "Ended"
        }
    }
    
    private func formatSessionDuration(_ session: FocusSession) -> String {
        let duration = Date().timeIntervalSince(session.startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct ProductivityMetricRow: View {
    let metric: ProductivityMetric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.category.displayName)
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.8))
                
                Text(String(format: "%.1f", metric.value))
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
            }
            
            Spacer()
            
            // Trend indicator removed - would need historical data
        }
        .padding(.vertical, 6)
    }
}

struct TrendDirectionBadge: View {
    let direction: TrendData.TrendDirection
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 12))
            Text(direction.rawValue.capitalized)
                .font(.custom("Nunito", size: 12))
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var iconName: String {
        switch direction {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "equal"
        case .volatile: return "arrow.up.arrow.down"
        }
    }
    
    private var badgeColor: Color {
        switch direction {
        case .increasing: return .green
        case .decreasing: return .red
        case .stable: return .blue
        case .volatile: return .orange
        }
    }
}

struct TrendDataCard: View {
    let trend: TrendData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trend.metricName)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
                
                // Trend direction indicator
                TrendDirectionBadge(direction: trend.trendDirection)
            }
            
            if !trend.insights.isEmpty {
                Text(trend.insights.first?.description ?? "")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

struct DashboardPerformanceMetricsCard: View {
    let metrics: DashboardPerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("System Performance")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.black.opacity(0.8))
            
            VStack(spacing: 8) {
                PerformanceBar(label: "CPU", value: metrics.cpuUsage, maxValue: 100, color: .blue)
                PerformanceBar(label: "Memory", value: metrics.memoryUsage, maxValue: 1024, color: .purple)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PerformanceBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
                
                Spacer()
                
                Text(String(format: "%.1f", value))
                    .font(.custom("Nunito", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(value / maxValue, 1.0)), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
}

struct DashboardInsightCard: View {
    let insight: ProductivityInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForInsightType(insight.type))
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text(insight.title)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
                
                ConfidenceBadge(confidence: insight.confidenceLevel)
            }
            
            Text(insight.description)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))
                .lineLimit(3)
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func iconForInsightType(_ type: ProductivityInsight.InsightType) -> String {
        switch type {
        case .peakPerformance: return "chart.line.uptrend.xyaxis"
        case .productivityPattern: return "chart.bar.fill"
        case .energyOptimization: return "battery.100"
        case .taskEfficiency: return "clock.fill"
        case .schedulingImprovement: return "calendar.badge.clock"
        case .goalProgress: return "target"
        case .burnoutRisk: return "exclamationmark.triangle.fill"
        case .focusQuality: return "eye.fill"
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 6, height: 6)
            Text(String(format: "%.0f%%", confidence * 100))
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.6))
        }
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct DashboardRecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(.purple)
                .frame(width: 32, height: 32)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Text(recommendation.description)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

struct DashboardPerformanceMetrics {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
}

struct DailyJournalView: View {
    @ObservedObject var featureFlagManager: FeatureFlagManager
    @StateObject private var generator = DailyJournalGenerator.shared
    @State private var journalEntry: String = ""
    @State private var selectedMood: JournalMood = .neutral
    @State private var journalEntries: [JournalEntry] = []
    @State private var selectedTemplate: JournalTemplate = .reflective
    @State private var showingTemplateSelector = false
    @State private var selectedDate = Date()

    enum JournalMood: String, CaseIterable, Codable {
        case productive = "productive"
        case focused = "focused"
        case tired = "tired"
        case stressed = "stressed"
        case creative = "creative"
        case neutral = "neutral"

        var emoji: String {
            switch self {
            case .productive: return "🚀"
            case .focused: return "🎯"
            case .tired: return "😴"
            case .stressed: return "😰"
            case .creative: return "💡"
            case .neutral: return "😐"
            }
        }

        var color: String {
            switch self {
            case .productive: return "52C41A"
            case .focused: return "007AFF"
            case .tired: return "FF9500"
            case .stressed: return "FF3B30"
            case .creative: return "AF52DE"
            case .neutral: return "8E8E93"
            }
        }
    }

    struct JournalEntry: Identifiable, Codable {
        let id: UUID
        let date: Date
        let content: String
        let mood: JournalMood
        let tags: [String]

        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Daily Journal")
                            .font(.custom("InstrumentSerif-Regular", size: 36))
                            .foregroundColor(.black)

                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                        
                        Text("Auto-generated daily at midnight • \(formatDate(selectedDate))")
                                    .font(.custom("Nunito", size: 13))
                        .foregroundColor(.black.opacity(0.6))
                    }
                }

                // Loading state
                if generator.isGenerating {
                    GenerationProgressCard(generator: generator)
                }
                
                // Error state
                if let error = generator.generationError {
                    ErrorCard(error: error, onRetry: { regenerateJournal() })
                }
                
                // Generated journal content
                if let journal = generator.generatedJournal {
                    GeneratedJournalContent(journal: journal)
                }
                
                // Empty state
                if !generator.isGenerating && generator.generatedJournal == nil && generator.generationError == nil {
                    EmptyJournalState(onGenerate: { generateTodayJournal() })
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingTemplateSelector) {
            TemplateSelector(selectedTemplate: $selectedTemplate)
        }
        .onAppear {
            // Auto-generate journal if none exists for today
            if generator.generatedJournal == nil && !generator.isGenerating {
                generateTodayJournal()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func generateTodayJournal() {
        Task {
            await generator.generateJournal(for: selectedDate, template: selectedTemplate)
        }
    }
    
    private func regenerateJournal() {
        Task {
            await generator.generateJournal(for: selectedDate, template: selectedTemplate)
        }
    }
}

struct JournalEntryCard: View {
    let entry: DailyJournalView.JournalEntry

    var body: some View {
        UnifiedCard(padding: 16, cornerRadius: 12, hoverEnabled: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(entry.mood.emoji)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.formattedDate)
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.black.opacity(0.6))

                        Text(entry.mood.rawValue.capitalized)
                            .font(.custom("Nunito", size: 10))
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: entry.mood.color))
                    }

                    Spacer()
                }

                Text(entry.content)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !entry.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.custom("Nunito", size: 11))
                                .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.25, green: 0.17, blue: 0).opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Feature Flag Onboarding Steps View

struct FeatureOnboardingFlowView: View {
    let feature: FeatureFlag
    let onComplete: () -> Void
    @State private var currentStep: Int = 0
    @State private var isCompleted = false

    private var steps: [OnboardingStep] {
        switch feature {
        case .suggestedTodos:
            return [
                OnboardingStep(
                    title: "Welcome to Suggested Todos",
                    description: "AI-powered task suggestions based on your activity patterns",
                    icon: "checklist",
                    content: "Learn how the system analyzes your timeline to suggest relevant tasks"
                ),
                OnboardingStep(
                    title: "Smart Suggestions",
                    description: "Context-aware recommendations that fit your workflow",
                    icon: "brain",
                    content: "Get personalized suggestions based on your recent activities and patterns"
                ),
                OnboardingStep(
                    title: "Integration",
                    description: "Seamlessly integrate with your existing workflow",
                    icon: "link",
                    content: "Suggestions appear right where you need them in your timeline"
                )
            ]
        case .planner:
            return [
                OnboardingStep(
                    title: "Smart Planning",
                    description: "Intelligent planning tools with timeline integration",
                    icon: "calendar.badge.clock",
                    content: "Plan your day with AI-powered insights and recommendations"
                ),
                OnboardingStep(
                    title: "Timeline Integration",
                    description: "Your plans connect directly with your activity timeline",
                    icon: "link",
                    content: "See how your plans align with actual time spent"
                ),
                OnboardingStep(
                    title: "Progress Tracking",
                    description: "Monitor your planning effectiveness",
                    icon: "chart.bar",
                    content: "Track completed plans and improve your planning over time"
                )
            ]
        case .dailyJournal:
            return [
                OnboardingStep(
                    title: "Daily Reflection",
                    description: "Automated journaling with mood and productivity tracking",
                    icon: "book.closed",
                    content: "Capture your thoughts and feelings throughout the day"
                ),
                OnboardingStep(
                    title: "Mood Tracking",
                    description: "Track your emotional state alongside productivity",
                    icon: "heart",
                    content: "Understand patterns in your mood and performance"
                ),
                OnboardingStep(
                    title: "Personal Growth",
                    description: "Build a record of your personal and professional journey",
                    icon: "growth_chart",
                    content: "Look back on your progress and growth over time"
                )
            ]
        case .enhancedDashboard:
            return [
                OnboardingStep(
                    title: "Enhanced Insights",
                    description: "Advanced analytics and insights dashboard",
                    icon: "chart.bar.doc.horizontal",
                    content: "Get deeper insights into your productivity patterns"
                ),
                OnboardingStep(
                    title: "Data Visualization",
                    description: "Beautiful charts and visual representations",
                    icon: "chart.pie.fill",
                    content: "Understand your data at a glance with interactive visualizations"
                ),
                OnboardingStep(
                    title: "Actionable Insights",
                    description: "Turn data into actionable improvements",
                    icon: "lightbulb",
                    content: "Get specific recommendations to enhance your productivity"
                )
            ]
        case .jarvisChat:
            return [
                OnboardingStep(
                    title: "Meet Jarvis",
                    description: "Your AI productivity assistant",
                    icon: "brain.head.profile",
                    content: "Get personalized guidance and support for your productivity journey"
                ),
                OnboardingStep(
                    title: "Smart Conversations",
                    description: "Context-aware assistance based on your data",
                    icon: "message",
                    content: "Jarvis understands your work patterns and provides relevant help"
                ),
                OnboardingStep(
                    title: "Continuous Learning",
                    description: "Gets smarter as it learns from you",
                    icon: "graduationcap",
                    content: "Your assistant improves over time with personalized insights"
                )
            ]
        default:
            return [
                OnboardingStep(
                    title: "New Feature",
                    description: "Discover a new way to enhance your productivity",
                    icon: feature.icon,
                    content: feature.description
                )
            ]
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))

                Text(steps[currentStep].title)
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(.black.opacity(0.9))

                Text(steps[currentStep].description)
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Content
            Text(steps[currentStep].content)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Progress Indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Navigation
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Previous") {
                        currentStep -= 1
                    }
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        currentStep += 1
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button("Get Started") {
                        isCompleted = true
                        onComplete()
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(32)
        .frame(width: 500, height: 400)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let content: String
}

// MARK: - Preview Components

struct SuggestedTodosPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested for Today")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            VStack(spacing: 8) {
                SuggestedTodoItem(title: "Review code changes from yesterday", priority: .high)
                SuggestedTodoItem(title: "Prepare presentation slides", priority: .medium)
                SuggestedTodoItem(title: "Answer team emails", priority: .low)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct PlannerPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Plan")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            VStack(spacing: 8) {
                PlannerItem(title: "Morning: Code Review", time: "9:00 AM - 11:00 AM", status: .completed)
                PlannerItem(title: "Afternoon: Client Meeting", time: "2:00 PM - 3:00 PM", status: .inProgress)
                PlannerItem(title: "Evening: Documentation", time: "4:00 PM - 5:00 PM", status: .pending)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct PerformanceAnalyticsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            // Simple chart placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 100)
                .cornerRadius(4)
                .overlay(
                    Text("Performance Chart")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.5))
                )
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct DataInsightsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            VStack(spacing: 8) {
                FeatureInsightCard(
                    title: "Peak Productivity",
                    insight: "You're most productive between 10 AM - 12 PM",
                    confidence: 0.85
                )
                FeatureInsightCard(
                    title: "Focus Pattern",
                    insight: "Music helps you stay focused longer",
                    confidence: 0.72
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct SuggestedTodoItem: View {
    let title: String
    let priority: Priority

    enum Priority: String {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var color: String {
            switch self {
            case .high: return "FF3B30"
            case .medium: return "FF9500"
            case .low: return "52C41A"
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: priority.color))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.7))

            Spacer()

            Text(priority.rawValue.uppercased())
                .font(.custom("Nunito", size: 10))
                .fontWeight(.medium)
                .foregroundColor(Color(hex: priority.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: priority.color).opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.4))
        .cornerRadius(6)
    }
}

struct PlannerItem: View {
    let title: String
    let time: String
    let status: Status

    enum Status: String {
        case completed = "completed"
        case inProgress = "in_progress"
        case pending = "pending"

        var color: String {
            switch self {
            case .completed: return "34C759"
            case .inProgress: return "007AFF"
            case .pending: return "8E8E93"
            }
        }

        var displayName: String {
            switch self {
            case .completed: return "Completed"
            case .inProgress: return "In Progress"
            case .pending: return "Pending"
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: status.color))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(1)

                Text(time)
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.black.opacity(0.5))
            }

            Spacer()

            Text(status.displayName)
                .font(.custom("Nunito", size: 10))
                .fontWeight(.medium)
                .foregroundColor(Color(hex: status.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: status.color).opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.4))
        .cornerRadius(6)
    }
}

struct FeatureInsightCard: View {
    let title: String
    let insight: String
    let confidence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.custom("Nunito", size: 12))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.7))

                Spacer()

                Text("\(Int(confidence * 100))%")
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.black.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(insight)
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.6))
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.4))
        .cornerRadius(6)
    }
}