import SwiftUI
import AppKit

struct DashboardView: View {
    @StateObject private var dashboardEngine = DashboardEngine()
    @StateObject private var queryProcessor = QueryProcessor()
    @State private var searchText: String = ""
    @State private var selectedTab: DashboardTab = .overview
    @State private var showingInsightDetail: ProductivityInsight?
    @State private var isRefreshing: Bool = false
    @State private var showingCustomization: Bool = false
    @State private var editingWidget: DashboardWidget? = nil
    @State private var availableWidgets: [DashboardWidget] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var latestQueryAnswer: QueryAnswer?
    @State private var showingQueryAlert: Bool = false

    // Dashboard configuration
    @State private var configuration = DashboardConfiguration(
        widgets: [
            DashboardWidget(
                id: "focus-time",
                type: .focusTime,
                title: "Focus Time",
                position: .init(row: 0),
                size: .large
            ),
            DashboardWidget(
                id: "productivity-score",
                type: .productivity,
                title: "Productivity Score",
                position: .init(row: 1),
                size: .medium
            ),
            DashboardWidget(
                id: "app-usage",
                type: .apps,
                title: "App Usage",
                position: .init(row: 2),
                size: .large
            ),
            DashboardWidget(
                id: "insights",
                type: .insights,
                title: "Insights",
                position: .init(row: 3),
                size: .large
            )
        ],
        theme: .default,
        layout: .default,
        preferences: .default.updating(timeRange: .week, showDetailedAnalysis: false)
    )

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Dashboard")
                            .font(.custom("InstrumentSerif-Regular", size: 42))
                            .foregroundColor(.black)

                        Spacer()

                        HStack(spacing: 12) {
                            // Customization button
                            Button(action: { showingCustomization = true }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Customize Dashboard")

                            // Refresh button
                            Button(action: refreshData) {
                                Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Refresh Data")
                        }
                    }

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))

                        TextField("Ask about your productivity...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.custom("Nunito", size: 14))
                            .onSubmit {
                                handleSearch()
                            }

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Tab selector
                DashboardTabSelector(selectedTab: $selectedTab)

                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Overview Tab
                    DashboardOverviewView(
                        engine: dashboardEngine,
                        configuration: $configuration,
                        onInsightTap: { insight in
                            showingInsightDetail = insight
                        }
                    )
                    .tag(DashboardTab.overview)

                    // Charts Tab
                    DashboardChartsView(
                        engine: dashboardEngine,
                        configuration: configuration
                    )
                    .tag(DashboardTab.charts)

                    // Insights Tab
                    DashboardInsightsView(
                        engine: dashboardEngine,
                        onInsightTap: { insight in
                            showingInsightDetail = insight
                        }
                    )
                    .tag(DashboardTab.insights)

                    // Trends Tab
                    DashboardTrendsView(
                        engine: dashboardEngine,
                        configuration: configuration
                    )
                    .tag(DashboardTab.trends)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            dashboardEngine.startAutoRefresh()
            initializeAvailableWidgets()
        }
        .onDisappear {
            dashboardEngine.stopAutoRefresh()
        }
        .sheet(item: $showingInsightDetail) { insight in
            InsightDetailView(insight: insight)
        }
        .sheet(isPresented: $showingCustomization) {
            DashboardCustomizationView(
                configuration: $configuration,
                availableWidgets: $availableWidgets,
                onSave: saveConfiguration
            )
        }
        .alert("Query Result", isPresented: $showingQueryAlert) {
            Button("OK") { }
        } message: {
            Text(latestQueryAnswer?.answer ?? "")
        }
    }

    private func handleSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            let context = await queryProcessor.processQuery(searchText)
            let metrics = await MainActor.run { dashboardEngine.productivityMetrics }
            let answer = await queryProcessor.generateAnswer(
                for: context,
                with: metrics
            )
            await MainActor.run {
                latestQueryAnswer = answer
                showingQueryAlert = true
            }
        }
        searchText = ""
    }

    private func refreshData() {
        isRefreshing = true
        Task {
            await dashboardEngine.refreshData()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func initializeAvailableWidgets() {
        availableWidgets = [
            // Focus Time Widgets
            DashboardWidget(
                id: "focus-time-mini",
                type: .focusTime,
                title: "Focus Time Today",
                position: .init(row: -1),
                size: .small
            ),
            DashboardWidget(
                id: "focus-time-week",
                type: .focusTime,
                title: "Weekly Focus",
                position: .init(row: -1),
                size: .medium
            ),

            // Productivity Widgets
            DashboardWidget(
                id: "productivity-score",
                type: .productivity,
                title: "Productivity Score",
                position: .init(row: -1),
                size: .medium
            ),
            DashboardWidget(
                id: "productivity-trend",
                type: .productivity,
                title: "Productivity Trend",
                position: .init(row: -1),
                size: .large
            ),

            // Task Widgets
            DashboardWidget(
                id: "tasks-completed",
                type: .tasks,
                title: "Tasks Completed",
                position: .init(row: -1),
                size: .small
            ),
            DashboardWidget(
                id: "task-progress",
                type: .tasks,
                title: "Task Progress",
                position: .init(row: -1),
                size: .medium
            ),

            // App Usage Widgets
            DashboardWidget(
                id: "top-apps",
                type: .apps,
                title: "Top Apps",
                position: .init(row: -1),
                size: .medium
            ),
            DashboardWidget(
                id: "app-usage-detailed",
                type: .apps,
                title: "App Usage Analysis",
                position: .init(row: -1),
                size: .large
            ),

            // Wellness Widgets
            DashboardWidget(
                id: "break-time",
                type: .wellness,
                title: "Break Time",
                position: .init(row: -1),
                size: .small
            ),
            DashboardWidget(
                id: "session-length",
                type: .wellness,
                title: "Session Length",
                position: .init(row: -1),
                size: .medium
            ),

            // Goals Widgets
            DashboardWidget(
                id: "goal-progress",
                type: .goals,
                title: "Goal Progress",
                position: .init(row: -1),
                size: .medium
            ),

            // Insights Widget
            DashboardWidget(
                id: "recent-insights",
                type: .insights,
                title: "Recent Insights",
                position: .init(row: -1),
                size: .large
            ),

            // Trends Widget
            DashboardWidget(
                id: "weekly-trends",
                type: .trends,
                title: "Weekly Trends",
                position: .init(row: -1),
                size: .large
            )
        ]
    }

    private func saveConfiguration() {
        // Save configuration to UserDefaults or persistent storage
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(encoded, forKey: "dashboard_configuration")
        }
    }
}

