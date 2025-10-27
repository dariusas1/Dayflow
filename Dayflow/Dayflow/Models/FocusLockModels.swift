//
//  FocusLockModels.swift
//  FocusLock
//
//  Core data models for FocusLock functionality
//

import Foundation
import SwiftUI

// MARK: - Session State
enum FocusSessionState: String, CaseIterable, Codable {
    case idle = "idle"
    case arming = "arming"
    case active = "active"
    case `break` = "break"
    case ended = "ended"

    var description: String {
        switch self {
        case .idle: return "Not in a focus session"
        case .arming: return "Preparing to start focus"
        case .active: return "Focus session active"
        case .break: return "Emergency break in progress"
        case .ended: return "Session completed"
        }
    }

    var isActive: Bool {
        return self == .active || self == .break
    }

    var canStart: Bool {
        return self == .idle || self == .ended
    }

    var canEnd: Bool {
        return self == .active || self == .break
    }
}

// MARK: - Focus Session
struct FocusSession: Codable, Identifiable {
    let id: UUID
    let taskName: String
    let startTime: Date
    var endTime: Date?
    var state: FocusSessionState
    var allowedApps: [String]
    var emergencyBreaks: [EmergencyBreak]
    var interruptions: [SessionInterruption]

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let duration = Int(duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%dm %ds", minutes, seconds)
    }

    var isCompleted: Bool {
        return state == .ended && duration >= 300 // At least 5 minutes
    }

    init(taskName: String, allowedApps: [String] = []) {
        self.id = UUID()
        self.taskName = taskName
        self.startTime = Date()
        self.state = .arming
        self.allowedApps = allowedApps
        self.emergencyBreaks = []
        self.interruptions = []
    }

    init(id: UUID, taskName: String, startTime: Date, endTime: Date?, state: FocusSessionState, allowedApps: [String], emergencyBreaks: [EmergencyBreak], interruptions: [SessionInterruption]) {
        self.id = id
        self.taskName = taskName
        self.startTime = startTime
        self.endTime = endTime
        self.state = state
        self.allowedApps = allowedApps
        self.emergencyBreaks = emergencyBreaks
        self.interruptions = interruptions
    }
}

// MARK: - Emergency Break
struct EmergencyBreak: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let reason: BreakReason

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var isActive: Bool {
        return endTime == nil
    }

    init(reason: BreakReason) {
        self.id = UUID()
        self.startTime = Date()
        self.reason = reason
    }

    init(id: UUID, startTime: Date, endTime: Date?, reason: BreakReason) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.reason = reason
    }
}

enum BreakReason: String, Codable, CaseIterable {
    case userRequested = "user_requested"
    case systemAlert = "system_alert"
    case appBlocked = "app_blocked"

    var description: String {
        switch self {
        case .userRequested: return "User requested break"
        case .systemAlert: return "System alert interruption"
        case .appBlocked: return "Blocked app access attempt"
        }
    }
}

// MARK: - Session Interruption
struct SessionInterruption: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let blockedAppName: String
    let blockedAppBundleID: String

    init(blockedAppName: String, blockedAppBundleID: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.blockedAppName = blockedAppName
        self.blockedAppBundleID = blockedAppBundleID
    }

    init(id: UUID, timestamp: Date, blockedAppName: String, blockedAppBundleID: String) {
        self.id = id
        self.timestamp = timestamp
        self.blockedAppName = blockedAppName
        self.blockedAppBundleID = blockedAppBundleID
    }
}

// MARK: - Session Summary
struct SessionSummary: Codable {
    let sessionId: UUID
    let taskName: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let isCompleted: Bool
    let emergencyBreakCount: Int
    let interruptionCount: Int

    var durationFormatted: String {
        let duration = Int(duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%dm %ds", minutes, seconds)
    }

    init(session: FocusSession) {
        self.sessionId = session.id
        self.taskName = session.taskName
        self.startTime = session.startTime
        self.endTime = session.endTime ?? Date()
        self.duration = session.duration
        self.isCompleted = session.isCompleted
        self.emergencyBreakCount = session.emergencyBreaks.count
        self.interruptionCount = session.interruptions.count
    }
}

// MARK: - App Policy
struct AppPolicy: Codable {
    let bundleID: String
    let appName: String
    let isAllowed: Bool
    let taskSpecificRules: [String: Bool] // taskName -> isAllowed

    init(bundleID: String, appName: String, isAllowed: Bool, taskSpecificRules: [String: Bool] = [:]) {
        self.bundleID = bundleID
        self.appName = appName
        self.isAllowed = isAllowed
        self.taskSpecificRules = taskSpecificRules
    }
}

// MARK: - Global Settings
struct FocusLockSettings: Codable {
    var globalAllowedApps: [String] // Bundle IDs
    var emergencyBreakDuration: TimeInterval // Default 20 seconds
    var minimumSessionDuration: TimeInterval // Default 5 minutes
    var autoStartDetection: Bool
    var enableNotifications: Bool
    var logSessions: Bool

    static let `default` = FocusLockSettings(
        globalAllowedApps: [
            "com.apple.Terminal",
            "com.apple.finder",
            "com.apple.TextEdit",
            "com.apple.Safari",
            "com.apple.systempreferences"
        ],
        emergencyBreakDuration: 20.0,
        minimumSessionDuration: 300.0, // 5 minutes
        autoStartDetection: true,
        enableNotifications: true,
        logSessions: true
    )
}

// MARK: - Task Detection Result
struct TaskDetectionResult {
    let taskName: String
    let confidence: Double // 0.0 to 1.0
    let detectionMethod: DetectionMethod
    let timestamp: Date
    let sourceApp: String // App where task was detected
    let applicationName: String // For compatibility with FusedDetectionResult
    let applicationBundleID: String // For compatibility with FusedDetectionResult

    enum DetectionMethod: String, CaseIterable, Codable {
        case accessibility = "accessibility"
        case ocr = "ocr"
        case manual = "manual"
    }
}

// MARK: - Analytics Data
struct SessionAnalytics: Codable {
    let date: Date // Day of session
    let totalSessions: Int
    let completedSessions: Int
    let totalDuration: TimeInterval
    let averageSessionDuration: TimeInterval
    let totalInterruptions: Int
    let totalEmergencyBreaks: Int
    let mostUsedTask: String
    let completionRate: Double

    init(sessions: [FocusSession]) {
        guard !sessions.isEmpty else {
            self.date = Date()
            self.totalSessions = 0
            self.completedSessions = 0
            self.totalDuration = 0
            self.averageSessionDuration = 0
            self.totalInterruptions = 0
            self.totalEmergencyBreaks = 0
            self.mostUsedTask = ""
            self.completionRate = 0.0
            return
        }

        let calendar = Calendar.current
        self.date = calendar.startOfDay(for: Date())

        self.totalSessions = sessions.count
        self.completedSessions = sessions.filter { $0.isCompleted }.count
        self.totalDuration = sessions.reduce(0) { $0 + $1.duration }
        self.averageSessionDuration = self.totalDuration / Double(self.totalSessions)
        self.totalInterruptions = sessions.reduce(0) { $0 + $1.interruptions.count }
        self.totalEmergencyBreaks = sessions.reduce(0) { $0 + $1.emergencyBreaks.count }

        // Find most used task
        let taskNames = sessions.map { $0.taskName }
        let taskCounts = Dictionary(grouping: taskNames, by: { $0 }).mapValues { $0.count }
        self.mostUsedTask = taskCounts.max { $0.value < $1.value }?.key ?? ""

        self.completionRate = Double(self.completedSessions) / Double(self.totalSessions)
    }
}

// MARK: - Planner Models

enum PlannerPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum PlannerEnergyLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case peak = "peak"

    var numericValue: Double {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .peak: return 1.0
        }
    }
}

enum TaskDependencyType: String, Codable {
    case finishToStart = "finish_to_start"  // Task B must start after Task A finishes
    case startToStart = "start_to_start"    // Task B must start at same time as Task A
    case finishToFinish = "finish_to_finish" // Task B must finish at same time as Task A
}

