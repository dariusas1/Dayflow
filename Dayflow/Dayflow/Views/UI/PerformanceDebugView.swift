//
//  PerformanceDebugView.swift
//  FocusLock
//
//  Comprehensive performance debugging dashboard for developers
//  Provides real-time performance monitoring, alerting, and optimization insights
//

import SwiftUI
import Combine
import Charts

// MARK: - Performance Debug View

struct PerformanceDebugView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var resourceOptimizer = ResourceOptimizer.shared
    @State private var selectedTab: DebugTab = .overview
    @State private var selectedComponent: FocusLockComponent? = nil
    @State private var showAlerts = true
    @State private var autoRefresh = true
    @State private var refreshInterval: TimeInterval = 1.0
    @State private var timeRange: TimeRange = .lastHour

    private var timer: Timer = {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Auto-refresh handled by Combine publishers
        }
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with controls
                headerView

                // Tab selector
                tabSelectorView

                // Content based on selected tab
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Performance Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { exportPerformanceData() }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { resetAllMetrics() }) {
                            Label("Reset Metrics", systemImage: "arrow.clockwise")
                        }
                        Button(action: { toggleAutoRefresh() }) {
                            Label(autoRefresh ? "Stop Auto Refresh" : "Start Auto Refresh",
                                  systemImage: autoRefresh ? "pause.circle" : "play.circle")
                        }

                        Divider()

                        Picker("Refresh Rate", selection: $refreshInterval) {
                            Text("0.5s").tag(TimeInterval(0.5))
                            Text("1s").tag(TimeInterval(1.0))
                            Text("2s").tag(TimeInterval(2.0))
                            Text("5s").tag(TimeInterval(5.0))
                        }

                        Divider()

                        Toggle("Show Alerts", isOn: $showAlerts)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                setupMonitoring()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            // System status indicators
            HStack {
                systemStatusIndicator("CPU", value: performanceMonitor.currentMetrics?.systemMetrics.cpuUsage ?? 0.0,
                                   budget: 80.0, // Default CPU budget
                                   color: .blue)
                systemStatusIndicator("Memory", value: performanceMonitor.currentMetrics?.systemMetrics.memoryUsage.used ?? 0.0,
                                   budget: 70.0, // Default memory budget
                                   color: .green)
                systemStatusIndicator("Thermal", value: Double(performanceMonitor.currentMetrics?.thermalMetrics?.state.rawValue ?? 0),
                                   budget: 3.0, color: .orange)
                systemStatusIndicator("Power", value: Double(performanceMonitor.batteryMetrics?.batteryLevel ?? 0.0),
                                   budget: 100.0, color: .purple)

                Spacer()

                // Alert counter
                if showAlerts && !performanceMonitor.activeAlerts.isEmpty {
                    Button(action: { selectedTab = .alerts }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("\(performanceMonitor.activeAlerts.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Time range selector
            HStack {
                Picker("Time Range", selection: $timeRange) {
                    Text("Last Hour").tag(TimeRange.lastHour)
                    Text("Last 6 Hours").tag(TimeRange.last6Hours)
                    Text("Last Day").tag(TimeRange.lastDay)
                    Text("Last Week").tag(TimeRange.lastWeek)
                }
                .pickerStyle(SegmentedPickerStyle())

                Spacer()

                Text("Last Updated: \(formatDate(Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
    }

    private func systemStatusIndicator(_ title: String, value: Double, budget: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(for: value, budget: budget))
                    .frame(width: 6, height: 6)

                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Tab Selector

    private var tabSelectorView: some View {
        HStack {
            ForEach(DebugTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack {
                        Image(systemName: tab.icon)
                        Text(tab.title)
                    }
                    .font(.caption)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color.accentColor : Color.clear)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .overview:
            OverviewDashboardView(
                performanceMonitor: performanceMonitor,
                resourceOptimizer: resourceOptimizer,
                timeRange: timeRange
            )
        case .components:
            ComponentPerformanceView(
                performanceMonitor: performanceMonitor,
                selectedComponent: $selectedComponent
            )
        case .alerts:
            AlertsDashboardView(
                performanceMonitor: performanceMonitor,
                showAlerts: $showAlerts
            )
        case .optimizations:
            OptimizationInsightsView(
                resourceOptimizer: resourceOptimizer
            )
        case .background:
            BackgroundTasksView(
                performanceMonitor: performanceMonitor
            )
        case .battery:
            BatteryAnalyticsView(
                performanceMonitor: performanceMonitor
            )
        }
    }

    // MARK: - Helper Methods

    private func statusColor(for value: Double, budget: Double) -> Color {
        let percentage = value / budget
        if percentage < 0.5 { return .green }
        if percentage < 0.8 { return .yellow }
        return .red
    }

    private func setupMonitoring() {
        if autoRefresh {
            // Monitoring is handled by Combine publishers in the PerformanceMonitor
        }
    }

    private func cleanup() {
        timer.invalidate()
    }

    private func exportPerformanceData() {
        // Export performance data to file
        print("Exporting performance data...")
        // TODO: Implement export functionality once PerformanceMonitor methods are available
    }

    private func resetAllMetrics() {
        print("Resetting all metrics...")
        // TODO: Implement reset functionality once PerformanceMonitor methods are available
    }

    private func toggleAutoRefresh() {
        autoRefresh.toggle()
        if autoRefresh {
            setupMonitoring()
        } else {
            cleanup()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Debug Tabs

enum DebugTab: CaseIterable {
    case overview
    case components
    case alerts
    case optimizations
    case background
    case battery

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .components: return "Components"
        case .alerts: return "Alerts"
        case .optimizations: return "Optimizations"
        case .background: return "Background"
        case .battery: return "Battery"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "speedometer"
        case .components: return "cube.box"
        case .alerts: return "exclamationmark.triangle"
        case .optimizations: return "gear.circle"
        case .background: return "clock.circle"
        case .battery: return "battery.100"
        }
    }
}

// MARK: - Time Range

enum TimeRange {
    case lastHour
    case last6Hours
    case lastDay
    case lastWeek

    var duration: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last6Hours: return 21600
        case .lastDay: return 86400
        case .lastWeek: return 604800
        }
    }
}

// MARK: - Overview Dashboard View

struct OverviewDashboardView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @ObservedObject var resourceOptimizer: ResourceOptimizer
    let timeRange: TimeRange

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // System Performance Overview
                systemPerformanceCard

                // Component Status Grid
                componentStatusGrid

                // Recent Alerts
                recentAlertsCard

                // Performance Trends
                performanceTrendsCard

                // Resource Optimization Status
                optimizationStatusCard
            }
            .padding()
        }
    }

    private var systemPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Performance")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                metricCard("CPU Usage",
                          value: performanceMonitor.currentMetrics?.systemMetrics.cpuUsage ?? 0.0,
                          format: .percentage,
                          trend: getTrend(for: .cpu))

                metricCard("Memory Usage",
                          value: performanceMonitor.currentMetrics?.systemMetrics.memoryUsage.used ?? 0.0,
                          format: .percentage,
                          trend: getTrend(for: .memory))

                metricCard("Thermal State",
                          value: Double(performanceMonitor.currentMetrics?.thermalMetrics?.state.rawValue ?? 0),
                          format: .thermal,
                          trend: getTrend(for: .thermal))

                metricCard("Battery Level",
                          value: Double(performanceMonitor.currentMetrics?.batteryMetrics?.batteryLevel ?? 0.0),
                          format: .percentage,
                          trend: getTrend(for: .battery))
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricCard(_ title: String, value: Double, format: MetricFormat, trend: TrendDirection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text(formatValue(value, format: format))
                    .font(.title2)
                    .fontWeight(.bold)

                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }

            ProgressView(value: value, total: format == .thermal ? 4.0 : 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor(for: value, format: format)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var componentStatusGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Component Status")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(performanceMonitor.componentMetrics.values), id: \.component) { tracker in
                    ComponentStatusCard(
                        component: tracker.component,
                        metrics: tracker.toComponentMetrics
                    )
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recentAlertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alerts")
                .font(.headline)
                .fontWeight(.semibold)

            if performanceMonitor.recentAlerts.isEmpty {
                Text("No recent alerts")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(performanceMonitor.recentAlerts.prefix(5)), id: \.id) { alert in
                        AlertRow(alert: alert)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var performanceTrendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.headline)
                .fontWeight(.semibold)

            // Simple performance chart placeholder
            Text("Performance chart implementation would go here")
                .foregroundColor(.secondary)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var optimizationStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Status")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading) {
                    Text("Active Optimizations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(resourceOptimizer.activeOptimizations.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Efficiency Gain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(resourceOptimizer.currentOptimizationEfficiency * 100, specifier: "%.1f")%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Methods

    private func getTrend(for metric: MetricType) -> TrendDirection {
        // Calculate trend based on recent data
        return .stable // Placeholder
    }

    private func formatValue(_ value: Double, format: MetricFormat) -> String {
        switch format {
        case .percentage:
            return "\(Int(value * 100))%"
        case .thermal:
            switch Int(value) {
            case 0: return "Fair"
            case 1: return "Nominal"
            case 2: return "Serious"
            case 3: return "Critical"
            default: return "Unknown"
            }
        }
    }

    private func progressColor(for value: Double, format: MetricFormat) -> Color {
        let threshold = format == .thermal ? 3.0 : 0.8
        if value < threshold * 0.5 { return .green }
        if value < threshold * 0.8 { return .yellow }
        return .red
    }
}

// MARK: - Component Status Card

struct ComponentStatusCard: View {
    let component: FocusLockComponent
    let metrics: ComponentMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(component.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                statusIndicator(metrics.health)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("CPU")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(metrics.cpuUsage * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Memory")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(metrics.memoryUsage * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Tasks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(metrics.activeTasks)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusIndicator(_ health: ComponentHealth) -> some View {
        Circle()
            .fill(healthColor(health))
            .frame(width: 8, height: 8)
    }

    private func healthColor(_ health: ComponentHealth) -> Color {
        switch health.status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let alert: PerformanceAlert

    var body: some View {
        HStack {
            Image(systemName: alert.severity.icon)
                .foregroundColor(alert.severity.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(alert.message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(formatDate(alert.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum MetricFormat {
    case percentage
    case thermal
}

enum TrendDirection {
    case improving
    case stable
    case degrading

    var icon: String {
        switch self {
        case .improving: return "arrow.down.right"
        case .stable: return "minus"
        case .degrading: return "arrow.up.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .yellow
        case .degrading: return .red
        }
    }
}

enum MetricType {
    case cpu
    case memory
    case thermal
    case battery
}

// MARK: - Component Performance View

struct ComponentPerformanceView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @Binding var selectedComponent: FocusLockComponent?

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(performanceMonitor.componentMetrics.values), id: \.component) { tracker in
                    NavigationLink(destination: ComponentDetailView(
                        component: tracker.component,
                        metrics: tracker.toComponentMetrics
                    )) {
                        ComponentRow(component: tracker.component, metrics: tracker.toComponentMetrics)
                    }
                }
            }
            .navigationTitle("Components")
        }
    }
}

// MARK: - Component Row

struct ComponentRow: View {
    let component: FocusLockComponent
    let metrics: ComponentMetrics

    var body: some View {
        HStack {
            statusIndicator(metrics.health)

            VStack(alignment: .leading) {
                Text(component.displayName)
                    .font(.headline)

                Text("Tasks: \(metrics.activeTasks) | CPU: \(Int(metrics.cpuUsage * 100))% | Memory: \(Int(metrics.memoryUsage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            chevronIcon
        }
        .padding(.vertical, 4)
    }

    private func statusIndicator(_ health: ComponentHealth) -> some View {
        Circle()
            .fill(healthColor(health))
            .frame(width: 12, height: 12)
    }

    private func healthColor(_ health: ComponentHealth) -> Color {
        switch health.status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
            .font(.caption)
    }
}

// MARK: - Component Detail View

struct ComponentDetailView: View {
    let component: FocusLockComponent
    let metrics: ComponentMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Performance Metrics
                performanceMetricsSection

                // Task Information
                taskInfoSection

                // Health Timeline
                healthTimelineSection
            }
            .padding()
        }
        .navigationTitle(component.displayName)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(component.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                statusBadge(metrics.health)
            }

            Text("Detailed performance metrics and activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                metricCard("CPU Usage", value: metrics.cpuUsage, format: .percentage, trend: .stable)
                metricCard("Memory Usage", value: metrics.memoryUsage, format: .percentage, trend: .stable)
                metricCard("Response Time", value: metrics.averageResponseTime, format: .milliseconds, trend: .stable)
                metricCard("Throughput", value: metrics.throughput, format: .operationsPerSecond, trend: .stable)
            }
        }
    }

    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Information")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                InfoRow(title: "Active Tasks", value: "\(metrics.activeTasks)")
                InfoRow(title: "Completed Tasks", value: "\(metrics.completedTasks)")
                InfoRow(title: "Failed Tasks", value: "\(metrics.failedTasks)")
                InfoRow(title: "Average Queue Time", value: "\(Int(metrics.averageQueueTime * 1000))ms")
            }
        }
    }

    private var healthTimelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Timeline")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Health timeline chart implementation would go here")
                .foregroundColor(.secondary)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func statusBadge(_ health: ComponentHealth) -> some View {
        Text(health.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(healthColor(health))
            .clipShape(Capsule())
    }

    private func healthColor(_ health: ComponentHealth) -> Color {
        switch health.status {
        case .healthy: return .green
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Alerts Dashboard View

struct AlertsDashboardView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @Binding var showAlerts: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Alert Statistics
                alertStatisticsSection

                // Active Alerts
                if !performanceMonitor.activeAlerts.isEmpty {
                    activeAlertsSection
                }

                // Recent Alerts
                recentAlertsSection

                // Alert History
                alertHistorySection
            }
            .padding()
        }
        .navigationTitle("Alerts")
    }

    private var alertStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert Statistics")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                AlertStatCard(title: "Active", count: performanceMonitor.activeAlerts.count, color: .red)
                AlertStatCard(title: "Today", count: performanceMonitor.todayAlertCount, color: .orange)
                AlertStatCard(title: "This Week", count: performanceMonitor.weekAlertCount, color: .yellow)
                AlertStatCard(title: "Resolved", count: performanceMonitor.resolvedAlertCount, color: .green)
            }
        }
    }

    private var activeAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Alerts")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 8) {
                ForEach(performanceMonitor.activeAlerts, id: \.id) { alert in
                    AlertCard(alert: alert, isActive: true)
                }
            }
        }
    }

    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alerts")
                .font(.headline)
                .fontWeight(.semibold)

            if performanceMonitor.recentAlerts.isEmpty {
                Text("No recent alerts")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(performanceMonitor.recentAlerts, id: \.id) { alert in
                        AlertCard(alert: alert, isActive: false)
                    }
                }
            }
        }
    }

    private var alertHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert History")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Alert history timeline implementation would go here")
                .foregroundColor(.secondary)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Alert Stat Card