// MARK: - Dashboard Tabs

enum DashboardTab: String, CaseIterable {
    case overview = "Overview"
    case charts = "Charts"
    case insights = "Insights"
    case trends = "Trends"

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .charts: return "chart.bar.fill"
        case .insights: return "lightbulb.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct DashboardTabSelector: View {
    @Binding var selectedTab: DashboardTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .black : .gray)

                        Text(tab.rawValue)
                            .font(.custom("Nunito", size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .black : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Dashboard Views

struct DashboardOverviewView: View {
    @ObservedObject var engine: DashboardEngine
    @Binding var configuration: DashboardConfiguration
    let onInsightTap: (ProductivityInsight) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Customizable widget grid
                CustomizableWidgetGrid(
                    widgets: configuration.widgets,
                    engine: engine,
                    onInsightTap: onInsightTap
                )

                // Quick insights (if not showing as widget)
                if !configuration.widgets.contains(where: { $0.type == .insights }) {
                    QuickInsightsSection(
                        insights: engine.insights,
                        onInsightTap: onInsightTap
                    )
                }

                // Recent trends (if not showing as widget)
                if !configuration.widgets.contains(where: { $0.type == .trends }) {
                    RecentTrendsSection(trends: engine.trends)
                }

                // Top recommendations
                TopRecommendationsSection(
                    recommendations: engine.recommendations
                )
            }
            .padding()
        }
    }
}

struct DashboardChartsView: View {
    @ObservedObject var engine: DashboardEngine
    let configuration: DashboardConfiguration

    var body: some View {
        ProductivityCharts(
            metrics: engine.metrics,
            trends: engine.trends,
            style: .colorful
        )
    }
}

struct DashboardInsightsView: View {
    @ObservedObject var engine: DashboardEngine
    let onInsightTap: (ProductivityInsight) -> Void

