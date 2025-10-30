//
//  AXExtractor.swift
//  FocusLock
//
//  Enhanced accessibility content extraction for structured UI data
//

import Foundation
import AppKit
import os.log

class AXExtractor {
    static let shared = AXExtractor()

    private let logger = Logger(subsystem: "FocusLock", category: "AXExtractor")

    // Whitelisted applications for accessibility extraction
    private let whitelistedApps: Set<String> = [
        "com.apple.Terminal",
        "com.apple.finder",
        "com.apple.TextEdit",
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode",
        "com.jetbrains.intellij",
        "com.sublimetext.3",
        "com.apple.mail",
        "com.apple.Notes",
        "com.apple.reminders",
        "com.apple.Calendar",
        "com.apple.Slack",
        "com.hnc.Discord",
        "org.telegram.TelegramDesktop",
        "us.zoom.xos",
        "com.microsoft.teams2"
    ]

    // Task-specific patterns
    private let taskPatterns: [String: [String]] = [
        "coding": [
            "func", "class", "struct", "enum", "protocol", "import", "let", "var",
            "def ", "class ", "function ", "const ", "import ",
            "TODO:", "FIXME:", "NOTE:", "HACK:"
        ],
        "writing": [
            "Chapter", "Section", "Introduction", "Conclusion", "Summary",
            "Abstract", "Keywords:", "References:", "Bibliography"
        ],
        "research": [
            "Methodology", "Results", "Discussion", "Analysis", "Data",
            "Experiment", "Survey", "Interview", "Case Study"
        ],
        "communication": [
            "Subject:", "To:", "From:", "CC:", "BCC:", "Reply:", "Forward:",
            "Meeting", "Agenda", "Minutes", "Action Items"
        ],
        "planning": [
            "Goal", "Objective", "Milestone", "Deadline", "Timeline",
            "Priority", "Sprint", "Backlog", "Epic", "Story"
        ]
    ]

    private init() {
        requestAccessibilityPermissions()
    }

    // MARK: - Public Interface

    func extractContent(from windowInfo: WindowInfo) async -> AXExtractionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard whitelistedApps.contains(windowInfo.bundleIdentifier) else {
            return AXExtractionResult(
                windowInfo: windowInfo,
                content: nil,
                structuredData: nil,
                taskDetection: nil,
                error: AXExtractionError.appNotWhitelisted
            )
        }

        guard let axElement = getAXElement(for: windowInfo) else {
            return AXExtractionResult(
                windowInfo: windowInfo,
                content: nil,
                structuredData: nil,
                taskDetection: nil,
                error: AXExtractionError.accessibilityElementNotFound
            )
        }