struct PlannerTask: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var estimatedDuration: TimeInterval // in seconds
    var priority: PlannerPriority
    var deadline: Date?
    var category: TaskCategory = .work
    var complexity: Double = 0.5
    var requiredResources: Set<String> = []
    var relatedGoalID: UUID?
    var goalAlignmentScore: Double?
    var sourceIdentifier: String?
    var externalSource: Bool = false
    var isCompleted: Bool = false
    var isOverdue: Bool = false
    var hasResourceConflict: Bool = false
    var isFocusSessionProtected: Bool = false
    var preferredEnergyLevel: PlannerEnergyLevel?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    // Scheduling properties
    var scheduledStartTime: Date?
    var scheduledEndTime: Date?
    var actualStartTime: Date?
    var actualEndTime: Date?
    var parentTaskID: UUID? // For subtasks
    var dependencyIDs: [UUID] // Tasks that must be completed before this one
    var dependentIDs: [UUID] // Tasks that depend on this one

    // AI optimization properties
    var optimalStartTime: Date? // AI-predicted best start time
    var confidenceScore: Double // AI confidence in scheduling (0.0 to 1.0)
    var completionProbability: Double // Predicted probability of completion
    var focusSessionRecommendation: Bool // Whether AI recommends this for focus session

    var isScheduled: Bool {
        return scheduledStartTime != nil && scheduledEndTime != nil
    }

    var durationFormatted: String {
        let duration = Int(estimatedDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    init(
        title: String,
        description: String = "",
        estimatedDuration: TimeInterval,
        priority: PlannerPriority = .medium,
        category: TaskCategory = .work,
        deadline: Date? = nil,
        complexity: Double = 0.5,
        requiredResources: Set<String> = [],
        relatedGoalID: UUID? = nil,
        goalAlignmentScore: Double? = nil,
        sourceIdentifier: String? = nil,
        externalSource: Bool = false,
        isFocusSessionProtected: Bool = false,
        preferredEnergyLevel: PlannerEnergyLevel? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.deadline = deadline
        self.category = category
        self.complexity = max(0.0, min(complexity, 1.0))
        self.requiredResources = requiredResources
        self.relatedGoalID = relatedGoalID
        self.goalAlignmentScore = goalAlignmentScore
        self.sourceIdentifier = sourceIdentifier
        self.externalSource = externalSource
        self.isCompleted = false
        self.isOverdue = deadline.map { Date() > $0 } ?? false
        self.hasResourceConflict = false
        self.isFocusSessionProtected = isFocusSessionProtected
        self.preferredEnergyLevel = preferredEnergyLevel
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = nil
        self.scheduledStartTime = nil
        self.scheduledEndTime = nil
        self.actualStartTime = nil
        self.actualEndTime = nil
        self.parentTaskID = nil
        self.dependencyIDs = []
        self.dependentIDs = []
        self.optimalStartTime = nil
        self.confidenceScore = 0.5
        self.completionProbability = 0.8
        self.focusSessionRecommendation = isFocusSessionProtected
    }

    mutating func markCompleted() {
        isCompleted = true
        completedAt = Date()
        actualEndTime = Date()
        isOverdue = false
        updatedAt = Date()
    }

    mutating func updateSchedule(startTime: Date, endTime: Date) {
        scheduledStartTime = startTime
        scheduledEndTime = endTime
        updatedAt = Date()
    }

    static func == (lhs: PlannerTask, rhs: PlannerTask) -> Bool {
        return lhs.id == rhs.id
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case work
    case learning
    case personal
    case health
    case productivity
    case career
}

struct TimeBlock: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date
    var taskID: UUID?
    var blockType: TimeBlockType
    var title: String
    var isProtected: Bool // Cannot be moved during rescheduling
    var energyLevel: PlannerEnergyLevel
    var breakBuffer: TimeInterval // Buffer time before/after this block

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let duration = Int(duration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    init(
        startTime: Date,
        endTime: Date,
        taskID: UUID? = nil,
        blockType: TimeBlockType = .task,
        title: String = "",
        isProtected: Bool = false,
        energyLevel: PlannerEnergyLevel = .medium,
        breakBuffer: TimeInterval = 300 // 5 minutes default
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.taskID = taskID
        self.blockType = blockType
        self.title = title
        self.isProtected = isProtected
        self.energyLevel = energyLevel
        self.breakBuffer = breakBuffer
    }
}

enum TimeBlockType: String, CaseIterable, Codable {
    case task = "task"
    case focus = "focus"
    case `break` = "break"
    case buffer = "buffer"
    case meeting = "meeting"
    case deepWork = "deep_work"

    var color: String {
        switch self {
        case .task: return "blue"
        case .focus: return "red"
        case .break: return "green"
        case .buffer: return "gray"
        case .meeting: return "purple"
        case .deepWork: return "orange"
        }
    }

    var isProductive: Bool {
        switch self {
        case .task, .focus, .deepWork: return true
        case .break, .buffer, .meeting: return false
        }
    }
}

struct DailyPlan: Codable, Identifiable {
    let id: UUID
    let date: Date
    var timeBlocks: [TimeBlock]
    var tasks: [PlannerTask]
    var totalScheduledTime: TimeInterval
    var totalFocusTime: TimeInterval
    var totalBreakTime: TimeInterval
    var productivityScore: Double // AI-calculated productivity potential
    var adherenceScore: Double // How well user followed the plan
    var createdAt: Date
    var updatedAt: Date

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var completionRate: Double {
        guard !tasks.isEmpty else { return 0.0 }
        let completedTasks = tasks.filter { $0.isCompleted }.count
        return Double(completedTasks) / Double(tasks.count)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.timeBlocks = []
        self.tasks = []
        self.totalScheduledTime = 0
        self.totalFocusTime = 0
        self.totalBreakTime = 0
        self.productivityScore = 0.0
        self.adherenceScore = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func addTimeBlock(_ block: TimeBlock) {
        timeBlocks.append(block)
        updateTimeMetrics()
        updatedAt = Date()
    }

    mutating func addTask(_ task: PlannerTask) {
        tasks.append(task)
        updateTimeMetrics()
        updatedAt = Date()
    }

    private mutating func updateTimeMetrics() {
        totalScheduledTime = timeBlocks.reduce(0) { $0 + $1.duration }
        totalFocusTime = timeBlocks.filter { $0.blockType == .focus || $0.blockType == .deepWork }
            .reduce(0) { $0 + $1.duration }
        totalBreakTime = timeBlocks.filter { $0.blockType == .break }
            .reduce(0) { $0 + $1.duration }
    }

    mutating func updateAdherenceScore(actualBlocks: [TimeBlock]) {
        // Compare planned vs actual time blocks
        let plannedProductiveTime = timeBlocks.filter { $0.blockType.isProductive }
            .reduce(0) { $0 + $1.duration }
        let actualProductiveTime = actualBlocks.filter { $0.blockType.isProductive }
            .reduce(0) { $0 + $1.duration }

        if plannedProductiveTime > 0 {
            adherenceScore = min(actualProductiveTime / plannedProductiveTime, 1.0)
        }
        updatedAt = Date()
    }
}

// Energy pattern models
struct EnergyPattern: Codable {
    let hourOfDay: Int // 0-23
    var averageEnergyLevel: PlannerEnergyLevel
    var focusSessionSuccessRate: Double // Success rate for focus sessions
    var taskCompletionRate: Double
    var sampleSize: Int // Number of data points
    var lastUpdated: Date

    var confidence: Double {
        // Higher confidence with more data points
        return min(Double(sampleSize) / 50.0, 1.0)
    }

    init(hourOfDay: Int) {
        self.hourOfDay = hourOfDay
        self.averageEnergyLevel = .medium
        self.focusSessionSuccessRate = 0.5
        self.taskCompletionRate = 0.5
        self.sampleSize = 0
        self.lastUpdated = Date()
    }

    mutating func updateWithSession(session: FocusSession, completed: Bool) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: session.startTime)
        guard hour == hourOfDay else { return }

        sampleSize += 1

        // Update completion rate with exponential moving average
        let alpha = 0.1 // Learning rate
        taskCompletionRate = alpha * (completed ? 1.0 : 0.0) + (1 - alpha) * taskCompletionRate

        // Update focus session success rate
        if session.isCompleted {
            focusSessionSuccessRate = alpha * 1.0 + (1 - alpha) * focusSessionSuccessRate
        }

        lastUpdated = Date()
    }
}

// Scheduling constraint models
struct SchedulingConstraint: Codable {
    let id: UUID
    var type: ConstraintType
    var taskID: UUID
    var parameter: String?
    private var numericValueStorage: Double?
    private var stringValueStorage: String?
    var isActive: Bool

    enum ConstraintType: String, CaseIterable, Codable {
        case startTime = "start_time"
        case endTime = "end_time"
        case maxDailyTasks = "max_daily_tasks"
        case minBreakTime = "min_break_time"
        case energyLevel = "energy_level"
        case dependency = "dependency"
        case deadline = "deadline"
        case focusSessionOnly = "focus_session_only"
        case maxFocusTime = "max_focus_time"
        case energyAlignment = "energy_alignment"
        case deadlinePriority = "deadline_priority"
        case categoryBalance = "category_balance"
        case maxWorkHours = "max_work_hours"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case taskID
        case parameter
        case numericValue
        case stringValue
        case legacyValue = "value"
        case isActive
    }

    var value: Double {
        get {
            if let numericValueStorage {
                return numericValueStorage
            }
            if let stringValueStorage, let numeric = Double(stringValueStorage) {
                return numeric
            }
            return 0
        }
        set {
            numericValueStorage = newValue
            stringValueStorage = nil
        }
    }

    var intValue: Int {
        return Int(value.rounded())
    }

    var stringValue: String? {
        get {
            if let stringValueStorage {
                return stringValueStorage
            }
            if let numericValueStorage {
                return String(numericValueStorage)
            }
            return nil
        }
        set {
            stringValueStorage = newValue
            if let newValue, let numeric = Double(newValue) {
                numericValueStorage = numeric
            } else {
                numericValueStorage = nil
            }
        }
    }

    init(type: ConstraintType, taskID: UUID, parameter: String? = nil, value: Double, isActive: Bool = true) {
        self.id = UUID()
        self.type = type
        self.taskID = taskID
        self.parameter = parameter
        self.numericValueStorage = value
        self.stringValueStorage = nil
        self.isActive = isActive
    }

    init(type: ConstraintType, taskID: UUID, parameter: String? = nil, stringValue: String, isActive: Bool = true) {
        self.id = UUID()
        self.type = type
        self.taskID = taskID
        self.parameter = parameter
        self.numericValueStorage = Double(stringValue)
        self.stringValueStorage = stringValue
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ConstraintType.self, forKey: .type)
        taskID = try container.decode(UUID.self, forKey: .taskID)
        parameter = try container.decodeIfPresent(String.self, forKey: .parameter)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true

        numericValueStorage = try container.decodeIfPresent(Double.self, forKey: .numericValue)
        stringValueStorage = try container.decodeIfPresent(String.self, forKey: .stringValue)

        if numericValueStorage == nil {
            if let legacyNumeric = try container.decodeIfPresent(Double.self, forKey: .legacyValue) {
                numericValueStorage = legacyNumeric
            } else if stringValueStorage == nil,
                      let legacyString = try container.decodeIfPresent(String.self, forKey: .legacyValue) {
                stringValueStorage = legacyString
                numericValueStorage = Double(legacyString)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(taskID, forKey: .taskID)
        try container.encodeIfPresent(parameter, forKey: .parameter)
        try container.encode(isActive, forKey: .isActive)

        if let numericValueStorage {
            try container.encode(numericValueStorage, forKey: .numericValue)
        } else if let stringValueStorage {
            try container.encode(stringValueStorage, forKey: .stringValue)
        }
    }
}

// Adaptive scheduling models
struct SchedulingFeedback: Codable {
    let id: UUID
    let taskID: UUID
    let plannedStartTime: Date
    let plannedEndTime: Date
    let actualStartTime: Date?
    let actualEndTime: Date?
    let userRating: Int // 1-5 rating of scheduling quality
    let feedback: String
    let timestamp: Date

    var accuracyScore: Double {
        guard let actualStart = actualStartTime,
              let actualEnd = actualEndTime else { return 0.0 }

        let plannedDuration = plannedEndTime.timeIntervalSince(plannedStartTime)
        let actualDuration = actualEnd.timeIntervalSince(actualStart)

        if plannedDuration == 0 { return 0.0 }

        let accuracy = 1.0 - abs(actualDuration - plannedDuration) / plannedDuration
        return max(accuracy, 0.0)
    }

    init(taskID: UUID, plannedStart: Date, plannedEnd: Date, rating: Int, feedback: String) {
        self.id = UUID()
        self.taskID = taskID
        self.plannedStartTime = plannedStart
        self.plannedEndTime = plannedEnd
        self.actualStartTime = nil
        self.actualEndTime = nil
        self.userRating = rating
        self.feedback = feedback
        self.timestamp = Date()
    }

    mutating func recordActualTimes(start: Date, end: Date) {
        actualStartTime = start
        actualEndTime = end
    }
}

// Calendar integration models
struct CalendarEvent: Codable, Identifiable {
    let id: UUID
    var externalID: String? // ID from external calendar
    var title: String
    var startTime: Date
    var endTime: Date
    var isRecurring: Bool
    var location: String?
    var notes: String?
    var taskID: UUID? // Associated planner task
    var source: CalendarSource

    enum CalendarSource: String, Codable {
        case focusLock = "focuslock"
        case appleCalendar = "apple_calendar"
        case googleCalendar = "google_calendar"
        case outlook = "outlook"
    }

    init(
        title: String,
        startTime: Date,
        endTime: Date,
        source: CalendarSource = .focusLock,
        taskID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isRecurring = false
        self.source = source
        self.taskID = taskID
    }
}

// MARK: - Dashboard Productivity Models

struct ProductivityMetric: Identifiable, Codable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
    let category: MetricCategory
    let timestamp: Date
    let metadata: [String: AnyCodable]

    enum MetricCategory: String, Codable, CaseIterable {
        case focusTime = "focus_time"
        case taskCompletion = "task_completion"
        case appUsage = "app_usage"
        case productivity = "productivity"
        case wellness = "wellness"
        case goals = "goals"

        var displayName: String {
            switch self {
            case .focusTime: return "Focus Time"
            case .taskCompletion: return "Task Completion"
            case .appUsage: return "App Usage"
            case .productivity: return "Productivity"
            case .wellness: return "Wellness"
            case .goals: return "Goals"
            }
        }

        var color: Color {
            switch self {
            case .focusTime: return .blue
            case .taskCompletion: return .green
            case .appUsage: return .orange
            case .productivity: return .purple
            case .wellness: return .pink
            case .goals: return .teal
            }
        }
    }

    init(name: String, value: Double, unit: String, category: MetricCategory, timestamp: Date = Date(), metadata: [String: Any] = [:]) {
        self.name = name
        self.value = value
        self.unit = unit
        self.category = category
        self.timestamp = timestamp
        self.metadata = metadata.mapValues { AnyCodable($0) }
    }
}

// MARK: - Query Processing Models

struct QueryResult: Identifiable {
    let id = UUID()
    let query: String
    let answer: String
    let supportingData: [ProductivityMetric]
    let visualizations: [ChartType]
    let confidence: Double
    let processingTime: TimeInterval
    let timestamp: Date

    enum ChartType: String, CaseIterable {
        case lineChart = "line"
        case barChart = "bar"
        case pieChart = "pie"
        case scatterPlot = "scatter"
        case timeline = "timeline"

        var displayName: String {
            switch self {
            case .lineChart: return "Line Chart"
            case .barChart: return "Bar Chart"
            case .pieChart: return "Pie Chart"
            case .scatterPlot: return "Scatter Plot"
            case .timeline: return "Timeline"
            }
        }
    }
}

// MARK: - Trend Analysis Models

struct TrendData: Identifiable, Codable {
    let id = UUID()
    let metricName: String
    let datapoints: [DataPoint]
    let trendDirection: TrendDirection
    let trendStrength: Double // 0.0 to 1.0
    let insights: [TrendInsight]
    let dateRange: DateInterval

    enum TrendDirection: String, Codable {
        case increasing = "increasing"
        case decreasing = "decreasing"
        case stable = "stable"
        case volatile = "volatile"

        var arrow: String {
            switch self {
            case .increasing: return "↑"
            case .decreasing: return "↓"
            case .stable: return "→"
            case .volatile: return "↕"
            }
        }

        var color: Color {
            switch self {
            case .increasing: return .green
            case .decreasing: return .red
            case .stable: return .blue
            case .volatile: return .orange
            }
        }
    }

    struct DataPoint: Identifiable, Codable {
        let id = UUID()
        let date: Date
        let value: Double
        let context: [String: AnyCodable]?

        init(date: Date, value: Double, context: [String: Any] = [:]) {
            self.date = date
            self.value = value
            self.context = context.mapValues { AnyCodable($0) }
        }
    }

    struct TrendInsight: Identifiable, Codable {
        let id = UUID()
        let type: InsightType
        let title: String
        let description: String
        let severity: Severity
        let actionable: Bool
        let suggestions: [String]

        enum InsightType: String, Codable, CaseIterable {
            case peakPerformance = "peak_performance"
            case productivityDrop = "productivity_drop"
            case unusualPattern = "unusual_pattern"
            case goalProgress = "goal_progress"
            case burnoutRisk = "burnout_risk"
            case opportunity = "opportunity"

            var icon: String {
                switch self {
                case .peakPerformance: return "star.circle"
                case .productivityDrop: return "arrow.down.circle"
                case .unusualPattern: return "questionmark.circle"
                case .goalProgress: return "target"
                case .burnoutRisk: return "exclamationmark.triangle"
                case .opportunity: return "lightbulb.circle"
                }
            }

            var color: Color {
                switch self {
                case .peakPerformance: return .green
                case .productivityDrop: return .red
                case .unusualPattern: return .yellow
                case .goalProgress: return .blue
                case .burnoutRisk: return .orange
                case .opportunity: return .purple
                }
            }
        }

        enum Severity: String, Codable, CaseIterable {
            case low = "low"
            case medium = "medium"
            case high = "high"
            case critical = "critical"

            var color: Color {
                switch self {
                case .low: return .green
                case .medium: return .yellow
                case .high: return .orange
                case .critical: return .red
                }
            }

            var priority: Int {
                switch self {
                case .low: return 1
                case .medium: return 2
                case .high: return 3
                case .critical: return 4
                }
            }
        }
    }
}

// MARK: - Widget Configuration Models

struct DashboardWidget: Identifiable, Codable {
    let id = UUID()
    let type: WidgetType
    let title: String
    let configuration: WidgetConfiguration
    let position: WidgetPosition
    let isVisible: Bool
    let refreshInterval: TimeInterval

    enum WidgetType: String, Codable, CaseIterable {
        case productivityScore = "productivity_score"
        case focusTimeChart = "focus_time_chart"
        case topApplications = "top_applications"
        case taskProgress = "task_progress"
        case trendAnalysis = "trend_analysis"
        case insights = "insights"
        case goalsOverview = "goals_overview"
        case quickQuery = "quick_query"

        var displayName: String {
            switch self {
            case .productivityScore: return "Productivity Score"
            case .focusTimeChart: return "Focus Time"
            case .topApplications: return "Top Applications"
            case .taskProgress: return "Task Progress"
            case .trendAnalysis: return "Trend Analysis"
            case .insights: return "Insights"
            case .goalsOverview: return "Goals Overview"
            case .quickQuery: return "Quick Query"
            }
        }

        var defaultSize: WidgetSize {
            switch self {
            case .productivityScore: return .small
            case .focusTimeChart: return .medium
            case .topApplications: return .medium
            case .taskProgress: return .small
            case .trendAnalysis: return .large
            case .insights: return .medium
            case .goalsOverview: return .medium
            case .quickQuery: return .small
            }
        }

        var icon: String {
            switch self {
            case .productivityScore: return "chart.bar"
            case .focusTimeChart: return "clock"
            case .topApplications: return "app.badge"
            case .taskProgress: return "checklist"
            case .trendAnalysis: return "line.chart.uptrend.xyaxis"
            case .insights: return "lightbulb"
            case .goalsOverview: return "target"
            case .quickQuery: return "magnifyingglass.circle"
            }
        }
    }

    enum WidgetSize: String, Codable, CaseIterable {
        case small = "small"
        case medium = "medium"
        case large = "large"
        case full = "full"

        var dimensions: (width: Int, height: Int) {
            switch self {
            case .small: return (2, 2)
            case .medium: return (4, 2)
            case .large: return (4, 4)
            case .full: return (8, 8)
            }
        }
    }

    struct WidgetConfiguration: Codable {
        let timeRange: TimeRange
        let refreshInterval: TimeInterval
        let customSettings: [String: AnyCodable]

        enum TimeRange: String, Codable, CaseIterable {
            case lastDay = "last_day"
            case lastWeek = "last_week"
            case lastMonth = "last_month"
            case lastQuarter = "last_quarter"
            case lastYear = "last_year"
            case custom = "custom"

            var displayName: String {
                switch self {
                case .lastDay: return "Last Day"
                case .lastWeek: return "Last Week"
                case .lastMonth: return "Last Month"
                case .lastQuarter: return "Last Quarter"
                case .lastYear: return "Last Year"
                case .custom: return "Custom"
                }
            }
        }
    }

    struct WidgetPosition: Codable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int

        init(x: Int = 0, y: Int = 0, width: Int = 2, height: Int = 2) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }
}

