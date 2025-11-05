//
//  DynamicAllowlistManager.swift
//  FocusLock
//
//  Manages dynamic allowlist rules based on detected tasks
//

import Foundation
import Combine
import AppKit
import os.log

@MainActor
class DynamicAllowlistManager: ObservableObject {
    private let logger = Logger(subsystem: "FocusLock", category: "DynamicAllowlist")
    private let settingsManager = FocusLockSettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Published state
    @Published var currentAllowlist: [String] = []
    @Published var currentTask: String?
    @Published var isDynamicModeEnabled: Bool = true

    // Task rule storage
    private var taskRules: [String: TaskRule] = [:]
    private let taskRulesKey = "FocusLockTaskRules"

    // Default allowlist for when no rules match
    private let defaultAllowlist: [String] = [
        "com.apple.finder",
        "com.apple.systempreferences",
        "com.apple.Terminal",
        "com.apple.ActivityMonitor",
        "com.apple.Console",
        "com.apple.Notes",
        "com.apple.Safari",
        "com.apple.mail",
        "com.apple.Music",
        "com.apple.Maps",
        "com.apple.Photos",
        "com.apple.VoiceMemos",
        "com.apple.Calendar",
        "com.apple.Contacts",
        "com.apple.FaceTime"
    ]

    init() {
        loadTaskRules()
        setupObservation()
    }

    // MARK: - Public Interface

    func updateAllowlist(for taskName: String) {
        currentTask = taskName

        guard isDynamicModeEnabled else {
            currentAllowlist = settingsManager.currentSettings.globalAllowedApps
            return
        }

        let allowlist = computeAllowlist(for: taskName)

        if allowlist != currentAllowlist {
            currentAllowlist = allowlist
            logger.info("Updated allowlist for task '\(taskName)' to \(allowlist.count) apps")
        }
    }

    func addTaskRule(_ rule: TaskRule) {
        taskRules[rule.taskPattern] = rule
        saveTaskRules()
        logger.info("Added task rule: \(rule.taskPattern) with \(rule.allowedApps.count) apps")
    }

    func removeTaskRule(for pattern: String) {
        taskRules.removeValue(forKey: pattern)
        saveTaskRules()
        logger.info("Removed task rule for pattern: \(pattern)")
    }

    func enableDynamicMode(_ enabled: Bool) {
        isDynamicModeEnabled = enabled
        if !enabled {
            currentAllowlist = settingsManager.currentSettings.globalAllowedApps
        }
    }

    func getAllowedApps(for taskName: String) -> [String] {
        let allowlist = computeAllowlist(for: taskName)
        return allowlist
    }

    func isAppAllowed(_ bundleID: String) -> Bool {
        return currentAllowlist.contains(bundleID)
    }

    // MARK: - Private Methods

    private func computeAllowlist(for taskName: String) -> [String] {
        var combinedAllowlist = defaultAllowlist

        // Find matching rules
        let matchingRules = findMatchingRules(for: taskName)

        for rule in matchingRules {
            // Add allowed apps from this rule
            combinedAllowlist.append(contentsOf: rule.allowedApps)

            // Add system apps (always allowed)
            combinedAllowlist.append(contentsOf: getSystemApps())

            // Remove blocked apps from this rule
            combinedAllowlist.removeAll { bundleID in
                rule.blockedApps.contains(bundleID)
            }

            logger.debug("Applied rule '\(rule.taskPattern)' - allowed: \(rule.allowedApps.count), blocked: \(rule.blockedApps.count)")
        }

        // Remove duplicates and add global allowlist
        let globalApps = settingsManager.currentSettings.globalAllowedApps
        combinedAllowlist.append(contentsOf: globalApps)

        // Remove duplicates while preserving order
        var seen = Set<String>()
        var uniqueAllowlist: [String] = []
        for app in combinedAllowlist {
            if !seen.contains(app) {
                seen.insert(app)
                uniqueAllowlist.append(app)
            }
        }

        return uniqueAllowlist
    }

    private func findMatchingRules(for taskName: String) -> [TaskRule] {
        var matchingRules: [TaskRule] = []

        for (pattern, rule) in taskRules {
            if matchesPattern(pattern: pattern, taskName: taskName) {
                matchingRules.append(rule)
            }
        }

        // Sort by priority (higher priority first)
        matchingRules.sort { $0.priority > $1.priority }

        return matchingRules
    }

    private func matchesPattern(pattern: String, taskName: String) -> Bool {
        // Simple pattern matching for now - can be enhanced later
        let lowerPattern = pattern.lowercased()
        let lowerTaskName = taskName.lowercased()

        // Exact match
        if lowerPattern == lowerTaskName {
            return true
        }

        // Contains match
        if lowerTaskName.contains(lowerPattern) {
            return true
        }

        // Keyword match
        let keywords = pattern.lowercased().components(separatedBy: ",")
        return keywords.allSatisfy { keyword in
            lowerTaskName.contains(keyword)
        }
    }

