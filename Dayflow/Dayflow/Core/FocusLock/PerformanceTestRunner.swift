//
//  PerformanceTestRunner.swift
//  FocusLock
//
//  Quick performance validation runner for development and CI
//

import Foundation
import SwiftUI

@MainActor
class PerformanceTestRunner: ObservableObject {
    static let shared = PerformanceTestRunner()

    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentTest: String = ""
    @Published var lastReport: PerformanceTestReport?

    private let validator = PerformanceValidator.shared

    func runQuickValidation() async {
        await runValidationSuite(name: "Quick Validation", duration: 60)
    }

    func runFullValidation() async {
        await runValidationSuite(name: "Full Validation", duration: 600) // 10 minutes
    }

    func runStressTest() async {
        await runValidationSuite(name: "Stress Test", duration: 300) // 5 minutes
    }

    private func runValidationSuite(name: String, duration: TimeInterval) async {
        isRunning = true
        progress = 0.0
        currentTest = "Starting \(name)..."

        let startTime = Date()

        // Run the validation
        let report = await validator.runComprehensivePerformanceTests()

        // Update UI
        currentTest = "Generating report..."
        progress = 0.9

        // Simulate some reporting time
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        lastReport = report
        currentTest = "\(name) completed"
        progress = 1.0

        let durationTaken = Date().timeIntervalSince(startTime)
        print("🚀 \(name) completed in \(String(format: "%.1f", durationTaken))s")
        print("📊 Results: \(report.passedTests)/\(report.totalTests) tests passed")
        print("💯 Pass rate: \(String(format: "%.1f", report.passRate * 100))%")

        if !report.isHealthy {
            print("⚠️  Critical failures detected:")
            for failure in report.criticalFailures {
                print("   ❌ \(failure.testName): \(failure.error ?? "Performance threshold exceeded")")
            }
        }

        if !report.recommendations.isEmpty {
            print("💡 Recommendations:")
            for recommendation in report.recommendations.prefix(5) {
                print("   • \(recommendation)")
            }
        }

        isRunning = false
    }

    func generateMarkdownReport() -> String {
        guard let report = lastReport else {
            return "# Performance Test Report\n\nNo test results available."
        }

        var markdown = "# FocusLock Performance Test Report\n\n"
        markdown += "**Generated:** \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .medium, timeStyle: .medium))\n\n"
        markdown += "## Summary\n\n"
        markdown += "- **Pass Rate:** \(String(format: "%.1f", report.passRate * 100))%\n"
        markdown += "- **Tests Passed:** \(report.passedTests)/\(report.totalTests)\n"
        markdown += "- **Status:** \(report.isHealthy ? "✅ Healthy" : "⚠️ Needs Attention")\n"
        markdown += "- **Overall:** \(report.summary)\n\n"

        if !report.criticalFailures.isEmpty {
            markdown += "## 🚨 Critical Failures\n\n"
            for failure in report.criticalFailures {
                markdown += "### \(failure.testName)\n"
                markdown += "- **Status:** ❌ Failed\n"
                markdown += "- **CPU Usage:** \(String(format: "%.1f", failure.cpuUsage))%\n"
                markdown += "- **Memory Usage:** \(String(format: "%.1f", failure.memoryUsage))MB\n"
                if let error = failure.error {
                    markdown += "- **Error:** \(error)\n"
                }
                markdown += "\n"
            }
        }

        if !report.warnings.isEmpty {
            markdown += "## ⚠️ Warnings\n\n"
            for warning in report.warnings {
                markdown += "### \(warning.testName)\n"
                markdown += "- **Status:** ⚠️ Warning\n"
                markdown += "- **CPU Usage:** \(String(format: "%.1f", warning.cpuUsage))%\n"
                markdown += "- **Memory Usage:** \(String(format: "%.1f", warning.memoryUsage))MB\n"
                if let error = warning.error {
                    markdown += "- **Issue:** \(error)\n"
                }
                markdown += "\n"
            }
        }

        if !report.recommendations.isEmpty {
            markdown += "## 💡 Recommendations\n\n"
            for (index, recommendation) in report.recommendations.enumerated() {
                markdown += "\(index + 1). \(recommendation)\n"
            }
            markdown += "\n"
        }

        markdown += "## 📊 Detailed Results\n\n"
        markdown += "| Test Name | Status | CPU (%) | Memory (MB) | Notes |\n"
        markdown += "|-----------|--------|---------|-------------|-------|\n"

        for result in report.detailedResults {
            let status = result.passed ? "✅ Pass" : "❌ Fail"
            let notes = result.error ?? "\(result.additionalMetrics.count) metrics"
            markdown += "| \(result.testName) | \(status) | \(String(format: "%.1f", result.cpuUsage)) | \(String(format: "%.1f", result.memoryUsage)) | \(notes) |\n"
        }

        return markdown
    }
}

