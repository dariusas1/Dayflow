//
//  PerformanceModels.swift
//  FocusLock
//
//  Shared performance testing models used across the performance validation system
//

import Foundation

// MARK: - Performance Test Result

public struct PerformanceTestResult: Codable {
    public let testName: String
    public let passed: Bool
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let additionalMetrics: [String: Any]
    public let error: String?

    public init(testName: String, passed: Bool, cpuUsage: Double, memoryUsage: Double, additionalMetrics: [String: Any] = [:], error: String? = nil) {
        self.testName = testName
        self.passed = passed
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.additionalMetrics = additionalMetrics
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case testName, passed, cpuUsage, memoryUsage, additionalMetrics, error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(testName, forKey: .testName)
        try container.encode(passed, forKey: .passed)
        try container.encode(cpuUsage, forKey: .cpuUsage)
        try container.encode(memoryUsage, forKey: .memoryUsage)

        // Filter additionalMetrics to only include encodable values
        let encodableMetrics = additionalMetrics.compactMapValues { value -> String? in
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? Int {
                return String(numberValue)
            } else if let doubleValue = value as? Double {
                return String(doubleValue)
            } else if let boolValue = value as? Bool {
                return String(boolValue)
            }
            return nil
        }
        try container.encode(encodableMetrics, forKey: .additionalMetrics)

        if let error = error {
            try container.encode(error, forKey: .error)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        testName = try container.decode(String.self, forKey: .testName)
        passed = try container.decode(Bool.self, forKey: .passed)
        cpuUsage = try container.decode(Double.self, forKey: .cpuUsage)
        memoryUsage = try container.decode(Double.self, forKey: .memoryUsage)
        error = try container.decodeIfPresent(String.self, forKey: .error)

        // Decode additionalMetrics as String-to-String mapping, then convert back to appropriate types
        let decodedMetrics = try container.decodeIfPresent([String: String].self, forKey: .additionalMetrics) ?? [:]
        var restoredMetrics: [String: Any] = [:]

        for (key, stringValue) in decodedMetrics {
            // Try to restore original types from string representations
            if let intValue = Int(stringValue) {
                restoredMetrics[key] = intValue
            } else if let doubleValue = Double(stringValue) {
                restoredMetrics[key] = doubleValue
            } else if let boolValue = Bool(stringValue) {
                restoredMetrics[key] = boolValue
            } else {
                restoredMetrics[key] = stringValue
            }
        }

        additionalMetrics = restoredMetrics
    }
}

extension PerformanceTestResult: @unchecked Sendable {}

// MARK: - Performance Test Report

public struct PerformanceTestReport: Codable, Sendable {
    public let timestamp: Date
    public let passRate: Double
    public let totalTests: Int
    public let passedTests: Int
    public let criticalFailures: [PerformanceTestResult]
    public let warnings: [PerformanceTestResult]
    public let detailedResults: [PerformanceTestResult]
    public let recommendations: [String]

    public init(
        timestamp: Date,
        passRate: Double,
        totalTests: Int,
        passedTests: Int,
        criticalFailures: [PerformanceTestResult],
        warnings: [PerformanceTestResult],
        detailedResults: [PerformanceTestResult],
        recommendations: [String]
    ) {
        self.timestamp = timestamp
        self.passRate = passRate
        self.totalTests = totalTests
        self.passedTests = passedTests
        self.criticalFailures = criticalFailures
        self.warnings = warnings
        self.detailedResults = detailedResults
        self.recommendations = recommendations
    }

    public var failedTests: Int {
        return max(totalTests - passedTests, 0)
    }

    public var isHealthy: Bool {
        criticalFailures.isEmpty && passRate >= 0.9
    }

    public var summary: String {
        if isHealthy {
            return "All systems operating within budget"
        }

        if criticalFailures.isEmpty {
            return "Warnings detected - review recommended"
        }

        return "Critical performance regressions detected"
    }
}