// MARK: - Recommendation Engine Models

struct Recommendation: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let category: RecommendationCategory
    let priority: Priority
    let actionable: Bool
    let estimatedImpact: Impact
    let suggestedActions: [SuggestedAction]
    let evidence: [ProductivityMetric]
    let createdAt: Date
    let dismissedAt: Date?

    enum RecommendationCategory: String, Codable, CaseIterable {
        case focusImprovement = "focus_improvement"
        case timeManagement = "time_management"
        case appUsage = "app_usage"
        case goalSetting = "goal_setting"
        case wellness = "wellness"
        case habitFormation = "habit_formation"

        var displayName: String {
            switch self {
            case .focusImprovement: return "Focus Improvement"
            case .timeManagement: return "Time Management"
            case .appUsage: return "App Usage"
            case .goalSetting: return "Goal Setting"
            case .wellness: return "Wellness"
            case .habitFormation: return "Habit Formation"
            }
        }

        var icon: String {
            switch self {
            case .focusImprovement: return "brain.head.profile"
            case .timeManagement: return "clock.arrow.circlepath"
            case .appUsage: return "app.badge.checkmark"
            case .goalSetting: return "target"
            case .wellness: return "heart.circle"
            case .habitFormation: return "repeat"
            }
        }

        var color: Color {
            switch self {
            case .focusImprovement: return .blue
            case .timeManagement: return .green
            case .appUsage: return .orange
            case .goalSetting: return .purple
            case .wellness: return .pink
            case .habitFormation: return .teal
            }
        }
    }

    enum Priority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"

        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .urgent: return .red
            }
        }

        var level: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .urgent: return 4
            }
        }
    }

    enum Impact: String, Codable, CaseIterable {
        case minimal = "minimal"
        case moderate = "moderate"
        case significant = "significant"
        case transformative = "transformative"

        var displayName: String {
            switch self {
            case .minimal: return "Minimal"
            case .moderate: return "Moderate"
            case .significant: return "Significant"
            case .transformative: return "Transformative"
            }
        }

        var color: Color {
            switch self {
            case .minimal: return .gray
            case .moderate: return .blue
            case .significant: return .green
            case .transformative: return .purple
            }
        }
    }

    struct SuggestedAction: Identifiable, Codable {
        let id = UUID()
        let title: String
        let description: String
        let difficulty: Difficulty
        let estimatedTime: TimeInterval
        let steps: [String]

        enum Difficulty: String, Codable, CaseIterable {
            case easy = "easy"
            case moderate = "moderate"
            case challenging = "challenging"

            var color: Color {
                switch self {
                case .easy: return .green
                case .moderate: return .yellow
                case .challenging: return .red
                }
            }
        }
    }
}

// MARK: - Dashboard Configuration

struct DashboardConfiguration: Codable {
    let widgets: [DashboardWidget]
    let theme: DashboardTheme
    let layout: GridLayout
    let preferences: UserPreferences

    struct DashboardTheme: Codable {
        let colorScheme: ColorScheme
        let accentColor: String
        let chartStyle: ChartStyle

        enum ColorScheme: String, Codable, CaseIterable {
            case light = "light"
            case dark = "dark"
            case system = "system"

