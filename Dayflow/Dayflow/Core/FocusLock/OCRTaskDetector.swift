//
//  OCRTaskDetector.swift
//  FocusLock
//
//  OCR-based task detection using Vision framework
//

import Foundation
import SwiftUI
import Vision
import AppKit
import CoreGraphics
import ScreenCaptureKit
import os.log

class OCRTaskDetector: TaskDetector {
    private let logger = Logger(subsystem: "FocusLock", category: "OCRTaskDetector")
    private var _isDetecting = false
    private var detectionTimer: Timer?
    private var lastScreenshot: CGImage?
    private var processingQueue = DispatchQueue(label: "FocusLock.OCR", qos: .userInitiated)

    // Performance optimization: adaptive timing and caching
    private var resultCache: [String: TaskDetectionResult] = [:]
    private var lastCacheTime: Date?
    private var cacheTimeout: TimeInterval = 60.0 // Cache results for 60 seconds
    private var detectionInterval: TimeInterval = 10.0 // Start with 10 seconds, adaptive
    private var baseDetectionInterval: TimeInterval = 10.0
    private var maxDetectionInterval: TimeInterval = 60.0 // Max 1 minute between OCR runs
    private var consecutiveSimilarResults: Int = 0
    private var currentDetectionResult: TaskDetectionResult?

    var isDetecting: Bool { _isDetecting }

    func startDetection() async throws {
        guard !_isDetecting else { return }

        // Check screen recording permissions
        guard CGPreflightScreenCaptureAccess() else {
            throw TaskDetectorError.screenRecordingPermissionDenied
        }

        _isDetecting = true
        logger.info("Started OCR-based task detection")

        // Reset adaptive timing
        detectionInterval = baseDetectionInterval
        consecutiveSimilarResults = 0
        resultCache.removeAll()
        lastCacheTime = nil
        currentDetectionResult = nil

        // Start periodic detection with adaptive intervals
        startAdaptiveTimer()
    }

    func stopDetection() {
        _isDetecting = false
        detectionTimer?.invalidate()
        detectionTimer = nil
        lastScreenshot = nil
        logger.info("Stopped OCR-based task detection")
    }

    private func startAdaptiveTimer() {
        // Invalidate existing timer if any
        detectionTimer?.invalidate()

        // Create new timer with current interval
        detectionTimer = Timer.scheduledTimer(withTimeInterval: detectionInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performOCRDetection()
            }
        }