struct AlertStatCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Alert Card

struct AlertCard: View {
    let alert: PerformanceAlert
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(alert.severity.color)
                .frame(width: 12, height: 12)

            // Alert content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(alert.severity.displayName)
                        .font(.caption)
                        .foregroundColor(alert.severity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(alert.severity.color.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                HStack {
                    Text(alert.component.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatDate(alert.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Action buttons
            if isActive {
                VStack(spacing: 8) {
                    Button(action: { /* Acknowledge alert */ }) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { /* Dismiss alert */ }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(isActive ? alert.severity.color.opacity(0.05) : Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(alert.severity.color.opacity(0.3), lineWidth: isActive ? 1 : 0)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Optimization Insights View

struct OptimizationInsightsView: View {
    @ObservedObject var resourceOptimizer: ResourceOptimizer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Optimization Overview
                optimizationOverviewSection

                // Active Optimizations
                activeOptimizationsSection

                // Performance Recommendations
                recommendationsSection

                // Optimization History
                optimizationHistorySection
            }
            .padding()
        }
        .navigationTitle("Optimizations")
    }

    private var optimizationOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization Overview")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                OptimizationMetricCard(
                    title: "Efficiency Gain",
                    value: resourceOptimizer.currentOptimizationEfficiency,
                    format: .percentage
                )

                OptimizationMetricCard(
                    title: "Active Optimizations",
                    value: Double(resourceOptimizer.activeOptimizations.count),
                    format: .count
                )

                OptimizationMetricCard(
                    title: "Performance Score",
                    value: resourceOptimizer.currentPerformanceScore,
                    format: .score
                )
            }
        }
    }

    private var activeOptimizationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Optimizations")
                .font(.headline)
                .fontWeight(.semibold)

            if resourceOptimizer.activeOptimizations.isEmpty {
                Text("No active optimizations")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(resourceOptimizer.activeOptimizations, id: \.id) { optimization in
                        OptimizationCard(optimization: optimization)
                    }
                }
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Recommendations")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 8) {
                ForEach(resourceOptimizer.optimizationRecommendations, id: \.id) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
    }

    private var optimizationHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimization History")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Optimization history timeline implementation would go here")
                .foregroundColor(.secondary)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Optimization Metric Card

struct OptimizationMetricCard: View {
    let title: String
    let value: Double
    let format: OptimizationFormat

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatValue(value, format: format))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(formatColor(format))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatValue(_ value: Double, format: OptimizationFormat) -> String {
        switch format {
        case .percentage:
            return "\(Int(value * 100))%"
        case .count:
            return "\(Int(value))"
        case .score:
            return "\(value, specifier: "%.1f")"
        }
    }