    var body: some View {
            InsightsView(
                insights: engine.insights,
                recommendations: engine.recommendations,
                trends: engine.trends,
                configuration: DashboardConfiguration(
                widgets: [],
                theme: .default,
                layout: .default,
                preferences: .default.updating(timeRange: .week, showDetailedAnalysis: true)
            )
        )
    }
}

struct DashboardTrendsView: View {
    @ObservedObject var engine: DashboardEngine
    let configuration: DashboardConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Trend summary
                TrendSummarySection(trends: engine.trends)

                // Detailed trend charts
                DetailedTrendChartsSection(
                    trends: engine.trends,
                    metrics: engine.metrics
                )

                // Performance patterns
                PerformancePatternsSection(insights: engine.insights.filter { $0.category == .pattern })
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct KeyMetricsRow: View {
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricCard(
                title: "Focus Time",
                value: formatFocusTime(engine.metrics.filter { $0.category == .focusTime }.reduce(0, { $0 + $1.value })),
                icon: "clock.fill",
                color: .blue,
                trend: getTrendForMetric(.focusTime, trends: engine.trends)
            )

            MetricCard(
                title: "Productivity",
                value: formatPercentage(engine.metrics.filter { $0.category == .productivity }.last?.value ?? 0),
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                trend: getTrendForMetric(.productivity, trends: engine.trends)
            )

            MetricCard(
                title: "Tasks",
                value: "\(engine.metrics.filter { $0.category == .taskCompletion }.reduce(0, { $0 + Int($1.value) }))",
                icon: "checkmark.circle.fill",
                color: .orange,
                trend: getTrendForMetric(.taskCompletion, trends: engine.trends)
            )

            MetricCard(
                title: "Insights",
                value: "\(engine.insights.count)",
                icon: "lightbulb.fill",
                color: .purple,
                trend: .neutral
            )
        }
    }

    private func formatFocusTime(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private func formatPercentage(_ value: Double) -> String {
        return String(format: "%.0f%%", value * 100)
    }

    private func getTrendForMetric(_ category: MetricCategory, trends: [TrendData]) -> TrendDirection {
        return trends.first { $0.metricName.contains(category.rawValue) }?.trendDirection ?? .neutral
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: TrendDirection

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: trend.arrow)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(trend.color)
                }
            }

            Text(value)
                .font(.custom("Nunito", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct QuickInsightsSection: View {
    let insights: [ProductivityInsight]
    let onInsightTap: (ProductivityInsight) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Insights")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(insights.prefix(4), id: \.id) { insight in
                    MiniInsightCard(insight: insight, onTap: { onInsightTap(insight) })
                }
            }
        }
    }
}

struct MiniInsightCard: View {
    let insight: ProductivityInsight
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: insight.icon)
                .font(.system(size: 16))
                .foregroundColor(insight.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .lineLimit(1)

                Text(insight.description)
                    .font(.custom("Nunito", size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            PriorityIndicator(priority: insight.priority)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
}

struct RecentTrendsSection: View {
    let trends: [TrendData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Trends")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trends.prefix(3), id: \.id) { trend in
                        TrendCard(trend: trend, insights: [])
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct TopRecommendationsSection: View {
    let recommendations: [Recommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Recommendations")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            VStack(spacing: 8) {
                ForEach(recommendations.prefix(3), id: \.id) { recommendation in
                    MiniRecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
}

struct MiniRecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: recommendation.icon)
                .font(.system(size: 16))
                .foregroundColor(recommendation.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .lineLimit(1)

                Text(recommendation.description)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            PriorityIndicator(priority: recommendation.priority)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct MiniChartsSection: View {
    @ObservedObject var engine: DashboardEngine
    let configuration: DashboardConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Overview")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                WidgetProductivityScore(
                    metrics: engine.metrics,
                    style: .colorful
                )

                WidgetFocusTimeChart(
                    metrics: engine.metrics,
                    style: .colorful
                )
            }
        }
    }
}

struct TrendSummarySection: View {
    let trends: [TrendData]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trend Summary")
                .font(.custom("InstrumentSerif-Regular", size: 28))
                .foregroundColor(.black)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(trends, id: \.id) { trend in
                    TrendSummaryCard(trend: trend)
                }
            }
        }
    }
}

