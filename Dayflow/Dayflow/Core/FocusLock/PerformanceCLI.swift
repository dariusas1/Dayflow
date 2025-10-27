//
//  PerformanceCLI.swift
//  FocusLock
//
//  Command-line interface for performance testing
//

import Foundation
import UserNotifications

struct PerformanceCLI {
    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else {
            showUsage()
            return
        }

        let command = arguments[1]
        let args = Array(arguments.dropFirst(2))

        switch command {
        case "validate":
            await ValidateCommand().run(with: args)
        case "report":
            await ReportCommand().run(with: args)
        case "watch":
            await WatchCommand().run(with: args)
        default:
            print("❌ Unknown command: \(command)")
            showUsage()
        }
    }

    private static func showUsage() {
        print("FocusLock Performance Testing CLI")
        print("Usage: focuslock-perf <command> [options]")
        print("")
        print("Commands:")
        print("  validate  Run performance validation tests")
        print("  report    Generate performance report from last test run")
        print("  watch     Continuously monitor performance metrics")
        print("")
        print("Use 'help <command>' for more information on a specific command.")
    }
}

// MARK: - Validate Command

struct ValidateCommand {
    func run(with arguments: [String]) async {
        var validationType: ValidationType = .quick
        var outputFormat: OutputFormat = .console
        var outputPath: String?
        var strict = false

        // Parse arguments
        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--type", "-t":
                if i + 1 < arguments.count {
                    validationType = ValidationType(rawValue: arguments[i + 1]) ?? .quick
                    i += 1
                }
            case "--format", "-f":
                if i + 1 < arguments.count {
                    outputFormat = OutputFormat(rawValue: arguments[i + 1]) ?? .console
                    i += 1
                }
            case "--output", "-o":
                if i + 1 < arguments.count {
                    outputPath = arguments[i + 1]
                    i += 1
                }
            case "--strict", "-s":
                strict = true
            default:
                print("⚠️  Unknown option: \(arguments[i])")
            }
            i += 1
        }

        print("🚀 Starting FocusLock Performance Validation")
        print("📊 Validation type: \(validationType.description)")
        print("⏱️  Estimated duration: \(validationType.duration)")

        let runner = PerformanceTestRunner.shared
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            switch validationType {
            case .quick:
                await runner.runQuickValidation()
            case .full:
                await runner.runFullValidation()
            case .stress:
                await runner.runStressTest()
            }

            semaphore.signal()
        }

        semaphore.wait()

        guard let report = runner.lastReport else {
            print("❌ No test results available")
            if strict { exit(1) }
            return
        }

        // Output results
        switch outputFormat {
        case .console:
            outputToConsole(report)
        case .json:
            outputToJSON(report, outputPath: outputPath)
        case .markdown:
            outputToMarkdown(report, outputPath: outputPath)
        }

        // Exit with appropriate status
        if !report.isHealthy {
            print("\n⚠️  Performance validation has issues")
            if strict {
                exit(1)
            }
        } else {
            print("\n✅ Performance validation passed successfully")
        }
    }

    func outputToConsole(_ report: PerformanceTestReport) {
        print("\n" + String(repeating: "=", count: 60))
        print("PERFORMANCE VALIDATION RESULTS")
        print(String(repeating: "=", count: 60))

        print("\n📊 SUMMARY:")
        print("   Pass Rate: \(String(format: "%.1f", report.passRate * 100))%")
        print("   Tests Passed: \(report.passedTests)/\(report.totalTests)")
        print("   Status: \(report.isHealthy ? "✅ Healthy" : "⚠️ Needs Attention")")
        print("   Overall: \(report.summary)")

        if !report.criticalFailures.isEmpty {
            print("\n🚨 CRITICAL FAILURES:")
            for failure in report.criticalFailures {
                print("   ❌ \(failure.testName)")
                if let error = failure.error {
                    print("      \(error)")
                }
                print("      CPU: \(String(format: "%.1f", failure.cpuUsage))%, Memory: \(String(format: "%.1f", failure.memoryUsage))MB")
            }
        }

        if !report.warnings.isEmpty {
            print("\n⚠️  WARNINGS:")
            for warning in report.warnings {
                print("   ⚠️  \(warning.testName)")
                print("      CPU: \(String(format: "%.1f", warning.cpuUsage))%, Memory: \(String(format: "%.1f", warning.memoryUsage))MB")
            }
        }

        if !report.recommendations.isEmpty {
            print("\n💡 RECOMMENDATIONS:")
            for (index, recommendation) in report.recommendations.enumerated() {
                print("   \(index + 1). \(recommendation)")
            }
        }

        print("\n" + String(repeating: "=", count: 60))
    }

    private func outputToJSON(_ report: PerformanceTestReport, outputPath: String?) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(report)
            let jsonString = String(data: data, encoding: String.Encoding.utf8)!

            if let outputPath = outputPath {
                try jsonString.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
                print("📄 JSON report written to: \(outputPath)")
            } else {
                print(jsonString)
            }
        } catch {
            print("❌ Failed to generate JSON report: \(error)")
        }
    }

    private func outputToMarkdown(_ report: PerformanceTestReport, outputPath: String?) {
        let runner = PerformanceTestRunner.shared
        let markdown = runner.generateMarkdownReport()

        do {
            if let outputPath = outputPath {
                try markdown.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
                print("📄 Markdown report written to: \(outputPath)")
            } else {
                print(markdown)
            }
        } catch {
            print("❌ Failed to generate Markdown report: \(error)")
        }
    }
}

// MARK: - Report Command

