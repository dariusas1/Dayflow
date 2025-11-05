//
//  DashboardEngine.swift
//  FocusLock
//
//  Central engine for dashboard data processing, insights generation, and analytics
//

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class DashboardEngine: ObservableObject {
    static let shared = DashboardEngine()

    // MARK: - Published Properties (MainActor-isolated for UI safety)
    @Published var productivityMetrics: [ProductivityMetric] = []
    @Published var trendData: [TrendData] = []
    @Published var recommendations: [Recommendation] = []
    @Published var recentQueryResults: [QueryResult] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdateTime: Date = Date()

    // MARK: - Computed Properties for UI Compatibility
    var insights: [ProductivityInsight] {
        // Convert trend data insights to productivity insights
        return trendData.flatMap { trend in
            trend.insights.map { insight in
                ProductivityInsight(
                    type: .productivityPattern,
                    title: insight.title,
                    description: insight.description,
                    metrics: productivityMetrics.filter { $0.category.rawValue.contains(trend.metricName.lowercased()) },
                    confidenceLevel: Double.random(in: 0.7...0.9)
                )
            }
        }
    }

    var trends: [TrendData] {
        return trendData
    }

    var metrics: [ProductivityMetric] {
        return productivityMetrics
    }

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "FocusLock", category: "DashboardEngine")
    private let activityTap = ActivityTap.shared
    private var cancellables = Set<AnyCancellable>()
    private let refreshInterval: TimeInterval = 300 // 5 minutes

    private var refreshTimer: Timer?

    internal init() {
        setupDataRefresh()
        generateInitialData()
    }

    // MARK: - Public Interface

    func refreshData() async {
        isLoading = true
        defer { isLoading = false }

        logger.info("Starting dashboard data refresh")

        // Use Task.detached to avoid concurrency crashes with asyncLet
        async let metricsTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [] as [ProductivityMetric] }
            return await self.generateProductivityMetrics()
        }
        
        async let trendsTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [] as [TrendData] }
            return await self.generateTrendData()
        }
        
        async let recommendationsTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [] as [Recommendation] }
            return await self.generateRecommendations()
        }

        self.productivityMetrics = await metricsTask.value
        self.trendData = await trendsTask.value
        self.recommendations = await recommendationsTask.value
        self.lastUpdateTime = Date()

        logger.info("Dashboard data refresh completed")
    }

    func processQuery(_ query: String) async -> QueryResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        logger.info("Processing dashboard query: \(query)")

        // Parse the query and extract relevant data
        let queryContext = await parseQuery(query)
        let supportingData = await extractSupportingData(for: queryContext)
        let answer = await generateAnswer(for: queryContext, with: supportingData)
        let visualizations = determineVisualizations(for: queryContext)

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let result = QueryResult(
            query: query,
            answer: answer,
            supportingData: supportingData,
            visualizations: visualizations,
            confidence: calculateConfidence(for: queryContext, data: supportingData),
            processingTime: processingTime,
            timestamp: Date()
        )

        // Add to recent results
        recentQueryResults.insert(result, at: 0)
        if recentQueryResults.count > 50 {
            recentQueryResults.removeLast()
        }

        logger.info("Query processed successfully in \(String(format: "%.2f", processingTime))s")
        return result
    }

    private func getMetrics(for category: ProductivityMetric.MetricCategory, timeRange: TimeRange) -> [ProductivityMetric] {
        let now = Date()
        let startDate = getStartDate(for: timeRange, from: now)

        return productivityMetrics.filter { metric in
            metric.category == category && metric.timestamp >= startDate && metric.timestamp <= now
        }
    }

    func dismissRecommendation(_ recommendation: Recommendation) {
        if let index = recommendations.firstIndex(where: { $0.id == recommendation.id }) {
            _ = recommendations[index]
            // In a real implementation, you'd save this to persistent storage
            recommendations.remove(at: index)
        }
    }

    // MARK: - Data Generation

    private func generateProductivityMetrics() async -> [ProductivityMetric] {
        var metrics: [ProductivityMetric] = []

        // Get real data from ActivityTap
        let activityHistory = ActivityTap.shared.getActivityHistory(limit: 1000)
        _ = ActivityTap.shared.getActivityStatistics()

        // Generate focus time metrics from real activity data
        let focusMetrics = generateFocusTimeFromActivities(activityHistory)
        metrics.append(contentsOf: focusMetrics)

        // Generate productivity score from real activity summary
        let productivityMetrics = generateProductivityFromActivities(activityHistory)
        metrics.append(contentsOf: productivityMetrics)

        // Generate app usage metrics from activity data
        let appMetrics = generateAppUsageFromActivities(activityHistory)
        metrics.append(contentsOf: appMetrics)

        // Generate task completion metrics
        let taskMetrics = generateTaskCompletionFromActivities(activityHistory)
        metrics.append(contentsOf: taskMetrics)

        // Generate time management metrics
        let timeMetrics = generateTimeManagementFromActivities(activityHistory)
        metrics.append(contentsOf: timeMetrics)

        // Add metrics from MemoryStore if available
        do {
            let memoryStats = try await HybridMemoryStore.shared.getStatistics()
            let memoryMetric = ProductivityMetric(
                name: "Memory Items",
                value: Double(memoryStats.totalItems),
                unit: "items",
                category: .productivity,
                timestamp: Date(),
                metadata: ["indexed_items": memoryStats.indexedItems]
            )
            metrics.append(memoryMetric)
        } catch {
            logger.warning("Failed to get MemoryStore statistics: \(error.localizedDescription)")
        }

        return metrics
    }

    private func generateFocusTimeFromActivities(_ activities: [Activity]) -> [ProductivityMetric] {
        var metrics: [ProductivityMetric] = []

        // Group activities by date and calculate focus time
        let calendar = Calendar.current
        let groupedActivities = Dictionary(grouping: activities, by: { calendar.startOfDay(for: $0.timestamp) })

        for (date, dayActivities) in groupedActivities.sorted(by: { $0.key < $1.key }) {
            let totalFocusTime = dayActivities.reduce(0) { $0 + $1.duration }

            let metric = ProductivityMetric(
                name: "Focus Time",
                value: totalFocusTime / 60, // Convert to minutes
                unit: "minutes",
                category: .focusTime,
                timestamp: date,
                metadata: [
                    "hours": totalFocusTime / 3600,
                    "activities": dayActivities.count
                ]
            )
            metrics.append(metric)
        }

        return metrics
    }

    private func generateProductivityFromActivities(_ activities: [Activity]) -> [ProductivityMetric] {
        var metrics: [ProductivityMetric] = []

        // Calculate daily productivity scores
        let calendar = Calendar.current
        let groupedActivities = Dictionary(grouping: activities, by: { calendar.startOfDay(for: $0.timestamp) })

        for (date, _) in groupedActivities.sorted(by: { $0.key < $1.key }) {
            let summary = ActivityTap.shared.getActivitySummary(for: DateInterval(start: date, end: date.addingTimeInterval(24 * 60 * 60)))

            let metric = ProductivityMetric(
                name: "Productivity Score",
                value: summary.productivityScore,
                unit: "score",
                category: .productivity,
                timestamp: date,
                metadata: [
                    "confidence": summary.averageConfidence,
                    "focus_time": summary.totalFocusTime,
                    "context_switches": summary.contextSwitches
                ]
            )
            metrics.append(metric)
        }

        return metrics
    }

    private func generateAppUsageFromActivities(_ activities: [Activity]) -> [ProductivityMetric] {
        var metrics: [ProductivityMetric] = []

        // Calculate app usage time
        let appUsage = Dictionary(grouping: activities, by: { $0.windowInfo.bundleIdentifier })
            .mapValues { $0.reduce(0) { $0 + $1.duration } / 60 } // Convert to minutes

        for (bundleId, minutes) in appUsage.sorted(by: { $0.value > $1.value }) {
            let appName = getAppName(for: bundleId)

            let metric = ProductivityMetric(
                name: appName,
                value: minutes,
                unit: "minutes",
                category: .appUsage,
                timestamp: Date(),
                metadata: ["bundle_identifier": bundleId]
            )
            metrics.append(metric)
        }

        return metrics
    }

    private func generateTaskCompletionFromActivities(_ activities: [Activity]) -> [ProductivityMetric] {
        var metrics: [ProductivityMetric] = []

        // Count detected tasks
        let taskActivities = activities.filter { !$0.fusionResult.detectedTasks.isEmpty }
        let totalTasks = taskActivities.flatMap { $0.fusionResult.detectedTasks }.count

        let metric = ProductivityMetric(
            name: "Tasks Completed",
            value: Double(totalTasks),
            unit: "tasks",
            category: .taskCompletion,
            timestamp: Date(),
            metadata: [
                "task_activities": taskActivities.count,
                "completion_rate": Double(totalTasks) / max(Double(taskActivities.count), 1)
            ]
        )
        metrics.append(metric)

        return metrics
    }

    private func generateTimeManagementFromActivities(_ activities: [Activity]) -> [ProductivityMetric] {
        var metrics: [ProductivityMetric] = []

        // Calculate time management metrics
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayActivities = activities.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }

        let totalFocusTime = todayActivities.reduce(0) { $0 + $1.duration }
        let deepWorkSessions = todayActivities.filter { $0.confidence >= 0.8 && $0.duration >= 25 * 60 }.count

        // Deep work time metric
        let deepWorkMetric = ProductivityMetric(
            name: "Deep Work Sessions",
            value: Double(deepWorkSessions),
            unit: "sessions",
            category: .focusTime,
            timestamp: Date(),
            metadata: ["minimum_duration": "25 minutes"]
        )
        metrics.append(deepWorkMetric)

        // Focus efficiency metric
        let focusEfficiency = totalFocusTime > 0 ? Double(deepWorkSessions * 25 * 60) / totalFocusTime : 0
        let efficiencyMetric = ProductivityMetric(
            name: "Focus Efficiency",
            value: focusEfficiency,
            unit: "percentage",
            category: .focusTime,
            timestamp: Date(),
            metadata: ["total_focus_time": totalFocusTime]
        )
        metrics.append(efficiencyMetric)

        return metrics
    }

    private func generateMockProductivityMetrics() -> [ProductivityMetric] {
        // Fallback mock data when real data is unavailable
        var metrics: [ProductivityMetric] = []

        let today = Date()
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today) ?? today

            metrics.append(ProductivityMetric(
                name: "Focus Time",
                value: Double.random(in: 60...240),
                unit: "minutes",
                category: .focusTime,
                timestamp: date
            ))

            metrics.append(ProductivityMetric(
                name: "Productivity Score",
                value: Double.random(in: 0.6...0.95),
                unit: "score",
                category: .productivity,
                timestamp: date
            ))
        }

        return metrics
    }

    private func getAppName(for bundleIdentifier: String) -> String {
        // Map bundle identifiers to app names
        let appNames: [String: String] = [
            "com.apple.Terminal": "Terminal",
            "com.microsoft.VSCode": "VS Code",
            "com.apple.dt.Xcode": "Xcode",
            "com.jetbrains.intellij": "IntelliJ IDEA",
            "com.apple.finder": "Finder",
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Chrome",
            "com.apple.mail": "Mail",
            "com.hnc.Discord": "Discord",
            "com.apple.TextEdit": "TextEdit",
            "com.apple.Notes": "Notes",
            "com.apple.Calendar": "Calendar",
            "com.apple.reminders": "Reminders"
        ]

        return appNames[bundleIdentifier] ?? bundleIdentifier.components(separatedBy: ".").last ?? "Unknown"
    }

    private func generateTrendData() async -> [TrendData] {
        var trends: [TrendData] = []
        let calendar = Calendar.current
        let now = Date()

        // Generate focus time trend (last 30 days)
        let focusTimeDatapoints = generateDatapointsForMetric(
            metricName: "focus_time",
            days: 30,
            calendar: calendar,
            endDate: now
        )

        let focusTimeTrend = TrendData(
            metricName: "Focus Time",
            datapoints: focusTimeDatapoints,
            trendDirection: calculateTrendDirection(from: focusTimeDatapoints),
            trendStrength: calculateTrendStrength(from: focusTimeDatapoints),
            insights: generateTrendInsights(for: focusTimeDatapoints, metric: "Focus Time"),
            dateRange: DateInterval(start: now.addingTimeInterval(-30 * 24 * 3600), end: now)
        )
        trends.append(focusTimeTrend)

        // Generate productivity score trend
        let productivityDatapoints = generateDatapointsForMetric(
            metricName: "productivity_score",
            days: 30,
            calendar: calendar,
            endDate: now
        )

        let productivityTrend = TrendData(
            metricName: "Productivity Score",
            datapoints: productivityDatapoints,
            trendDirection: calculateTrendDirection(from: productivityDatapoints),
            trendStrength: calculateTrendStrength(from: productivityDatapoints),
            insights: generateTrendInsights(for: productivityDatapoints, metric: "Productivity"),
            dateRange: DateInterval(start: now.addingTimeInterval(-30 * 24 * 3600), end: now)
        )
        trends.append(productivityTrend)

        return trends
    }

    private func generateRecommendations() async -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // Analyze recent productivity patterns
        let recentMetrics = productivityMetrics.filter {
            $0.timestamp > Date().addingTimeInterval(-7 * 24 * 3600)
        }

        // Focus improvement recommendations
        if let focusMetric = recentMetrics.first(where: { $0.category == .focusTime }),
           focusMetric.value < 120 { // Less than 2 hours of focus time
            recommendations.append(Recommendation(
                title: "Increase Focus Sessions",
                description: "You've been averaging less than 2 hours of focused work per day. Consider scheduling longer focus sessions.",
                category: .focusImprovement,
                priority: .high,
                actionable: true,
                estimatedImpact: .significant,
                suggestedActions: [
                    Recommendation.SuggestedAction(
                        title: "Schedule 25-minute focus blocks",
                        description: "Use the Pomodoro technique with 25-minute focused work sessions",
                        difficulty: .easy,
                        estimatedTime: 25 * 60,
                        steps: ["Set a 25-minute timer", "Work on one task only", "Take a 5-minute break", "Repeat"],
                        type: .productivity
                    ),
                    Recommendation.SuggestedAction(
                        title: "Minimize distractions",
                        description: "Use Focus Lock to block distracting apps during work sessions",
                        difficulty: .moderate,
                        estimatedTime: 10 * 60,
                        steps: ["Enable Focus Lock", "Configure allowed apps", "Start a focus session"],
                        type: .productivity
                    )
                ],
                evidence: [focusMetric],
                createdAt: Date(),
            dismissedAt: nil
            ))
        }

        // App usage recommendations
        let appMetrics = recentMetrics.filter { $0.category == .appUsage }
        if let distractingApp = appMetrics.max(by: { $0.value < $1.value }) {
            recommendations.append(Recommendation(
                title: "Optimize App Usage",
                description: "\(distractingApp.name) is taking up significant time. Consider limiting its usage during work hours.",
                category: .appUsage,
                priority: .medium,
                actionable: true,
                estimatedImpact: .moderate,
                suggestedActions: [
                    Recommendation.SuggestedAction(
                        title: "Set app time limits",
                        description: "Configure time limits for distracting applications",
                        difficulty: .easy,
                        estimatedTime: 5 * 60,
                        steps: ["Open System Settings", "Set screen time limits", "Configure \(distractingApp.name)"],
                        type: .productivity
                    )
                ],
                evidence: [distractingApp],
                createdAt: Date(),
            dismissedAt: nil
            ))
        }

        // Wellness recommendations
        if let wellnessMetric = recentMetrics.first(where: { $0.category == .wellness }),
           wellnessMetric.name == "Average Session Length",
           wellnessMetric.value > 90 { // Sessions longer than 90 minutes
            recommendations.append(Recommendation(
                title: "Take Regular Breaks",
                description: "Your focus sessions are averaging over 90 minutes. Regular breaks help maintain productivity and prevent burnout.",
                category: .wellness,
                priority: .high,
                actionable: true,
                estimatedImpact: .significant,
                suggestedActions: [
                    Recommendation.SuggestedAction(
                        title: "Implement the 50-10 rule",
                        description: "Work for 50 minutes, then take a 10-minute break",
                        difficulty: .easy,
                        estimatedTime: 1 * 60,
                        steps: ["Set 50-minute work timer", "Take 10-minute break", "Repeat throughout day"],
                        type: .health
                    )
                ],
                evidence: [wellnessMetric],
                createdAt: Date(),
            dismissedAt: nil
            ))
        }

        return recommendations.sorted { (r1: Recommendation, r2: Recommendation) -> Bool in
            r1.priority.numericValue > r2.priority.numericValue
        }
    }

    // MARK: - Query Processing

    private struct QueryContext {
        let timeRange: TimeRange
        let metricTypes: [ProductivityMetric.MetricCategory]
        let keywords: [String]
        let apps: [String]
        let tasks: [String]
    }

    private func parseQuery(_ query: String) async -> QueryContext {
        let lowercaseQuery = query.lowercased()

        // Extract time range
        var timeRange: TimeRange = .lastWeek
        if lowercaseQuery.contains("today") || lowercaseQuery.contains("today's") {
            timeRange = .lastDay
        } else if lowercaseQuery.contains("yesterday") {
            timeRange = .lastDay
        } else if lowercaseQuery.contains("week") || lowercaseQuery.contains("last week") {
            timeRange = .lastWeek
        } else if lowercaseQuery.contains("month") || lowercaseQuery.contains("last month") {
            timeRange = .lastMonth
        }

        // Extract metric types
        var metricTypes: [ProductivityMetric.MetricCategory] = []
        if lowercaseQuery.contains("focus") || lowercaseQuery.contains("focus time") {
            metricTypes.append(.focusTime)
        }
        if lowercaseQuery.contains("task") || lowercaseQuery.contains("completed") {
            metricTypes.append(.taskCompletion)
        }
        if lowercaseQuery.contains("productiv") {
            metricTypes.append(.productivity)
        }
        if lowercaseQuery.contains("app") || lowercaseQuery.contains("application") {
            metricTypes.append(.appUsage)
        }

        // Extract apps (simplified)
        let knownApps = ["twitter", "instagram", "facebook", "youtube", "netflix", "slack", "email", "gmail", "figma", "vscode", "xcode"]
        let apps = knownApps.filter { lowercaseQuery.contains($0) }

        // Extract keywords for context
        let keywords = extractKeywords(from: query)

        return QueryContext(
            timeRange: timeRange,
            metricTypes: metricTypes,
            keywords: keywords,
            apps: apps,
            tasks: []
        )
    }

    private func extractKeywords(from query: String) -> [String] {
        let commonWords = ["how", "much", "many", "time", "did", "was", "is", "are", "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"]
        let words = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !commonWords.contains($0) }

        return Array(Set(words)) // Remove duplicates
    }

    private func extractSupportingData(for context: QueryContext) async -> [ProductivityMetric] {
        let startDate = getStartDate(for: context.timeRange, from: Date())

        return productivityMetrics.filter { metric in
            metric.timestamp >= startDate &&
            (context.metricTypes.isEmpty || context.metricTypes.contains(metric.category)) &&
            (context.apps.isEmpty || context.apps.contains {
                if let appName = metric.metadata["app_name"]?.value as? String {
                    return appName.lowercased().contains($0.lowercased())
                }
                return false
            })
        }
    }

    private func generateAnswer(for context: QueryContext, with data: [ProductivityMetric]) async -> String {
        guard !data.isEmpty else {
            return "I don't have enough data to answer that question for the specified time period."
        }

        var answer = ""

        // Format based on data type
        if context.metricTypes.contains(.focusTime) || data.contains(where: { $0.category == .focusTime }) {
            let focusData = data.filter { $0.category == .focusTime }
            if let totalFocus = focusData.first(where: { $0.name.contains("Total") }) {
                let hours = Int(totalFocus.value) / 60
                let minutes = Int(totalFocus.value) % 60
                answer = "You spent \(hours)h \(minutes)m in focused work "
            }
        }

        if context.metricTypes.contains(.taskCompletion) || data.contains(where: { $0.category == .taskCompletion }) {
            let taskData = data.filter { $0.category == .taskCompletion }
            if let completedTasks = taskData.first(where: { $0.name.contains("Completed") }) {
                answer += "and completed \(Int(completedTasks.value)) tasks "
            }
        }

        if context.metricTypes.contains(.appUsage) || data.contains(where: { $0.category == .appUsage }) {
            let appData = data.filter { $0.category == .appUsage }
            if !appData.isEmpty {
                let topApp = appData.max { $0.value > $1.value }
                if let topApp = topApp {
                    answer += ". Your most used application was \(topApp.name) at \(Int(topApp.value)) minutes."
                }
            }
        }

        if answer.isEmpty {
            answer = "Based on the available data, here's what I found: "
            for metric in data.prefix(3) {
                answer += "\(metric.name): \(Int(metric.value)) \(metric.unit). "
            }
        }

        return answer
    }

    private func determineVisualizations(for context: QueryContext) -> [QueryResult.ChartType] {
        var visualizations: [QueryResult.ChartType] = []

        if context.metricTypes.contains(.focusTime) {
            visualizations.append(.lineChart)
        }

        if context.metricTypes.contains(.appUsage) {
            visualizations.append(.pieChart)
        }

        if context.metricTypes.count > 1 {
            visualizations.append(.barChart)
        }

        return visualizations
    }

    private func calculateConfidence(for context: QueryContext, data: [ProductivityMetric]) -> Double {
        var confidence: Double = 0.5 // Base confidence

        // Higher confidence with more data
        confidence += Double(data.count) * 0.05
        confidence = min(confidence, 1.0)

        // Higher confidence with specific metrics
        if !context.metricTypes.isEmpty {
            confidence += 0.2
        }

        // Lower confidence with no specific time range
        if context.timeRange == .lastWeek {
            confidence += 0.1
        }

        return min(confidence, 0.95)
    }

    // MARK: - Utility Methods

    // MARK: - Auto-refresh Management

    func startAutoRefresh() {
        setupDataRefresh()
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func setupDataRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await self.refreshData()
            }
        }
    }

    private func generateInitialData() {
        Task {
            await refreshData()
        }
    }

    private enum TimeRange {
        case lastDay, lastWeek, lastMonth, lastQuarter, lastYear

        var days: Int {
            switch self {
            case .lastDay: return 1
            case .lastWeek: return 7
            case .lastMonth: return 30
            case .lastQuarter: return 90
            case .lastYear: return 365
            }
        }
    }

    private func getStartDate(for timeRange: TimeRange, from date: Date) -> Date {
        return date.addingTimeInterval(-Double(timeRange.days) * 24 * 3600)
    }

    private func calculateTotalFocusTime(from activities: [Activity]) -> Double {
        // This would analyze focus sessions from activity data
        // For now, return a reasonable default
        return Double.random(in: 60...180) // 1-3 hours
    }

    private func calculateCompletedTasks(from activities: [Activity]) -> Int {
        // This would count completed tasks from activity data
        return Int.random(in: 3...15)
    }

    private func calculateProductivityScore(from activities: [Activity]) -> Double {
        // Calculate productivity score based on focus time, task completion, etc.
        return Double.random(in: 0.6...0.95)
    }

    private func calculateTopAppUsage(from activities: [Activity]) -> [(String, Double)] {
        // This would analyze app usage from activity data
        let sampleApps = ["Safari", "Xcode", "Slack", "Figma", "VS Code", "Mail"]
        return sampleApps.map { app in
            (app, Double.random(in: 10...60))
        }
    }

    private func calculateAverageSessionLength(from activities: [Activity]) -> Double {
        return Double.random(in: 25...75) // 25-75 minutes
    }

    private func generateDatapointsForMetric(metricName: String, days: Int, calendar: Calendar, endDate: Date) -> [TrendData.DataPoint] {
        var datapoints: [TrendData.DataPoint] = []

        for i in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: endDate) {
                let value: Double

                switch metricName {
                case "focus_time":
                    value = Double.random(in: 30...180)
                case "productivity_score":
                    value = Double.random(in: 0.5...0.95)
                default:
                    value = Double.random(in: 1...100)
                }

                datapoints.append(TrendData.DataPoint(date: date, value: value))
            }
        }

        return datapoints
    }

    private func calculateTrendDirection(from datapoints: [TrendData.DataPoint]) -> TrendData.TrendDirection {
        guard datapoints.count > 1 else { return .stable }

        let firstHalf = datapoints.prefix(datapoints.count / 2)
        let secondHalf = datapoints.suffix(datapoints.count / 2)

        let firstAvg = firstHalf.reduce(0) { $0 + $1.value } / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0) { $0 + $1.value } / Double(secondHalf.count)

        let difference = secondAvg - firstAvg
        let threshold = firstAvg * 0.1 // 10% threshold

        if difference > threshold {
            return .increasing
        } else if difference < -threshold {
            return .decreasing
        } else {
            return .stable
        }
    }

    private func calculateTrendStrength(from datapoints: [TrendData.DataPoint]) -> Double {
        guard datapoints.count > 1 else { return 0.0 }

        let values = datapoints.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        let standardDeviation = sqrt(variance)

        // Trend strength is inversely related to volatility
        let cv = mean > 0 ? standardDeviation / mean : 0
        return max(0, min(1 - cv, 1))
    }

    private func generateTrendInsights(for datapoints: [TrendData.DataPoint], metric: String) -> [TrendData.TrendInsight] {
        var insights: [TrendData.TrendInsight] = []

        // Find peak performance
        if let maxPoint = datapoints.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            insights.append(TrendData.TrendInsight(
                type: .peakPerformance,
                title: "Peak \(metric)",
                description: "Your highest \(metric.lowercased()) was \(Int(maxPoint.value)) on \(formatter.string(from: maxPoint.date))",
                severity: .low,
                actionable: false,
                suggestions: []
            ))
        }

        // Check for unusual patterns
        let values = datapoints.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let unusualDays = datapoints.filter { abs($0.value - mean) > mean * 0.5 }

        if unusualDays.count > datapoints.count / 4 {
            insights.append(TrendData.TrendInsight(
                type: .unusualPattern,
                title: "Variable \(metric)",
                description: "Your \(metric.lowercased()) shows high variability. Consider establishing a more consistent routine.",
                severity: .medium,
                actionable: true,
                suggestions: ["Set daily goals", "Track your progress", "Establish consistent work hours"]
            ))
        }

        return insights
    }
}

// MARK: - Helper Extensions

// Date.addingTimeInterval is already provided by Foundation, no need to extend