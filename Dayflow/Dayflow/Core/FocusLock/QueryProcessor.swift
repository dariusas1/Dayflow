//
//  QueryProcessor.swift
//  FocusLock
//
//  Natural language query processor for user productivity data queries
//

import Foundation
import NaturalLanguage
import Combine
import os.log

class QueryProcessor: ObservableObject {
    static let shared = QueryProcessor()

    private let logger = Logger(subsystem: "FocusLock", category: "QueryProcessor")
    private let nlpModel = NLEmbedding.embed(for: .english)

    // Query patterns and keywords
    private let timePatterns: [String: DateComponents]
    private let metricKeywords: [String: ProductivityMetric.MetricCategory]
    private let appKeywords: Set<String>
    private let questionWords: Set<String>

    private init() {
        // Initialize time patterns
        timePatterns = [
            "today": DateComponents(day: 0),
            "yesterday": DateComponents(day: -1),
            "this week": DateComponents(day: -7),
            "last week": DateComponents(day: -7),
            "past week": DateComponents(day: -7),
            "this month": DateComponents(month: -1),
            "last month": DateComponents(month: -1),
            "past month": DateComponents(month: -1),
            "recent": DateComponents(day: -3)
        ]

        // Initialize metric keywords
        metricKeywords = [
            "focus time": .focusTime,
            "focus": .focusTime,
            "focusing": .focusTime,
            "task": .taskCompletion,
            "tasks": .taskCompletion,
            "completed": .taskCompletion,
            "productivity": .productivity,
            "productive": .productivity,
            "app": .appUsage,
            "application": .appUsage,
            "program": .appUsage,
            "wellness": .wellness,
            "break": .wellness,
            "rest": .wellness,
            "goal": .goals,
            "goals": .goals,
            "objective": .goals
        ]

        // Common app keywords
        appKeywords = [
            "twitter", "instagram", "facebook", "youtube", "netflix", "tiktok",
            "slack", "discord", "zoom", "teams", "skype",
            "safari", "chrome", "firefox", "browser",
            "xcode", "vscode", "intellij", "pycharm", "android studio",
            "figma", "sketch", "photoshop", "illustrator",
            "mail", "gmail", "outlook", "spark", "airmail",
            "notion", "obsidian", "evernote", "things", "todoist"
        ]

        // Question words
        questionWords = [
            "how", "much", "many", "what", "which", "when", "where",
            "did", "do", "are", "is", "was", "were", "have", "has",
            "show", "tell", "give", "list", "display", "find"
        ]
    }

    // MARK: - Public Interface

    func processQuery(_ query: String) async -> ProcessedQuery {
        let startTime = CFAbsoluteTimeGetCurrent()

        logger.info("Processing query: \(query)")

        // Clean and normalize the query
        let normalizedQuery = normalizeQuery(query)

        // Extract query components
        let timeRange = extractTimeRange(from: normalizedQuery)
        let metrics = extractMetrics(from: normalizedQuery)
        let apps = extractApps(from: normalizedQuery)
        let operations = extractOperations(from: normalizedQuery)
        let filters = extractFilters(from: normalizedQuery)

        // Build query context
        let context = QueryContext(
            originalQuery: query,
            normalizedQuery: normalizedQuery,
            timeRange: timeRange,
            targetMetrics: metrics,
            targetApps: apps,
            operations: operations,
            filters: filters,
            confidence: calculateQueryConfidence(context: nil),
            processingTime: CFAbsoluteTimeGetCurrent() - startTime
        )

        logger.info("Query processed with \(metrics.count) metrics, confidence: \(context.confidence)")
        return context
    }

