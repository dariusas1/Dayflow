//
//  DetectorFuser.swift
//  FocusLock
//
//  Fuses multiple detection methods with confidence scoring and temporal stabilization
//

import Foundation
import Combine
import os.log

// Import DetectionMethod from models
typealias DetectionMethod = TaskDetectionResult.DetectionMethod

@MainActor
class DetectorFuser {
    private let logger = Logger(subsystem: "FocusLock", category: "DetectorFuser")
    private let accessibilityDetector = AccessibilityTaskDetector()
    private let ocrDetector = OCRTaskDetector()

    // Detection configuration
    private let stabilizationWindow: TimeInterval = 10.0 // 10 seconds
    private let minConfidence: Double = 0.6
    private let confidenceThreshold: Double = 0.8

    // Performance optimization: adaptive timing
    private var fusionInterval: TimeInterval = 2.0 // Start with 2 seconds
    private let baseFusionInterval: TimeInterval = 2.0
    private let maxFusionInterval: TimeInterval = 10.0 // Max 10 seconds
    private var consecutiveStableResults: Int = 0
    private let maxHistorySize: Int = 30 // Limit history to reduce memory usage

    // State management
    private var detectionHistory: [DetectionRecord] = []
    private var currentResult: FusedDetectionResult?
    private var cancellables = Set<AnyCancellable>()
    private var fusionTimer: Timer?

    // Performance optimization: result caching
    private var lastOCRResult: TaskDetectionResult?
    private var lastOCRResultTime: Date?
    private let ocrCacheTimeout: TimeInterval = 5.0 // Cache OCR for 5 seconds

    // Published results for SwiftUI integration
    @Published var currentTask: String?
    @Published var isDetecting: Bool = false
    @Published var confidence: Double = 0.0

    init() {
        setupAdaptiveFusion()
    }

    // MARK: - Private Setup Methods
    private func setupAdaptiveFusion() {
        // Initialize adaptive fusion timing
        startAdaptiveFusion()
    }

    // MARK: - Public Interface

    func startFusion() async throws {
        guard !isDetecting else { return }

        logger.info("Starting detection fusion")
        isDetecting = true

        // Reset performance optimization state
        fusionInterval = baseFusionInterval
        consecutiveStableResults = 0
        detectionHistory.removeAll()
        lastOCRResult = nil
        lastOCRResultTime = nil

        // Start all detectors
        async let accessibilityResult = accessibilityDetector.startDetection()
        async let ocrResult = ocrDetector.startDetection()

        // Start adaptive fusion
        startAdaptiveFusion()
    }

    func stopFusion() {
        isDetecting = false
        fusionTimer?.invalidate()
        fusionTimer = nil
        accessibilityDetector.stopDetection()
        ocrDetector.stopDetection()
        logger.info("Stopped detection fusion")

        currentTask = nil
        confidence = 0.0
    }

    func getStabilizedTask() -> String? {
        return currentResult?.taskName
    }

    func getConfidence() -> Double {
        return confidence
    }

    // MARK: - Private Methods

