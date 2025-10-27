//
//  InsightsView.swift
//  FocusLock
//
//  Comprehensive insights and recommendations for productivity optimization
//

import Foundation
import SwiftUI

struct InsightsView: View {
    let insights: [ProductivityInsight]
    let recommendations: [Recommendation]
    let trends: [TrendData]
    let configuration: DashboardConfiguration

    @State private var selectedInsight: ProductivityInsight?
    @State private var expandedRecommendation: Recommendation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Productivity Insights")
                        .font(.custom("InstrumentSerif-Regular", size: 32))
                        .foregroundColor(.black)

                    Text("Personalized analysis and recommendations based on your productivity patterns")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal)

                // Key Insights Section
                if !insights.isEmpty {
                    InsightsSection(
                        title: "Key Insights",
                        insights: insights.filter { $0.priority.level >= Recommendation.Priority.medium.level },
                        selectedInsight: $selectedInsight
                    )
                }

                // Trend Analysis Section
                if !trends.isEmpty {
                    TrendAnalysisSection(
                        trends: trends,
                        insights: insights.filter { $0.category == .trend }
                    )
                }

                // Recommendations Section
                if !recommendations.isEmpty {
                    RecommendationsSection(
                        recommendations: recommendations,
                        expandedRecommendation: $expandedRecommendation,
                        onApplyAction: { recommendation in
                            handleRecommendationAction(recommendation)
                        }
                    )
                }

                // Performance Patterns Section
                if !insights.isEmpty {
                    PerformancePatternsSection(insights: insights.filter { $0.category == .pattern })
                }

                // Quick Actions Section
                QuickActionsSection(
                    insights: insights,
                    recommendations: recommendations,
                    onQuickAction: handleQuickAction
                )

                // Detailed Analysis Section
                if configuration.showDetailedAnalysis {
                    DetailedAnalysisSection(
                        insights: insights,
                        trends: trends,
                        recommendations: recommendations
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedInsight) { insight in
            InsightDetailView(insight: insight)
        }
    }

    private func handleRecommendationAction(_ recommendation: Recommendation) {
        // Handle recommendation actions (e.g., apply settings, start timer)
        expandedRecommendation = recommendation
    }

    private func handleQuickAction(_ action: QuickAction) {
        // Handle quick actions (e.g., start focus session, take a break)
        switch action {
        case .startFocus:
            // Start focus session
            break
        case .takeBreak:
            // Take a break
            break
        case .adjustGoals:
            // Adjust productivity goals
            break
        case .reviewPatterns:
            // Review productivity patterns
            break
        }
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let title: String
    let insights: [ProductivityInsight]
    @Binding var selectedInsight: ProductivityInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(insights.prefix(6), id: \.id) { insight in
                    InsightCard(
                        insight: insight,
                        onTap: { selectedInsight = insight }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct InsightCard: View {
    let insight: ProductivityInsight
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(insight.color)

                Spacer()

                PriorityIndicator(priority: insight.priority)
            }

            Text(insight.title)
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .lineLimit(2)

            Text(insight.description)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.gray)
                .lineLimit(3)

            if let impact = insight.impact {
                Text("Impact: \(impact)")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(insight.color.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(insight.color.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Trend Analysis Section

struct TrendAnalysisSection: View {
    let trends: [TrendData]
    let insights: [ProductivityInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trend Analysis")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(trends.prefix(3), id: \.id) { trend in
                        TrendCard(trend: trend, insights: insights)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct TrendCard: View {
    let trend: TrendData
    let insights: [ProductivityInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trend.metricName)
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Text(trend.periodDescription)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(trend.trendDirection.arrow)
                            .foregroundColor(trend.trendDirection.color)
                        Text(String(format: "%.1f%%", trend.trendStrength * 100))
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(trend.trendDirection.color)
                    }

                    Text("trend")
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.gray)
                }
            }

            // Mini trend visualization
            MiniTrendView(trend: trend)

            // Related insights
            let relatedInsights = insights.filter { insight in
                insight.relatedMetrics.contains(trend.metricName)
            }

            if !relatedInsights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related Insights")
                        .font(.custom("Nunito", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    ForEach(relatedInsights.prefix(2), id: \.id) { insight in
                        HStack {
                            Circle()
                                .fill(insight.color)
                                .frame(width: 4, height: 4)

                            Text(insight.title)
                                .font(.custom("Nunito", size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct MiniTrendView: View {
    let trend: TrendData

    var body: some View {
        GeometryReader { geometry in
            let points = generateTrendPoints(in: geometry.size, from: trend.datapoints)

            Path { path in
                guard points.count > 1 else { return }

                path.move(to: points[0])
                for i in 1..<points.count {
                    path.addLine(to: points[i])
                }
            }
            .trim(from: 0, to: 1)
            .stroke(
                trend.trendDirection.color,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 60)
    }

    private func generateTrendPoints(in size: CGSize, from datapoints: [TrendData.DataPoint]) -> [CGPoint] {
        guard !datapoints.isEmpty else { return [] }

        let maxValue = datapoints.map(\.value).max() ?? 1
        let minValue = datapoints.map(\.value).min() ?? 0
        let range = maxValue - minValue

        return datapoints.enumerated().map { index, point in
            let x = CGFloat(index) / CGFloat(datapoints.count - 1) * size.width
            let normalizedValue = range > 0 ? (point.value - minValue) / range : 0.5
            let y = size.height * (1 - normalizedValue)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Recommendations Section

struct RecommendationsSection: View {
    let recommendations: [Recommendation]
    @Binding var expandedRecommendation: Recommendation?
    let onApplyAction: (Recommendation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(recommendations.prefix(5), id: \.id) { recommendation in
                    RecommendationCard(
                        recommendation: recommendation,
                        isExpanded: expandedRecommendation?.id == recommendation.id,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expandedRecommendation = expandedRecommendation?.id == recommendation.id ? nil : recommendation
                            }
                        },
                        onApplyAction: { onApplyAction(recommendation) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    let isExpanded: Bool
    let onToggle: () -> Void
    let onApplyAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recommendation.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(recommendation.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Text(recommendation.category.displayName)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            Text(recommendation.description)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.gray)
                .lineLimit(isExpanded ? nil : 2)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !recommendation.steps.isEmpty {
                        Text("Steps to implement:")
                            .font(.custom("Nunito", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(recommendation.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.custom("Nunito", size: 12))
                                        .fontWeight(.medium)
                                        .foregroundColor(recommendation.color)

                                    Text(step)
                                        .font(.custom("Nunito", size: 12))
                                        .foregroundColor(.gray)

                                    Spacer()
                                }
                            }
                        }
                    }

                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                            .foregroundColor(.green)

                        Text("Expected impact: \(recommendation.impactDescription)")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.green)
                    }

                    Button(action: onApplyAction) {
                        Text("Apply Recommendation")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(recommendation.color)
                            .cornerRadius(8)
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

// MARK: - Performance Patterns Section

struct PerformancePatternsSection: View {
    let insights: [ProductivityInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Patterns")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(insights.prefix(4), id: \.id) { insight in
                    PatternCard(insight: insight)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PatternCard: View {
    let insight: ProductivityInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(insight.color)

                Spacer()

                Text(insight.type.rawValue.capitalized)
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(insight.title)
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .lineLimit(2)

            Text(insight.description)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    let insights: [ProductivityInsight]
    let recommendations: [Recommendation]
    let onQuickAction: (QuickAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(QuickAction.allCases, id: \.self) { action in
                    QuickActionButton(
                        action: action,
                        insights: insights,
                        recommendations: recommendations,
                        onTap: { onQuickAction(action) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

enum QuickAction: CaseIterable {
    case startFocus
    case takeBreak
    case adjustGoals
    case reviewPatterns

    var title: String {
        switch self {
        case .startFocus: return "Start Focus"
        case .takeBreak: return "Take Break"
        case .adjustGoals: return "Adjust Goals"
        case .reviewPatterns: return "Review Patterns"
        }
    }

    var icon: String {
        switch self {
        case .startFocus: return "play.circle.fill"
        case .takeBreak: return "pause.circle.fill"
        case .adjustGoals: return "target"
        case .reviewPatterns: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .startFocus: return .blue
        case .takeBreak: return .orange
        case .adjustGoals: return .green
        case .reviewPatterns: return .purple
        }
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    let insights: [ProductivityInsight]
    let recommendations: [Recommendation]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 24))
                    .foregroundColor(action.color)

                Text(action.title)
                    .font(.custom("Nunito", size: 11))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Detailed Analysis Section

struct DetailedAnalysisSection: View {
    let insights: [ProductivityInsight]
    let trends: [TrendData]
    let recommendations: [Recommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Analysis")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
                .padding(.horizontal)

            VStack(spacing: 16) {
                // Productivity Score Breakdown
                ProductivityScoreBreakdown(insights: insights)

                // Time Analysis
                TimeAnalysisSection(insights: insights, trends: trends)

                // Goal Progress
                GoalProgressSection(insights: insights, recommendations: recommendations)
            }
            .padding(.horizontal)
        }
    }
}

struct ProductivityScoreBreakdown: View {
    let insights: [ProductivityInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Score Breakdown")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            let scoreInsights = insights.filter { $0.category == .productivity }

            if !scoreInsights.isEmpty {
                VStack(spacing: 8) {
                    ForEach(scoreInsights, id: \.id) { insight in
                        HStack {
                            Text(insight.title)
                                .font(.custom("Nunito", size: 14))
                                .foregroundColor(.gray)

                            Spacer()

                            if let value = insight.value {
                                Text(String(format: "%.1f", value))
                                    .font(.custom("Nunito", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                            }
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

struct TimeAnalysisSection: View {
    let insights: [ProductivityInsight]
    let trends: [TrendData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Analysis")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            let timeInsights = insights.filter { $0.category == .timeManagement }

            if !timeInsights.isEmpty {
                VStack(spacing: 8) {
                    ForEach(timeInsights.prefix(3), id: \.id) { insight in
                        HStack {
                            Image(systemName: insight.icon)
                                .font(.system(size: 16))
                                .foregroundColor(insight.color)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(insight.title)
                                    .font(.custom("Nunito", size: 14))
                                    .foregroundColor(.black)

                                Text(insight.description)
                                    .font(.custom("Nunito", size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }

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

struct GoalProgressSection: View {
    let insights: [ProductivityInsight]
    let recommendations: [Recommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Progress")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            let goalInsights = insights.filter { $0.category == .goal }
            let goalRecommendations = recommendations.filter { $0.category == .goalSetting }

            if !goalInsights.isEmpty || !goalRecommendations.isEmpty {
                VStack(spacing: 8) {
                    ForEach(goalInsights.prefix(2), id: \.id) { insight in
                        GoalProgressRow(insight: insight)
                    }

                    ForEach(goalRecommendations.prefix(2), id: \.id) { recommendation in
                        HStack {
                            Image(systemName: "target")
                                .font(.system(size: 16))
                                .foregroundColor(recommendation.color)

                            Text(recommendation.title)
                                .font(.custom("Nunito", size: 14))
                                .foregroundColor(.black)
                                .lineLimit(1)

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

struct GoalProgressRow: View {
    let insight: ProductivityInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(insight.title)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black)

                Spacer()

            if let progress = insight.progressValue {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.custom("Nunito", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(insight.color)
            }
        }

        if let progress = insight.progressValue {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: insight.color))
                .scaleEffect(y: 0.8)
        }
    }
}
}

// MARK: - Supporting Views

struct PriorityIndicator: View {
    let priority: Recommendation.Priority

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<priority.level, id: \.self) { _ in
                Circle()
                    .fill(priority.color)
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Detail View

struct InsightDetailView: View {
    let insight: ProductivityInsight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: insight.icon)
                            .font(.system(size: 28))
                            .foregroundColor(insight.color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.custom("InstrumentSerif-Regular", size: 24))
                                .foregroundColor(.black)

                            Text(insight.type.rawValue.capitalized)
                                .font(.custom("Nunito", size: 16))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        PriorityIndicator(priority: insight.priority)
                    }

                    // Description
                    Text(insight.description)
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.gray)
                        .lineLimit(nil)

                    // Detailed content
                    if let data = insight.data {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Detailed Analysis")
                                .font(.custom("Nunito", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)

                            // Render detailed data based on type
                            DetailedDataView(data: data, color: insight.color)
                        }
                    }

                    // Impact and recommendations
                    if let impact = insight.impact {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expected Impact")
                                .font(.custom("Nunito", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)

                            Text(impact)
                                .font(.custom("Nunito", size: 16))
                                .foregroundColor(.gray)
                        }
                    }

                    // Related metrics
                    if !insight.relatedMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Metrics")
                                .font(.custom("Nunito", size: 18))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(insight.relatedMetrics, id: \.self) { metric in
                                    HStack {
                                        Circle()
                                            .fill(insight.color)
                                            .frame(width: 6, height: 6)

                                        Text(metric)
                                            .font(.custom("Nunito", size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Insight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailedDataView: View {
    let data: [String: String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key + ":")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.black)

                    Spacer()

                    Text(data[key] ?? "")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(color)
                }
            }
        }
    }
}

private extension ProductivityInsight {
    enum Category {
        case productivity
        case pattern
        case timeManagement
        case trend
        case goal
    }

    var category: Category {
        switch type {
        case .peakPerformance, .focusQuality:
            return .productivity
        case .productivityPattern, .taskEfficiency:
            return .pattern
        case .schedulingImprovement:
            return .timeManagement
        case .goalProgress:
            return .goal
        case .energyOptimization, .burnoutRisk:
            return .trend
        }
    }

    var icon: String {
        switch type {
        case .peakPerformance: return "speedometer"
        case .productivityPattern: return "chart.line.uptrend.xyaxis"
        case .energyOptimization: return "bolt.fill"
        case .taskEfficiency: return "checkmark.seal.fill"
        case .schedulingImprovement: return "calendar"
        case .goalProgress: return "target"
        case .burnoutRisk: return "exclamationmark.triangle.fill"
        case .focusQuality: return "eye.fill"
        }
    }

    var color: Color {
        switch type {
        case .peakPerformance: return .green
        case .productivityPattern: return .purple
        case .energyOptimization: return .orange
        case .taskEfficiency: return .blue
        case .schedulingImprovement: return .teal
        case .goalProgress: return .pink
        case .burnoutRisk: return .red
        case .focusQuality: return .indigo
        }
    }

    var priority: Recommendation.Priority {
        switch confidenceLevel {
        case ..<0.4: return .low
        case ..<0.7: return .medium
        case ..<0.9: return .high
        default: return .urgent
        }
    }

    var relatedMetrics: [String] {
        metrics.map(\.name)
    }

    var value: Double? {
        metrics.first?.value
    }

    var progressValue: Double? {
        guard let metric = metrics.first else { return nil }
        if metric.unit.contains("%") {
            return min(max(metric.value / 100, 0), 1)
        }
        if (0...1).contains(metric.value) {
            return metric.value
        }
        return min(max(metric.value / 100, 0), 1)
    }

    var impact: String? {
        recommendations.first?.expectedImpact.displayName
    }

    var data: [String: String]? {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let entries = metrics.reduce(into: [String: String]()) { result, metric in
            let number = NSNumber(value: metric.value)
            let formattedValue = formatter.string(from: number) ?? String(format: "%.1f", metric.value)
            if metric.unit.isEmpty {
                result[metric.name] = formattedValue
            } else {
                result[metric.name] = "\(formattedValue) \(metric.unit)"
            }
        }
        return entries.isEmpty ? nil : entries
    }
}

private extension ProductivityRecommendation.ImpactLevel {
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .moderate: return "Moderate"
        case .significant: return "Significant"
        case .transformative: return "Transformative"
        }
    }
}

private extension Recommendation {
    var icon: String { category.icon }

    var color: Color { category.color }

    var steps: [String] {
        suggestedActions.flatMap { action in
            var items = [action.title]
            items.append(contentsOf: action.steps)
            return items
        }
    }

    var impactDescription: String { estimatedImpact.displayName }
}

private extension TrendData {
    var periodDescription: String {
        TrendData.periodFormatter.string(from: dateRange) ?? ""
    }

    static var periodFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#if DEBUG
#Preview {
    let focusTimeMetric = ProductivityMetric(
        name: "Focus Time",
        value: 180,
        unit: "minutes",
        category: .focusTime,
        metadata: ["trend": "up"]
    )

    let productivityScoreMetric = ProductivityMetric(
        name: "Productivity Score",
        value: 0.85,
        unit: "index",
        category: .productivity,
        metadata: ["trend": "steady"]
    )

    return InsightsView(
        insights: [
            ProductivityInsight(
                type: .productivityPattern,
                title: "Peak Productivity Hours",
                description: "You're most productive between 9 AM and 12 PM",
                metrics: [
                    ProductivityMetric(
                        name: "Focus Time",
                        value: 195,
                        unit: "minutes",
                        category: .focusTime
                    ),
                    ProductivityMetric(
                        name: "Productivity Score",
                        value: 88,
                        unit: "%",
                        category: .productivity
                    )
                ],
                recommendations: [
                    ProductivityRecommendation(
                        category: .focus,
                        title: "Optimize Morning Routine",
                        description: "Start your most important work during peak hours",
                        expectedImpact: .significant,
                        difficulty: .moderate,
                        estimatedTimeToImplement: 900,
                        steps: [
                            "Schedule important tasks before 12 PM",
                            "Minimize meetings during morning hours",
                            "Prepare work materials the night before"
                        ]
                    )
                ],
                confidenceLevel: 0.88
            )
        ],
        recommendations: [
            Recommendation(
                title: "Optimize Morning Routine",
                description: "Start your most important work during peak hours",
                category: .focusImprovement,
                priority: .high,
                actionable: true,
                estimatedImpact: .significant,
                suggestedActions: [
                    Recommendation.SuggestedAction(
                        title: "Schedule focus blocks",
                        description: "Plan dedicated deep work sessions each morning",
                        difficulty: .moderate,
                        estimatedTime: 1800,
                        steps: [
                            "Reserve 9-11 AM for deep work",
                            "Silence notifications",
                            "Review top priorities"
                        ]
                    ),
                    Recommendation.SuggestedAction(
                        title: "Prepare the night before",
                        description: "Lay out tasks and context to start strong",
                        difficulty: .easy,
                        estimatedTime: 600,
                        steps: [
                            "Review tomorrow's agenda",
                            "List the top three tasks",
                            "Stage supporting documents"
                        ]
                    )
                ],
                evidence: [
                    ProductivityMetric(
                        name: "Morning Focus Time",
                        value: 120,
                        unit: "minutes",
                        category: .focusTime
                    )
                ],
                createdAt: Date(),
                dismissedAt: nil
            )
        ],
        trends: [
            TrendData(
                metricName: "Focus Time",
                datapoints: [
                    TrendData.DataPoint(date: Date().addingTimeInterval(-3 * 24 * 3600), value: 150),
                    TrendData.DataPoint(date: Date().addingTimeInterval(-2 * 24 * 3600), value: 165),
                    TrendData.DataPoint(date: Date().addingTimeInterval(-1 * 24 * 3600), value: 175),
                    TrendData.DataPoint(date: Date(), value: 185)
                ],
                trendDirection: .increasing,
                trendStrength: 0.7,
                insights: [],
                dateRange: DateInterval(
                    start: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                    end: Date()
                )
            )
        ],
        configuration: DashboardConfiguration(
            widgets: [],
            theme: .default,
            layout: .default,
            preferences: .default.updating(timeRange: .week, showDetailedAnalysis: true)
        )
    )
}
#endif