struct ReportCommand {
    func run(with arguments: [String]) async {
        var format: OutputFormat = .markdown
        var outputPath: String?

        // Parse arguments
        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--format", "-f":
                if i + 1 < arguments.count {
                    format = OutputFormat(rawValue: arguments[i + 1]) ?? .markdown
                    i += 1
                }
            case "--output", "-o":
                if i + 1 < arguments.count {
                    outputPath = arguments[i + 1]
                    i += 1
                }
            default:
                print("⚠️  Unknown option: \(arguments[i])")
            }
            i += 1
        }

        let runner = PerformanceTestRunner.shared

        guard let report = runner.lastReport else {
            print("❌ No test results available. Run 'validate' first.")
            exit(1)
        }

        switch format {
        case .markdown:
            let markdown = runner.generateMarkdownReport()
            do {
                if let outputPath = outputPath {
                    try markdown.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
                    print("📄 Markdown report written to: \(outputPath)")
                } else {
                    print(markdown)
                }
            } catch {
                print("❌ Failed to write Markdown report: \(error)")
            }
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            do {
                let data = try encoder.encode(report)
                let jsonString = String(data: data, encoding: String.Encoding.utf8)!

                if let outputPath = outputPath {
                    try jsonString.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
                    print("📄 JSON report written to: \(outputPath)")
                } else {
                    print(jsonString)
                }
            } catch {
                print("❌ Failed to generate JSON report: \(error)")
            }
        case .console:
            // Reuse console output from validate command
            let validateCmd = ValidateCommand()
            validateCmd.outputToConsole(report)
        }
    }
}

// MARK: - Watch Command

struct WatchCommand {
    func run(with arguments: [String]) async {
        var interval: Int = 300
        var iterations: Int = 0
        var alert = false

        // Parse arguments
        var i = 0
        while i < arguments.count {
            switch arguments[i] {
            case "--interval", "-i":
                if i + 1 < arguments.count, let value = Int(arguments[i + 1]) {
                    interval = value
                    i += 1
                }
            case "--iterations", "-n":
                if i + 1 < arguments.count, let value = Int(arguments[i + 1]) {
                    iterations = value
                    i += 1
                }
            case "--alert", "-a":
                alert = true
            default:
                print("⚠️  Unknown option: \(arguments[i])")
            }
            i += 1
        }
        print("👁️  Starting performance monitoring")
        print("⏱️  Interval: \(interval) seconds")
        print("🔄 Iterations: \(iterations == 0 ? "Unlimited" : String(iterations))")

        let runner = PerformanceTestRunner.shared
        var currentIteration = 0
        var lastReport: PerformanceTestReport?

        while iterations == 0 || currentIteration < iterations {
            currentIteration += 1
            print("\n" + String(repeating: "=", count: 50))
            print("🏃 Iteration \(currentIteration) - \(Date())")
            print(String(repeating: "=", count: 50))

            let semaphore = DispatchSemaphore(value: 0)

            Task {
                await runner.runQuickValidation()
                semaphore.signal()
            }

            semaphore.wait()

            guard let report = runner.lastReport else {
                print("❌ No results for iteration \(currentIteration)")
                continue
            }

            // Compare with previous run
            if let lastReport = lastReport {
                let healthChange = report.passRate - lastReport.passRate
                if healthChange < -0.1 {
                    print("⚠️  Performance degraded by \(String(format: "%.1f", -healthChange * 100))%")
                } else if healthChange > 0.05 {
                    print("✅ Performance improved by \(String(format: "%.1f", healthChange * 100))%")
                } else {
                    print("➡️  Performance stable")
                }
            }

            print("📊 Pass Rate: \(String(format: "%.1f", report.passRate * 100))%")
            print("🎯 Status: \(report.isHealthy ? "Healthy" : "Needs Attention")")

            if !report.isHealthy && alert {
                print("🚨 ALERT: Performance issues detected!")

                // System notification (macOS)
                let notification = UNMutableNotificationContent()
                notification.title = "FocusLock Performance Alert"
                notification.body = "Performance issues detected: \(report.summary)"
                notification.sound = .default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: notification,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Failed to send notification: \(error)")
                    }
                }
            }

            lastReport = report

            if iterations > 0 && currentIteration < iterations {
                print("⏳ Waiting \(interval) seconds...")
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }

        print("\n✅ Monitoring completed after \(currentIteration) iterations")
    }
}

// MARK: - Supporting Types

enum ValidationType: String, CaseIterable {
    case quick = "quick"
    case full = "full"
    case stress = "stress"

    var description: String {
        switch self {
        case .quick: return "Quick validation (1 minute)"
        case .full: return "Full validation (10 minutes)"
        case .stress: return "Stress test (5 minutes)"
        }
    }

    var duration: String {
        switch self {
        case .quick: return "~1 minute"
        case .full: return "~10 minutes"
        case .stress: return "~5 minutes"
        }
    }
}

enum OutputFormat: String, CaseIterable {
    case console = "console"
    case json = "json"
    case markdown = "markdown"
}

// MARK: - Main Entry Point

// This would be called from the main app or a command-line tool
extension PerformanceCLI {
    static func runFromArguments(_ arguments: [String]) async {
        let fullArgs = ["focuslock-perf"] + arguments
        await PerformanceCLI.main(with: fullArgs)
    }

    static func main(with arguments: [String]) async {
        let args = arguments
        guard args.count > 1 else {
            showUsage()
            return
        }

        let command = args[1]
        let commandArgs = Array(args.dropFirst(2))

        switch command {
        case "validate":
            await ValidateCommand().run(with: commandArgs)
        case "report":
            await ReportCommand().run(with: commandArgs)
        case "watch":
            await WatchCommand().run(with: commandArgs)
        default:
            print("❌ Unknown command: \(command)")
            showUsage()
        }
    }
}