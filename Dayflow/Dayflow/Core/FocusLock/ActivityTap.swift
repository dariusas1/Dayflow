//
//  ActivityTap.swift
//  FocusLock
//
//  Fusion system for multi-source activity detection and contextual analysis
//

import Foundation
import AppKit
import ScreenCaptureKit
import os.log

class ActivityTap {
    static let shared = ActivityTap()

    private let logger = Logger(subsystem: "FocusLock", category: "ActivityTap")

    // Component extractors
    private let axExtractor = AXExtractor.shared
    private let ocrExtractor = OCRExtractor.shared

    // Activity tracking
    private var currentActivity: Activity?
    private var activityHistory: [Activity] = []
    private let maxHistorySize = 1000

    // Configuration
    private let activityUpdateInterval: TimeInterval = 30.0 // Update every 30 seconds
    private let confidenceThreshold: Double = 0.6
    private var activityTimer: Timer?

    // Performance monitoring
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimeSamples = 50

    private init() {
        startActivityMonitoring()
    }

    // MARK: - Public Interface

    func getCurrentActivity() async -> Activity? {
        return currentActivity
    }

    func getActivityHistory(since date: Date? = nil, limit: Int = 100) -> [Activity] {
        var filteredHistory = activityHistory

        if let since = date {
            filteredHistory = filteredHistory.filter { $0.timestamp >= since }
        }

        return Array(filteredHistory.suffix(limit).reversed())
    }

    func getActivitySummary(for dateRange: DateInterval) -> ActivitySummary {
        let activities = activityHistory.filter {
            dateRange.contains($0.timestamp)
        }

        return ActivitySummary(
            dateRange: dateRange,
            activities: activities,
            totalActivities: activities.count,
            averageConfidence: activities.isEmpty ? 0 : activities.reduce(0) { $0 + $1.confidence } / Double(activities.count),
            topCategories: calculateTopCategories(from: activities),
            totalFocusTime: calculateTotalFocusTime(from: activities),
            contextSwitches: calculateContextSwitches(from: activities)
        )
    }

    func forceActivityUpdate() async -> Activity? {
        return await updateCurrentActivity()
    }

    // MARK: - Private Methods