    private func formatColor(_ format: OptimizationFormat) -> Color {
        switch format {
        case .percentage: return .green
        case .count: return .blue
        case .score: return .purple
        }
    }
}

// MARK: - Optimization Card

struct OptimizationCard: View {
    let optimization: OptimizationStrategy

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(optimization.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(optimization.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("Efficiency: +\(Int(optimization.efficiencyGain * 100))%")
                        .font(.caption2)
                        .foregroundColor(.green)

                    Spacer()

                    Text("Started: \(formatDate(optimization.startTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { /* Stop optimization */ }) {
                Image(systemName: "stop.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Background Tasks View

struct BackgroundTasksView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Background Task Overview
                backgroundTaskOverviewSection

                // Active Tasks
                activeTasksSection

                // Task Schedule
                taskScheduleSection

                // Performance Impact
                performanceImpactSection
            }
            .padding()
        }
        .navigationTitle("Background Tasks")
    }

    private var backgroundTaskOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background Task Overview")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                TaskMetricCard(title: "Active Tasks", value: Double(performanceMonitor.backgroundTaskManager.activeTasks.count))
                TaskMetricCard(title: "Queued Tasks", value: Double(performanceMonitor.backgroundTaskManager.queuedTasks.count))
                TaskMetricCard(title: "Completed Today", value: Double(performanceMonitor.backgroundTaskMetrics.completedTasksToday))
                TaskMetricCard(title: "Success Rate", value: performanceMonitor.backgroundTaskMetrics.successRate, isPercentage: true)
            }
        }
    }

    private var activeTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Tasks")
                .font(.headline)
                .fontWeight(.semibold)

            if performanceMonitor.backgroundTaskManager.activeTasks.isEmpty {
                Text("No active background tasks")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(performanceMonitor.backgroundTaskManager.activeTasks, id: \.id) { task in
                        BackgroundTaskCard(task: task, isActive: true)
                    }
                }
            }
        }
    }

    private var taskScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Schedule")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Task schedule timeline implementation would go here")
                .foregroundColor(.secondary)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var performanceImpactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Impact")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ImpactRow(title: "CPU Usage", value: performanceMonitor.backgroundTaskMetrics.averageCpuImpact, threshold: 0.1)
                ImpactRow(title: "Memory Usage", value: performanceMonitor.backgroundTaskMetrics.averageMemoryImpact, threshold: 0.05)
                ImpactRow(title: "Battery Impact", value: performanceMonitor.backgroundTaskMetrics.batteryDrainRate, threshold: 0.01)
            }
        }
    }
}