        do {
            // Extract content
            let content = try await extractTextContent(from: axElement)

            // Extract structured data
            let structuredData = try await extractStructuredData(from: axElement, windowInfo: windowInfo)

            // Detect tasks
            let taskDetection = await detectTasks(from: content, in: windowInfo)

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("AX extraction completed in \(String(format: "%.3f", duration))s")

            return AXExtractionResult(
                windowInfo: windowInfo,
                content: content,
                structuredData: structuredData,
                taskDetection: taskDetection,
                error: nil
            )

        } catch {
            logger.error("AX extraction failed: \(error.localizedDescription)")
            return AXExtractionResult(
                windowInfo: windowInfo,
                content: nil,
                structuredData: nil,
                taskDetection: nil,
                error: error
            )
        }
    }

    func extractApplicationState(bundleIdentifier: String) async -> AXApplicationState? {
        guard whitelistedApps.contains(bundleIdentifier) else { return nil }

        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard let app = runningApps.first else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard let window = focusedWindow else { return nil }

        let windowElement = window as! AXUIElement

        // Extract window title
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue)
        let windowTitle = titleValue as? String

        // Extract role and description
        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(windowElement, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String

        var roleDescValue: AnyObject?
        AXUIElementCopyAttributeValue(windowElement, kAXRoleDescriptionAttribute as CFString, &roleDescValue)
        let roleDescription = roleDescValue as? String

        return AXApplicationState(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: app.processIdentifier,
            windowTitle: windowTitle,
            role: role,
            roleDescription: roleDescription,
            isActive: app.isActive,
            launchDate: app.launchDate ?? Date()
        )
    }

    // MARK: - Private Methods

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            logger.warning("Accessibility permissions not granted")
        } else {
            logger.info("Accessibility permissions granted")
        }
    }

    private func getAXElement(for windowInfo: WindowInfo) -> AXUIElement? {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: windowInfo.bundleIdentifier)
        guard let app = runningApps.first else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        // Get all windows for the application
        var windowsValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)

        guard let windows = windowsValue as? [AXUIElement] else { return nil }

        // Find the matching window by title or position
        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)

            if let title = titleValue as? String, title == windowInfo.title {
                return window
            }

            // Fallback: match by position if title is not available
            var positionValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)

            if let position = positionValue as? NSValue {
                let point = position.pointValue
                if abs(point.x - windowInfo.frame.origin.x) < 10 && abs(point.y - windowInfo.frame.origin.y) < 10 {
                    return window
                }
            }
        }

        return nil
    }

    private func extractTextContent(from axElement: AXUIElement) async throws -> String {
        var content = ""

        // Try to get direct text content first
        var textValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &textValue)

        if let text = textValue as? String, !text.isEmpty {
            content = text
        } else {
            // Recursively extract from children
            content = try await extractTextFromChildren(of: axElement)
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextFromChildren(of axElement: AXUIElement) async throws -> String {
        var childrenValue: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(axElement, kAXChildrenAttribute as CFString, &childrenValue)

        guard let children = childrenValue as? [AXUIElement] else { return "" }

        var content = ""

        for child in children {
            // Get child's role to determine if we should extract text
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            let role = roleValue as? String ?? ""

            // Skip certain roles that don't contain useful text
            if ["AXGroup", "AXSplitGroup", "AXUnknown"].contains(role) {
                let childContent = try await extractTextFromChildren(of: child)
                if !childContent.isEmpty {
                    content += childContent + "\n"
                }
                continue
            }

            // Extract text based on role
            if role == "AXStaticText" {
                var textValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &textValue)

                if let text = textValue as? String, !text.isEmpty {
                    content += text + " "
                }
            } else if role == "AXTextField" || role == "AXTextArea" {
                var textValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &textValue)

                if let text = textValue as? String, !text.isEmpty {
                    content += text + "\n"
                }
            } else if role == "AXButton" {
                var titleValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)

                if let title = titleValue as? String, !title.isEmpty {
                    content += "[Button: \(title)] "
                }
            } else if role == "AXMenuItem" {
                var titleValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)

                if let title = titleValue as? String, !title.isEmpty {
                    content += "[Menu: \(title)] "
                }
            } else {
                // Recursively process other roles
                let childContent = try await extractTextFromChildren(of: child)
                if !childContent.isEmpty {
                    content += childContent + " "
                }
            }
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractStructuredData(from axElement: AXUIElement, windowInfo: WindowInfo) async throws -> AXStructuredData {
        var structuredData = AXStructuredData(windowInfo: windowInfo)

        // Extract UI elements
        structuredData.uiElements = try await extractUIElements(from: axElement)

        // Extract tables if present
        structuredData.tables = try await extractTables(from: axElement)

        // Extract lists if present
        structuredData.lists = try await extractLists(from: axElement)

        // Extract forms if present
        structuredData.forms = try await extractForms(from: axElement)

        // Extract code structure if in development environment
        if isDevelopmentEnvironment(bundleIdentifier: windowInfo.bundleIdentifier) {
            structuredData.codeStructure = try await extractCodeStructure(from: axElement)
        }

        return structuredData
    }

    private func extractUIElements(from axElement: AXUIElement) async throws -> [CapturedAXElement] {
        var elements: [CapturedAXElement] = []

        var childrenValue: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(axElement, kAXChildrenAttribute as CFString, &childrenValue)

        guard let children = childrenValue as? [AXUIElement] else { return elements }

        for child in children {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            let role = roleValue as? String ?? ""

            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)

            var valueValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueValue)

            let element = CapturedAXElement(
                role: role,
                title: titleValue as? String,
                value: valueValue as? String,
                frame: await getElementFrame(child)
            )

            elements.append(element)

            // Recursively extract from children
            elements.append(contentsOf: try await extractUIElements(from: child))
        }

        return elements
    }

    private func extractTables(from axElement: AXUIElement) async throws -> [AXTable] {
        var tables: [AXTable] = []

        var childrenValue: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(axElement, kAXChildrenAttribute as CFString, &childrenValue)

        guard let children = childrenValue as? [AXUIElement] else { return tables }

        for child in children {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            if roleValue as? String == "AXTable" {
                let table = try await extractTableData(from: child)
                tables.append(table)
            } else {
                tables.append(contentsOf: try await extractTables(from: child))
            }
        }

        return tables
    }

    private func extractTableData(from tableElement: AXUIElement) async throws -> AXTable {
        var rows: [[String]] = []

        var rowsValue: AnyObject?
        AXUIElementCopyAttributeValue(tableElement, kAXRowsAttribute as CFString, &rowsValue)

        if let rowElements = rowsValue as? [AXUIElement] {
            for rowElement in rowElements {
                var rowContent: [String] = []

                var columnsValue: AnyObject?
                AXUIElementCopyAttributeValue(rowElement, kAXColumnsAttribute as CFString, &columnsValue)

                if let cells = columnsValue as? [AXUIElement] {
                    for cell in cells {
                        var cellValue: AnyObject?
                        AXUIElementCopyAttributeValue(cell, kAXValueAttribute as CFString, &cellValue)

                        if let value = cellValue as? String {
                            rowContent.append(value)
                        } else {
                            rowContent.append("")
                        }
                    }
                }

                rows.append(rowContent)
            }
        }

        return AXTable(rows: rows)
    }

    private func extractLists(from axElement: AXUIElement) async throws -> [AXList] {
        var lists: [AXList] = []

        var childrenValue: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(axElement, kAXChildrenAttribute as CFString, &childrenValue)

        guard let children = childrenValue as? [AXUIElement] else { return lists }

        for child in children {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            if roleValue as? String == "AXList" {
                let list = try await extractListData(from: child)
                lists.append(list)
            } else {
                lists.append(contentsOf: try await extractLists(from: child))
            }
        }

        return lists
    }

    private func extractListData(from listElement: AXUIElement) async throws -> AXList {
        var items: [String] = []

        var childrenValue: AnyObject?
        AXUIElementCopyAttributeValue(listElement, kAXChildrenAttribute as CFString, &childrenValue)

        if let childElements = childrenValue as? [AXUIElement] {
            for child in childElements {
                var roleValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

                if roleValue as? String == "AXListItem" {
                    var itemValue: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &itemValue)

                    if let value = itemValue as? String {
                        items.append(value)
                    } else {
                        // Try title as fallback
                        var titleValue: AnyObject?
                        AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)

                        if let title = titleValue as? String {
                            items.append(title)
                        }
                    }
                }
            }
        }

        return AXList(items: items)
    }

    private func extractForms(from axElement: AXUIElement) async throws -> [AXForm] {
        var forms: [AXForm] = []

        var childrenValue: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(axElement, kAXChildrenAttribute as CFString, &childrenValue)

        guard let children = childrenValue as? [AXUIElement] else { return forms }

        for child in children {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            if roleValue as? String == "AXGroup" {
                // Check if this group contains form elements
                let formElements = try await extractFormElements(from: child)
                if !formElements.isEmpty {
                    let form = AXForm(elements: formElements)
                    forms.append(form)
                }
            } else {
                forms.append(contentsOf: try await extractForms(from: child))
            }
        }

        return forms
    }

    private func extractFormElements(from axElement: AXUIElement) async throws -> [AXFormElement] {
        var elements: [AXFormElement] = []

        var childrenValue: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(axElement, kAXChildrenAttribute as CFString, &childrenValue)

        guard let children = childrenValue as? [AXUIElement] else { return elements }

        for child in children {
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)

            let role = roleValue as? String ?? ""

            if ["AXTextField", "AXTextArea", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXComboBox"].contains(role) {
                var titleValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)

                var valueValue: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueValue)

                let element = AXFormElement(
                    role: role,
                    title: titleValue as? String,
                    value: valueValue as? String,
                    frame: await getElementFrame(child)
                )

                elements.append(element)
            }
        }

        return elements
    }

    private func extractCodeStructure(from axElement: AXUIElement) async throws -> AXCodeStructure? {
        // This is a simplified version - in practice, you'd want more sophisticated code parsing
        let content = try await extractTextContent(from: axElement)

        var codeStructure = AXCodeStructure()

        // Detect functions/classes
        let functionPattern = #"(func|function|def|class|struct|enum|protocol)\s+\w+"#
        let functionRegex = try NSRegularExpression(pattern: functionPattern, options: [])
        let matches = functionRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            if let range = Range(match.range, in: content) {
                let matchString = String(content[range])
                codeStructure.functions.append(matchString)
            }
        }

        // Detect imports
        let importPattern = #"(import|from|require)\s+[\w./]+"#
        let importRegex = try NSRegularExpression(pattern: importPattern, options: [])
        let importMatches = importRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in importMatches {
            if let range = Range(match.range, in: content) {
                let matchString = String(content[range])
                codeStructure.imports.append(matchString)
            }
        }

        // Detect TODO/FIXME comments
        let todoPattern = #"TODO|FIXME|NOTE|HACK|XXX"#
        let todoRegex = try NSRegularExpression(pattern: todoPattern, options: [])
        let todoMatches = todoRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in todoMatches {
            if let range = Range(match.range, in: content) {
                let lineRange = content.lineRange(for: range)
                let lineString = String(content[lineRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                codeStructure.todos.append(lineString)
            }
        }

        return codeStructure
    }

    private func detectTasks(from content: String, in windowInfo: WindowInfo) async -> AXTaskDetectionResult {
        var detectedTasks: [DetectedTask] = []
        let contentLower = content.lowercased()

        // Check for task patterns
        for (category, patterns) in taskPatterns {
            for pattern in patterns {
                if contentLower.contains(pattern.lowercased()) {
                    let confidence = calculateTaskConfidence(content: content, pattern: pattern, category: category)

                    if confidence > 0.5 {
                        let task = DetectedTask(
                            category: category,
                            pattern: pattern,
                            confidence: confidence,
                            context: extractTaskContext(content: content, pattern: pattern),
                            windowInfo: windowInfo
                        )
                        detectedTasks.append(task)
                    }
                }
            }
        }

        // Detect specific task indicators
        detectedTasks.append(contentsOf: detectSpecificTasks(content: content, windowInfo: windowInfo))

        // Sort by confidence and remove duplicates
        detectedTasks.sort { $0.confidence > $1.confidence }
        detectedTasks = removeDuplicateTasks(detectedTasks)

        return AXTaskDetectionResult(
            primaryTask: detectedTasks.first,
            allTasks: Array(detectedTasks.prefix(5)), // Top 5 tasks
            confidence: detectedTasks.first?.confidence ?? 0.0
        )
    }

    private func calculateTaskConfidence(content: String, pattern: String, category: String) -> Double {
        var confidence: Double = 0.5 // Base confidence

        // Boost confidence based on frequency
        let occurrences = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.contains(pattern.lowercased()) }
            .count

        confidence += Double(occurrences) * 0.1

        // Boost confidence for certain patterns
        if ["TODO:", "FIXME:", "func", "def "].contains(pattern) {
            confidence += 0.2
        }

        // Boost confidence based on content length (longer content with pattern = higher confidence)
        if content.count > 100 {
            confidence += 0.1
        }

        return min(confidence, 1.0)
    }

    private func extractTaskContext(content: String, pattern: String) -> String {
        // Extract surrounding text for context
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if line.lowercased().contains(pattern.lowercased()) {
                let start = max(0, index - 2)
                let end = min(lines.count - 1, index + 2)
                let contextLines = Array(lines[start...end])
                return contextLines.joined(separator: "\n")
            }
        }

        return content.prefix(200).description
    }

    private func detectSpecificTasks(content: String, windowInfo: WindowInfo) -> [DetectedTask] {
        var tasks: [DetectedTask] = []

        // Detect TODO/FIXME items
        let todoRegex = try? NSRegularExpression(pattern: #"(TODO|FIXME|NOTE|HACK|XXX):\s*(.+)"#, options: [])
        if let regex = todoRegex {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

            for match in matches {
                if let range = Range(match.range, in: content) {
                    let taskString = String(content[range])
                    let task = DetectedTask(
                        category: "task",
                        pattern: taskString,
                        confidence: 0.9,
                        context: taskString,
                        windowInfo: windowInfo
                    )
                    tasks.append(task)
                }
            }
        }

        // Detect email-related tasks
        if windowInfo.bundleIdentifier.contains("mail") {
            let emailPatterns = ["reply to", "respond to", "follow up on", "send email to"]
            for pattern in emailPatterns {
                if content.lowercased().contains(pattern) {
                    let task = DetectedTask(
                        category: "communication",
                        pattern: pattern,
                        confidence: 0.8,
                        context: extractTaskContext(content: content, pattern: pattern),
                        windowInfo: windowInfo
                    )
                    tasks.append(task)
                }
            }
        }

        // Detect calendar/meeting tasks
        if windowInfo.bundleIdentifier.contains("calendar") || content.lowercased().contains("meeting") {
            let meetingPatterns = ["schedule meeting", "attend meeting", "prepare for", "agenda"]
            for pattern in meetingPatterns {
                if content.lowercased().contains(pattern) {
                    let task = DetectedTask(
                        category: "planning",
                        pattern: pattern,
                        confidence: 0.7,
                        context: extractTaskContext(content: content, pattern: pattern),
                        windowInfo: windowInfo
                    )
                    tasks.append(task)
                }
            }
        }

        return tasks
    }

    private func removeDuplicateTasks(_ tasks: [DetectedTask]) -> [DetectedTask] {
        var uniqueTasks: [DetectedTask] = []
        var seenPatterns = Set<String>()

        for task in tasks {
            let normalizedPattern = task.pattern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if !seenPatterns.contains(normalizedPattern) {
                seenPatterns.insert(normalizedPattern)
                uniqueTasks.append(task)
            }
        }

        return uniqueTasks
    }

    private func isDevelopmentEnvironment(bundleIdentifier: String) -> Bool {
        let devApps = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.sublimetext.3",
            "com.apple.Terminal"
        ]

        return devApps.contains(bundleIdentifier)
    }

    private func getElementFrame(_ axElement: AXUIElement) async -> CGRect {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &sizeValue)

        if let position = positionValue as? NSValue,
           let size = sizeValue as? NSValue {
            let point = position.pointValue
            let dimensions = size.sizeValue
            return CGRect(origin: point, size: dimensions)
        }

        return CGRect.zero
    }
}