            var displayName: String {
                switch self {
                case .light: return "Light"
                case .dark: return "Dark"
                case .system: return "System"
                }
            }
        }

        enum ChartStyle: String, Codable, CaseIterable {
            case minimal = "minimal"
            case colorful = "colorful"
            case monochrome = "monochrome"

            var displayName: String {
                switch self {
                case .minimal: return "Minimal"
                case .colorful: return "Colorful"
                case .monochrome: return "Monochrome"
                }
            }
        }
    }

    struct GridLayout: Codable {
        let columns: Int
        let rows: Int
        let spacing: CGFloat
        let padding: CGFloat

        static let `default` = GridLayout(columns: 8, rows: 8, spacing: 12, padding: 16)
    }

    struct UserPreferences: Codable {
        let autoRefresh: Bool
        let refreshInterval: TimeInterval
        let showInsights: Bool
        let showRecommendations: Bool
        let enableAnimations: Bool
        let compactMode: Bool

        static let `default` = UserPreferences(
            autoRefresh: true,
            refreshInterval: 300, // 5 minutes
            showInsights: true,
            showRecommendations: true,
            enableAnimations: true,
            compactMode: false
        )
    }
}

// MARK: - Performance Models

struct PerformanceMetrics: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: UUID?
    let componentMetrics: [ComponentPerformanceMetric]
    let systemMetrics: SystemPerformanceMetric
    let batteryMetrics: BatteryMetrics?
    let thermalMetrics: ThermalMetrics?

    var overallScore: Double {
        let componentScore = componentMetrics.isEmpty ? 1.0 : componentMetrics.map { $0.score }.reduce(0, +) / Double(componentMetrics.count)
        let systemScore = systemMetrics.score
        let batteryScore = batteryMetrics?.score ?? 1.0
        let thermalScore = thermalMetrics?.score ?? 1.0

        return (componentScore + systemScore + batteryScore + thermalScore) / 4.0
    }

    var isOptimal: Bool {
        return overallScore >= 0.8 && systemMetrics.isWithinBudgets
    }

    init(sessionId: UUID? = nil, componentMetrics: [ComponentPerformanceMetric] = [], systemMetrics: SystemPerformanceMetric, batteryMetrics: BatteryMetrics? = nil, thermalMetrics: ThermalMetrics? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionId = sessionId
        self.componentMetrics = componentMetrics
        self.systemMetrics = systemMetrics
        self.batteryMetrics = batteryMetrics
        self.thermalMetrics = thermalMetrics
    }
}

struct ComponentPerformanceMetric: Codable, Identifiable {
    let id: UUID
    let component: FocusLockComponent
    let operation: ComponentOperation
    let responseTime: TimeInterval
    let memoryUsage: MemoryUsage
    let cpuUsage: Double
    let errorRate: Double
    let throughput: Double // operations per second
    let timestamp: Date

    var score: Double {
        var score: Double = 1.0

        // Response time scoring (lower is better, target < 1s)
        if responseTime > 3.0 {
            score *= 0.3
        } else if responseTime > 1.0 {
            score *= 0.7
        }

        // Error rate scoring (lower is better, target < 1%)
        if errorRate > 0.05 {
            score *= 0.5
        } else if errorRate > 0.01 {
            score *= 0.8
        }

        // Memory usage scoring (lower is better, target < 50MB)
        if memoryUsage.peak > 100 {
            score *= 0.5
        } else if memoryUsage.peak > 50 {
            score *= 0.8
        }

        // CPU usage scoring (lower is better, target < 20%)
        if cpuUsage > 0.5 {
            score *= 0.4
        } else if cpuUsage > 0.2 {
            score *= 0.8
        }

        return score
    }

    var isHealthy: Bool {
        return score >= 0.7 && errorRate < 0.01 && responseTime < 1.0
    }

    init(component: FocusLockComponent, operation: ComponentOperation, responseTime: TimeInterval, memoryUsage: MemoryUsage, cpuUsage: Double, errorRate: Double = 0.0, throughput: Double = 1.0) {
        self.id = UUID()
        self.component = component
        self.operation = operation
        self.responseTime = responseTime
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.errorRate = errorRate
        self.throughput = throughput
        self.timestamp = Date()
    }
}

struct SystemPerformanceMetric: Codable {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: SystemMemoryUsage
    let diskIO: DiskIOMetrics
    let networkIO: NetworkIOMetrics
    let processCount: Int
    let threadCount: Int

    var score: Double {
        var score: Double = 1.0

        // CPU usage (target < 8% active, < 1.5% idle)
        let cpuTarget = 0.08
        if cpuUsage > cpuTarget * 2 {
            score *= 0.3
        } else if cpuUsage > cpuTarget {
            score *= 0.7
        }

        // Memory usage (target < 250MB)
        if memoryUsage.used > 500 {
            score *= 0.3
        } else if memoryUsage.used > 250 {
            score *= 0.7
        }

        return score
    }

    var isWithinBudgets: Bool {
        return cpuUsage < 0.08 && memoryUsage.used < 250.0
    }

    init(cpuUsage: Double, memoryUsage: SystemMemoryUsage, diskIO: DiskIOMetrics, networkIO: NetworkIOMetrics, processCount: Int, threadCount: Int) {
        self.timestamp = Date()
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskIO = diskIO
        self.networkIO = networkIO
        self.processCount = processCount
        self.threadCount = threadCount
    }
}

struct MemoryUsage: Codable {
    let current: Double
    let peak: Double
    let average: Double
    let allocations: Int
    let deallocations: Int

    var pressure: MemoryPressure {
        if peak > 500 { return .critical }
        if peak > 250 { return .high }
        if peak > 150 { return .medium }
        return .low
    }

    init(current: Double, peak: Double = current, average: Double = current, allocations: Int = 0, deallocations: Int = 0) {
        self.current = current
        self.peak = peak
        self.average = average
        self.allocations = allocations
        self.deallocations = deallocations
    }
}

struct SystemMemoryUsage: Codable {
    let used: Double
    let available: Double
    let total: Double
    let pressure: Double
    let purgeable: Double

    var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return used / total
    }

    init(used: Double, available: Double, total: Double, pressure: Double = 0, purgeable: Double = 0) {
        self.used = used
        self.available = available
        self.total = total
        self.pressure = pressure
        self.purgeable = purgeable
    }
}

struct DiskIOMetrics: Codable {
    let readsPerSecond: Double
    let writesPerSecond: Double
    let readBytesPerSecond: Double
    let writeBytesPerSecond: Double
    let queueDepth: Int

    var isOptimal: Bool {
        return readsPerSecond < 100 && writesPerSecond < 100 && queueDepth < 10
    }

    init(readsPerSecond: Double = 0, writesPerSecond: Double = 0, readBytesPerSecond: Double = 0, writeBytesPerSecond: Double = 0, queueDepth: Int = 0) {
        self.readsPerSecond = readsPerSecond
        self.writesPerSecond = writesPerSecond
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.queueDepth = queueDepth
    }
}

struct NetworkIOMetrics: Codable {
    let bytesInPerSecond: Double
    let bytesOutPerSecond: Double
    let packetsInPerSecond: Double
    let packetsOutPerSecond: Double
    let connections: Int

    var totalThroughput: Double {
        return bytesInPerSecond + bytesOutPerSecond
    }

    init(bytesInPerSecond: Double = 0, bytesOutPerSecond: Double = 0, packetsInPerSecond: Double = 0, packetsOutPerSecond: Double = 0, connections: Int = 0) {
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.packetsInPerSecond = packetsInPerSecond
        self.packetsOutPerSecond = packetsOutPerSecond
        self.connections = connections
    }
}

struct BatteryMetrics: Codable {
    let level: Double // 0.0 to 1.0
    let state: BatteryState
    let timeRemaining: TimeInterval?
    let temperature: Double?
    let voltage: Double?
    let cycleCount: Int?

    var score: Double {
        var score: Double = 1.0

        if level < 0.1 {
            score *= 0.3
        } else if level < 0.2 {
            score *= 0.6
        }

        if state == .unplugged && level < 0.3 {
            score *= 0.8
        }

        if let temperature = temperature, temperature > 40 {
            score *= 0.9
        }

        return score
    }

    var isHealthy: Bool {
        return level > 0.2 && (temperature == nil || temperature! < 40)
    }

    var estimatedMinutesRemaining: Int? {
        guard let timeRemaining = timeRemaining else { return nil }
        return Int(timeRemaining / 60)
    }

    init(level: Double, state: BatteryState, timeRemaining: TimeInterval? = nil, temperature: Double? = nil, voltage: Double? = nil, cycleCount: Int? = nil) {
        self.level = level
        self.state = state
        self.timeRemaining = timeRemaining
        self.temperature = temperature
        self.voltage = voltage
        self.cycleCount = cycleCount
    }
}

struct ThermalMetrics: Codable {
    let temperature: Double
    let state: ThermalState
    let throttlingActive: Bool
    let fanSpeed: Double?

    var score: Double {
        switch state {
        case .normal: return 1.0
        case .fair: return 0.8
        case .serious: return 0.5
        case .critical: return 0.2
        }
    }

    var isOptimal: Bool {
        return state == .normal && !throttlingActive
    }

    init(temperature: Double, state: ThermalState, throttlingActive: Bool = false, fanSpeed: Double? = nil) {
        self.temperature = temperature
        self.state = state
        self.throttlingActive = throttlingActive
        self.fanSpeed = fanSpeed
    }
}

// MARK: - Performance Budget Models

struct PerformanceBudget: Codable {
    let maxCPUUsage: Double
    let maxMemoryUsage: Double
    let maxDiskIO: DiskIOMetrics
    let maxNetworkIO: NetworkIOMetrics
    let minBatteryLevel: Double?
    let maxTemperature: Double?

    var isStringent: Bool {
        return maxCPUUsage < 0.05 && maxMemoryUsage < 150.0
    }

    init(maxCPUUsage: Double = 0.08, maxMemoryUsage: Double = 250.0, maxDiskIO: DiskIOMetrics = DiskIOMetrics(), maxNetworkIO: NetworkIOMetrics = NetworkIOMetrics(), minBatteryLevel: Double? = nil, maxTemperature: Double? = nil) {
        self.maxCPUUsage = maxCPUUsage
        self.maxMemoryUsage = maxMemoryUsage
        self.maxDiskIO = maxDiskIO
        self.maxNetworkIO = maxNetworkIO
        self.minBatteryLevel = minBatteryLevel
        self.maxTemperature = maxTemperature
    }