// MARK: - Task Metric Card

struct TaskMetricCard: View {
    let title: String
    let value: Double
    var isPercentage: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(isPercentage ? "\(Int(value * 100))%" : "\(Int(value))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Background Task Card

struct BackgroundTaskCard: View {
    let task: BackgroundTaskInfo
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(task.priority.displayName)
                        .font(.caption)
                        .foregroundColor(task.priority.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.priority.color.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("Started: \(formatDate(task.startTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let progress = task.progress {
                        Text("Progress: \(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            if isActive {
                Button(action: { /* Cancel task */ }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Impact Row

struct ImpactRow: View {
    let title: String
    let value: Double
    let threshold: Double

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)

            Spacer()

            Text("\(Int(value * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(value > threshold ? .red : .green)

            // Progress bar
            ProgressView(value: value, total: threshold * 2)
                .progressViewStyle(LinearProgressViewStyle(tint: value > threshold ? .red : .green))
                .frame(width: 100)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Battery Analytics View

struct BatteryAnalyticsView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Battery Status
                batteryStatusSection

                // Power Efficiency Metrics
                powerEfficiencySection

                // Battery Usage Breakdown
                batteryUsageBreakdownSection

                // Power Optimization Recommendations
                powerOptimizationSection

                // Battery History
                batteryHistorySection
            }
            .padding()
        }
        .navigationTitle("Battery Analytics")
    }

    private var batteryStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery Status")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                BatteryMetricCard(
                    title: "Current Level",
                    value: Double(performanceMonitor.batteryMetrics.batteryLevel),
                    format: .percentage,
                    color: batteryColor(performanceMonitor.batteryMetrics.batteryLevel)
                )

                BatteryMetricCard(
                    title: "Power Source",
                    value: performanceMonitor.batteryMetrics.powerState == .battery ? 0 : 1,
                    format: .powerSource
                )

                BatteryMetricCard(
                    title: "Thermal State",
                    value: Double(performanceMonitor.batteryMetrics.thermalState),
                    format: .thermal
                )
            }
        }
    }