    private func startAdaptiveFusion() {
        // Invalidate existing timer
        fusionTimer?.invalidate()

        // Create new timer with current interval
        let interval = fusionInterval
        fusionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performFusion()
            }
        }

        logger.debug("Started adaptive fusion timer with interval: \(Int(self.fusionInterval))s")
    }

    private func performFusion() async {
        let results = await gatherDetectionResults()
        let fusedResult = fuseDetectionResults(results)

        updateCurrentResult(fusedResult)
        adaptFusionInterval(result: fusedResult)
    }

    private func gatherDetectionResults() async -> [TaskDetectionResult] {
        var results: [TaskDetectionResult] = []

        // Get accessibility result
        if let accessibilityResult = await accessibilityDetector.detectCurrentTask() {
            results.append(accessibilityResult)
        }

        // Get OCR result with caching and conditional logic
        if shouldPerformOCR(accessibilityResult: results.first) {
            if let ocrResult = await getOCRResult() {
                results.append(ocrResult)
            }
        }

        return results
    }

    private func shouldPerformOCR(accessibilityResult: TaskDetectionResult?) -> Bool {
        // Don't perform OCR if we have a recent cached result
        if let lastOCRTime = lastOCRResultTime,
           Date().timeIntervalSince(lastOCRTime) < ocrCacheTimeout {
            return false
        }

        // Perform OCR if accessibility confidence is low or missing
        guard let accessibilityResult = accessibilityResult else { return true }
        return accessibilityResult.confidence < 0.7
    }

    private func getOCRResult() async -> TaskDetectionResult? {
        // Check cache first
        if let lastResult = lastOCRResult,
           let lastTime = lastOCRResultTime,
           Date().timeIntervalSince(lastTime) < ocrCacheTimeout {
            return lastResult
        }

        // Get fresh OCR result
        let result = await ocrDetector.detectCurrentTask()

        // Update cache
        if let result = result {
            lastOCRResult = result
            lastOCRResultTime = Date()
        }

        return result
    }

    private func adaptFusionInterval(result: FusedDetectionResult?) {
        guard let fusedResult = result else {
            // Reset to base interval on failure
            fusionInterval = baseFusionInterval
            consecutiveStableResults = 0
            updateAdaptiveFusion()
            return
        }

        // Check if we have a stable result
        let isStable = fusedResult.fusedConfidence >= confidenceThreshold

        if isStable {
            consecutiveStableResults += 1

            // Increase interval gradually when we have stable results
            if consecutiveStableResults > 5 {
                let newInterval = min(fusionInterval * 1.2, maxFusionInterval)
                if newInterval != self.fusionInterval {
                    self.fusionInterval = newInterval
                    updateAdaptiveFusion()
                    logger.debug("Increasing fusion interval to \(Int(self.fusionInterval))s")
                }
            }
        } else {
            // Reset when result is not stable
            consecutiveStableResults = 0
            let newInterval = max(self.fusionInterval * 0.8, baseFusionInterval)
            if newInterval != self.fusionInterval {
                self.fusionInterval = newInterval
                updateAdaptiveFusion()
                logger.debug("Decreasing fusion interval to \(Int(self.fusionInterval))s")
            }
        }
    }

    private func updateAdaptiveFusion() {
        guard isDetecting else { return }
        startAdaptiveFusion()
    }

    private func fuseDetectionResults(_ results: [TaskDetectionResult]) -> FusedDetectionResult? {
        guard !results.isEmpty else { return nil }

        // Weight the results
        let weightedResults = results.map { result in
            let weight = self.calculateWeight(for: result)
            return WeightedResult(result: result, weight: weight)
        }

        // Sort by weight
        let sortedResults = weightedResults.sorted { $0.weight > $1.weight }

        // Get the highest weighted result
        guard let topResult = sortedResults.first?.result else {
            return nil
        }

        // Create fused result
        let fusedResult = FusedDetectionResult(
            taskName: topResult.taskName,
            applicationName: topResult.applicationName,
            applicationBundleID: topResult.applicationBundleID,
            fusedConfidence: calculateFusedConfidence(weightedResults),
            detectionMethods: results.map { $0.detectionMethod },
            timestamp: topResult.timestamp,
            sourceResults: results
        )

        return fusedResult
    }

    private func calculateWeight(for result: TaskDetectionResult) -> Double {
        var weight: Double = 0.0

        // Base weight from confidence
        weight += result.confidence

        // Prefer accessibility detection
        if result.detectionMethod == .accessibility {
            weight += 0.2
        }

        // Prefer recent detections
        let timeSinceDetection = Date().timeIntervalSince(result.timestamp)
        if timeSinceDetection < 5.0 {
            weight += 0.1 * (1.0 - timeSinceDetection / 5.0)
        }

        // Prefer task names that look meaningful
        if isMeaningfulTaskName(result.taskName) {
            weight += 0.1
        }

        return weight
    }

    private func calculateFusedConfidence(_ weightedResults: [WeightedResult]) -> Double {
        let totalWeight = weightedResults.reduce(0) { $0 + $1.weight }
        let weightedConfidence = weightedResults.reduce(0) { $0 + ($1.result.confidence * $1.weight) }
        return weightedConfidence / totalWeight
    }

    private func isMeaningfulTaskName(_ name: String) -> Bool {
        // Skip generic names
        let genericNames = ["Unknown Task", "Untitled", "Document", "File"]
        return !genericNames.contains(name) && name.count > 3
    }

    private func updateCurrentResult(_ result: FusedDetectionResult?) {
        let now = Date()

        // Add to history with memory management
        if let result = result {
            let record = DetectionRecord(
                fusedResult: result,
                timestamp: now
            )
            detectionHistory.append(record)

            // Limit history size to prevent memory bloat
            if detectionHistory.count > maxHistorySize {
                detectionHistory.removeFirst(detectionHistory.count - maxHistorySize)
            }
        }

        // Check if this is a stable detection
        if let stabilizedResult = checkForStabilization() {
            currentResult = stabilizedResult
            currentTask = stabilizedResult.taskName
            confidence = stabilizedResult.fusedConfidence

            logger.debug("Task stabilized to: \(stabilizedResult.taskName) with confidence: \(stabilizedResult.fusedConfidence)")
        }
    }

    private func checkForStabilization() -> FusedDetectionResult? {
        guard let latest = detectionHistory.last else { return nil }

        // Check if we have enough history
        let recentRecords = detectionHistory.filter {
            $0.timestamp.timeIntervalSinceNow >= -self.stabilizationWindow
        }

        guard recentRecords.count >= 3 else { return nil }

        // Check if recent results are consistent
        let uniqueTasks = Set(recentRecords.map { $0.fusedResult.taskName })
        guard uniqueTasks.count == 1 else { return nil }

        // Check if confidence is consistently high
        let avgConfidence = recentRecords.reduce(0) {
            $0 + $1.fusedResult.fusedConfidence
        } / Double(recentRecords.count)

        guard avgConfidence >= confidenceThreshold else { return nil }

        return latest.fusedResult
    }

    // Note: Cleanup is now handled in updateCurrentResult to be more memory efficient
}

// MARK: - Supporting Types

private struct WeightedResult {
    let result: TaskDetectionResult
    let weight: Double
}

struct FusedDetectionResult {
    let taskName: String
    let applicationName: String
    let applicationBundleID: String
    let fusedConfidence: Double
    let detectionMethods: [DetectionMethod]
    let timestamp: Date
    let sourceResults: [TaskDetectionResult]
}

private struct DetectionRecord {
    let fusedResult: FusedDetectionResult
    let timestamp: Date
}

// MARK: - Detection Methods Extension

extension DetectionMethod: CustomStringConvertible {
    var description: String {
        return self.rawValue
    }
}