        logger.debug("Started adaptive OCR timer with interval: \(Int(self.detectionInterval))s")
    }

    private func updateAdaptiveTimer() {
        guard _isDetecting else { return }

        // Restart timer with new interval
        startAdaptiveTimer()
    }

    func detectCurrentTask() async -> TaskDetectionResult? {
        return await performOCRDetection()
    }

    private func performOCRDetection() async -> TaskDetectionResult? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let applicationName = frontmostApp.localizedName ?? "Unknown"
        let bundleID = frontmostApp.bundleIdentifier ?? ""

        // Create cache key based on app and recent content hash
        let cacheKey = "\(bundleID)_\(applicationName)"

        // Check cache first
        if let cachedResult = resultCache[cacheKey],
           let lastCacheTime = lastCacheTime,
           Date().timeIntervalSince(lastCacheTime) < cacheTimeout {

            // Log cache hit for performance monitoring
            logger.debug("OCR cache hit for \(applicationName)")

            return cachedResult
        }

        // Capture screen of active window
        guard let screenshot = await captureWindowScreenshot() else {
            return nil
        }

        // Perform OCR on screenshot
        guard let (taskName, confidence) = await performOCR(on: screenshot) else {
            return nil
        }

        let result = TaskDetectionResult(
            taskName: taskName,
            confidence: confidence,
            detectionMethod: .ocr,
            timestamp: Date(),
            sourceApp: applicationName,
            applicationName: applicationName,
            applicationBundleID: bundleID
        )

        // Update cache
        resultCache[cacheKey] = result
        lastCacheTime = Date()

        // Adapt detection interval based on result similarity
        adaptDetectionInterval(result: result)

        return result
    }

    private func adaptDetectionInterval(result: TaskDetectionResult?) {
        guard let currentResult = result else {
            // Reset to base interval on failure
            detectionInterval = baseDetectionInterval
            consecutiveSimilarResults = 0
            updateAdaptiveTimer()
            return
        }

        // Check if this result is similar to the last one
        if let lastResult = currentDetectionResult {
            let similarity = calculateResultSimilarity(lastResult, currentResult)

            if similarity > 0.8 { // High similarity threshold
                consecutiveSimilarResults += 1

                // Increase interval gradually when we have consistent results
                if consecutiveSimilarResults > 3 {
                    let newInterval = min(detectionInterval * 1.3, maxDetectionInterval)
                    if newInterval != detectionInterval {
                        detectionInterval = newInterval
                        updateAdaptiveTimer()
                        logger.debug("Increasing OCR detection interval to \(Int(self.detectionInterval))s")
                    }
                }
            } else {
                // Reset when we get different results
                consecutiveSimilarResults = 0
                let newInterval = max(detectionInterval * 0.7, baseDetectionInterval)
                if newInterval != self.detectionInterval {
                    self.detectionInterval = newInterval
                    updateAdaptiveTimer()
                    logger.debug("Decreasing OCR detection interval to \(Int(self.detectionInterval))s")
                }
            }
        }

        // Store current result for next comparison
        currentDetectionResult = currentResult
    }

    private func calculateResultSimilarity(_ result1: TaskDetectionResult, _ result2: TaskDetectionResult) -> Double {
        // Simple similarity calculation based on task name and application
        let taskSimilarity = result1.taskName.lowercased() == result2.taskName.lowercased() ? 1.0 : 0.0
        let appSimilarity = result1.applicationBundleID == result2.applicationBundleID ? 1.0 : 0.0

        // Weight task similarity more heavily than app similarity
        return (taskSimilarity * 0.8) + (appSimilarity * 0.2)
    }

    private func captureWindowScreenshot() async -> CGImage? {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                    // Get the main display
                    let config = SCStreamConfiguration()
                    // Use the main screen frame instead of content.cgFrame
                    let mainScreen = NSScreen.main ?? NSScreen.screens.first
                    let screenFrame = mainScreen?.frame ?? CGRect.zero
                    config.width = Int(screenFrame.width)
                    config.height = Int(screenFrame.height)
                    config.sourceRect = screenFrame
                    config.scalesToFit = true

                    // Start capture - updated API for modern ScreenCaptureKit
                    guard let displayID = mainScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let filter = SCContentFilter(display: displayID, excludingWindows: [], onScreenWindowsOnly: true)
                    let stream = try await SCStream(filter: filter, configuration: config, delegate: nil)

                    // Capture first frame
                    stream.startCapture()

                    // Wait for frame
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    // Get the frame
                    let sampleBuffer = try await stream.nextFrame()
                    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        stream.stopCapture()
                        continuation.resume(returning: nil)
                        return
                    }
                    CVPixelBufferLockBaseAddress(imageBuffer, [])

                    // Create CGImage
                    let width = CVPixelBufferGetWidth(imageBuffer)
                    let height = CVPixelBufferGetHeight(imageBuffer)
                    let bitsPerComponent = 8
                    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
                    let colorSpace = CGColorSpaceCreateDeviceRGB()

                    guard let pixelData = CVPixelBufferGetBaseAddress(imageBuffer) else {
                        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                        stream.stopCapture()
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let context = CGContext(
                        data: pixelData,
                        width: width,
                        height: height,
                        bitsPerComponent: bitsPerComponent,
                        bytesPerRow: bytesPerRow,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    ) else {
                        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                        stream.stopCapture()
                        continuation.resume(returning: nil)
                        return
                    }

                    let cgImage = context.makeImage()

                    CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                    stream.stopCapture()

                    continuation.resume(returning: cgImage)

                } catch {
                    logger.error("Failed to capture window screenshot: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func performOCR(on image: CGImage) async -> (String, Double)? {
        return await withCheckedContinuation { continuation in
            processingQueue.async {
                let request = VNRecognizeTextRequest(completionHandler: { request, error in
                    if let error = error {
                        self.logger.error("OCR request failed: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    // Extract and process text
                    var extractedText = ""
                    var totalConfidence: Double = 0
                    var observationCount = 0

                    for observation in observations {
                        guard let topCandidate = observation.topCandidates(1).first else { continue }

                        let text = topCandidate.string
                        let confidence = topCandidate.confidence

                        // Skip very short text or common UI elements
                        if text.count < 3 || self.isCommonUIText(text) {
                            continue
                        }

                        extractedText += text + " "
                        totalConfidence += Double(confidence)
                        observationCount += 1
                    }

                    if observationCount == 0 {
                        continuation.resume(returning: nil)
                        return
                    }

                    let avgConfidence = totalConfidence / Double(observationCount)
                    let taskName = self.extractTaskFromOCRText(extractedText)

                    continuation.resume(returning: (taskName, avgConfidence))
                })

                // Configure request for better accuracy
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                // Perform OCR
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try? handler.perform([request])
            }
        }
    }

    private func extractTaskFromOCRText(_ text: String) -> String {
        // Clean up the text
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Split into words and filter
        let words = cleaned.components(separatedBy: " ")
            .filter { $0.count > 2 }
            .filter { !isCommonUIText($0) }
            .filter { !isStopWord($0) }

        // Look for task-related words
        let taskWords = words.filter { isTaskRelatedWord($0) }

        if !taskWords.isEmpty {
            return taskWords.joined(separator: " ")
        }

        // Fallback to first few meaningful words
        let meaningfulWords = words.prefix(3)
        return meaningfulWords.joined(separator: " ")
    }

    private func isCommonUIText(_ text: String) -> Bool {
        let commonUIText = [
            "File", "Edit", "View", "Window", "Help", "About", "Close",
            "Cancel", "OK", "Yes", "No", "Save", "Open", "New", "Exit",
            "Menu", "Back", "Forward", "Home", "Settings", "Search"
        ]

        return commonUIText.contains { $0.lowercased() == text.lowercased() }
    }

    private func isStopWord(_ text: String) -> Bool {
        let stopWords = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "as", "is", "was", "are", "been", "be", "have", "has",
            "will", "would", "could", "should", "may", "might", "must", "can", "do", "does", "did"
        ]

        return stopWords.contains(text.lowercased())
    }

    private func isTaskRelatedWord(_ word: String) -> Bool {
        let taskKeywords = [
            "project", "task", "issue", "bug", "feature", "document", "file",
            "email", "message", "report", "analysis", "presentation", "meeting",
            "development", "design", "implementation", "testing", "review",
            "code", "database", "server", "client", "user", "system", "application"
        ]

        return taskKeywords.contains { word.lowercased().contains($0) }
    }
}

// MARK: - Error Handling

extension TaskDetectorError {
    static var screenRecordingPermissionDenied: TaskDetectorError {
        return .accessibilityPermissionDenied
    }
}