    func generateAnswer(for context: QueryContext, with data: [ProductivityMetric]) async -> QueryAnswer {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Enhanced answer generation with MemoryStore integration
        let enhancedAnswer = await generateEnhancedAnswer(for: context, data: data)

        // Determine answer strategy
        let strategy = determineAnswerStrategy(for: context, data: data)

        // Generate answer based on strategy
        var answer = ""
        var confidence: Double = 0.0
        var supportingMetrics: [ProductivityMetric] = []
        var visualizations: [QueryResult.ChartType] = []

        switch strategy {
        case .timeBasedComparison:
            answer = generateTimeBasedAnswer(for: context, data: data)
            confidence = 0.85
            supportingMetrics = filterDataForContext(context, data: data)
            visualizations = [.lineChart]

        case .aggregationQuery:
            answer = generateAggregationAnswer(for: context, data: data)
            confidence = 0.90
            supportingMetrics = filterDataForContext(context, data: data)
            visualizations = [.barChart, .pieChart]

        case .appSpecificQuery:
            answer = generateAppSpecificAnswer(for: context, data: data)
            confidence = 0.80
            supportingMetrics = filterDataForContext(context, data: data)
            visualizations = [.pieChart]

        case .rankingQuery:
            answer = generateRankingAnswer(for: context, data: data)
            confidence = 0.75
            supportingMetrics = filterDataForContext(context, data: data)
            visualizations = [.barChart]

        case .patternQuery:
            answer = generatePatternAnswer(for: context, data: data)
            confidence = 0.70
            supportingMetrics = filterDataForContext(context, data: data)
            visualizations = [.lineChart, .scatterPlot]

        case .generalQuery:
            answer = generateGeneralAnswer(for: context, data: data)
            confidence = 0.60
            supportingMetrics = filterDataForContext(context, data: data)
            visualizations = [.barChart]
        }

        // Enhance answer with MemoryStore insights if available
        if !enhancedAnswer.isEmpty {
            answer = enhancedAnswer + "\n\n" + answer
            confidence = min(confidence + 0.15, 0.95) // Boost confidence with MemoryStore data
        }

        // Add follow-up suggestions
        let suggestions = generateFollowUpSuggestions(for: context, answer: answer)

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime

        logger.info("Generated answer in \(String(format: "%.2f", processingTime))s with confidence \(confidence)")

        return QueryAnswer(
            answer: answer,
            confidence: confidence,
            supportingMetrics: supportingMetrics,
            visualizations: visualizations,
            suggestions: suggestions,
            processingTime: processingTime
        )
    }

    func suggestFollowUpQuestions(for query: String, context: QueryContext) async -> [String] {
        var suggestions: [String] = []

        // Analyze the original query and suggest related questions
        let normalizedQuery = normalizeQuery(query)

        // Time-based suggestions
        if !context.targetMetrics.isEmpty {
            suggestions.append("How does my \(context.targetMetrics.first?.displayName.lowercased() ?? "productivity") compare to last week?")
        }

        // App-based suggestions
        if !context.targetApps.isEmpty {
            suggestions.append("What other apps are taking up my time?")
            suggestions.append("How can I reduce time spent on \(context.targetApps.first ?? "apps")?")
        }

        // Pattern-based suggestions
        suggestions.append("What time of day am I most productive?")
        suggestions.append("How has my productivity trended over the past month?")

        // General productivity suggestions
        suggestions.append("What's my productivity score today?")
        suggestions.append("How many tasks have I completed this week?")

        return Array(suggestions.prefix(3))
    }

    // MARK: - Query Analysis

    private func normalizeQuery(_ query: String) -> String {
        return query
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
    }

    private func extractTimeRange(from query: String) -> TimeRange {
        for (pattern, components) in timePatterns {
            if query.contains(pattern) {
                return TimeRange(
                    keyword: pattern,
                    components: components,
                    startDate: calculateDate(from: components),
                    endDate: Date()
                )
            }
        }

        // Default to last week if no time range found
        return TimeRange(
            keyword: "last week",
            components: DateComponents(day: -7),
            startDate: calculateDate(from: DateComponents(day: -7)),
            endDate: Date()
        )
    }

    private func extractMetrics(from query: String) -> [ProductivityMetric.MetricCategory] {
        var foundMetrics: Set<ProductivityMetric.MetricCategory> = []

        for (keyword, metric) in metricKeywords {
            if query.contains(keyword) {
                foundMetrics.insert(metric)
            }
        }

        return Array(foundMetrics)
    }

    private func extractApps(from query: String) -> [String] {
        var foundApps: Set<String> = []

        for app in appKeywords {
            if query.contains(app) {
                foundApps.insert(app)
            }
        }

        return Array(foundApps)
    }