struct TrendSummaryCard: View {
    let trend: TrendData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trend.metricName)
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: trend.trendDirection.arrow)
                        .foregroundColor(trend.trendDirection.color)
                    Text(String(format: "%.1f%%", trend.trendStrength * 100))
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(trend.trendDirection.color)
                }
            }

            Text(trend.period)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.gray)

            // Mini chart
            MiniTrendView(trend: trend)
                .frame(height: 80)

            if !trend.insights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Insights")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.black)

                    ForEach(trend.insights.prefix(2), id: \.self) { insight in
                        HStack {
                            Circle()
                                .fill(trend.trendDirection.color)
                                .frame(width: 4, height: 4)

                            Text(insight)
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(2)

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct DetailedTrendChartsSection: View {
    let trends: [TrendData]
    let metrics: [ProductivityMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Analysis")
                .font(.custom("InstrumentSerif-Regular", size: 28))
                .foregroundColor(.black)

            // Focus time trend chart
            if let focusTrend = trends.first(where: { $0.metricName == "Focus Time" }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus Time Patterns")
                        .font(.custom("Nunito", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    TrendAnalysisChart(trends: [focusTrend], style: .colorful)
                        .frame(height: 200)
                }
            }

            // Productivity score trend chart
            if let productivityTrend = trends.first(where: { $0.metricName == "Productivity Score" }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Productivity Trends")
                        .font(.custom("Nunito", size: 20))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    TrendAnalysisChart(trends: [productivityTrend], style: .colorful)
                        .frame(height: 200)
                }
            }
        }
    }
}

// MARK: - Legacy Banner (keep for potential future use)

private struct InfiniteScrollingBanner: View {
    enum Direction { case leftToRight, rightToLeft }

    let imageName: String
    let speed: CGFloat        // points per second
    let direction: Direction
    let blurRadius: CGFloat

    @State private var startTime: TimeInterval = Date().timeIntervalSinceReferenceDate
    @State private var imageAspect: CGFloat = 2.0 // fallback aspect ratio (w/h)

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let elapsed = max(0, now - startTime)

                // Determine tile size from available height and image aspect ratio
                let h = max(1, geo.size.height)
                let tileW = max(1, h * imageAspect)

                // Compute how many tiles to fully cover width even while shifting
                let visibleW = max(1, geo.size.width)
                let needed = Int(ceil(visibleW / tileW)) + 2

                // Offset that loops per tileW
                let shift = CGFloat(elapsed) * speed
                let phase = shift.truncatingRemainder(dividingBy: tileW)
                let xOffset = (direction == .rightToLeft) ? -phase : phase

                HStack(spacing: 0) {
                    ForEach(0..<max(2, needed), id: \.self) { _ in
                        Image(imageName)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: tileW, height: h)
                            .clipped()
                    }
                }
                .offset(x: xOffset)
                .blur(radius: blurRadius, opaque: true)
            }
        }
        .onAppear {
            startTime = Date().timeIntervalSinceReferenceDate
            if let img = NSImage(named: imageName), img.size.height > 0 {
                imageAspect = img.size.width / img.size.height
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Customizable Widget Grid

struct CustomizableWidgetGrid: View {
    let widgets: [DashboardWidget]
    @ObservedObject var engine: DashboardEngine
    let onInsightTap: (ProductivityInsight) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 300), spacing: 16)
    ]

    var body: some View {
        if widgets.isEmpty {
            EmptyWidgetsView()
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(widgets) { widget in
                    DashboardWidgetView(
                        widget: widget,
                        engine: engine,
                        onInsightTap: onInsightTap
                    )
                }
            }
        }
    }
}

struct EmptyWidgetsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Widgets Added")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.gray)

            Text("Tap the customize button to add widgets to your dashboard")
                .font(.custom("Nunito", size: 16))
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