    func validate(_ metrics: PerformanceMetrics) -> BudgetViolation {
        var violations: [String] = []

        if metrics.systemMetrics.cpuUsage > maxCPUUsage {
            violations.append("CPU usage exceeds budget: \(Int(metrics.systemMetrics.cpuUsage * 100))% > \(Int(maxCPUUsage * 100))%")
        }

        if metrics.systemMetrics.memoryUsage.used > maxMemoryUsage {
            violations.append("Memory usage exceeds budget: \(Int(metrics.systemMetrics.memoryUsage.used))MB > \(Int(maxMemoryUsage))MB")
        }

        if let minBattery = minBatteryLevel, let battery = metrics.batteryMetrics, battery.level < minBattery {
            violations.append("Battery level below minimum: \(Int(battery.level * 100))% < \(Int(minBattery * 100))%")
        }

        if let maxTemp = maxTemperature, let thermal = metrics.thermalMetrics, thermal.temperature > maxTemp {
            violations.append("Temperature exceeds maximum: \(thermal.temperature)°C > \(maxTemp)°C")
        }

        return BudgetViolation(
            hasViolations: !violations.isEmpty,
            violations: violations,
            severity: violations.count > 2 ? .critical : violations.isEmpty ? .none : .warning
        )
    }
}

struct BudgetViolation: Codable {
    let hasViolations: Bool
    let violations: [String]
    let severity: ViolationSeverity

    init(hasViolations: Bool, violations: [String] = [], severity: ViolationSeverity = .warning) {
        self.hasViolations = hasViolations
        self.violations = violations
        self.severity = severity
    }
}

enum ViolationSeverity: String, CaseIterable, Codable {
    case none = "none"
    case warning = "warning"
    case critical = "critical"
}

// MARK: - Power Efficiency Models

struct PowerEfficiencyMetrics: Codable {
    let timestamp: Date
    let powerConsumption: Double // Watts
    let energyPerOperation: Double
    let efficiencyScore: Double
    let recommendations: [PowerRecommendation]

    var isEfficient: Bool {
        return efficiencyScore >= 0.7 && powerConsumption < 10.0
    }

    init(powerConsumption: Double, energyPerOperation: Double, efficiencyScore: Double, recommendations: [PowerRecommendation] = []) {
        self.timestamp = Date()
        self.powerConsumption = powerConsumption
        self.energyPerOperation = energyPerOperation
        self.efficiencyScore = efficiencyScore
        self.recommendations = recommendations
    }
}

struct PowerRecommendation: Codable {
    let type: PowerRecommendationType
    let description: String
    let estimatedSavings: Double // Percentage
    let priority: PowerRecommendationPriority

    init(type: PowerRecommendationType, description: String, estimatedSavings: Double, priority: PowerRecommendationPriority = .medium) {
        self.type = type
        self.description = description
        self.estimatedSavings = estimatedSavings
        self.priority = priority
    }
}

enum PowerRecommendationType: String, CaseIterable, Codable {
    case reduceBackgroundProcessing = "reduce_background_processing"
    case lowerProcessingFrequency = "lower_processing_frequency"
    case enableLowPowerMode = "enable_low_power_mode"
    case optimizeMemoryUsage = "optimize_memory_usage"
    case reduceNetworkActivity = "reduce_network_activity"
}

enum PowerRecommendationPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - Background Processing Models

struct BackgroundTaskMetrics: Codable {
    let taskId: String
    let component: FocusLockComponent
    let priority: TaskPriority
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval?
    let resourceUsage: ResourceUsage
    let success: Bool
    let error: String?

    var isCompleted: Bool {
        return endTime != nil && duration != nil
    }

    var efficiency: Double {
        guard let duration = duration else { return 0 }
        let expectedDuration = getExpectedDuration(for: component, priority: priority)
        return min(expectedDuration / duration, 1.0)
    }

    init(taskId: String, component: FocusLockComponent, priority: TaskPriority, resourceUsage: ResourceUsage, success: Bool = true, error: String? = nil) {
        self.taskId = taskId
        self.component = component
        self.priority = priority
        self.startTime = Date()
        self.endTime = nil
        self.duration = nil
        self.resourceUsage = resourceUsage
        self.success = success
        self.error = error
    }

    mutating func complete(success: Bool = true, error: String? = nil) {
        self.endTime = Date()
        self.duration = endTime?.timeIntervalSince(startTime)
        self.success = success
        self.error = error
    }

    private func getExpectedDuration(for component: FocusLockComponent, priority: TaskPriority) -> TimeInterval {
        let baseDuration: TimeInterval

        switch component {
        case .memoryStore: baseDuration = 2.0
        case .ocrExtractor: baseDuration = 5.0
        case .axExtractor: baseDuration = 1.0
        case .jarvisChat: baseDuration = 8.0
        case .activityTap: baseDuration = 0.5
        }

        let priorityMultiplier: Double
        switch priority {
        case .critical: priorityMultiplier = 0.5
        case .high: priorityMultiplier = 0.75
        case .medium: priorityMultiplier = 1.0
        case .low: priorityMultiplier = 1.5
        }

        return baseDuration * priorityMultiplier
    }
}

// MARK: - Supporting Enums

enum MemoryPressure: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum BatteryState: String, CaseIterable, Codable {
    case unplugged = "unplugged"
    case charging = "charging"
    case plugged = "plugged"
    case unknown = "unknown"
}

enum ThermalState: String, CaseIterable, Codable {
    case normal = "normal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"
}

enum FocusLockComponent: String, CaseIterable, Codable {
    case memoryStore = "memory_store"
    case activityTap = "activity_tap"
    case ocrExtractor = "ocr_extractor"
    case axExtractor = "ax_extractor"
    case jarvisChat = "jarvis_chat"

    var displayName: String {
        switch self {
        case .memoryStore: return "Memory Store"
        case .activityTap: return "Activity Tap"
        case .ocrExtractor: return "OCR Extractor"
        case .axExtractor: return "AX Extractor"
        case .jarvisChat: return "Jarvis Chat"
        }
    }
}

enum ComponentOperation: String, CaseIterable, Codable {
    case search = "search"
    case index = "index"
    case embed = "embed"
    case extract = "extract"
    case process = "process"
    case monitor = "monitor"
    case cache = "cache"
    case other = "other"

    var displayName: String {
        switch self {
        case .search: return "Search"
        case .index: return "Index"
        case .embed: return "Embed"
        case .extract: return "Extract"
        case .process: return "Process"
        case .monitor: return "Monitor"
        case .cache: return "Cache"
        case .other: return "Other"
        }
    }
}

enum TaskPriority: Int, CaseIterable, Codable {
    case critical = 1
    case high = 2
    case medium = 3
    case low = 4

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

struct ResourceUsage: Codable {
    let timestamp: Date
    let cpuPercent: Double
    let memoryMB: Double
    let diskUsageMB: Double
    let networkActivity: NetworkActivity

    init(timestamp: Date, cpuPercent: Double, memoryMB: Double, diskUsageMB: Double, networkActivity: NetworkActivity) {
        self.timestamp = timestamp
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.diskUsageMB = diskUsageMB
        self.networkActivity = networkActivity
    }
}

struct NetworkActivity: Codable {
    let incomingBytesPerSecond: Double
    let outgoingBytesPerSecond: Double
    let totalBytesPerSecond: Double

    init(incomingBytesPerSecond: Double, outgoingBytesPerSecond: Double, totalBytesPerSecond: Double) {
        self.incomingBytesPerSecond = incomingBytesPerSecond
        self.outgoingBytesPerSecond = outgoingBytesPerSecond
        self.totalBytesPerSecond = totalBytesPerSecond
    }
}

// MARK: - Suggested Todos Models

struct SuggestedTodo: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let priority: SuggestionPriority
    let confidence: Double // AI confidence score 0.0-1.0
    let sourceContent: String // Original content that generated this suggestion
    let sourceType: SuggestionSourceType
    let sourceActivityId: UUID? // Reference to the Activity that generated this
    let contextTags: [String]
    let estimatedDuration: TimeInterval?
    let deadline: Date?
    let createdAt: Date
    var lastShown: Date?
    var userFeedback: UserFeedback?
    var isAccepted: Bool?
    var isDismissed: Bool
    var dismissReason: String?
    var learningScore: Double // Machine learning score for this suggestion

    var isActive: Bool {
        return !isDismissed && (userFeedback == nil || userFeedback?.score != nil)
    }

    var isHighPriority: Bool {
        return priority == .urgent || priority == .high
    }

    var urgencyScore: Double {
        var score = Double(priority.numericValue) / 4.0

        if let deadline = deadline {
            let hoursUntilDeadline = deadline.timeIntervalSinceNow / 3600
            if hoursUntilDeadline < 0 {
                score += 1.0 // Overdue
            } else if hoursUntilDeadline < 24 {
                score += 0.8 // Due within 24 hours
            } else if hoursUntilDeadline < 72 {
                score += 0.4 // Due within 3 days
            }
        }

        return min(score, 1.0)
    }

    var relevanceScore: Double {
        return (confidence * 0.6 + learningScore * 0.4)
    }

    init(
        title: String,
        description: String,
        priority: SuggestionPriority = .medium,
        confidence: Double = 0.7,
        sourceContent: String,
        sourceType: SuggestionSourceType,
        sourceActivityId: UUID? = nil,
        contextTags: [String] = [],
        estimatedDuration: TimeInterval? = nil,
        deadline: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.confidence = confidence
        self.sourceContent = sourceContent
        self.sourceType = sourceType
        self.sourceActivityId = sourceActivityId
        self.contextTags = contextTags
        self.estimatedDuration = estimatedDuration
        self.deadline = deadline
        self.createdAt = Date()
        self.learningScore = 0.5 // Default learning score
        self.isDismissed = false
    }

    static func == (lhs: SuggestedTodo, rhs: SuggestedTodo) -> Bool {
        return lhs.id == rhs.id
    }

    mutating func markAsShown() {
        lastShown = Date()
    }

    mutating func accept() {
        isAccepted = true
        userFeedback = UserFeedback(score: 1.0, timestamp: Date())
    }

    mutating func dismiss(reason: String) {
        isDismissed = true
        dismissReason = reason
        userFeedback = UserFeedback(score: 0.0, timestamp: Date())
    }

    mutating func updateLearningScore(_ score: Double) {
        learningScore = max(0.0, min(1.0, score))
    }
}

enum SuggestionPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

enum SuggestionSourceType: String, Codable, CaseIterable {
    case activityFusion = "activity_fusion"
    case ocrText = "ocr_text"
    case accessibility = "accessibility"
    case memorySearch = "memory_search"
    case userPattern = "user_pattern"
    case deadlineProximity = "deadline_proximity"
    case recurringTask = "recurring_task"

    var displayName: String {
        switch self {
        case .activityFusion: return "Activity Detection"
        case .ocrText: return "Text Analysis"
        case .accessibility: return "App Context"
        case .memorySearch: return "Memory Search"
        case .userPattern: return "Pattern Recognition"
        case .deadlineProximity: return "Deadline Alert"
        case .recurringTask: return "Recurring Task"
        }
    }
}

struct UserFeedback: Codable {
    let score: Double // 0.0 (rejected) to 1.0 (accepted)
    let timestamp: Date
    let comment: String?