    private func extractOperations(from query: String) -> [QueryOperation] {
        var operations: [QueryOperation] = []

        // Comparison operations
        if query.contains("compare") || query.contains("vs") || query.contains("versus") {
            operations.append(.comparison)
        }

        // Ranking operations
        if query.contains("top") || query.contains("most") || query.contains("best") || query.contains("highest") {
            operations.append(.ranking)
        }

        // Aggregation operations
        if query.contains("total") || query.contains("sum") || query.contains("average") || query.contains("mean") {
            operations.append(.aggregation)
        }

        // Pattern operations
        if query.contains("pattern") || query.contains("trend") || query.contains("change") || query.contains("growth") {
            operations.append(.pattern)
        }

        return operations
    }

    private func extractFilters(from query: String) -> [QueryFilter] {
        var filters: [QueryFilter] = []

        // Category filters
        if query.contains("productive") {
            filters.append(.productiveOnly)
        } else if query.contains("unproductive") {
            filters.append(.unproductiveOnly)
        }

        // Value filters
        if let range = extractRange(from: query) {
            filters.append(.valueRange(range))
        }

        return filters
    }

    private func extractRange(from query: String) -> ClosedRange<Double>? {
        // Look for patterns like "more than X", "less than Y", "between X and Y"
        let moreThanPattern = #"more than (\d+)"#
        let lessThanPattern = #"less than (\d+)"#
        let betweenPattern = #"between (\d+) and (\d+)"#

        if let match = query.range(of: moreThanPattern, options: .regularExpression) {
            let numberString = String(query[match])
            if let number = Double(numberString) {
                return number...Double.greatestFiniteMagnitude
            }
        }

        if let match = query.range(of: lessThanPattern, options: .regularExpression) {
            let numberString = String(query[match])
            if let number = Double(numberString) {
                return Double.leastFiniteMagnitude...number
            }
        }

        if let range = query.range(of: betweenPattern, options: .regularExpression) {
            let captures = query.captures(with: NSRegularExpression(pattern: betweenPattern))
            if captures.count > 1 {
                let startString = String(captures[0])
                let endString = String(captures[1])
                if let start = Double(startString), let end = Double(endString) {
                    return min(start, end)...max(start, end)
                }
            }
        }

        return nil
    }

    private func calculateQueryConfidence(context: QueryContext?) -> Double {
        var confidence: Double = 0.5 // Base confidence

        // Increase confidence for specific queries
        if let ctx = context {
            confidence += Double(ctx.targetMetrics.count) * 0.1
            confidence += Double(ctx.targetApps.count) * 0.05
            confidence += Double(ctx.operations.count) * 0.1

            // Penalize very general queries
            if ctx.targetMetrics.isEmpty && ctx.targetApps.isEmpty && ctx.operations.isEmpty {
                confidence -= 0.2
            }
        }

        return min(confidence, 0.95)
    }

    // MARK: - Answer Generation Strategies

    private func determineAnswerStrategy(for context: QueryContext, data: [ProductivityMetric]) -> AnswerStrategy {
        if !context.operations.isEmpty {
            if context.operations.contains(.comparison) {
                return .timeBasedComparison
            } else if context.operations.contains(.ranking) {
                return .rankingQuery
            } else if context.operations.contains(.aggregation) {
                return .aggregationQuery
            } else if context.operations.contains(.pattern) {
                return .patternQuery
            }
        }

        if !context.targetApps.isEmpty {
            return .appSpecificQuery
        }

        return .generalQuery
    }

    private func generateTimeBasedAnswer(for context: QueryContext, data: [ProductivityMetric]) -> String {
        let relevantData = filterDataForContext(context, data: data)

        if let metric = relevantData.first {
            let value = Int(metric.value)
            let unit = metric.unit

            switch metric.category {
            case .focusTime:
                let hours = value / 60
                let minutes = value % 60
                return "You've spent \(hours) hours and \(minutes) minutes in focused work \(context.timeRange.keyword)."

            case .taskCompletion:
                return "You've completed \(value) tasks \(context.timeRange.keyword)."

            case .appUsage:
                return "You've spent \(value) minutes using \(metric.name) \(context.timeRange.keyword)."

            case .productivity:
                let percentage = Int(value * 100)
                return "Your productivity score is \(percentage)% \(context.timeRange.keyword)."

            case .wellness:
                let minutes = value
                return "Your average session length is \(minutes) minutes \(context.timeRange.keyword)."

            case .goals:
                let percentage = Int(value * 100)
                return "You're \(percentage)% of the way to your goals \(context.timeRange.keyword)."
            }
        }

        return "I found relevant data, but need more specific information to provide a detailed answer."
    }

