//
//  ProductivityCharts.swift
//  FocusLock
//
//  Comprehensive charts and visualizations for dashboard productivity metrics
//

import SwiftUI
import Charts

struct ProductivityCharts: View {
    let metrics: [ProductivityMetric]
    let trends: [TrendData]
    let style: ChartStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Focus Time Chart
                FocusTimeChart(metrics: metrics.filter { $0.category == .focusTime }, style: style)
                    .frame(height: 250)

                // Productivity Score Chart
                ProductivityScoreChart(metrics: metrics.filter { $0.category == .productivity }, style: style)
                    .frame(height: 200)

                // App Usage Chart
                AppUsageChart(metrics: metrics.filter { $0.category == .appUsage }, style: style)
                    .frame(height: 300)

                // Trend Analysis Chart
                if !trends.isEmpty {
                    TrendAnalysisChart(trends: trends, style: style)
                        .frame(height: 250)
                }

                // Task Progress Chart
                TaskProgressChart(metrics: metrics.filter { $0.category == .taskCompletion }, style: style)
                    .frame(height: 200)
            }
            .padding()
        }
    }
}

enum ChartStyle {
    case minimal
    case colorful
    case monochrome

    var primaryColor: Color {
        switch self {
        case .minimal: return .blue
        case .colorful: return .purple
        case .monochrome: return .gray
        }
    }

    var accentColor: Color {
        switch self {
        case .minimal: return .blue.opacity(0.8)
        case .colorful: return .orange
        case .monochrome: return .black
        }
    }
}

// MARK: - Focus Time Chart

struct FocusTimeChart: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Time Overview")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    message: "No focus time data available",
                    description: "Start tracking focus sessions to see your productivity patterns"
                )
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(metrics, id: \.id) { metric in
                        BarMark(
                            x: .value("Date", dayFormatter.string(from: metric.timestamp)),
                            y: .value("Minutes", metric.value)
                        )
                        .foregroundStyle(style.primaryColor)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - Productivity Score Chart

struct ProductivityScoreChart: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Score")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    message: "No productivity data available",
                    description: "Complete more tasks to see your productivity trends"
                )
                .frame(height: 150)
            } else {
                Chart {
                    ForEach(metrics, id: \.id) { metric in
                        LineMark(
                            x: .value("Date", dayFormatter.string(from: metric.timestamp)),
                            y: .value("Score", metric.value * 100)
                        )
                        .foregroundStyle(style.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol {
                      Circle().strokeBorder(lineWidth: 2).fill(Color.white)
                  }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - App Usage Chart

struct AppUsageChart: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle
    @State private var selectedAngle: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("App Usage")
                    .font(.custom("InstrumentSerif-Regular", size: 24))
                    .foregroundColor(.black)

                Spacer()

                if !metrics.isEmpty {
                    Text("Total: \(totalMinutes) min")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }
            }

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "app.badge",
                    message: "No app usage data available",
                    description: "Start tracking to see which apps you use most"
                )
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                        SectorMark(
                            angle: .value("Time", metric.value),
                            innerRadius: .ratio(0.4),
                            angularInset: 1
                        )
                        .foregroundStyle(colorForApp(at: index, total: metrics.count))
                        .opacity(0.8)
                    }
                }
                .frame(height: 250)
                .chartAngleSelection(value: Binding(
                get: { selectedAngle ?? 270 },
                set: { selectedAngle = $0 }
            ))
                .chartBackground { _ in
                    Color.clear
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var totalMinutes: Int {
        Int(metrics.reduce(0) { $0 + $1.value })
    }

    private func colorForApp(at index: Int, total: Int) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .red, .purple,
            .pink, .teal, .indigo, .brown, .gray
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Trend Analysis Chart

struct TrendAnalysisChart: View {
    let trends: [TrendData]
    let style: ChartStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Analysis")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            // Focus Time Trend
            if let focusTrend = trends.first(where: { $0.metricName == "Focus Time" }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(focusTrend.metricName)
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.black)

                        Spacer()

                        HStack(spacing: 4) {
                            Text(focusTrend.trendDirection.arrow)
                                .foregroundColor(focusTrend.trendDirection.color)
                            Text(String(format: "%.1f%%", focusTrend.trendStrength * 100))
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(.gray)
                        }
                    }

                    Chart {
                        ForEach(focusTrend.datapoints, id: \.id) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Minutes", point.value)
                            )
                            .foregroundStyle(style.primaryColor)
                        }

                        RuleMark(y: .value("Average", calculateAverage(from: focusTrend.datapoints)))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic)
                    }
                    .frame(height: 180)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func calculateAverage(from datapoints: [TrendData.DataPoint]) -> Double {
        guard !datapoints.isEmpty else { return 0 }
        return datapoints.reduce(0) { $0 + $1.value } / Double(datapoints.count)
    }
}