    private var powerEfficiencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power Efficiency Metrics")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                EfficiencyMetricCard(
                    title: "Energy Efficiency",
                    value: performanceMonitor.powerEfficiencyMetrics.energyEfficiency,
                    unit: "operations/Wh"
                )

                EfficiencyMetricCard(
                    title: "Battery Drain Rate",
                    value: performanceMonitor.powerEfficiencyMetrics.batteryDrainRate,
                    unit: "%/hour"
                )

                EfficiencyMetricCard(
                    title: "Power Adaptation Score",
                    value: performanceMonitor.powerEfficiencyMetrics.powerAdaptationScore,
                    unit: "score"
                )

                EfficiencyMetricCard(
                    title: "Low Power Mode Savings",
                    value: performanceMonitor.powerEfficiencyMetrics.lowPowerModeSavings,
                    unit: "%"
                )
            }
        }
    }

    private var batteryUsageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery Usage Breakdown")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(Array(performanceMonitor.componentBatteryUsage.keys), id: \.self) { component in
                    BatteryUsageRow(
                        component: component,
                        usage: performanceMonitor.componentBatteryUsage[component]!
                    )
                }
            }
        }
    }

    private var powerOptimizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power Optimization Recommendations")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVStack(spacing: 8) {
                ForEach(performanceMonitor.powerOptimizationRecommendations, id: \.id) { recommendation in
                    PowerOptimizationCard(recommendation: recommendation)
                }
            }
        }
    }

    private var batteryHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery History")
                .font(.headline)
                .fontWeight(.semibold)

            Text("Battery history chart implementation would go here")
                .foregroundColor(.secondary)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func batteryColor(_ level: Int) -> Color {
        if level > 60 { return .green }
        if level > 30 { return .yellow }
        return .red
    }
}