// MARK: - Data Models

struct WindowInfo {
    let bundleIdentifier: String
    let title: String
    let frame: CGRect
    let processIdentifier: pid_t
}

struct AXExtractionResult {
    let windowInfo: WindowInfo
    let content: String?
    let structuredData: AXStructuredData?
    let taskDetection: AXTaskDetectionResult?
    let error: Error?
}

struct AXStructuredData {
    let windowInfo: WindowInfo
    var uiElements: [CapturedAXElement] = []
    var tables: [AXTable] = []
    var lists: [AXList] = []
    var forms: [AXForm] = []
    var codeStructure: AXCodeStructure?

    init(windowInfo: WindowInfo) {
        self.windowInfo = windowInfo
    }
}

struct CapturedAXElement {
    let role: String
    let title: String?
    let value: String?
    let frame: CGRect
}

struct AXTable {
    let rows: [[String]]
}

struct AXList {
    let items: [String]
}

struct AXForm {
    let elements: [AXFormElement]
}

struct AXFormElement {
    let role: String
    let title: String?
    let value: String?
    let frame: CGRect
}

struct AXCodeStructure {
    var functions: [String] = []
    var imports: [String] = []
    var todos: [String] = []
}

struct AXApplicationState {
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let windowTitle: String?
    let role: String?
    let roleDescription: String?
    let isActive: Bool
    let launchDate: Date
}

struct AXTaskDetectionResult {
    let primaryTask: DetectedTask?
    let allTasks: [DetectedTask]
    let confidence: Double
}

struct DetectedTask {
    let category: String
    let pattern: String
    let confidence: Double
    let context: String
    let windowInfo: WindowInfo
}

enum AXExtractionError: Error {
    case appNotWhitelisted
    case accessibilityElementNotFound
    case permissionDenied
    case extractionFailed
}