struct DashboardWidgetView: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine
    let onInsightTap: (ProductivityInsight) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Widget Header
            HStack {
                Image(systemName: widget.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)

                Text(widget.title)
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Spacer()

                if let subtitle = widget.subtitle {
                    Text(subtitle)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }
            }

            // Widget Content
            Group {
                switch widget.type {
                case .focusTime:
                    FocusTimeWidgetContent(widget: widget, engine: engine)
                case .productivity:
                    ProductivityWidgetContent(widget: widget, engine: engine)
                case .apps:
                    AppsWidgetContent(widget: widget, engine: engine)
                case .tasks:
                    TasksWidgetContent(widget: widget, engine: engine)
                case .wellness:
                    WellnessWidgetContent(widget: widget, engine: engine)
                case .goals:
                    GoalsWidgetContent(widget: widget, engine: engine)
                case .insights:
                    InsightsWidgetContent(widget: widget, engine: engine, onInsightTap: onInsightTap)
                case .trends:
                    TrendsWidgetContent(widget: widget, engine: engine)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: widget.size.height)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Widget Content Views

struct FocusTimeWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        let todayFocus = engine.metrics.first { $0.category == .focusTime && Calendar.current.isDateInToday($0.timestamp) }

        if widget.size == .small {
            MiniChartWidget(
                title: "Today",
                value: todayFocus != nil ? "\(Int(todayFocus!.value)) min" : "0 min",
                trend: calculateTrend(),
                color: .blue
            )
        } else if widget.size == .medium {
            MediumChartWidget(
                title: "Focus Time",
                value: todayFocus != nil ? "\(Int(todayFocus!.value)) minutes" : "No data",
                description: "Total focus time today"
            )
        } else {
            LargeChartWidget(
                title: "Focus Time Analysis",
                metrics: engine.metrics.filter { $0.category == .focusTime },
                chartType: .bar
            )
        }
    }

    private func calculateTrend() -> WidgetTrend {
        let recentMetrics = engine.metrics.filter { $0.category == .focusTime }
            .suffix(7)

        guard recentMetrics.count >= 2 else { return .neutral }

        let recent = recentMetrics.suffix(3)
        let previous = recentMetrics.dropLast(3).suffix(3)

        let recentAvg = recent.reduce(0) { $0 + $1.value } / Double(recent.count)
        let previousAvg = previous.reduce(0) { $0 + $1.value } / Double(previous.count)

        if recentAvg > previousAvg * 1.1 {
            return .up
        } else if recentAvg < previousAvg * 0.9 {
            return .down
        } else {
            return .neutral
        }
    }
}

struct ProductivityWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        let latestScore = engine.metrics.first { $0.category == .productivity }

        if widget.size == .small {
            MiniChartWidget(
                title: "Score",
                value: latestScore != nil ? "\(Int(latestScore!.value * 100))%" : "--",
                trend: .neutral,
                color: .green
            )
        } else if widget.size == .medium {
            MediumChartWidget(
                title: "Productivity",
                value: latestScore != nil ? "\(Int(latestScore!.value * 100))%" : "No data",
                description: "Current productivity score"
            )
        } else {
            LargeChartWidget(
                title: "Productivity Trends",
                metrics: engine.metrics.filter { $0.category == .productivity },
                chartType: .line
            )
        }
    }
}

struct AppsWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        let topApps = engine.metrics.filter { $0.category == .appUsage }
            .sorted { $0.value > $1.value }
            .prefix(widget.size == .small ? 3 : 5)

        if widget.size == .small {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(topApps.prefix(3)), id: \.id) { app in
                    HStack {
                        Circle()
                            .fill(colorForApp(app.name))
                            .frame(width: 8, height: 8)

                        Text(app.name)
                            .font(.custom("Nunito", size: 12))
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(app.value))m")
                            .font(.custom("Nunito", size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
        } else if widget.size == .medium {
            WidgetTopApps(metrics: Array(topApps), style: .minimal)
        } else {
            AppUsageChart(metrics: Array(topApps), style: .minimal)
        }
    }

    private func colorForApp(_ appName: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .teal]
        let hash = abs(appName.hashValue)
        return colors[hash % colors.count]
    }
}

struct TasksWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        let taskMetrics = engine.metrics.filter { $0.category == .taskCompletion }

        if widget.size == .small {
            let totalTasks = taskMetrics.reduce(0) { $0 + $1.value }
            MiniChartWidget(
                title: "Tasks",
                value: "\(Int(totalTasks))",
                trend: .up,
                color: .orange
            )
        } else if widget.size == .medium {
            MediumChartWidget(
                title: "Task Progress",
                value: "\(taskMetrics.count) completed",
                description: "Tasks finished recently"
            )
        } else {
            TaskProgressChart(metrics: taskMetrics, style: .minimal)
        }
    }
}