    init(score: Double, timestamp: Date = Date(), comment: String? = nil) {
        self.score = max(0.0, min(1.0, score))
        self.timestamp = timestamp
        self.comment = comment
    }
}

struct TaskSuggestion: Codable {
    let id: UUID
    let originalText: String
    let extractedTask: String
    let confidence: Double
    let actionType: ActionType
    let context: String
    let suggestedPriority: SuggestionPriority
    let estimatedDuration: TimeInterval?
    let tags: [String]

    enum ActionType: String, Codable, CaseIterable {
        case create = "create"
        case review = "review"
        case complete = "complete"
        case schedule = "schedule"
        case research = "research"
        case contact = "contact"
        case respond = "respond"
        case followUp = "follow_up"
        case prepare = "prepare"

        var displayName: String {
            switch self {
            case .create: return "Create"
            case .review: return "Review"
            case .complete: return "Complete"
            case .schedule: return "Schedule"
            case .research: return "Research"
            case .contact: return "Contact"
            case .respond: return "Respond"
            case .followUp: return "Follow Up"
            case .prepare: return "Prepare"
            }
        }

        var icon: String {
            switch self {
            case .create: return "plus.circle"
            case .review: return "doc.text.magnifyingglass"
            case .complete: return "checkmark.circle"
            case .schedule: return "calendar.badge.clock"
            case .research: return "magnifyingglass"
            case .contact: return "person.crop.circle"
            case .respond: return "reply"
            case .followUp: return "arrow.clockwise"
            case .prepare: return "gear.circle"
            }
        }
    }

    init(
        originalText: String,
        extractedTask: String,
        confidence: Double,
        actionType: ActionType,
        context: String = "",
        suggestedPriority: SuggestionPriority = .medium,
        estimatedDuration: TimeInterval? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.originalText = originalText
        self.extractedTask = extractedTask
        self.confidence = confidence
        self.actionType = actionType
        self.context = context
        self.suggestedPriority = suggestedPriority
        self.estimatedDuration = estimatedDuration
        self.tags = tags
    }
}

struct UserPreferenceProfile: Codable {
    var preferredActionTypes: [ActionType: Double] // Preference scores 0.0-1.0
    var preferredCategories: [String: Double]
    var typicalWorkingHours: TimeRange
    var averageTaskDuration: TimeInterval
    var completionRateByPriority: [SuggestionPriority: Double]
    var feedbackPatterns: FeedbackPatterns
    var lastUpdated: Date

    struct TimeRange: Codable {
        let startHour: Int // 0-23
        let endHour: Int // 0-23

        var durationHours: Int {
            if endHour > startHour {
                return endHour - startHour
            } else {
                return (24 - startHour) + endHour
            }
        }

        init(startHour: Int = 9, endHour: Int = 17) {
            self.startHour = startHour
            self.endHour = endHour
        }

        func contains(_ date: Date) -> Bool {
            let hour = Calendar.current.component(.hour, from: date)
            if startHour <= endHour {
                return hour >= startHour && hour <= endHour
            } else {
                return hour >= startHour || hour <= endHour
            }
        }
    }

    struct FeedbackPatterns: Codable {
        var acceptanceRateByHour: [Int: Double] // Hour -> acceptance rate
        var dismissalReasons: [String: Int] // Reason -> count
        var optimalSuggestionCount: Int // Max suggestions per session
        var preferredSuggestionFrequency: TimeInterval // Hours between suggestions

        init() {
            self.acceptanceRateByHour = [:]
            self.dismissalReasons = [:]
            self.optimalSuggestionCount = 5
            self.preferredSuggestionFrequency = 2.0
        }
    }

    init() {
        self.preferredActionTypes = [:]
        self.preferredCategories = [:]
        self.typicalWorkingHours = TimeRange()
        self.averageTaskDuration = 30 * 60 // 30 minutes
        self.completionRateByPriority = [:]
        self.feedbackPatterns = FeedbackPatterns()
        self.lastUpdated = Date()
    }

    mutating func updateFromFeedback(_ feedback: UserFeedback, suggestion: SuggestedTodo) {
        lastUpdated = Date()

        // Update action type preferences
        let actionType = inferActionType(from: suggestion.title)
        preferredActionTypes[actionType] = (preferredActionTypes[actionType] ?? 0.5) * 0.8 + feedback.score * 0.2

        // Update category preferences
        for tag in suggestion.contextTags {
            preferredCategories[tag] = (preferredCategories[tag] ?? 0.5) * 0.8 + feedback.score * 0.2
        }

        // Update completion rates
        completionRateByPriority[suggestion.priority] = (completionRateByPriority[suggestion.priority] ?? 0.5) * 0.8 + feedback.score * 0.2

        // Update feedback patterns
        let hour = Calendar.current.component(.hour, from: feedback.timestamp)
        feedbackPatterns.acceptanceRateByHour[hour] = (feedbackPatterns.acceptanceRateByHour[hour] ?? 0.5) * 0.8 + feedback.score * 0.2

        if let reason = suggestion.dismissReason {
            feedbackPatterns.dismissalReasons[reason, default: 0] += 1
        }
    }

    private func inferActionType(from title: String) -> TaskSuggestion.ActionType {
        let lowercaseTitle = title.lowercased()

        if lowercaseTitle.contains("create") || lowercaseTitle.contains("make") || lowercaseTitle.contains("build") {
            return .create
        } else if lowercaseTitle.contains("review") || lowercaseTitle.contains("check") || lowercaseTitle.contains("verify") {
            return .review
        } else if lowercaseTitle.contains("schedule") || lowercaseTitle.contains("plan") || lowercaseTitle.contains("organize") {
            return .schedule
        } else if lowercaseTitle.contains("research") || lowercaseTitle.contains("study") || lowercaseTitle.contains("learn") {
            return .research
        } else if lowercaseTitle.contains("email") || lowercaseTitle.contains("call") || lowercaseTitle.contains("message") {
            return .contact
        } else if lowercaseTitle.contains("reply") || lowercaseTitle.contains("respond") || lowercaseTitle.contains("answer") {
            return .respond
        } else if lowercaseTitle.contains("follow") || lowercaseTitle.contains("check in") {
            return .followUp
        } else if lowercaseTitle.contains("prepare") || lowercaseTitle.contains("setup") || lowercaseTitle.contains("ready") {
            return .prepare
        } else {
            return .complete
        }
    }
}

struct SuggestionEngineConfig: Codable {
    var maxSuggestionsPerSession: Int
    var minConfidenceThreshold: Double
    var focusSessionInterruptionThreshold: Double // Probability of interrupting during focus
    var learningRate: Double // How quickly to adapt to user feedback
    var contextRetentionDays: Int // How long to consider context relevant
    var priorityWeights: PriorityWeights
    var nlpProcessing: NLPConfig

    struct PriorityWeights: Codable {
        var urgencyWeight: Double
        var importanceWeight: Double
        var userPreferenceWeight: Double
        var deadlineWeight: Double
        var contextRelevanceWeight: Double

        init() {
            self.urgencyWeight = 0.25
            self.importanceWeight = 0.20
            self.userPreferenceWeight = 0.20
            self.deadlineWeight = 0.25
            self.contextRelevanceWeight = 0.10
        }
    }

    struct NLPConfig: Codable {
        var enableEntityRecognition: Bool
        var enableSentimentAnalysis: Bool
        var enableIntentClassification: Bool
        var customKeywords: [String: [String]] // Category -> keywords

        init() {
            self.enableEntityRecognition = true
            self.enableSentimentAnalysis = true
            self.enableIntentClassification = true
            self.customKeywords = [
                "urgent": ["asap", "urgent", "immediately", "as soon as possible", "right away"],
                "deadline": ["due", "deadline", "by", "before", "on", "by end of"],
                "meeting": ["meeting", "call", "discuss", "review with", "sync"],
                "email": ["email", "message", "reply", "respond", "send"],
                "task": ["task", "todo", "item", "action", "complete", "finish"]
            ]
        }
    }

    init() {
        self.maxSuggestionsPerSession = 5
        self.minConfidenceThreshold = 0.6
        self.focusSessionInterruptionThreshold = 0.1
        self.learningRate = 0.1
        self.contextRetentionDays = 7
        self.priorityWeights = PriorityWeights()
        self.nlpProcessing = NLPConfig()
    }
}

// MARK: - Advanced Planner Models for Time Blocking and Scheduling

// User Preferences and Settings
struct UserPlannerPreferences: Codable {
    var workingHoursStart: Int // Hour (0-23)
    var workingHoursEnd: Int   // Hour (0-23)
    var defaultFocusSessionDuration: TimeInterval
    var defaultBreakDuration: TimeInterval
    var energyBasedScheduling: Bool
    var adaptiveLearningEnabled: Bool
    var calendarIntegrationEnabled: Bool
    var notificationReminders: [NotificationType]
    var colorScheme: PlannerColorScheme
    var timelineViewMode: TimelineViewMode

    enum NotificationType: String, CaseIterable, Codable {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case breakTime = "break_time"
        case taskDeadline = "task_deadline"
        case dailyPlan = "daily_plan"
    }

    enum PlannerColorScheme: String, CaseIterable, Codable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        case focus = "focus"
    }

    enum TimelineViewMode: String, CaseIterable, Codable {
        case day = "day"
        case week = "week"
        case month = "month"
        case agenda = "agenda"
    }

    static let `default` = UserPlannerPreferences(
        workingHoursStart: 9,
        workingHoursEnd: 18,
        defaultFocusSessionDuration: 3600, // 1 hour
        defaultBreakDuration: 900,     // 15 minutes
        energyBasedScheduling: true,
        adaptiveLearningEnabled: true,
        calendarIntegrationEnabled: false,
        notificationReminders: [.sessionStart, .sessionEnd, .taskDeadline],
        colorScheme: .system,
        timelineViewMode: .day
    )
}

// Suggested Tasks Integration
struct SuggestedTask: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var estimatedDuration: TimeInterval
    var suggestedPriority: PlannerPriority
    var source: TaskSource
    var tags: [String]
    var confidenceScore: Double // AI confidence in suggestion relevance
    var relevanceScore: Double   // How relevant to current goals
    var isAccepted: Bool
    var createdAt: Date

    enum TaskSource: String, CaseIterable, Codable {
        case suggestedTodos = "suggested_todos"
        case calendarEvent = "calendar_event"
        case email = "email"
        case slack = "slack"
        case habitual = "habitual"
        case goalBased = "goal_based"
        case aiRecommended = "ai_recommended"
    }

    init(title: String, description: String, estimatedDuration: TimeInterval, suggestedPriority: PlannerPriority, source: TaskSource, confidenceScore: Double = 0.8) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.estimatedDuration = estimatedDuration
        self.suggestedPriority = suggestedPriority
        self.source = source
        self.tags = []
        self.confidenceScore = confidenceScore
        self.relevanceScore = 0.5
        self.isAccepted = false
        self.createdAt = Date()
    }
}

