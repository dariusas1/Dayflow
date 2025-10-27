//
//  TaskDetector.swift
//  FocusLock
//
//  Protocol and implementations for detecting user's current task
//

import Foundation
import AppKit
import Accessibility
import os.log

// MARK: - Task Detection Protocol

protocol TaskDetector {
    func detectCurrentTask() async -> TaskDetectionResult?
    func startDetection() async throws
    func stopDetection()
    var isDetecting: Bool { get }
}


// DetectionMethod is now defined in FocusLockModels.swift

// MARK: - Accessibility Task Detector

@MainActor
class AccessibilityTaskDetector: TaskDetector {
    private let logger = Logger(subsystem: "FocusLock", category: "TaskDetector")
    internal var isDetecting = false
    private var detectionTimer: Timer?

    
    func startDetection() async throws {
        guard !isDetecting else { return }

        // Check accessibility permissions
        guard checkAccessibilityPermissions() else {
            throw TaskDetectorError.accessibilityPermissionDenied
        }

        isDetecting = true
        logger.info("Started accessibility-based task detection")

        // Start periodic detection
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performDetection()
            }
        }
    }

    func stopDetection() {
        isDetecting = false
        detectionTimer?.invalidate()
        detectionTimer = nil
        logger.info("Stopped accessibility-based task detection")
    }

    func detectCurrentTask() async -> TaskDetectionResult? {
        return await performDetection()
    }

    private func performDetection() async -> TaskDetectionResult? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let applicationName = frontmostApp.localizedName ?? "Unknown"
        let bundleID = frontmostApp.bundleIdentifier ?? ""

        // Try to get window title and content
        let windowInfo = getActiveWindowInfo()

        // Extract task from window content
        let taskName = extractTaskFromWindow(windowInfo: windowInfo)

        let confidence = calculateConfidence(
            windowInfo: windowInfo,
            applicationName: applicationName,
            taskName: taskName
        )

        return TaskDetectionResult(
            taskName: taskName,
            confidence: confidence,
            detectionMethod: .accessibility,
            timestamp: Date(),
            sourceApp: applicationName,
            applicationName: applicationName,
            applicationBundleID: bundleID
        )
    }

    private func checkAccessibilityPermissions() -> Bool {
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): kCFBooleanTrue] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func getActiveWindowInfo() -> WindowInfo? {
        // Get the focused window
        let focusedWindow = NSApp.keyWindow
        guard let window = focusedWindow else { return nil }

        // Use accessibility to get window title
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let windowRef = AXUIElementCreateApplication(pid_t(frontmostApp?.processIdentifier ?? 0))
        var focusedWindowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(windowRef, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)

        guard result == .success, let windowElement = focusedWindowRef else {
            return nil
        }

        // Get window title
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXTitleAttribute as CFString, &title)
        let windowTitle = title as? String

        // Get window content
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXValueAttribute as CFString, &value)
        let windowContent = value as? String

        return WindowInfo(
            title: windowTitle ?? "",
            content: windowContent ?? "",
            element: windowElement as! AXUIElement
        )
    }

    private struct WindowInfo {
        let title: String
        let content: String
        let element: AXUIElement
    }

    private func extractTaskFromWindow(windowInfo: WindowInfo?) -> String {
        guard let window = windowInfo else {
            return "Unknown Task"
        }

        // Priority order: content > title > application name
        if !window.content.isEmpty {
            return extractTaskFromContent(window.content)
        }

        if !window.title.isEmpty {
            return extractTaskFromTitle(window.title)
        }

        return "Unknown Task"
    }

    private func extractTaskFromContent(_ content: String) -> String {
        // Remove common UI artifacts and clean up
        let cleaned = content
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Split into lines and look for meaningful content
        let lines = cleaned.components(separatedBy: .newlines)

        for line in lines {
            let taskLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines and very short ones
            if taskLine.count < 3 { continue }

            // Skip common UI elements
            if isCommonUIElement(taskLine) { continue }

            // Look for task-related keywords
            if isTaskRelated(taskLine) {
                return cleanTaskName(taskLine)
            }
        }

        // Fallback to first meaningful line
        for line in lines {
            let taskLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if taskLine.count > 5 && !isCommonUIElement(taskLine) {
                return cleanTaskName(taskLine)
            }
        }

        return "Unknown Task"
    }

    private func extractTaskFromTitle(_ title: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip common browser/application titles
        if cleaned.contains("Google") || cleaned.contains("YouTube") ||
           cleaned.contains("Safari") || cleaned.contains("Chrome") {
            return "Unknown Task"
        }

        return cleanTaskName(cleaned)
    }

    private func isCommonUIElement(_ text: String) -> Bool {
        let commonElements = [
            "File", "Edit", "View", "Window", "Help", "About", "Preferences",
            "Settings", "Tools", "Window", "Minimize", "Close", "Zoom",
            "Back", "Forward", "Refresh", "Stop", "Home", "Search",
            "Menu", "File", "Edit", "View", "Go", "Bookmarks",
            "History", "Downloads", "Extensions", "Settings"
        ]

        return commonElements.contains { $0.lowercased() == text.lowercased() }
    }

    private func isTaskRelated(_ text: String) -> Bool {
        // Look for common task indicators
        let taskIndicators = [
            "document", "file", "email", "message", "project", "task",
            "issue", "bug", "feature", "branch", "commit", "pull request",
            "analysis", "report", "presentation", "spreadsheet", "slide"
        ]

        return taskIndicators.contains { text.lowercased().contains($0) }
    }

    private func cleanTaskName(_ taskName: String) -> String {
        // Remove common prefixes/suffixes
        var cleaned = taskName

        // Remove file extensions
        let extensions = [".swift", ".py", ".js", ".html", ".css", ".md", ".txt"]
        for ext in extensions {
            cleaned = cleaned.replacingOccurrences(of: ext, with: "")
        }

        // Remove common prefixes
        let prefixes = ["Document:", "File:", "Untitled", "New"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        // Limit length and clean up
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Truncate if too long
        if cleaned.count > 50 {
            cleaned = String(cleaned.prefix(50))
        }

        return cleaned.isEmpty ? "Unknown Task" : cleaned
    }

    private func calculateConfidence(windowInfo: WindowInfo?, applicationName: String, taskName: String) -> Double {
        var confidence = 0.5 // Base confidence

        // Higher confidence if we have good window content
        if let window = windowInfo, !window.content.isEmpty {
            confidence += 0.3
        }

        // Higher confidence if task name is meaningful
        if taskName != "Unknown Task" && taskName.count > 5 {
            confidence += 0.2
        }

        // Lower confidence for common applications
        let commonApps = ["Safari", "Chrome", "Finder", "Mail", "Messages"]
        if commonApps.contains(applicationName) {
            confidence -= 0.1
        }

        return min(max(confidence, 0.0), 1.0)
    }
}

// MARK: - Task Detector Errors

enum TaskDetectorError: Error, LocalizedError {
    case accessibilityPermissionDenied
    case detectionUnavailable
    case processNotFound

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permissions are required for task detection"
        case .detectionUnavailable:
            return "Task detection is currently unavailable"
        case .processNotFound:
            return "No active application process found"
        }
    }
}