// MARK: - Battery Metric Card

struct BatteryMetricCard: View {
    let title: String
    let value: Double
    let format: BatteryFormat
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatValue(value, format: format))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatValue(_ value: Double, format: BatteryFormat) -> String {
        switch format {
        case .percentage:
            return "\(Int(value))%"
        case .powerSource:
            return value == 1 ? "AC" : "Battery"
        case .thermal:
            switch Int(value) {
            case 0: return "Fair"
            case 1: return "Nominal"
            case 2: return "Serious"
            case 3: return "Critical"
            default: return "Unknown"
            }
        }
    }
}

// MARK: - Efficiency Metric Card

struct EfficiencyMetricCard: View {
    let title: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 2) {
                Text("\(value, specifier: "%.1f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Battery Usage Row

struct BatteryUsageRow: View {
    let component: FocusLockComponent
    let usage: FocusLockModels.ComponentBatteryUsage

    var body: some View {
        HStack {
            Text(component.displayName)
                .font(.subheadline)

            Spacer()

            Text("\(Int(usage.powerConsumption * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)

            ProgressView(value: usage.powerConsumption, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: usageColor(usage.powerConsumption)))
                .frame(width: 80)
        }
        .padding(.vertical, 2)
    }

    private func usageColor(_ usage: Double) -> Color {
        if usage < 0.1 { return .green }
        if usage < 0.2 { return .yellow }
        return .red
    }
}

// MARK: - Power Optimization Card

struct PowerOptimizationCard: View {
    let recommendation: FocusLockModels.PowerOptimizationRecommendation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("Savings: \(Int(recommendation.expectedSavings * 100))%")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Button("Apply") {
                    // Apply power optimization
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Enums

enum BatteryFormat {
    case percentage
    case powerSource
    case thermal
}

enum OptimizationFormat {
    case percentage
    case count
    case score
}

// MARK: - Preview

struct PerformanceDebugView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDebugView()
    }
}