// Advanced Scheduling Constraints
struct AdvancedSchedulingConstraint: Codable {
    let id: UUID
    var type: AdvancedConstraintType
    var parameters: [String: AnyCodable]
    var isActive: Bool
    var priority: ConstraintPriority
    var flexibility: FlexibilityLevel

    enum AdvancedConstraintType: String, CaseIterable, Codable {
        case energyLevel = "energy_level"
        case focusWindows = "focus_windows"
        case batchProcessing = "batch_processing"
        case timeboxing = "timeboxing"
        case pomodoro = "pomodoro"
        case ultradianRhythm = "ultradian_rhythm"
        case calendarAvailability = "calendar_availability"
        case deepWorkProtection = "deep_work_protection"
        case meetingFree = "meeting_free"
        case taskBatching = "task_batching"
    }

    enum ConstraintPriority: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"

        var numericValue: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }
    }

    enum FlexibilityLevel: String, CaseIterable, Codable {
        case rigid = "rigid"        // Cannot be broken
        case firm = "firm"          // Can be broken with good reason
        case flexible = "flexible"  // Can be adjusted easily
        case optional = "optional"   // Nice to have only

        var multiplier: Double {
            switch self {
            case .rigid: return 1.0
            case .firm: return 0.8
            case .flexible: return 0.6
            case .optional: return 0.4
            }
        }
    }

    init(type: AdvancedConstraintType, priority: ConstraintPriority = .medium, flexibility: FlexibilityLevel = .flexible) {
        self.id = UUID()
        self.type = type
        self.parameters = [:]
        self.isActive = true
        self.priority = priority
        self.flexibility = flexibility
    }
}

// Intelligent Rescheduling Models
struct ReschedulingContext: Codable {
    let reason: ReschedulingReason
    let affectedTasks: [UUID]
    let impact: ReschedulingImpact
    let timestamp: Date
    let userPreference: UserReschedulingPreference

    enum ReschedulingReason: String, CaseIterable, Codable {
        case taskOvertime = "task_overtime"
        case priorityChange = "priority_change"
        case deadlineChanged = "deadline_changed"
        case emergencyEvent = "emergency_event"
        case userRequest = "user_request"
        case energyPattern = "energy_pattern"
        case calendarConflict = "calendar_conflict"
        case adaptiveLearning = "adaptive_learning"
    }

    enum ReschedulingImpact: String, CaseIterable, Codable {
        case minimal = "minimal"      // Only immediate task
        case local = "local"          // Task and immediate dependencies
        case significant = "significant" // Multiple affected tasks
        case comprehensive = "comprehensive" // Major reorganization required
    }

    enum UserReschedulingPreference: String, CaseIterable, Codable {
        case automatic = "automatic"    // Always reschedule automatically
        case confirm = "confirm"        // Ask for confirmation
        case manual = "manual"        // User handles manually
        case disabled = "disabled"      // No rescheduling
    }

    init(reason: ReschedulingReason, affectedTasks: [UUID] = [], impact: ReschedulingImpact = .local, userPreference: UserReschedulingPreference = .automatic) {
        self.reason = reason
        self.affectedTasks = affectedTasks
        self.impact = impact
        self.timestamp = Date()
        self.userPreference = userPreference
    }
}

// Calendar Integration Enhancements
struct CalendarSyncSettings: Codable {
    var enabledSources: [CalendarSource]
    var syncDirection: SyncDirection
    var autoSync: Bool
    var syncInterval: TimeInterval
    var conflictResolution: ConflictResolutionStrategy
    var privateEvents: Bool
    var defaultEventDuration: TimeInterval

    enum SyncDirection: String, CaseIterable, Codable {
        case `import` = "import"        // Import from calendars only
        case export = "export"        // Export to calendars only
        case bidirectional = "bidirectional" // Both directions
    }

    enum ConflictResolutionStrategy: String, CaseIterable, Codable {
        case plannerWins = "planner_wins"    // FocusLock plan takes precedence
        case calendarWins = "calendar_wins"  // Calendar events take precedence
        case merge = "merge"              // Try to merge when possible
        case userDecision = "user_decision"  // Ask user to decide
    }

    static let `default` = CalendarSyncSettings(
        enabledSources: [],
        syncDirection: .import,
        autoSync: false,
        syncInterval: 1800, // 30 minutes
        conflictResolution: .plannerWins,
        privateEvents: true,
        defaultEventDuration: 3600 // 1 hour
    )
}

// Productivity and Analytics Models
struct ProductivityInsight: Codable, Identifiable {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let metrics: [ProductivityMetric]
    let recommendations: [ProductivityRecommendation]
    let confidenceLevel: Double
    let actionableItems: [ActionableItem]
    let validUntil: Date?
    let createdAt: Date

    enum InsightType: String, CaseIterable, Codable {
        case peakPerformance = "peak_performance"
        case productivityPattern = "productivity_pattern"
        case energyOptimization = "energy_optimization"
        case taskEfficiency = "task_efficiency"
        case schedulingImprovement = "scheduling_improvement"
        case goalProgress = "goal_progress"
        case burnoutRisk = "burnout_risk"
        case focusQuality = "focus_quality"
    }

    init(type: InsightType, title: String, description: String, metrics: [ProductivityMetric] = [], recommendations: [ProductivityRecommendation] = [], confidenceLevel: Double = 0.8, actionableItems: [ActionableItem] = [], validUntil: Date? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.metrics = metrics
        self.recommendations = recommendations
        self.confidenceLevel = confidenceLevel
        self.actionableItems = actionableItems
        self.validUntil = validUntil
        self.createdAt = Date()
    }
}

struct ProductivityRecommendation: Codable, Identifiable {
    let id = UUID()
    let category: RecommendationCategory
    let title: String
    let description: String
    let expectedImpact: ImpactLevel
    let difficulty: ImplementationDifficulty
    let estimatedTimeToImplement: TimeInterval
    let steps: [String]

    enum RecommendationCategory: String, CaseIterable, Codable {
        case scheduling = "scheduling"
        case energy = "energy"
        case focus = "focus"
        case breaks = "breaks"
        case goals = "goals"
        case habits = "habits"
        case tools = "tools"
        case environment = "environment"
    }

    enum ImpactLevel: String, CaseIterable, Codable {
        case minimal = "minimal"
        case moderate = "moderate"
        case significant = "significant"
        case transformative = "transformative"

        var score: Double {
            switch self {
            case .minimal: return 0.25
            case .moderate: return 0.5
            case .significant: return 0.75
            case .transformative: return 1.0
            }
        }
    }

    enum ImplementationDifficulty: String, CaseIterable, Codable {
        case easy = "easy"
        case moderate = "moderate"
        case challenging = "challenging"
        case complex = "complex"

        var estimatedTime: TimeInterval {
            switch self {
            case .easy: return 300      // 5 minutes
            case .moderate: return 900    // 15 minutes
            case .challenging: return 1800 // 30 minutes
            case .complex: return 3600   // 1 hour
            }
        }
    }
}

struct ActionableItem: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let type: ActionType
    let isCompleted: Bool
    let completedAt: Date?

    enum ActionType: String, CaseIterable, Codable {
        case setting = "setting"
        case habit = "habit"
        case technique = "technique"
        case tool = "tool"
        case exercise = "exercise"
        case reminder = "reminder"
    }
}

// Template and Quick Start Models
struct PlannerTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var category: TemplateCategory
    var tasks: [TemplateTask]
    var constraints: [AdvancedSchedulingConstraint]
    var estimatedDuration: TimeInterval
    var difficulty: TemplateDifficulty
    var tags: [String]
    var isBuiltIn: Bool
    var usageCount: Int
    var rating: Double?
    var createdAt: Date
    var updatedAt: Date

    enum TemplateCategory: String, CaseIterable, Codable {
        case daily = "daily"
        case weekly = "weekly"
        case project = "project"
        case meeting = "meeting"
        case study = "study"
        case exercise = "exercise"
        case creative = "creative"
        case administrative = "administrative"
    }

    enum TemplateDifficulty: String, CaseIterable, Codable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        case expert = "expert"
    }

    init(name: String, description: String, category: TemplateCategory, tasks: [TemplateTask] = [], constraints: [AdvancedSchedulingConstraint] = []) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.tasks = tasks
        self.constraints = constraints
        self.estimatedDuration = tasks.reduce(0) { $0 + $1.estimatedDuration }
        self.difficulty = .intermediate
        self.tags = []
        self.isBuiltIn = false
        self.usageCount = 0
        self.rating = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct TemplateTask: Codable, Identifiable {
    let id = UUID
    var title: String
    var description: String
    var estimatedDuration: TimeInterval
    var suggestedPriority: PlannerPriority
    var isOptional: Bool
    var dependencies: [UUID] // Other template task IDs
    var tags: [String]

    init(title: String, description: String, estimatedDuration: TimeInterval, suggestedPriority: PlannerPriority = .medium, isOptional: Bool = false) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.estimatedDuration = estimatedDuration
        self.suggestedPriority = suggestedPriority
        self.isOptional = isOptional
        self.dependencies = []
        self.tags = []
    }
}

// Privacy and Data Protection Models
struct PrivacySettings: Codable {
    var dataRetentionPeriod: RetentionPeriod
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool
    var calendarAccessLevel: CalendarAccessLevel
    var localEncryption: Bool
    var automaticCleanup: Bool
    var shareAnonymousData: Bool

    enum RetentionPeriod: String, CaseIterable, Codable {
        case week = "week"
        case month = "month"
        case quarter = "quarter"
        case year = "year"
        case forever = "forever"

        var timeInterval: TimeInterval {
            switch self {
            case .week: return 7 * 24 * 3600
            case .month: return 30 * 24 * 3600
            case .quarter: return 90 * 24 * 3600
            case .year: return 365 * 24 * 3600
            case .forever: return Double.greatestFiniteMagnitude
            }
        }
    }

    enum CalendarAccessLevel: String, CaseIterable, Codable {
        case none = "none"
        case titlesOnly = "titles_only"
        case basicInfo = "basic_info"
        case fullAccess = "full_access"
    }

    static let `default` = PrivacySettings(
        dataRetentionPeriod: .month,
        analyticsEnabled: true,
        crashReportingEnabled: true,
        calendarAccessLevel: .titlesOnly,
        localEncryption: true,
        automaticCleanup: true,
        shareAnonymousData: false
    )
}

// MARK: - Daily Journal Models