    private func generateAggregationAnswer(for context: QueryContext, data: [ProductivityMetric]) -> String {
        let relevantData = filterDataForContext(context, data: data)

        if relevantData.isEmpty {
            return "I don't have enough data to provide that information."
        }

        let totalValue = relevantData.reduce(0) { $0 + $1.value }
        let averageValue = totalValue / Double(relevantData.count)
        let topItem = relevantData.max { $0.value < $1.value }

        var answer = "Across your tracked metrics:"

        if context.targetMetrics.contains(.focusTime) {
            let focusData = relevantData.filter { $0.category == .focusTime }
            let totalFocus = focusData.reduce(0) { $0 + $1.value }
            answer += " Total focus time: \(Int(totalFocus)) minutes."
        }

        if let top = topItem {
            answer += " \(top.name) was highest at \(Int(top.value)) \(top.unit)."
        }

        return answer
    }

    private func generateAppSpecificAnswer(for context: QueryContext, data: [ProductivityMetric]) -> String {
        let appData = data.filter { metric in
            context.targetApps.contains { app in
                if let appName = metric.metadata["app_name"]?.value as? String {
                    return appName.lowercased().contains(app.lowercased())
                }
                return metric.name.lowercased().contains(app.lowercased())
            }
        }

        if appData.isEmpty {
            return "I don't have data on the apps you mentioned for the specified time period."
        }

        let totalAppTime = appData.reduce(0) { $0 + $1.value }
        let topApp = appData.max { $0.value < $1.value }

        var answer = "For \(context.targetApps.joined(separator: ", ")) \(context.timeRange.keyword):"

        if let top = topApp {
            answer += " \(top.name): \(Int(top.value)) minutes."
        }

        if appData.count > 1 {
            answer += " Total time across these apps: \(Int(totalAppTime)) minutes."
        }

        return answer
    }

    private func generateRankingAnswer(for context: QueryContext, data: [ProductivityMetric]) -> String {
        let relevantData = filterDataForContext(context, data: data)
        let sortedData = relevantData.sorted { $0.value > $1.value }

        guard !sortedData.isEmpty else {
            return "I don't have enough data to provide a ranking."
        }

        var answer = "Here are your top metrics \(context.timeRange.keyword):"
        for (index, metric) in sortedData.prefix(5).enumerated() {
            answer += "\n\(index + 1). \(metric.name): \(Int(metric.value)) \(metric.unit)"
        }

        return answer
    }

    private func generatePatternAnswer(for context: QueryContext, data: [ProductivityMetric]) -> String {
        let relevantData = filterDataForContext(context, data: data)

        if relevantData.count < 2 {
            return "I need more data points to identify patterns."
        }

        // Simple pattern analysis
        let values = relevantData.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let trend = calculateSimpleTrend(from: values)

        var answer = "I've noticed some patterns in your data:"

        if trend > 0.1 {
            answer += " Your productivity has been improving over time."
        } else if trend < -0.1 {
            answer += " Your productivity has been declining recently."
        } else {
            answer += " Your productivity has been relatively stable."
        }

        answer += " The average value is \(String(format: "%.1f", mean))."

        return answer
    }

    private func generateGeneralAnswer(for context: QueryContext, data: [ProductivityMetric]) -> String {
        let relevantData = filterDataForContext(context, data: data)

        if relevantData.isEmpty {
            return "I don't have data for that query. Try being more specific about what you'd like to know."
        }

        var answer = "Here's what I found:"

        for metric in relevantData.prefix(3) {
            answer += "\n• \(metric.name): \(Int(metric.value)) \(metric.unit)"
        }

        answer += "\n\nTry asking for more specific information if you'd like deeper insights."

        return answer
    }

    private func filterDataForContext(_ context: QueryContext, data: [ProductivityMetric]) -> [ProductivityMetric] {
        let startDate = context.timeRange.startDate

        return data.filter { metric in
            // Filter by time range
            guard metric.timestamp >= startDate else { return false }

            // Filter by target metrics
            if !context.targetMetrics.isEmpty {
                guard context.targetMetrics.contains(metric.category) else { return false }
            }

            // Filter by target apps
            if !context.targetApps.isEmpty {
                guard context.targetApps.contains { app in
                    if let appName = metric.metadata["app_name"]?.value as? String {
                        return appName.lowercased().contains(app.lowercased())
                    }
                    return metric.name.lowercased().contains(app.lowercased())
                } else { return false }
            }

            // Apply filters
            for filter in context.filters {
                switch filter {
                case .productiveOnly:
                    guard metric.category != .appUsage else { return false }
                case .unproductiveOnly:
                    guard metric.category == .appUsage else { return false }
                case .valueRange(let range):
                    guard range.contains(metric.value) else { return false }
                }
            }

            return true
        }
    }