// MARK: - SwiftUI Integration

struct PerformanceTestView: View {
    @StateObject private var runner = PerformanceTestRunner.shared
    @State private var showingReport = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Performance Test Suite")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color.black)

            if runner.isRunning {
                VStack(spacing: 12) {
                    ProgressView(value: runner.progress)
                        .progressViewStyle(LinearProgressViewStyle())

                    Text(runner.currentTest)
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(Color.gray)

                    Text("\(Int(runner.progress * 100))% Complete")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(Color.gray)
                }
                .frame(width: 300)
            } else {
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await runner.runQuickValidation()
                        }
                    }) {
                        Text("Run Quick Validation")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        Task {
                            await runner.runFullValidation()
                        }
                    }) {
                        Text("Run Full Validation")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        Task {
                            await runner.runStressTest()
                        }
                    }) {
                        Text("Run Stress Test")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if runner.lastReport != nil {
                        Button(action: {
                            showingReport = true
                        }) {
                            Text("View Last Report")
                                .font(.custom("Nunito", size: 14))
                                .foregroundColor(Color.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            Spacer()

            if let report = runner.lastReport {
                VStack(spacing: 8) {
                    HStack {
                        Text("Last Test Results")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(Color.gray)

                        Spacer()

                        Circle()
                            .fill(report.isHealthy ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text(report.summary)
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(report.isHealthy ? Color.green : Color.orange)
                    }

                    HStack {
                        Text("Pass Rate: \(String(format: "%.1f", report.passRate * 100))%")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(Color.gray)

                        Spacer()

                        Text("\(report.passedTests)/\(report.totalTests) tests")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(Color.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
        .sheet(isPresented: $showingReport) {
            PerformanceReportView(report: runner.lastReport!)
        }
    }
}

struct PerformanceReportView: View {
    let report: PerformanceTestReport
    @Environment(\.dismiss) private var dismiss
    @State private var showingMarkdown = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Test Report")
                        .font(.custom("InstrumentSerif-Regular", size: 20))
                        .foregroundColor(Color.black)

                    Text("Generated \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .medium, timeStyle: .medium))")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(Color.gray)

                    HStack {
                        Circle()
                            .fill(report.isHealthy ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text(report.summary)
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(report.isHealthy ? Color.green : Color.orange)

                        Spacer()

                        Text("\(String(format: "%.1f", report.passRate * 100))%")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(Color.blue)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                // Results Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Results")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color.black)

                    HStack {
                        Text("Passed:")
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.gray)

                        Text("\(report.passedTests)")
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.green)

                        Spacer()

                        Text("Failed:")
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.gray)

                        Text("\(report.totalTests - report.passedTests)")
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.red)
                    }
                }

                // Failures
                if !report.criticalFailures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🚨 Critical Failures")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color.red)

                        ForEach(report.criticalFailures, id: \.testName) { failure in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(failure.testName)
                                    .font(.custom("Nunito", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.black)

                                if let error = failure.error {
                                    Text(error)
                                        .font(.custom("Nunito", size: 12))
                                        .foregroundColor(Color.gray)
                                }

                                HStack {
                                    Text("CPU: \(String(format: "%.1f", failure.cpuUsage))%")
                                        .font(.custom("Nunito", size: 12))
                                        .foregroundColor(Color.gray)

                                    Spacer()

                                    Text("Memory: \(String(format: "%.1f", failure.memoryUsage))MB")
                                        .font(.custom("Nunito", size: 12))
                                        .foregroundColor(Color.gray)
                                }
                            }
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }

                // Recommendations
                if !report.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Recommendations")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color.blue)

                        ForEach(Array(report.recommendations.enumerated()), id: \.offset) { index, recommendation in
                            Text("\(index + 1). \(recommendation)")
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(Color.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Spacer()

                // Actions
                HStack {
                    Button(action: {
                        let markdown = PerformanceTestRunner.shared.generateMarkdownReport()
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(markdown, forType: .string)
                    }) {
                        Text("Copy Report")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(Color.gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .navigationTitle("Performance Report")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

#Preview {
    PerformanceTestView()
}