enum JournalTemplate: String, CaseIterable, Codable {
    case reflective = "reflective"
    case achievement = "achievement"
    case gratitude = "gratitude"
    case growth = "growth"
    case comprehensive = "comprehensive"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .reflective: return "Reflective"
        case .achievement: return "Achievement-Focused"
        case .gratitude: return "Gratitude"
        case .growth: return "Growth-Oriented"
        case .comprehensive: return "Comprehensive"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .reflective: return "Deep reflection on thoughts, feelings, and experiences"
        case .achievement: return "Focus on accomplishments and progress made"
        case .gratitude: return "Celebrate positive moments and express gratitude"
        case .growth: return "Explore learning opportunities and personal development"
        case .comprehensive: return "Balanced overview of all aspects of the day"
        case .custom: return "Personalized journal based on your preferences"
        }
    }

    var icon: String {
        switch self {
        case .reflective: return "brain.head.profile"
        case .achievement: return "trophy"
        case .gratitude: return "heart"
        case .growth: return "leaf.arrow.triangle.circlepath"
        case .comprehensive: return "book"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct DailyJournal: Codable, Identifiable {
    let id: UUID
    let date: Date
    let content: String
    let template: JournalTemplate
    let highlights: [JournalHighlight]
    let sentiment: SentimentAnalysis
    let userPreferences: JournalPreferences
    let generatedAt: Date
    let lastModified: Date

    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    var readingTime: String {
        let wordsPerMinute = 200
        let minutes = Int(ceil(Double(wordCount) / Double(wordsPerMinute)))
        return minutes == 1 ? "1 min read" : "\(minutes) min read"
    }

    init(date: Date, content: String, template: JournalTemplate, highlights: [JournalHighlight] = [], sentiment: SentimentAnalysis = SentimentAnalysis(), userPreferences: JournalPreferences = JournalPreferences()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.content = content
        self.template = template
        self.highlights = highlights
        self.sentiment = sentiment
        self.userPreferences = userPreferences
        self.generatedAt = Date()
        self.lastModified = Date()
    }
}

struct JournalHighlight: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let category: HighlightCategory
    let significance: Double // 0.0 to 1.0
    let timestamp: Date

    enum HighlightCategory: String, CaseIterable, Codable {
        case achievement = "achievement"
        case challenge = "challenge"
        case learning = "learning"
        case moment = "moment"
        case insight = "insight"
        case gratitude = "gratitude"

        var icon: String {
            switch self {
            case .achievement: return "star.circle"
            case .challenge: return "exclamationmark.triangle"
            case .learning: return "lightbulb.circle"
            case .moment: return "camera"
            case .insight: return "brain"
            case .gratitude: return "heart.circle"
            }
        }

        var color: String {
            switch self {
            case .achievement: return "yellow"
            case .challenge: return "orange"
            case .learning: return "blue"
            case .moment: return "green"
            case .insight: return "purple"
            case .gratitude: return "pink"
            }
        }
    }
}

struct SentimentAnalysis: Codable {
    let overallSentiment: SentimentScore
    let emotionalBreakdown: [EmotionScore]
    let confidence: Double // 0.0 to 1.0
    let keyEmotions: [String]

    var dominantEmotion: String? {
        emotionalBreakdown.max { $0.score }?.emotion
    }

    init() {
        self.overallSentiment = SentimentScore(emotion: "neutral", score: 0.5)
        self.emotionalBreakdown = []
        self.confidence = 0.0
        self.keyEmotions = []
    }

    init(overallSentiment: SentimentScore, emotionalBreakdown: [EmotionScore] = [], confidence: Double = 0.0, keyEmotions: [String] = []) {
        self.overallSentiment = overallSentiment
        self.emotionalBreakdown = emotionalBreakdown
        self.confidence = confidence
        self.keyEmotions = keyEmotions
    }
}

struct SentimentScore: Codable {
    let emotion: String
    let score: Double // 0.0 to 1.0

    var sentimentType: SentimentType {
        switch emotion.lowercased() {
        case "joy", "love", "gratitude", "excitement": return .positive
        case "sadness", "anger", "fear", "disappointment": return .negative
        default: return .neutral
        }
    }

    enum SentimentType: String, Codable {
        case positive = "positive"
        case negative = "negative"
        case neutral = "neutral"

        var icon: String {
            switch self {
            case .positive: return "face.smiling"
            case .negative: return "face.dashed"
            case .neutral: return "face.dashed.fill"
            }
        }

        var color: String {
            switch self {
            case .positive: return "green"
            case .negative: return "red"
            case .neutral: return "gray"
            }
        }
    }
}

struct EmotionScore: Codable {
    let emotion: String
    let score: Double // 0.0 to 1.0
    let intensity: Double // 0.0 to 1.0
}

struct JournalPreferences: Codable {
    var preferredTemplate: JournalTemplate
    var focusAreas: [JournalFocusArea]
    var lengthPreference: JournalLength
    var tonePreference: JournalTone
    var includeSentiment: Bool
    var includeHighlights: Bool
    var includeQuestions: Bool
    var customPrompts: [String]
    var learningData: UserLearningData

    static let `default` = JournalPreferences()

    init(
        preferredTemplate: JournalTemplate = .comprehensive,
        focusAreas: [JournalFocusArea] = JournalFocusArea.allCases,
        lengthPreference: JournalLength = .medium,
        tonePreference: JournalTone = .supportive,
        includeSentiment: Bool = true,
        includeHighlights: Bool = true,
        includeQuestions: Bool = true,
        customPrompts: [String] = [],
        learningData: UserLearningData = UserLearningData()
    ) {
        self.preferredTemplate = preferredTemplate
        self.focusAreas = focusAreas
        self.lengthPreference = lengthPreference
        self.tonePreference = tonePreference
        self.includeSentiment = includeSentiment
        self.includeHighlights = includeHighlights
        self.includeQuestions = includeQuestions
        self.customPrompts = customPrompts
        self.learningData = learningData
    }
}

enum JournalFocusArea: String, CaseIterable, Codable {
    case productivity = "productivity"
    case personalGrowth = "personal_growth"
    case relationships = "relationships"
    case health = "health"
    case creativity = "creativity"
    case emotions = "emotions"
    case goals = "goals"
    case challenges = "challenges"

    var displayName: String {
        switch self {
        case .productivity: return "Productivity"
        case .personalGrowth: return "Personal Growth"
        case .relationships: return "Relationships"
        case .health: return "Health & Wellness"
        case .creativity: return "Creativity"
        case .emotions: return "Emotional Well-being"
        case .goals: return "Goals & Progress"
        case .challenges: return "Challenges & Solutions"
        }
    }

    var icon: String {
        switch self {
        case .productivity: return "chart.bar"
        case .personalGrowth: return "arrow.up.circle"
        case .relationships: return "person.2"
        case .health: return "heart.circle"
        case .creativity: return "paintbrush"
        case .emotions: return "face.smiling"
        case .goals: return "target"
        case .challenges: return "puzzlepiece"
        }
    }
}

enum JournalLength: String, CaseIterable, Codable {
    case brief = "brief"
    case medium = "medium"
    case detailed = "detailed"

    var wordTarget: Int {
        switch self {
        case .brief: return 100
        case .medium: return 300
        case .detailed: return 600
        }
    }

    var displayName: String {
        switch self {
        case .brief: return "Brief (~100 words)"
        case .medium: return "Medium (~300 words)"
        case .detailed: return "Detailed (~600 words)"
        }
    }
}

enum JournalTone: String, CaseIterable, Codable {
    case supportive = "supportive"
    case analytical = "analytical"
    case motivational = "motivational"
    case gentle = "gentle"
    case professional = "professional"

    var description: String {
        switch self {
        case .supportive: return "Warm, encouraging, and understanding"
        case .analytical: return "Objective, structured, and insightful"
        case .motivational: return "Energetic, inspiring, and action-oriented"
        case .gentle: return "Soft, calming, and reflective"
        case .professional: return "Formal, focused, and goal-oriented"
        }
    }
}

struct UserLearningData: Codable {
    var engagementPatterns: [EngagementPattern]
    var preferredTopics: [String]
    var effectivePrompts: [String]
    var interactionHistory: [JournalInteraction]
    var adaptationScore: Double // How well AI has adapted to user preferences

    init() {
        self.engagementPatterns = []
        self.preferredTopics = []
        self.effectivePrompts = []
        self.interactionHistory = []
        self.adaptationScore = 0.5
    }

    mutating func recordInteraction(_ interaction: JournalInteraction) {
        interactionHistory.append(interaction)
        updateAdaptationScore()

        // Keep only last 100 interactions
        if interactionHistory.count > 100 {
            interactionHistory = Array(interactionHistory.suffix(100))
        }
    }

    private mutating func updateAdaptationScore() {
        guard !interactionHistory.isEmpty else { return }

        let recentInteractions = Array(interactionHistory.suffix(20))
        let positiveInteractions = recentInteractions.filter { $0.engagementScore > 0.7 }.count
        let score = Double(positiveInteractions) / Double(recentInteractions.count)
        adaptationScore = score
    }
}

struct EngagementPattern: Codable {
    let template: JournalTemplate
    let avgEngagementScore: Double
    let usageCount: Int
    let lastUsed: Date
}

struct JournalInteraction: Codable {
    let id: UUID
    let journalId: UUID
    let timestamp: Date
    let engagementScore: Double // 0.0 to 1.0
    let actions: [JournalAction]
    let feedback: JournalFeedback?

    init(journalId: UUID, engagementScore: Double, actions: [JournalAction] = [], feedback: JournalFeedback? = nil) {
        self.id = UUID()
        self.journalId = journalId
        self.timestamp = Date()
        self.engagementScore = engagementScore
        self.actions = actions
        self.feedback = feedback
    }

    enum JournalAction: String, Codable {
        case read = "read"
        case edit = "edit"
        case share = "share"
        case export = "export"
        case like = "like"
        case bookmark = "bookmark"
        case respond = "respond"
    }
}

struct JournalFeedback: Codable {
    let rating: Int // 1-5 stars
    let categories: [FeedbackCategory]
    let comment: String?
    let timestamp: Date

    struct FeedbackCategory: Codable {
        let category: String
        let rating: Int // 1-5
    }

    init(rating: Int, categories: [FeedbackCategory] = [], comment: String? = nil) {
        self.rating = rating
        self.categories = categories
        self.comment = comment
        self.timestamp = Date()
    }
}

struct JournalExport {
    let journalId: UUID
    let format: ExportFormat
    let content: String
    let metadata: [String: AnyCodable]
    let exportedAt: Date

    enum ExportFormat: String, CaseIterable, Codable {
        case markdown = "markdown"
        case pdf = "pdf"
        case plainText = "plain_text"
        case html = "html"

        var fileExtension: String {
            switch self {
            case .markdown: return ".md"
            case .pdf: return ".pdf"
            case .plainText: return ".txt"
            case .html: return ".html"
            }
        }

        var displayName: String {
            switch self {
            case .markdown: return "Markdown"
            case .pdf: return "PDF"
            case .plainText: return "Plain Text"
            case .html: return "HTML"
            }
        }
    }
}

struct JournalQuestion: Identifiable, Codable {
    let id: UUID
    let question: String
    let category: String
    let template: JournalTemplate
    let isPersonalized: Bool
    let generatedAt: Date

    init(question: String, category: String, template: JournalTemplate, isPersonalized: Bool = false) {
        self.id = UUID()
        self.question = question
        self.category = category
        self.template = template
        self.isPersonalized = isPersonalized
        self.generatedAt = Date()
    }
}