    private func generateFollowUpSuggestions(for context: QueryContext, answer: String) -> [String] {
        var suggestions: [String] = []

        // Time-based suggestions
        if context.timeRange.keyword != "today" {
            suggestions.append("How does this compare to today?")
        }

        // Metric-based suggestions
        if !context.targetMetrics.isEmpty {
            suggestions.append("What's contributing to my \(context.targetMetrics.first?.displayName.lowercased() ?? "productivity")?")
        }

        // Action-based suggestions
        if answer.contains("low") || answer.contains("declining") {
            suggestions.append("How can I improve this?")
        }

        return Array(suggestions.prefix(2))
    }

    private func calculateDate(from components: DateComponents) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: components, to: Date()) ?? Date()
    }

    private func calculateSimpleTrend(from values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        return (secondAvg - firstAvg) / firstAvg
    }

    // MARK: - Enhanced Answer Generation with MemoryStore Integration

    private func generateEnhancedAnswer(for context: QueryContext, data: [ProductivityMetric]) async -> String {
        // Extract key concepts from the query for semantic search
        let searchTerms = extractSearchTerms(from: context.normalizedQuery)

        do {
            // Search MemoryStore for relevant memories
            let memoryResults = try await HybridMemoryStore.shared.hybridSearch(
                query: searchTerms.joined(separator: " "),
                limit: 5,
                threshold: 0.3
            )

            guard !memoryResults.isEmpty else {
                return ""
            }

            // Analyze memory results to provide contextual insights
            var insights: [String] = []

            // Check for relevant patterns in memories
            let relevantMemories = memoryResults.filter { result in
                result.score > 0.5 // Only consider high-relevance memories
            }

            if !relevantMemories.isEmpty {
                // Generate insights based on memory content
                if searchTerms.contains("productivity") || searchTerms.contains("focus") {
                    insights.append(generateProductivityInsights(from: relevantMemories))
                }

                if searchTerms.contains("goal") || searchTerms.contains("task") {
                    insights.append(generateGoalInsights(from: relevantMemories))
                }

                if searchTerms.contains("challenge") || searchTerms.contains("problem") {
                    insights.append(generateChallengeInsights(from: relevantMemories))
                }

                // Add general memory insights
                if insights.isEmpty {
                    insights.append(generateGeneralInsights(from: relevantMemories, context: context))
                }
            }

            return insights.joined(separator: "\n\n")

        } catch {
            logger.error("MemoryStore search failed: \(error.localizedDescription)")
            return ""
        }
    }

    private func extractSearchTerms(from query: String) -> [String] {
        // Remove question words and extract meaningful terms
        let filteredQuery = query.components(separatedBy: " ")
            .filter { !questionWords.contains($0) }
            .joined(separator: " ")

        // Extract key terms related to productivity
        let productivityTerms = [
            "productivity", "focus", "concentrate", "work", "task", "goal",
            "habit", "routine", "schedule", "plan", "progress", "achievement",
            "distraction", "procrastination", "motivation", "energy", "time"
        ]

        let foundTerms = productivityTerms.filter { filteredQuery.contains($0) }

        // Add metric and app terms if present
        let metricTerms = context.targetMetrics.map { $0.displayName.lowercased() }
        let appTerms = context.targetApps

        return Array(Set(foundTerms + metricTerms + appTerms))
    }

    private func generateProductivityInsights(from memories: [MemorySearchResult]) -> String {
        var insights: [String] = []

        // Look for patterns in productivity-related memories
        let productiveMemories = memories.filter { memory in
            memory.item.content.lowercased().contains("productive") ||
            memory.item.content.lowercased().contains("focus") ||
            memory.item.content.lowercased().contains("accomplish")
        }

        if !productiveMemories.isEmpty {
            insights.append("Based on your past reflections, you've found that maintaining consistent focus periods leads to better outcomes.")
        }

        // Look for challenge patterns
        let challengeMemories = memories.filter { memory in
            memory.item.content.lowercased().contains("challenge") ||
            memory.item.content.lowercased().contains("struggle") ||
            memory.item.content.lowercased().contains("difficult")
        }

        if !challengeMemories.isEmpty {
            insights.append("You've noted challenges with maintaining productivity in the past. Consider the strategies that worked for you before.")
        }

        return "📝 **From your reflections**: " + insights.joined(separator: " ")
    }

    private func generateGoalInsights(from memories: [MemorySearchResult]) -> String {
        var insights: [String] = []

        // Look for goal-related patterns
        let goalMemories = memories.filter { memory in
            memory.item.content.lowercased().contains("goal") ||
            memory.item.content.lowercased().contains("objective") ||
            memory.item.content.lowercased().contains("target")
        }

        if !goalMemories.isEmpty {
            insights.append("Your past entries show you're most successful when breaking down larger goals into smaller, manageable tasks.")
        }

        // Look for completion patterns
        let completionMemories = memories.filter { memory in
            memory.item.content.lowercased().contains("complete") ||
            memory.item.content.lowercased().contains("finish") ||
            memory.item.content.lowercased().contains("achieve")
        }

        if !completionMemories.isEmpty {
            insights.append("You've consistently noted that tracking progress helps maintain motivation toward your goals.")
        }

        return "🎯 **Goal insights**: " + insights.joined(separator: " ")
    }

    private func generateChallengeInsights(from memories: [MemorySearchResult]) -> String {
        var insights: [String] = []

        // Look for challenge-related memories
        let challengeMemories = memories.filter { memory in
            memory.item.content.lowercased().contains("challenge") ||
            memory.item.content.lowercased().contains("obstacle") ||
            memory.item.content.lowercased().contains("barrier")
        }

        if !challengeMemories.isEmpty {
            insights.append("You've overcome similar challenges before by breaking them down into smaller steps.")
        }

        // Look for solution patterns
        let solutionMemories = memories.filter { memory in
            memory.item.content.lowercased().contains("solution") ||
            memory.item.content.lowercased().contains("solve") ||
            memory.item.content.lowercased().contains("fix")
        }

        if !solutionMemories.isEmpty {
            insights.append("Your past experiences show that taking a systematic approach works best for solving problems.")
        }

        return "💪 **Challenge insights**: " + insights.joined(separator: " ")
    }

    private func generateGeneralInsights(from memories: [MemorySearchResult], context: QueryContext) -> String {
        // Analyze memory content for general patterns
        let recentMemories = memories.prefix(3)

        var insights: [String] = []

        for memory in recentMemories {
            // Extract key themes from memory content
            let content = memory.item.content.lowercased()

            if content.contains("learn") || content.contains("discover") {
                insights.append("You're continuously learning and adapting your approach.")
            }

            if content.contains("improve") || content.contains("better") {
                insights.append("You have a growth mindset and actively seek improvement.")
            }

            if content.contains("habit") || content.contains("routine") {
                insights.append("Building consistent routines has been important to your success.")
            }
        }

        if insights.isEmpty {
            return "🧠 **Memory insight**: Your past reflections show patterns that can inform your current approach."
        }

        return "🧠 **From your memory**: " + insights.joined(separator: " ")
    }
}

// MARK: - Query Data Structures

struct QueryContext {
    let originalQuery: String
    let normalizedQuery: String
    let timeRange: TimeRange
    let targetMetrics: [ProductivityMetric.MetricCategory]
    let targetApps: [String]
    let operations: [QueryOperation]
    let filters: [QueryFilter]
    let confidence: Double
    let processingTime: TimeInterval
}

struct TimeRange {
    let keyword: String
    let components: DateComponents
    let startDate: Date
    let endDate: Date
}

enum QueryOperation {
    case comparison
    case ranking
    case aggregation
    case pattern
}

enum QueryFilter {
    case productiveOnly
    case unproductiveOnly
    case valueRange(ClosedRange<Double>)
}

struct QueryAnswer {
    let answer: String
    let confidence: Double
    let supportingMetrics: [ProductivityMetric]
    let visualizations: [QueryResult.ChartType]
    let suggestions: [String]
    let processingTime: TimeInterval
}

enum AnswerStrategy {
    case timeBasedComparison
    case aggregationQuery
    case appSpecificQuery
    case rankingQuery
    case patternQuery
    case generalQuery
}