// MARK: - Task Progress Chart

struct TaskProgressChart: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Progress")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    message: "No task data available",
                    description: "Complete tasks to track your progress over time"
                )
                .frame(height: 150)
            } else {
                Chart {
                    ForEach(metrics, id: \.id) { metric in
                        BarMark(
                            x: .value("Tasks", metric.name),
                            y: .value("Count", metric.value)
                        )
                        .foregroundStyle(style.primaryColor)
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Widget Chart Views

struct WidgetProductivityScore: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle

    var body: some View {
        VStack(spacing: 8) {
            Text("Productivity Score")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            if let latestScore = metrics.last(where: { $0.category == .productivity }) {
                ZStack {
                    Circle()
                        .trim(from: 0.0, to: latestScore.value)
                        .stroke(style.primaryColor, lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Text("\(Int(latestScore.value * 100))%")
                        .font(.custom("Nunito", size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(style.primaryColor)
                }
            } else {
                ZStack {
                    Circle()
                        .stroke(.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Text("--")
                        .font(.custom("Nunito", size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct WidgetFocusTimeChart: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle

    var body: some View {
        VStack(spacing: 8) {
            Text("Focus Time Today")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            if let todayFocus = metrics.first(where: {
                $0.category == .focusTime &&
                Calendar.current.isDateInToday($0.timestamp)
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(style.primaryColor)
                            .frame(width: 8, height: 8)

                        Text("\(Int(todayFocus.value)) min")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }

                    Text("\(Int(todayFocus.value / 60))h \(Int(todayFocus.value) % 60)m")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }
            } else {
                HStack {
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Text("No data")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct WidgetTopApps: View {
    let metrics: [ProductivityMetric]
    let style: ChartStyle

    var body: some View {
        VStack(spacing: 8) {
            Text("Top Apps")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            let topApps = Array(metrics.filter { $0.category == .appUsage }
                .sorted { $0.value > $1.value }
                .prefix(3))

            if topApps.isEmpty {
                HStack {
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 6, height: 6)

                    Text("No data")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(topApps, id: \.id) { app in
                        HStack {
                            Circle()
                                .fill(colorForApp(at: topApps.firstIndex(of: app)!))
                                .frame(width: 6, height: 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.custom("Nunito", size: 12))
                                    .foregroundColor(.black)
                                    .lineLimit(1)

                                Text("\(Int(app.value)) min")
                                    .font(.custom("Nunito", size: 10))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Rectangle()
                                .fill(style.accentColor.opacity(0.2))
                                .frame(width: app.value * 2, height: 4)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func colorForApp(at index: Int) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .red, .purple,
            .pink, .teal, .indigo, .brown, .gray
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Supporting Views

struct EmptyStateView: View {
    let icon: String
    let message: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))

            Text(message)
                .font(.custom("Nunito", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.gray)

            Text(description)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chart Legend

struct ChartLegend: View {
    let items: [LegendItem]
    let style: ChartStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.id) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)

                    Text(item.label)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black)
                }
            }
        }
    }
}

struct LegendItem {
    let id = UUID()
    let label: String
    let color: Color
}

#Preview {
    ProductivityCharts(
        metrics: [
            ProductivityMetric(
                name: "Focus Time",
                value: 120,
                unit: "minutes",
                category: .focusTime,
                timestamp: Date()
            ),
            ProductivityMetric(
                name: "Productivity Score",
                value: 0.85,
                unit: "score",
                category: .productivity,
                timestamp: Date()
            ),
            ProductivityMetric(
                name: "Safari",
                value: 45,
                unit: "minutes",
                category: .appUsage,
                timestamp: Date(),
                metadata: ["app_name": "Safari"]
            )
        ],
        trends: [],
        style: .colorful
    )
}