    private func getSystemApps() -> [String] {
        return [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.loginwindow",
            "com.apple.dock",
            "com.apple.notificationcenterui",
            "com.apple.controlcenter",
            "com.apple.systemuiserver",
            "com.apple.WindowManager",
            "com.apple.recentitems"
        ]
    }

    private func loadTaskRules() {
        guard let data = UserDefaults.standard.data(forKey: taskRulesKey),
              let decoded = try? JSONDecoder().decode([String: TaskRule].self, from: data) else {
            // Create default rules if none exist
            createDefaultRules()
            return
        }

        // Convert dictionary to proper structure
        var rules: [String: TaskRule] = [:]
        for (patternJSON, rule) in decoded {
            let pattern = patternJSON
            rules[pattern] = rule
        }
        taskRules = rules
    }

    private func saveTaskRules() {
        let patterns = Array(taskRules.keys)
        let rules = patterns.map { taskRules[$0] }

        guard let encoded = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(encoded, forKey: taskRulesKey)
    }

    private func createDefaultRules() {
        // Development tasks
        let devRule = TaskRule(
            taskPattern: "development, coding, programming, software, code",
            allowedApps: [
                "com.apple.Terminal",
                "com.apple.Xcode",
                "com.vscode",
                "com.jetbrains.intellijidea",
                "com.microsoft.VSCode",
                "com.github.desktop"
            ],
            blockedApps: [
                "com.youtube.Youtube",
                "com.reddit.Reddit",
                "com.twitter.twitter-mac",
                "com.facebook.Facebook"
            ],
            priority: 10,
            description: "Apps allowed during development work"
        )

        // Writing tasks
        let writingRule = TaskRule(
            taskPattern: "writing, document, report, essay, content",
            allowedApps: [
                "com.apple.Pages",
                "com.apple.TextEdit",
                "com.microsoft.Word",
                "com.google.Docs",
                "com.notion.notion",
                "org.mozilla.firefox"
            ],
            blockedApps: [
                "com.github.desktop",
                "com.spotify.client",
                "com.apple.Music"
            ],
            priority: 8,
            description: "Apps for writing and content creation"
        )

        // Research tasks
        let researchRule = TaskRule(
            taskPattern: "research, analysis, study, learning",
            allowedApps: [
                "com.apple.Safari",
                "com.google.Chrome",
                "com.mozilla.firefox",
                "org.mozilla.firefox"
            ],
            blockedApps: [
                "com.spotify.client",
                "com.youtube.Youtube"
            ],
            priority: 7,
            description: "Apps for research and learning"
        )

        taskRules = [
            "development, coding, programming": devRule,
            "writing, document, report": writingRule,
            "research, analysis, study": researchRule
        ]

        saveTaskRules()
    }

    private func setupObservation() {
        // Observe settings changes
        settingsManager.$settings
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }

    private func handleSettingsChange() {
        // Recompute allowlist if dynamic mode is enabled
        if isDynamicModeEnabled, let currentTask = currentTask {
            updateAllowlist(for: currentTask)
        }
    }
}

// MARK: - Task Rule Model

struct TaskRule: Codable {
    let taskPattern: String
    let allowedApps: [String]
    let blockedApps: [String]
    let priority: Int
    let description: String
    let createdAt: Date
    let isActive: Bool

    init(taskPattern: String, allowedApps: [String], blockedApps: [String], priority: Int = 5, description: String = "", isActive: Bool = true) {
        self.taskPattern = taskPattern
        self.allowedApps = allowedApps
        self.blockedApps = blockedApps
        self.priority = priority
        self.description = description
        self.createdAt = Date()
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case taskPattern
        case allowedApps
        case blockedApps
        case priority
        case description
        case createdAt
        case isActive
    }
}

extension TaskRule {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let taskPattern = try container.decode(String.self, forKey: .taskPattern)
        let allowedApps = try container.decodeIfPresent([String].self, forKey: .allowedApps) ?? []
        let blockedApps = try container.decodeIfPresent([String].self, forKey: .blockedApps) ?? []
        let priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 5
        let description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        _ = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        let isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true

        self.init(
            taskPattern: taskPattern,
            allowedApps: allowedApps,
            blockedApps: blockedApps,
            priority: priority,
            description: description,
            isActive: isActive
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskPattern, forKey: .taskPattern)
        try container.encode(allowedApps, forKey: .allowedApps)
        try container.encode(blockedApps, forKey: .blockedApps)
        try container.encode(priority, forKey: .priority)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isActive, forKey: .isActive)
    }
}