struct WellnessWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        if widget.size == .small {
            MiniChartWidget(
                title: "Wellness",
                value: "Good",
                trend: .up,
                color: .mint
            )
        } else if widget.size == .medium {
            MediumChartWidget(
                title: "Wellness Score",
                value: "85%",
                description: "Based on work-life balance"
            )
        } else {
            LargeChartWidget(
                title: "Wellness Overview",
                metrics: [],
                chartType: .line
            )
        }
    }
}

struct GoalsWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        if widget.size == .small {
            MiniChartWidget(
                title: "Goals",
                value: "3/5",
                trend: .up,
                color: .purple
            )
        } else if widget.size == .medium {
            MediumChartWidget(
                title: "Goal Progress",
                value: "60% complete",
                description: "3 of 5 goals on track"
            )
        } else {
            LargeChartWidget(
                title: "Goals Overview",
                metrics: [],
                chartType: .bar
            )
        }
    }
}

struct InsightsWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine
    let onInsightTap: (ProductivityInsight) -> Void

    var body: some View {
        let topInsights = Array(engine.insights.prefix(widget.size == .small ? 2 : 4))

        VStack(alignment: .leading, spacing: 12) {
            ForEach(topInsights, id: \.id) { insight in
                Button(action: { onInsightTap(insight) }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.type.systemImage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(insight.type.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.custom("Nunito", size: 13))
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .lineLimit(2)

                            Text(insight.description)
                                .font(.custom("Nunito", size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(widget.size == .small ? 2 : 3)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if topInsights.isEmpty {
                EmptyStateWidget(
                    icon: "lightbulb",
                    message: "No insights yet",
                    description: "Keep using FocusLock to get personalized insights"
                )
            }
        }
    }
}

struct TrendsWidgetContent: View {
    let widget: DashboardWidget
    @ObservedObject var engine: DashboardEngine

    var body: some View {
        if widget.size == .small {
            MiniChartWidget(
                title: "Trends",
                value: "Analyzing",
                trend: .up,
                color: .indigo
            )
        } else if widget.size == .medium {
            MediumChartWidget(
                title: "Productivity Trend",
                value: "+12%",
                description: "Compared to last week"
            )
        } else {
            if !engine.trends.isEmpty {
                TrendAnalysisChart(trends: engine.trends, style: .minimal)
            } else {
                EmptyStateWidget(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "Trends analyzing",
                    description: "More data needed for trend analysis"
                )
            }
        }
    }
}

// MARK: - Widget Helper Views

struct MiniChartWidget: View {
    let title: String
    let value: String
    let trend: WidgetTrend
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.gray)

                Spacer()

                Image(systemName: trend.systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(trend.color)
            }

            Text(value)
                .font(.custom("Nunito", size: 20))
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct MediumChartWidget: View {
    let title: String
    let value: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            Text(value)
                .font(.custom("Nunito", size: 24))
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(description)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
    }
}

struct LargeChartWidget: View {
    let title: String
    let metrics: [ProductivityMetric]
    let chartType: ChartType

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            if metrics.isEmpty {
                EmptyStateWidget(
                    icon: "chart.bar",
                    message: "No data available",
                    description: "Start tracking to see charts"
                )
            } else {
                // Simplified chart representation
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(metrics.prefix(5)), id: \.id) { metric in
                        HStack {
                            Text(metric.name)
                                .font(.custom("Nunito", size: 12))
                                .lineLimit(1)

                            Spacer()

                            Text("\(Int(metric.value))")
                                .font(.custom("Nunito", size: 12))
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
    }
}

struct EmptyStateWidget: View {
    let icon: String
    let message: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text(message)
                .font(.custom("Nunito", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.gray)

            Text(description)
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Supporting Types

enum WidgetTrend {
    case up
    case down
    case neutral

    var systemImage: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .neutral: return .gray
        }
    }
}

enum ChartType {
    case bar
    case line
    case pie
}