    private func startActivityMonitoring() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: self.activityUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCurrentActivity()
            }
        }

        logger.info("Started activity monitoring with \(self.activityUpdateInterval)s interval")
    }

    private func updateCurrentActivity() async -> Activity? {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Get current foreground application and window
            guard let foregroundApp = getForegroundApplication(),
                  let activeWindow = getActiveWindow(for: foregroundApp) else {
                logger.warning("Could not determine foreground application or active window")
                return nil
            }

            // Collect data from multiple sources
            let windowInfo = WindowInfo(
                bundleIdentifier: foregroundApp.bundleIdentifier ?? "",
                title: activeWindow.title ?? "",
                frame: activeWindow.frame,
                processIdentifier: foregroundApp.processIdentifier
            )

            async let axResult = axExtractor.extractContent(from: windowInfo)
            async let screenshot = captureScreenshot(for: activeWindow)
            async let appState = axExtractor.extractApplicationState(bundleIdentifier: foregroundApp.bundleIdentifier ?? "")

            // Wait for all async operations
            let (axExtraction, screenImage, applicationState) = try await (axResult, screenshot, appState)

            // Process OCR if we have a screenshot
            var ocrResult: OCRResult?
            if let image = screenImage {
                ocrResult = await ocrExtractor.extractText(from: image)
            }

            // Fusion analysis
            let fusionResult = fuseActivityData(
                windowInfo: windowInfo,
                axResult: axExtraction,
                ocrResult: ocrResult,
                appState: applicationState
            )

            // Create activity object
            let activity = Activity(
                id: UUID(),
                timestamp: Date(),
                windowInfo: windowInfo,
                applicationState: applicationState,
                axExtraction: axExtraction,
                ocrResult: ocrResult,
                fusionResult: fusionResult,
                confidence: fusionResult.overallConfidence,
                category: fusionResult.primaryCategory,
                context: fusionResult.context,
                metadata: buildActivityMetadata(
                    windowInfo: windowInfo,
                    axResult: axExtraction,
                    ocrResult: ocrResult,
                    appState: applicationState
                )
            )

            // Update current activity and history
            currentActivity = activity
            addToHistory(activity)

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            processingTimes.append(duration)
            if processingTimes.count > maxProcessingTimeSamples {
                processingTimes.removeFirst()
            }

            logger.info("Activity fusion completed in \(String(format: "%.3f", duration))s - Category: \(activity.category), Confidence: \(String(format: "%.2f", activity.confidence))")

            return activity

        } catch {
            logger.error("Activity update failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fuseActivityData(
        windowInfo: WindowInfo,
        axResult: AXExtractionResult,
        ocrResult: OCRResult?,
        appState: AXApplicationState?
    ) -> ActivityFusionResult {
        var fusionResult = ActivityFusionResult()

        // Initialize confidence weights
        let axWeight = axResult.error == nil ? 0.4 : 0.0
        let ocrWeight = ocrResult?.error == nil ? 0.3 : 0.0
        let appWeight = appState != nil ? 0.2 : 0.0
        let historicalWeight = 0.1

        var weightedConfidence: Double = 0
        var detectedCategories: [String: Double] = [:]
        var contextPieces: [String] = []

        // 1. Process AX extraction results
        if axResult.error == nil, let axContent = axResult.content, !axContent.isEmpty {
            let axConfidence = analyzeContentConfidence(axContent, source: "accessibility")
            detectedCategories[axConfidence.category] = axConfidence.confidence * axWeight
            contextPieces.append("AX: \(axContent.prefix(100))")
            weightedConfidence += axConfidence.confidence * axWeight

            // Extract structured data
            if let structuredData = axResult.structuredData {
                fusionResult.structuredElements.append(contentsOf: extractStructuredElements(from: structuredData))
                contextPieces.append("UI Elements: \(structuredData.uiElements.count)")
            }

            // Extract tasks
            if let taskDetection = axResult.taskDetection {
                fusionResult.detectedTasks.append(contentsOf: taskDetection.allTasks)
                contextPieces.append("Tasks: \(taskDetection.allTasks.count)")
            }
        }

        // 2. Process OCR results
        if let ocrResult = ocrResult, ocrResult.error == nil, !ocrResult.text.isEmpty {
            let ocrConfidence = analyzeContentConfidence(ocrResult.text, source: "ocr")
            detectedCategories[ocrConfidence.category] = max(detectedCategories[ocrConfidence.category] ?? 0, ocrConfidence.confidence * ocrWeight)
            contextPieces.append("OCR: \(ocrResult.text.prefix(100))")
            weightedConfidence += Double(ocrResult.confidence) * ocrWeight

            // Extract OCR-specific insights
            fusionResult.ocrInsights = extractOCRInsights(from: ocrResult)
        }

        // 3. Process application state
        if let appState = appState {
            let appCategory = categorizeApplication(appState.bundleIdentifier)
            detectedCategories[appCategory] = max(detectedCategories[appCategory] ?? 0, appWeight)
            contextPieces.append("App: \(appState.bundleIdentifier)")
            weightedConfidence += appWeight

            fusionResult.applicationInsights = extractApplicationInsights(from: appState)
        }

        // 4. Consider historical context
        if let recentActivity = getMostRecentSimilarActivity(for: windowInfo.bundleIdentifier) {
            let historicalCategory = recentActivity.category
            detectedCategories[historicalCategory] = max(detectedCategories[historicalCategory] ?? 0, historicalWeight)
            contextPieces.append("Recent: \(historicalCategory)")
            weightedConfidence += recentActivity.confidence * historicalWeight
        }

        // 5. Determine primary category and overall confidence
        fusionResult.primaryCategory = detectedCategories.max { $0.value > $1.value }?.key ?? "unknown"
        fusionResult.overallConfidence = min(weightedConfidence, 1.0)
        fusionResult.context = contextPieces.joined(separator: " | ")
        fusionResult.categoryScores = detectedCategories

        return fusionResult
    }

    private func analyzeContentConfidence(_ content: String, source: String) -> (category: String, confidence: Double) {
        var categoryScores: [String: Double] = [:]

        // Content-based classification
        if content.contains("func") || content.contains("def") || content.contains("class") {
            categoryScores["coding"] = 0.9
        }
        if content.contains("email") || content.contains("send") || content.contains("reply") {
            categoryScores["communication"] = 0.8
        }
        if content.contains("meeting") || content.contains("agenda") || content.contains("schedule") {
            categoryScores["planning"] = 0.8
        }
        if content.contains("write") || content.contains("edit") || content.contains("draft") {
            categoryScores["writing"] = 0.7
        }
        if content.contains("research") || content.contains("study") || content.contains("learn") {
            categoryScores["research"] = 0.7
        }
        if content.contains("browse") || content.contains("search") || content.contains("web") {
            categoryScores["browsing"] = 0.6
        }

        // Source-based confidence adjustment
        let sourceMultiplier = source == "accessibility" ? 1.0 : 0.8

        // Find highest scoring category
        if let (category, score) = categoryScores.max(by: { $0.value < $1.value }) {
            return (category, score * sourceMultiplier)
        }

        return ("unknown", 0.3)
    }

    private func categorizeApplication(_ bundleIdentifier: String) -> String {
        let appCategories: [String: String] = [
            "com.apple.Terminal": "development",
            "com.microsoft.VSCode": "development",
            "com.apple.dt.Xcode": "development",
            "com.jetbrains.intellij": "development",
            "com.apple.finder": "file_management",
            "com.apple.Safari": "browsing",
            "com.google.Chrome": "browsing",
            "com.apple.mail": "communication",
            "com.hnc.Discord": "communication",
            "com.apple.TextEdit": "writing",
            "com.apple.Notes": "writing",
            "com.apple.Calendar": "planning",
            "com.apple.reminders": "planning"
        ]

        return appCategories[bundleIdentifier] ?? "other"
    }

    private func extractStructuredElements(from structuredData: AXStructuredData) -> [StructuredElement] {
        var elements: [StructuredElement] = []

        // Extract UI elements
        for uiElement in structuredData.uiElements {
            let element = StructuredElement(
                type: "ui_element",
                role: uiElement.role,
                title: uiElement.title,
                value: uiElement.value,
                frame: uiElement.frame
            )
            elements.append(element)
        }

        // Extract tables
        for (index, table) in structuredData.tables.enumerated() {
            let element = StructuredElement(
                type: "table",
                role: "table",
                title: "Table \(index + 1)",
                value: "\(table.rows.count) rows",
                frame: CGRect.zero
            )
            elements.append(element)
        }

        // Extract lists
        for (index, list) in structuredData.lists.enumerated() {
            let element = StructuredElement(
                type: "list",
                role: "list",
                title: "List \(index + 1)",
                value: "\(list.items.count) items",
                frame: CGRect.zero
            )
            elements.append(element)
        }

        // Extract forms
        for (index, form) in structuredData.forms.enumerated() {
            let element = StructuredElement(
                type: "form",
                role: "form",
                title: "Form \(index + 1)",
                value: "\(form.elements.count) fields",
                frame: CGRect.zero
            )
            elements.append(element)
        }

        return elements
    }

    private func extractOCRInsights(from ocrResult: OCRResult) -> [OCRInsight] {
        var insights: [OCRInsight] = []

        // Analyze text patterns
        let text = ocrResult.text

        // Detect URLs
        let urlPattern = #"https?://[^\s]+"#
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let matches = urlRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.prefix(5) { // Limit to top 5 URLs
                if let range = Range(match.range, in: text) {
                    insights.append(OCRInsight(type: "url", value: String(text[range])))
                }
            }
        }

        // Detect email addresses
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let emailRegex = try? NSRegularExpression(pattern: emailPattern, options: []) {
            let matches = emailRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.prefix(3) { // Limit to top 3 emails
                if let range = Range(match.range, in: text) {
                    insights.append(OCRInsight(type: "email", value: String(text[range])))
                }
            }
        }

        // Detect dates
        let datePattern = #"\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2}"#
        if let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []) {
            let matches = dateRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.prefix(3) {
                if let range = Range(match.range, in: text) {
                    insights.append(OCRInsight(type: "date", value: String(text[range])))
                }
            }
        }

        // Detect phone numbers
        let phonePattern = #"\d{3}-\d{3}-\d{4}|\(\d{3}\)\s*\d{3}-\d{4}"#
        if let phoneRegex = try? NSRegularExpression(pattern: phonePattern, options: []) {
            let matches = phoneRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.prefix(2) {
                if let range = Range(match.range, in: text) {
                    insights.append(OCRInsight(type: "phone", value: String(text[range])))
                }
            }
        }

        return insights
    }

    private func extractApplicationInsights(from appState: AXApplicationState) -> [ApplicationInsight] {
        var insights: [ApplicationInsight] = []

        // Window title analysis
        if let windowTitle = appState.windowTitle {
            insights.append(ApplicationInsight(type: "window_title", value: windowTitle))

            // Look for specific patterns in window title
            if windowTitle.contains("-") {
                let components = windowTitle.components(separatedBy: " - ")
                if components.count > 1 {
                    insights.append(ApplicationInsight(type: "document_name", value: components.first ?? ""))
                }
            }
        }

        // Role-based insights
        if let role = appState.role {
            insights.append(ApplicationInsight(type: "window_role", value: role))
        }

        // State-based insights
        insights.append(ApplicationInsight(type: "is_active", value: String(appState.isActive)))
        insights.append(ApplicationInsight(type: "process_id", value: String(appState.processIdentifier)))

        return insights
    }

    private func getMostRecentSimilarActivity(for bundleIdentifier: String) -> Activity? {
        return activityHistory
            .filter { $0.windowInfo.bundleIdentifier == bundleIdentifier }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    private func buildActivityMetadata(
        windowInfo: WindowInfo,
        axResult: AXExtractionResult,
        ocrResult: OCRResult?,
        appState: AXApplicationState?
    ) -> [String: AnyCodable] {
        var metadata: [String: AnyCodable] = [:]

        // Processing information
        metadata["has_ax_content"] = AnyCodable(axResult.error == nil && axResult.content?.isEmpty == false)
        metadata["has_ocr_content"] = AnyCodable(ocrResult?.error == nil && ocrResult?.text.isEmpty == false)
        metadata["has_app_state"] = AnyCodable(appState != nil)

        // Performance metrics
        let avgProcessingTime = processingTimes.isEmpty ? 0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
        metadata["avg_processing_time"] = AnyCodable(avgProcessingTime)

        // Content metrics
        if let content = axResult.content {
            metadata["content_length"] = AnyCodable(content.count)
            metadata["word_count"] = AnyCodable(content.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count)
        }

        if let ocrText = ocrResult?.text {
            metadata["ocr_confidence"] = AnyCodable(ocrResult?.confidence ?? 0)
            metadata["ocr_region_count"] = AnyCodable(ocrResult?.regions.count ?? 0)
        }

        return metadata
    }

    private func addToHistory(_ activity: Activity) {
        activityHistory.append(activity)

        // Maintain history size limit
        if activityHistory.count > maxHistorySize {
            activityHistory.removeFirst(activityHistory.count - maxHistorySize)
        }
    }

    private func calculateTopCategories(from activities: [Activity]) -> [(String, Int)] {
        let categoryCounts = Dictionary(grouping: activities, by: { $0.category })
            .mapValues { $0.count }

        return categoryCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    private func calculateTotalFocusTime(from activities: [Activity]) -> TimeInterval {
        // This is a simplified calculation - in practice, you'd want to track actual focus durations
        return TimeInterval(activities.count) * activityUpdateInterval
    }

    private func calculateContextSwitches(from activities: [Activity]) -> Int {
        guard activities.count > 1 else { return 0 }

        var switches = 0
        for i in 1..<activities.count {
            if activities[i].category != activities[i-1].category ||
               activities[i].windowInfo.bundleIdentifier != activities[i-1].windowInfo.bundleIdentifier {
                switches += 1
            }
        }

        return switches
    }

    // MARK: - System Integration Methods

    private func getForegroundApplication() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    private func getActiveWindow(for app: NSRunningApplication) -> NSWindow? {
        // This is a simplified version - in practice, you'd want to use more sophisticated window detection
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            for windowInfo in windowList {
                if let windowOwnerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                   windowOwnerPID == app.processIdentifier,
                   let windowLayer = windowInfo[kCGWindowLayer as String] as? Int,
                   windowLayer == 0 { // Normal window layer
                    // Create a basic NSWindow representation
                    return NSWindow()
                }
            }
        }

        return nil
    }

    private func captureScreenshot(for window: NSWindow) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let screenRect = NSScreen.main?.frame ?? CGRect.zero
                let screenShot = CGDisplayCreateImage(CGMainDisplayID(), rect: screenRect)

                if let imageRef = screenShot {
                    let image = NSImage(cgImage: imageRef, size: screenRect.size)
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Public Utility Methods

    func getActivityStatistics() -> ActivityStatistics {
        let recentActivities = getActivityHistory(since: Date().addingTimeInterval(-24 * 60 * 60)) // Last 24 hours

        return ActivityStatistics(
            totalActivities: recentActivities.count,
            averageConfidence: recentActivities.isEmpty ? 0 : recentActivities.reduce(0) { $0 + $1.confidence } / Double(recentActivities.count),
            topCategories: calculateTopCategories(from: recentActivities),
            contextSwitches: calculateContextSwitches(from: recentActivities),
            averageProcessingTime: processingTimes.isEmpty ? 0 : processingTimes.reduce(0, +) / Double(processingTimes.count),
            currentActivity: currentActivity
        )
    }

    func clearHistory(olderThan date: Date) {
        activityHistory = activityHistory.filter { $0.timestamp >= date }
        logger.info("Cleared activity history older than \(date)")
    }
}

// MARK: - Data Models

struct Activity: Identifiable {
    let id: UUID
    let timestamp: Date
    let windowInfo: WindowInfo
    let applicationState: AXApplicationState?
    let axExtraction: AXExtractionResult?
    let ocrResult: OCRResult?
    let fusionResult: ActivityFusionResult
    let confidence: Double
    let category: String
    let context: String
    let metadata: [String: AnyCodable]

    var duration: TimeInterval {
        // Calculate duration based on next activity or current time
        // This would be implemented based on your activity tracking logic
        return 30.0 // Default 30 seconds per activity
    }

    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
}

struct ActivityFusionResult {
    var primaryCategory: String = "unknown"
    var overallConfidence: Double = 0.0
    var context: String = ""
    var categoryScores: [String: Double] = [:]
    var detectedTasks: [DetectedTask] = []
    var structuredElements: [StructuredElement] = []
    var ocrInsights: [OCRInsight] = []
    var applicationInsights: [ApplicationInsight] = []
}

struct StructuredElement: Codable {
    let type: String
    let role: String
    let title: String?
    let value: String?
    let frame: CGRect
}

struct OCRInsight: Codable {
    let type: String
    let value: String
}

struct ApplicationInsight: Codable {
    let type: String
    let value: String
}

struct ActivitySummary {
    let dateRange: DateInterval
    let activities: [Activity]
    let totalActivities: Int
    let averageConfidence: Double
    let topCategories: [(String, Int)]
    let totalFocusTime: TimeInterval
    let contextSwitches: Int

    var productivityScore: Double {
        // Calculate a productivity score based on various factors
        let confidenceScore = averageConfidence
        let focusScore = min(totalFocusTime / (60 * 60 * 8), 1.0) // 8 hours = full day
        let categoryScore = topCategories.first?.1 == 1 ? 1.0 : 0.8 // Focused category is good
        let switchPenalty = max(0, 1.0 - Double(contextSwitches) / 50.0) // Fewer switches is better

        return (confidenceScore + focusScore + categoryScore + switchPenalty) / 4.0
    }
}

struct ActivityStatistics {
    let totalActivities: Int
    let averageConfidence: Double
    let topCategories: [(String, Int)]
    let contextSwitches: Int
    let averageProcessingTime: TimeInterval
    let currentActivity: Activity?

    var isHealthy: Bool {
        return averageConfidence > 0.6 && averageProcessingTime < 2.0
    }
}

extension NSWindow {
    var title: String? {
        return title
    }

    var frame: CGRect {
        return frame
    }
}
