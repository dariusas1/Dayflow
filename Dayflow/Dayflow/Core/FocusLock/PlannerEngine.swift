//
//  PlannerEngine.swift
//  FocusLock
//
//  Main planner engine that orchestrates intelligent scheduling,
//  time-blocking optimization, and adaptive learning
//

import Foundation
import Combine
import os.log
import EventKit

@MainActor
class PlannerEngine: ObservableObject {
    static let shared = PlannerEngine()

    // MARK: - Published Properties
    @Published var currentPlan: DailyPlan?
    @Published var tasks: [PlannerTask] = []
    @Published var upcomingPlans: [DailyPlan] = []
    @Published var isPlanning: Bool = false
    @Published var planningProgress: Double = 0.0
    @Published var lastPlanUpdate: Date?
    @Published var hasCalendarAccess: Bool
    @Published var optimizationMetrics: PlanningMetrics

    // MARK: - Private Properties
    private let timeBlockOptimizer = TimeBlockOptimizer.shared
    private let sessionManager = SessionManager.shared
    private let logger = Logger(subsystem: "FocusLock", category: "PlannerEngine")
    private var cancellables = Set<AnyCancellable>()

    // Adaptive learning components
    private var adaptiveScheduler: AdaptiveScheduler
    private var goalBasedPlanner: GoalBasedPlanner
    private var priorityResolver: PriorityResolver
    private var reschedulingEngine: ReschedulingEngine

    // Calendar integration
    private var calendarManager: CalendarManager
    private var eventStore: EKEventStore?

    // Data persistence
    private var persistentStore: PlannerDataStore

    // MARK: - Initialization
    private init() {
        adaptiveScheduler = AdaptiveScheduler()
        goalBasedPlanner = GoalBasedPlanner()
        priorityResolver = PriorityResolver()
        reschedulingEngine = ReschedulingEngine()
        calendarManager = CalendarManager()
        hasCalendarAccess = calendarManager.hasCalendarAccess
        persistentStore = PlannerDataStore()

        setupObservation()
        loadPersistedData()
        initializeTodayPlan()
    }

    // MARK: - Public Methods

    /// Generate optimized daily plan for a specific date
    func generateDailyPlan(for date: Date = Date()) async throws -> DailyPlan {
        isPlanning = true
        planningProgress = 0.0

        defer {
            isPlanning = false
            planningProgress = 0.0
        }

        logger.info("Generating daily plan for \(date)")

        do {
            // Step 1: Load and prepare data (10%)
            planningProgress = 0.1
            let relevantTasks = try await loadRelevantTasks(for: date)
            let existingEvents = try await loadCalendarEvents(for: date)

            // Step 2: Apply goal-based planning (20%)
            planningProgress = 0.2
            let goalPrioritizedTasks = try await goalBasedPlanner.prioritizeTasks(
                relevantTasks,
                userGoals: await loadUserGoals(),
                date: date
            )

            // Step 3: Resolve priority conflicts (30%)
            planningProgress = 0.3
            let resolvedTasks = try await priorityResolver.resolveConflicts(
                tasks: goalPrioritizedTasks,
                constraints: await loadSchedulingConstraints()
            )

            // Step 4: Generate time blocks with optimization (40%)
            planningProgress = 0.4
            let initialBlocks = await generateInitialTimeBlocks(
                tasks: resolvedTasks,
                date: date,
                existingEvents: existingEvents
            )

            // Step 5: Apply intelligent rescheduling (50%)
            planningProgress = 0.5
            let optimizedBlocks = try await timeBlockOptimizer.optimizeTimeBlocks(
                for: resolvedTasks,
                on: date,
                existingBlocks: initialBlocks
            )

            // Step 6: Apply adaptive learning (60%)
            planningProgress = 0.6
            let adaptiveBlocks = await adaptiveScheduler.applyLearning(
                blocks: optimizedBlocks,
                tasks: resolvedTasks,
                date: date
            )

            // Step 7: Create and validate daily plan (70%)
            planningProgress = 0.7
            var plan = DailyPlan(date: date)

            for block in adaptiveBlocks {
                plan.addTimeBlock(block)
                if let taskID = block.taskID,
                   let task = resolvedTasks.first(where: { $0.id == taskID }) {
                    plan.addTask(task)
                }
            }

            // Step 8: Calculate productivity score (80%)
            planningProgress = 0.8
            plan.productivityScore = await calculateProductivityScore(plan: plan)

            // Step 9: Set up integration with FocusLock sessions (90%)
            planningProgress = 0.9
            await setupFocusLockIntegration(plan: plan)

            // Step 10: Save and finalize (100%)
            planningProgress = 1.0
            try await persistentStore.saveDailyPlan(plan)

            // Update published properties
            if Calendar.current.isDateInToday(date) {
                currentPlan = plan
            } else {
                updateUpcomingPlans(with: plan)
            }

            lastPlanUpdate = Date()
            updateOptimizationMetrics(plan: plan)

            logger.info("Daily plan generated successfully with score: \(plan.productivityScore)")
            return plan

        } catch {
            logger.error("Failed to generate daily plan: \(error.localizedDescription)")
            throw error
        }
    }

    /// Add a new task to the planning system
    func addTask(_ task: PlannerTask) {
        tasks.append(task)
        Task {
            do {
                try await persistentStore.saveTask(task)
                logger.info("Task added: \(task.title)")

                // Trigger re-planning if this affects today's plan
                if Calendar.current.isDateInToday(Date()) {
                    try await regenerateTodayPlan()
                }
            } catch {
                logger.error("Failed to save task: \(error.localizedDescription)")
            }
        }
    }

    /// Update an existing task
    func updateTask(_ task: PlannerTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        tasks[index] = task
        Task {
            do {
                try await persistentStore.saveTask(task)
                logger.info("Task updated: \(task.title)")

                // Re-plan if this affects today's schedule
                if Calendar.current.isDateInToday(Date()) {
                    try await regenerateTodayPlan()
                }
            } catch {
                logger.error("Failed to update task: \(error.localizedDescription)")
            }
        }
    }

    /// Mark a task as completed and provide feedback
    func completeTask(_ task: PlannerTask, rating: Int = 5, feedback: String = "") {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        var completedTask = task
        completedTask.markCompleted()
        tasks[index] = completedTask

        // Create feedback for adaptive learning
        if let startTime = completedTask.actualStartTime,
           let endTime = completedTask.actualEndTime {
            var feedbackRecord = SchedulingFeedback(
                taskID: task.id,
                plannedStart: completedTask.scheduledStartTime ?? startTime,
                plannedEnd: completedTask.scheduledEndTime ?? endTime,
                rating: rating,
                feedback: feedback
            )
            feedbackRecord.recordActualTimes(start: startTime, end: endTime)

            timeBlockOptimizer.addSchedulingFeedback(feedbackRecord)
        }

        Task {
            do {
                try await persistentStore.saveTask(completedTask)
                logger.info("Task completed: \(task.title) with rating: \(rating)")

                // Update current plan if this affects today
                if var plan = currentPlan {
                    if let taskIndex = plan.tasks.firstIndex(where: { $0.id == task.id }) {
                        plan.tasks[taskIndex] = completedTask
                        currentPlan = plan
                        try await persistentStore.saveDailyPlan(plan)
                    }
                }
            } catch {
                logger.error("Failed to save completed task: \(error.localizedDescription)")
            }
        }
    }

    /// Handle priority changes and automatic rescheduling
    func handlePriorityChange(for taskID: UUID, newPriority: PlannerPriority) async {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        var task = tasks[taskIndex]
        let oldPriority = task.priority
        task.priority = newPriority
        tasks[taskIndex] = task

        logger.info("Task priority changed: \(task.title) from \(oldPriority) to \(newPriority)")

        // Check if this requires rescheduling
        if requiresRescheduling(task: task, priorityChange: oldPriority != newPriority) {
            do {
                try await regenerateTodayPlan()
                logger.info("Auto-rescheduled due to priority change")
            } catch {
                logger.error("Failed to reschedule after priority change: \(error.localizedDescription)")
            }
        }
    }

    /// Handle when tasks take longer than expected
    func handleTaskOvertime(for taskID: UUID, additionalTime: TimeInterval) async {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }

        logger.info("Task overtime detected: \(task.title) +\(Int(additionalTime/60))min")

        do {
            try await reschedulingEngine.handleOvertime(
                taskID: taskID,
                additionalTime: additionalTime,
                currentPlan: currentPlan
            )

            // Regenerate plan if changes were made
            try await regenerateTodayPlan()
        } catch {
            logger.error("Failed to handle task overtime: \(error.localizedDescription)")
        }
    }

    /// Get task suggestions based on goals and patterns
    func getTaskSuggestions(limit: Int = 10) async -> [PlannerTaskSuggestion] {
        let userGoals = await loadUserGoals()
        let completionPatterns = await analyzeCompletionPatterns()

        return await PlannerTaskSuggestionEngine.generateSuggestions(
            goals: userGoals,
            patterns: completionPatterns,
            existingTasks: tasks,
            limit: limit
        )
    }

    /// Export plan to calendar
    func exportToCalendar(plan: DailyPlan) async throws {
        do {
            try await calendarManager.exportPlan(plan)
            hasCalendarAccess = true
            logger.info("Plan exported to calendar: \(plan.dateFormatted)")
        } catch CalendarError.accessDenied {
            hasCalendarAccess = false
            throw error
        }
    }

    @discardableResult
    func ensureCalendarAuthorization() async -> Bool {
        let granted = await calendarManager.ensureAuthorization()
        hasCalendarAccess = granted
        return granted
    }

    /// Import tasks from external sources
    func importTasks(from source: PlannerTaskSource) async throws -> [PlannerTask] {
        let importedTasks = try await TaskImporter.importTasks(from: source)

        for task in importedTasks {
            addTask(task)
        }

        logger.info("Imported \(importedTasks.count) tasks from \(source)")
        return importedTasks
    }

    // MARK: - Goal-Based Planning

    /// Set long-term goals
    func setGoals(_ goals: [PlannerGoal]) async {
        try await persistentStore.saveGoals(goals)

        // Re-plan today to align with new goals
        do {
            try await regenerateTodayPlan()
        } catch {
            logger.error("Failed to re-plan after setting goals: \(error.localizedDescription)")
        }
    }

    /// Get progress towards goals
    func getGoalProgress() async -> [GoalProgress] {
        let goals = await loadUserGoals()
        return await GoalProgressTracker.calculateProgress(goals: goals, tasks: tasks)
    }

    // MARK: - FocusLock Integration

    /// Start a focus session for a planned task
    func startFocusSession(for taskID: UUID) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }
        guard task.isFocusSessionProtected else { return false }

        logger.info("Starting focus session for planned task: \(task.title)")

        // Update task with actual start time
        if var plan = currentPlan {
            if let taskIndex = plan.tasks.firstIndex(where: { $0.id == taskID }) {
                plan.tasks[taskIndex].actualStartTime = Date()
                currentPlan = plan
            }
        }

        // Start the focus session
        sessionManager.startSession(taskName: task.title)
        return true
    }

    /// End a focus session and update the task
    func endFocusSession(for taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }

        logger.info("Ending focus session for: \(task.title)")

        // Update task with actual end time
        if var plan = currentPlan {
            if let taskIndex = plan.tasks.firstIndex(where: { $0.id == taskID }) {
                plan.tasks[taskIndex].actualEndTime = Date()
                currentPlan = plan
            }
        }

        sessionManager.endSession()
    }

    // MARK: - Private Methods

    private func setupObservation() {
        // Observe session completions to update energy patterns
        sessionManager.$lastSessionSummary
            .compactMap { $0 }
            .sink { [weak self] summary in
                Task { @MainActor in
                    self?.updatePlanWithSessionCompletion(summary)
                }
            }
            .store(in: &cancellables)
    }

    private func loadPersistedData() {
        Task {
            do {
                tasks = try await persistentStore.loadAllTasks()
                upcomingPlans = try await persistentStore.loadUpcomingPlans()

                if let todayPlan = try await persistentStore.loadDailyPlan(for: Date()) {
                    currentPlan = todayPlan
                }

                logger.info("Loaded \(tasks.count) tasks and \(upcomingPlans.count) upcoming plans")
            } catch {
                logger.error("Failed to load persisted data: \(error.localizedDescription)")
            }
        }
    }

    private func initializeTodayPlan() {
        Task {
            do {
                if currentPlan == nil {
                    currentPlan = try await generateDailyPlan()
                }
            } catch {
                logger.error("Failed to initialize today's plan: \(error.localizedDescription)")
            }
        }
    }

    private func regenerateTodayPlan() async throws {
        guard let todayPlan = currentPlan else { return }

        // Update existing plan with current state
        var updatedPlan = todayPlan
        updatedPlan.updatedAt = Date()

        // Re-generate with current data
        let newPlan = try await generateDailyPlan()
        currentPlan = newPlan
    }

    private func loadRelevantTasks(for date: Date) async throws -> [PlannerTask] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return tasks.filter { task in
            // Include incomplete tasks
            if task.isCompleted { return false }

            // Include tasks with deadlines on or before the target date
            if let deadline = task.deadline {
                return deadline <= endOfDay
            }

            // Include high and critical priority tasks
            if task.priority == .high || task.priority == .critical {
                return true
            }

            // Include focus session protected tasks
            if task.isFocusSessionProtected {
                return true
            }

            return false
        }
    }

    private func loadCalendarEvents(for date: Date) async throws -> [TimeBlock] {
        do {
            let events = try await calendarManager.loadEvents(for: date)
            hasCalendarAccess = true

            return events.map { event in
                TimeBlock(
                    startTime: event.startTime,
                    endTime: event.endTime,
                    blockType: .meeting,
                    title: event.title,
                    isProtected: true,
                    energyLevel: .medium,
                    breakBuffer: 300
                )
            }
        } catch CalendarError.accessDenied {
            hasCalendarAccess = false
            logger.error("Calendar access denied while loading events for date: \(date)")
            return []
        }
    }

    private func loadUserGoals() async -> [PlannerGoal] {
        do {
            return try await persistentStore.loadGoals()
        } catch {
            logger.error("Failed to load user goals: \(error.localizedDescription)")
            return []
        }
    }

    private func loadSchedulingConstraints() async -> [SchedulingConstraint] {
        do {
            return try await persistentStore.loadConstraints()
        } catch {
            logger.error("Failed to load constraints: \(error.localizedDescription)")
            return []
        }
    }

    private func generateInitialTimeBlocks(tasks: [PlannerTask], date: Date, existingEvents: [TimeBlock]) -> [TimeBlock] {
        var blocks = existingEvents
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Sort tasks by priority and create initial blocks
        let sortedTasks = tasks.sorted { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority.numericValue > task2.priority.numericValue
            }
            return task1.createdAt < task2.createdAt
        }

        var currentTime = startOfDay.addingTimeInterval(8 * 3600) // Start at 8 AM

        for task in sortedTasks {
            let startTime = findNextAvailableTime(from: currentTime, existingBlocks: blocks, duration: task.estimatedDuration)
            let blockType: TimeBlockType = task.isFocusSessionProtected ? .focus : .task

            let block = TimeBlock(
                startTime: startTime,
                endTime: startTime.addingTimeInterval(task.estimatedDuration),
                taskID: task.id,
                blockType: blockType,
                title: task.title,
                isProtected: task.isFocusSessionProtected,
                energyLevel: task.preferredEnergyLevel ?? .medium,
                breakBuffer: task.isFocusSessionProtected ? 900 : 300
            )

            blocks.append(block)
            currentTime = block.endTime.addingTimeInterval(block.breakBuffer)
        }

        return blocks.sorted { $0.startTime < $1.startTime }
    }

    private func findNextAvailableTime(from startTime: Date, existingBlocks: [TimeBlock], duration: TimeInterval) -> Date {
        var candidateTime = startTime

        while true {
            let candidateEndTime = candidateTime.addingTimeInterval(duration)

            let hasConflict = existingBlocks.contains { block in
                return candidateTime < block.endTime && candidateEndTime > block.startTime
            }

            if !hasConflict {
                return candidateTime
            }

            // Move to next available slot
            if let nextBlockStart = existingBlocks
                .filter { $0.startTime >= candidateTime }
                .sorted { $0.startTime < $1.startTime }
                .first?.startTime {
                candidateTime = nextBlockStart.addingTimeInterval(60)
            } else {
                candidateTime = candidateTime.addingTimeInterval(3600)
            }
        }
    }

    private func calculateProductivityScore(plan: DailyPlan) async -> Double {
        var score = 0.0
        var factors = 0

        // Focus time factor
        let focusHours = plan.totalFocusTime / 3600
        score += min(focusHours / 6.0, 1.0) * 0.3 // Max 6 hours of focus time
        factors += 1

        // Task completion factor
        let completionRate = plan.completionRate
        score += completionRate * 0.2
        factors += 1

        // Energy alignment factor
        let energyAlignment = await calculateEnergyAlignment(plan: plan)
        score += energyAlignment * 0.2
        factors += 1

        // Priority distribution factor
        let priorityScore = calculatePriorityScore(plan: plan)
        score += priorityScore * 0.2
        factors += 1

        // Break balance factor
        let breakBalance = calculateBreakBalance(plan: plan)
        score += breakBalance * 0.1
        factors += 1

        return factors > 0 ? score : 0.0
    }

    private func calculateEnergyAlignment(plan: DailyPlan) async -> Double {
        var alignmentScore = 0.0
        var blockCount = 0

        for block in plan.timeBlocks {
            guard let taskID = block.taskID,
                  let task = plan.tasks.first(where: { $0.id == taskID }) else { continue }

            let hour = Calendar.current.component(.hour, from: block.startTime)
            if let energyPattern = timeBlockOptimizer.energyPatterns.first(where: { $0.hourOfDay == hour }) {
                let alignment = calculateEnergyMatch(task: task, pattern: energyPattern)
                alignmentScore += alignment
                blockCount += 1
            }
        }

        return blockCount > 0 ? alignmentScore / Double(blockCount) : 0.5
    }

    private func calculateEnergyMatch(task: PlannerTask, pattern: EnergyPattern) -> Double {
        if let preferredEnergy = task.preferredEnergyLevel {
            return preferredEnergy == pattern.averageEnergyLevel ? 1.0 : 0.7
        }
        return 0.8
    }

    private func calculatePriorityScore(plan: DailyPlan) -> Double {
        let totalPriorityScore = plan.tasks.reduce(0) { $0 + $1.priority.numericValue }
        let maxPossibleScore = plan.tasks.count * 4 // Critical priority = 4

        return maxPossibleScore > 0 ? Double(totalPriorityScore) / Double(maxPossibleScore) : 0.5
    }

    private func calculateBreakBalance(plan: DailyPlan) -> Double {
        let workingTime = plan.totalScheduledTime - plan.totalBreakTime
        if workingTime == 0 { return 0.5 }

        let breakRatio = plan.totalBreakTime / workingTime
        // Ideal break ratio is around 0.15-0.2 (15-20%)
        let idealRatio = 0.175
        let deviation = abs(breakRatio - idealRatio)

        return max(0.0, 1.0 - deviation * 5) // Scale the deviation
    }

    private func setupFocusLockIntegration(plan: DailyPlan) async {
        // Configure notifications for upcoming focus sessions
        for block in plan.timeBlocks.filter({ $0.blockType == .focus }) {
            if let taskID = block.taskID,
               let task = plan.tasks.first(where: { $0.id == taskID }) {

                // Schedule notification 5 minutes before focus session
                scheduleFocusNotification(
                    task: task,
                    startTime: block.startTime,
                    reminderTime: block.startTime.addingTimeInterval(-300)
                )
            }
        }
    }

    private func scheduleFocusNotification(task: PlannerTask, startTime: Date, reminderTime: Date) {
        // In production, would schedule actual notifications
        logger.info("Scheduled focus notification for \(task.title) at \(reminderTime)")
    }

    private func updatePlanWithSessionCompletion(_ summary: SessionSummary) {
        guard var plan = currentPlan else { return }

        // Find the task associated with this session
        if let taskIndex = plan.tasks.firstIndex(where: { $0.title == summary.taskName }) {
            plan.tasks[taskIndex].actualStartTime = summary.startTime
            plan.tasks[taskIndex].actualEndTime = summary.endTime

            // Update adherence score
            let actualBlocks = plan.timeBlocks.filter { block in
                guard let taskID = block.taskID else { return false }
                return taskID == plan.tasks[taskIndex].id
            }
            plan.updateAdherenceScore(actualBlocks: actualBlocks)

            currentPlan = plan
        }
    }

    private func updateUpcomingPlans(with plan: DailyPlan) {
        // Remove old plans for the same date
        upcomingPlans.removeAll { Calendar.current.isDate($0.date, inSameDayAs: plan.date) }

        // Add the new plan
        upcomingPlans.append(plan)

        // Sort by date and keep only next 7 days
        upcomingPlans.sort { $0.date < $1.date }
        if upcomingPlans.count > 7 {
            upcomingPlans = Array(upcomingPlans.prefix(7))
        }
    }

    private func updateOptimizationMetrics(plan: DailyPlan) {
        optimizationMetrics = PlanningMetrics(
            productivityScore: plan.productivityScore,
            adherenceScore: plan.adherenceScore,
            completionRate: plan.completionRate,
            focusTimeHours: plan.totalFocusTime / 3600,
            breakTimeHours: plan.totalBreakTime / 3600,
            tasksScheduled: plan.tasks.count,
            lastOptimized: Date()
        )
    }

    private func requiresRescheduling(task: PlannerTask, priorityChange: Bool) -> Bool {
        // Always reschedule for critical tasks
        if task.priority == .critical { return true }

        // Reschedule for significant priority changes
        if priorityChange && task.priority == .high { return true }

        // Reschedule focus session tasks
        if task.isFocusSessionProtected { return true }

        // Reschedule overdue tasks
        if task.isOverdue { return true }

        return false
    }

    private func analyzeCompletionPatterns() async -> CompletionPatterns {
        // Analyze historical completion data to identify patterns
        return CompletionPatterns(
            bestTimeOfDay: await findMostProductiveHour(),
            averageCompletionTime: await calculateAverageCompletionTime(),
            successFactors: await identifySuccessFactors()
        )
    }

    private func findMostProductiveHour() async -> Int {
        // Find the hour with highest completion rate
        var bestHour = 9 // Default to 9 AM
        var bestRate = 0.0

        for pattern in timeBlockOptimizer.energyPatterns {
            if pattern.taskCompletionRate > bestRate {
                bestRate = pattern.taskCompletionRate
                bestHour = pattern.hourOfDay
            }
        }

        return bestHour
    }

    private func calculateAverageCompletionTime() async -> TimeInterval {
        // Calculate average time to complete tasks
        let completedTasks = tasks.filter { $0.isCompleted && $0.actualStartTime != nil && $0.actualEndTime != nil }

        guard !completedTasks.isEmpty else { return 3600 } // Default 1 hour

        let totalTime = completedTasks.reduce(0) { total, task in
            guard let start = task.actualStartTime, let end = task.actualEndTime else { return total }
            return total + end.timeIntervalSince(start)
        }

        return totalTime / Double(completedTasks.count)
    }

    private func identifySuccessFactors() async -> [String] {
        // Identify factors that contribute to successful task completion
        var factors: [String] = []

        // Analyze focus session success
        let focusSessionTasks = tasks.filter { $0.isFocusSessionProtected && $0.isCompleted }
        let focusSuccessRate = Double(focusSessionTasks.count) / Double(tasks.filter { $0.isFocusSessionProtected }.count)

        if focusSuccessRate > 0.8 {
            factors.append("Focus sessions")
        }

        // Analyze energy alignment
        let energyAlignedTasks = tasks.filter { task in
            guard let startTime = task.actualStartTime else { return false }
            let hour = Calendar.current.component(.hour, from: startTime)
            if let pattern = timeBlockOptimizer.energyPatterns.first(where: { $0.hourOfDay == hour }) {
                return task.preferredEnergyLevel == pattern.averageEnergyLevel
            }
            return false
        }

        let energyAlignmentRate = Double(energyAlignedTasks.count) / Double(tasks.filter { $0.preferredEnergyLevel != nil }.count)

        if energyAlignmentRate > 0.7 {
            factors.append("Energy alignment")
        }

        return factors
    }
}

// MARK: - Supporting Models

struct PlanningMetrics {
    let productivityScore: Double
    let adherenceScore: Double
    let completionRate: Double
    let focusTimeHours: Double
    let breakTimeHours: Double
    let tasksScheduled: Int
    let lastOptimized: Date
}

struct PlannerGoal: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var targetValue: Double
    var currentValue: Double
    var deadline: Date?
    var category: GoalCategory
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    enum GoalCategory: String, Codable, CaseIterable {
        case productivity = "productivity"
        case learning = "learning"
        case health = "health"
        case career = "career"
        case personal = "personal"
        case financial = "financial"
    }

    var progress: Double {
        guard targetValue > 0 else { return 0.0 }
        return min(currentValue / targetValue, 1.0)
    }

    var isCompleted: Bool {
        return progress >= 1.0
    }
}

struct GoalProgress {
    let goalID: UUID
    let goalTitle: String
    let progress: Double
    let tasksCompleted: Int
    let totalTasks: Int
    let isOnTrack: Bool
}

struct CompletionPatterns {
    let bestTimeOfDay: Int
    let averageCompletionTime: TimeInterval
    let successFactors: [String]
}

// MARK: - Supporting Classes

class AdaptiveScheduler {
    private let logger = Logger(subsystem: "FocusLock", category: "AdaptiveScheduler")
    private var learningModel: SchedulingLearningModel
    private var performanceHistory: [SchedulingPerformance] = []

    init() {
        learningModel = SchedulingLearningModel()
    }

    func applyLearning(blocks: [TimeBlock], tasks: [PlannerTask], date: Date) async -> [TimeBlock] {
        logger.info("Applying adaptive learning to \(blocks.count) time blocks")

        // Analyze historical performance patterns
        let patterns = analyzePerformancePatterns()

        // Apply machine learning optimizations
        var optimizedBlocks = blocks
        let learningFactors = await calculateLearningFactors(for: tasks, date: date)

        // Optimize scheduling based on learned patterns
        for (index, block) in optimizedBlocks.enumerated() {
            guard let taskID = block.taskID,
                  let task = tasks.first(where: { $0.id == taskID }) else { continue }

            // Apply learned adjustments
            let adjustedBlock = applyLearnedAdjustments(
                block: block,
                task: task,
                patterns: patterns,
                factors: learningFactors
            )
            optimizedBlocks[index] = adjustedBlock
        }

        // Apply conflict resolution based on learning
        optimizedBlocks = resolveLearnedConflicts(blocks: optimizedBlocks)

        logger.info("Adaptive scheduling applied successfully")
        return optimizedBlocks
    }

    private func analyzePerformancePatterns() -> SchedulingPatterns {
        // Analyze performance history to identify patterns
        var patterns = SchedulingPatterns()

        // Time-based patterns
        patterns.mostProductiveHours = findMostProductiveHours()
        patterns.optimalTaskDurations = findOptimalDurations()
        patterns.preferredBreakIntervals = findOptimalBreakIntervals()

        // Energy-based patterns
        patterns.energyPeakTimes = findEnergyPeakTimes()
        patterns.focusOptimalWindows = findFocusOptimalWindows()

        return patterns
    }

    private func calculateLearningFactors(for tasks: [PlannerTask], date: Date) async -> LearningFactors {
        var factors = LearningFactors()

        // Calculate day-specific factors
        factors.dayOfWeekMultiplier = calculateDayOfWeekMultiplier(for: date)
        factors.seasonalAdjustment = calculateSeasonalAdjustment(for: date)
        factors.weatherImpact = await calculateWeatherImpact(for: date)

        // Calculate task-specific factors
        factors.taskComplexityAdjustment = calculateComplexityAdjustment(tasks: tasks)
        factors.priorityWeighting = calculatePriorityWeighting(tasks: tasks)

        // Calculate user-specific factors
        factors.energyAlignmentBonus = await calculateEnergyAlignmentBonus()
        factors.goalAlignmentScore = await calculateGoalAlignmentScore()

        return factors
    }

    private func applyLearnedAdjustments(block: TimeBlock, task: PlannerTask, patterns: SchedulingPatterns, factors: LearningFactors) -> TimeBlock {
        var adjustedBlock = block

        // Adjust timing based on productivity patterns
        if patterns.mostProductiveHours.contains(Calendar.current.component(.hour, from: block.startTime)) {
            adjustedBlock.productivityMultiplier = 1.2
        }

        // Adjust duration based on optimal task durations
        if let optimalDuration = patterns.optimalTaskDurations[task.priority] {
            let durationRatio = optimalDuration / task.estimatedDuration
            if durationRatio > 1.2 || durationRatio < 0.8 {
                // Suggest duration adjustment
                adjustedBlock.suggestedDurationAdjustment = optimalDuration
            }
        }

        // Apply energy alignment
        if patterns.energyPeakTimes.contains(block.startTime) {
            adjustedBlock.energyAlignmentScore = 1.0
        }

        // Apply focus window optimization
        if task.isFocusSessionProtected && patterns.focusOptimalWindows.contains(block.startTime) {
            adjustedBlock.focusOptimizationScore = 1.0
        }

        return adjustedBlock
    }

    private func resolveLearnedConflicts(blocks: [TimeBlock]) -> [TimeBlock] {
        // Resolve conflicts based on learned conflict resolution patterns
        var resolvedBlocks = blocks

        // Apply learned conflict resolution strategies
        for (index, block) in resolvedBlocks.enumerated() {
            if block.hasLearnedConflict {
                resolvedBlocks[index] = resolveBlockConflict(block: block, strategy: .learnedPriority)
            }
        }

        return resolvedBlocks
    }

    // MARK: - Pattern Analysis Methods

    private func findMostProductiveHours() -> [Int] {
        var hourlyProductivity: [Int: Double] = [:]

        for performance in performanceHistory {
            let hour = Calendar.current.component(.hour, from: performance.startTime)
            hourlyProductivity[hour, default: 0.0] += performance.completionRate
        }

        // Find top 3 most productive hours
        let sortedHours = hourlyProductivity.sorted { $0.value > $1.value }
        return Array(sortedHours.prefix(3).map { $0.key })
    }

    private func findOptimalDurations() -> [PlannerPriority: TimeInterval] {
        var durations: [PlannerPriority: [TimeInterval]] = [:]

        for performance in performanceHistory {
            let duration = performance.actualDuration
            durations[performance.taskPriority, default: []].append(duration)
        }

        var optimalDurations: [PlannerPriority: TimeInterval] = [:]
        for (priority, durationList) in durations {
            let medianDuration = durationList.sorted()[durationList.count / 2]
            optimalDurations[priority] = medianDuration
        }

        return optimalDurations
    }

    private func findOptimalBreakIntervals() -> [TimeInterval] {
        var breakIntervals: [TimeInterval] = []

        for performance in performanceHistory {
            if performance.followedBreak {
                breakIntervals.append(performance.breakDuration)
            }
        }

        return breakIntervals.sorted()
    }

    private func findEnergyPeakTimes() -> [Date] {
        // Analyze energy patterns from performance history
        return performanceHistory
            .filter { $0.energyLevel > 0.8 }
            .map { $0.startTime }
            .sorted()
    }

    private func findFocusOptimalWindows() -> [Date] {
        // Find optimal windows for deep work based on historical performance
        return performanceHistory
            .filter { $0.wasFocusSession && $0.completionRate > 0.9 }
            .map { $0.startTime }
            .sorted()
    }

    // MARK: - Factor Calculation Methods

    private func calculateDayOfWeekMultiplier(for date: Date) -> Double {
        let dayOfWeek = Calendar.current.component(.weekday, from: date)

        // Analyze performance by day of week
        let dayPerformance = performanceHistory.filter { performance in
            Calendar.current.component(.weekday, from: performance.startTime) == dayOfWeek
        }

        guard !dayPerformance.isEmpty else { return 1.0 }

        let averagePerformance = dayPerformance.reduce(0) { $0 + $1.completionRate } / Double(dayPerformance.count)
        return averagePerformance
    }

    private func calculateSeasonalAdjustment(for date: Date) -> Double {
        let month = Calendar.current.component(.month, from: date)

        // Seasonal productivity patterns
        let seasonalMultipliers: [Int: Double] = [
            1: 0.9,  // January - post-holiday slowdown
            2: 1.0,  // February - normal
            3: 1.1,  // March - spring energy
            4: 1.2,  // April - peak productivity
            5: 1.1,  // May - good productivity
            6: 1.0,  // June - summer approaching
            7: 0.9,  // July - summer slowdown
            8: 0.9,  // August - summer slowdown
            9: 1.1,  // September - back to school
            10: 1.2, // October - fall productivity
            11: 1.1, // November - pre-holiday rush
            12: 0.8  // December - holiday season
        ]

        return seasonalMultipliers[month] ?? 1.0
    }

    private func calculateWeatherImpact(for date: Date) async -> Double {
        // In a real implementation, would fetch weather data
        // For now, return neutral impact
        return 1.0
    }

    private func calculateComplexityAdjustment(tasks: [PlannerTask]) -> Double {
        let averageComplexity = tasks.reduce(0) { $0 + $1.complexity } / Double(tasks.count)

        // Adjust for complexity
        switch averageComplexity {
        case 0.0..<0.3:
            return 1.1  // Low complexity - can be more productive
        case 0.3..<0.7:
            return 1.0  // Medium complexity - normal productivity
        case 0.7..<1.0:
            return 0.9  // High complexity - slower pace
        default:
            return 0.8  // Very high complexity - significant slowdown
        }
    }

    private func calculatePriorityWeighting(tasks: [PlannerTask]) -> Double {
        let highPriorityTasks = tasks.filter { $0.priority == .high || $0.priority == .critical }
        let priorityRatio = Double(highPriorityTasks.count) / Double(tasks.count)

        return 1.0 + (priorityRatio * 0.2) // Boost for high-priority heavy days
    }

    private func calculateEnergyAlignmentBonus() async -> Double {
        // Calculate how well current scheduling aligns with user's energy patterns
        return 1.0
    }

    private func calculateGoalAlignmentScore() async -> Double {
        // Calculate how well tasks align with user's goals
        return 1.0
    }

    // MARK: - Learning Methods

    func addPerformanceData(_ performance: SchedulingPerformance) {
        performanceHistory.append(performance)

        // Keep only last 1000 performance records
        if performanceHistory.count > 1000 {
            performanceHistory = Array(performanceHistory.suffix(1000))
        }

        // Update learning model
        learningModel.train(with: performanceHistory)
    }

    func getPerformanceInsights() -> [PerformanceInsight] {
        var insights: [PerformanceInsight] = []

        // Analyze patterns and generate insights
        let recentPerformance = Array(performanceHistory.suffix(100))
        guard !recentPerformance.isEmpty else { return insights }

        // Productivity patterns
        let bestHour = recentPerformance.max { $0.completionRate < $1.completionRate }?.startTime
        if let bestHour = bestHour {
            insights.append(PerformanceInsight(
                type: .productivity,
                title: "Peak Productivity Time",
                description: "You're most productive around \(Calendar.current.component(.hour, from: bestHour)):00",
                action: "Schedule important tasks during this time"
            ))
        }

        // Energy patterns
        let highEnergyTasks = recentPerformance.filter { $0.energyLevel > 0.8 }
        if !highEnergyTasks.isEmpty {
            insights.append(PerformanceInsight(
                type: .energy,
                title: "High Energy Tasks",
                description: "You perform \(Int((Double(highEnergyTasks.count) / Double(recentPerformance.count)) * 100))% better on high-energy tasks",
                action: "Align demanding tasks with your energy levels"
            ))
        }

        // Focus patterns
        let focusSessions = recentPerformance.filter { $0.wasFocusSession }
        let focusSuccessRate = focusSessions.reduce(0) { $0 + $1.completionRate } / Double(focusSessions.count)

        if focusSuccessRate > 0.8 {
            insights.append(PerformanceInsight(
                type: .focus,
                title: "Excellent Focus Performance",
                description: "Your focus sessions have a \(Int(focusSuccessRate * 100))% success rate",
                action: "Continue using focus sessions for important work"
            ))
        }

        return insights
    }
}

class GoalBasedPlanner {
    private let logger = Logger(subsystem: "FocusLock", category: "GoalBasedPlanner")
    private var goalAlignmentModel: GoalAlignmentModel

    init() {
        goalAlignmentModel = GoalAlignmentModel()
    }

    func prioritizeTasks(_ tasks: [PlannerTask], userGoals: [PlannerGoal], date: Date) async throws -> [PlannerTask] {
        logger.info("Prioritizing \(tasks.count) tasks based on \(userGoals.count) goals")

        var prioritizedTasks = tasks

        // Calculate goal alignment scores for each task
        for (index, task) in prioritizedTasks.enumerated() {
            let alignmentScore = calculateGoalAlignmentScore(task: task, goals: userGoals)
            prioritizedTasks[index].goalAlignmentScore = alignmentScore

            // Apply goal-based priority adjustments
            if alignmentScore > 0.8 {
                // Boost priority for well-aligned tasks
                prioritizedTasks[index].priority = boostPriority(task.priority, factor: 1.2)
            } else if alignmentScore < 0.3 && task.priority != .critical {
                // Consider lowering priority for poorly aligned tasks
                prioritizedTasks[index].priority = boostPriority(task.priority, factor: 0.8)
            }
        }

        // Apply deadline-based prioritization
        prioritizedTasks = applyDeadlinePrioritization(tasks: prioritizedTasks, date: date)

        // Apply goal-urgency weighting
        prioritizedTasks = applyGoalUrgencyWeighting(tasks: prioritizedTasks, goals: userGoals)

        // Sort by combined priority score
        prioritizedTasks.sort { task1, task2 in
            let score1 = calculateCombinedPriorityScore(task: task1)
            let score2 = calculateCombinedPriorityScore(task: task2)
            return score1 > score2
        }

        logger.info("Task prioritization completed")
        return prioritizedTasks
    }

    private func calculateGoalAlignmentScore(task: PlannerTask, goals: [PlannerGoal]) -> Double {
        var totalScore = 0.0
        var goalCount = 0

        // Check direct goal associations
        if let taskGoalID = task.relatedGoalID {
            if let goal = goals.first(where: { $0.id == taskGoalID }) {
                totalScore += calculateTaskGoalAlignment(task: task, goal: goal)
                goalCount += 1
            }
        }

        // Check indirect associations through categories and tags
        for goal in goals {
            let alignmentScore = calculateIndirectAlignment(task: task, goal: goal)
            if alignmentScore > 0.1 {
                totalScore += alignmentScore
                goalCount += 1
            }
        }

        return goalCount > 0 ? totalScore / Double(goalCount) : 0.5
    }

    private func calculateTaskGoalAlignment(task: PlannerTask, goal: PlannerGoal) -> Double {
        var score = 0.0

        // Category alignment
        if taskCategoryMatchesGoal(task: task, goal: goal) {
            score += 0.4
        }

        // Deadline alignment
        if let taskDeadline = task.deadline,
           let goalDeadline = goal.deadline {
            let deadlineAlignment = 1.0 - abs(taskDeadline.timeIntervalSince(goalDeadline)) / (30 * 24 * 3600) // 30 days
            score += 0.3 * max(0.0, deadlineAlignment)
        }

        // Priority alignment based on goal progress
        if goal.progress < 0.5 && task.priority.numericValue >= 3 {
            score += 0.2 // High priority tasks for struggling goals
        } else if goal.progress > 0.8 && task.priority.numericValue <= 2 {
            score += 0.1 // Lower priority tasks for nearly complete goals
        }

        return min(score, 1.0)
    }

    private func calculateIndirectAlignment(task: PlannerTask, goal: PlannerGoal) -> Double {
        var score = 0.0

        // Check for keyword matches in task title and description
        let taskText = (task.title + " " + (task.description ?? "")).lowercased()
        let goalKeywords = extractGoalKeywords(goal: goal)

        for keyword in goalKeywords {
            if taskText.contains(keyword.lowercased()) {
                score += 0.2
            }
        }

        return min(score, 0.5) // Cap indirect alignment at 0.5
    }

    private func taskCategoryMatchesGoal(task: PlannerTask, goal: PlannerGoal) -> Bool {
        // Map task categories to goal categories
        let taskCategory = task.category
        let goalCategory = goal.category

        switch (taskCategory, goalCategory) {
        case (.work, .career), (.personal, .personal), (.health, .health), (.learning, .learning):
            return true
        case (.work, .productivity), (.personal, .productivity):
            return true
        default:
            return false
        }
    }

    private func extractGoalKeywords(goal: PlannerGoal) -> [String] {
        // Extract keywords from goal title and description
        let text = (goal.title + " " + goal.description).lowercased()

        // Common productivity and goal-related keywords
        let keywords = ["learn", "study", "practice", "improve", "develop", "complete", "finish", "start", "create", "build", "exercise", "health", "read", "write", "code", "design", "plan", "organize", "review"]

        return keywords.filter { text.contains($0) }
    }

    private func boostPriority(_ priority: PlannerPriority, factor: Double) -> PlannerPriority {
        let numericValue = Double(priority.numericValue) * factor

        switch numericValue {
        case 0.0..<0.5:
            return .low
        case 0.5..<1.5:
            return .medium
        case 1.5..<2.5:
            return .high
        case 2.5..<3.5:
            return .critical
        default:
            return .critical
        }
    }

    private func applyDeadlinePrioritization(tasks: [PlannerTask], date: Date) -> [PlannerTask] {
        return tasks.map { task in
            var updatedTask = task

            if let deadline = task.deadline {
                let daysUntilDeadline = Calendar.current.dateComponents([.day], from: date, to: deadline).day ?? 0

                // Boost priority for tasks with imminent deadlines
                if daysUntilDeadline <= 1 && task.priority != .critical {
                    updatedTask.priority = .critical
                } else if daysUntilDeadline <= 3 && task.priority == .low {
                    updatedTask.priority = .medium
                } else if daysUntilDeadline <= 7 && task.priority == .medium {
                    updatedTask.priority = .high
                }

                // Mark as overdue if past deadline
                if daysUntilDeadline < 0 {
                    updatedTask.isOverdue = true
                }
            }

            return updatedTask
        }
    }

    private func applyGoalUrgencyWeighting(tasks: [PlannerTask], goals: [PlannerGoal]) -> [PlannerTask] {
        return tasks.map { task in
            var updatedTask = task

            // Check if task supports urgent goals
            if let goalID = task.relatedGoalID,
               let goal = goals.first(where: { $0.id == goalID }) {

                let urgencyScore = calculateGoalUrgency(goal: goal)
                if urgencyScore > 0.7 && task.priority == .medium {
                    updatedTask.priority = .high
                } else if urgencyScore > 0.9 && task.priority != .critical {
                    updatedTask.priority = .critical
                }
            }

            return updatedTask
        }
    }

    private func calculateGoalUrgency(goal: PlannerGoal) -> Double {
        var urgency = 0.0

        // Deadline urgency
        if let deadline = goal.deadline {
            let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
            if daysUntilDeadline <= 7 {
                urgency += 0.4
            } else if daysUntilDeadline <= 30 {
                urgency += 0.2
            }
        }

        // Progress urgency (goals behind schedule)
        if goal.progress < 0.3 {
            urgency += 0.3
        } else if goal.progress < 0.6 {
            urgency += 0.2
        }

        // Importance urgency
        if goal.category == .career || goal.category == .financial {
            urgency += 0.2
        }

        return min(urgency, 1.0)
    }

    private func calculateCombinedPriorityScore(task: PlannerTask) -> Double {
        var score = 0.0

        // Base priority score
        score += Double(task.priority.numericValue) * 0.4

        // Goal alignment score
        score += (task.goalAlignmentScore ?? 0.5) * 0.3

        // Deadline urgency score
        if let deadline = task.deadline {
            let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 999
            if daysUntilDeadline <= 1 {
                score += 1.0 * 0.2
            } else if daysUntilDeadline <= 7 {
                score += 0.5 * 0.2
            } else if daysUntilDeadline <= 30 {
                score += 0.2 * 0.2
            }
        }

        // Complexity factor (simpler tasks get slight boost)
        score += (1.0 - task.complexity) * 0.1

        return score
    }
}

class PriorityResolver {
    private let logger = Logger(subsystem: "FocusLock", category: "PriorityResolver")

    func resolveConflicts(tasks: [PlannerTask], constraints: [SchedulingConstraint]) async throws -> [PlannerTask] {
        logger.info("Resolving conflicts for \(tasks.count) tasks with \(constraints.count) constraints")

        // Build constraint satisfaction problem
        let csp = ConstraintSatisfactionProblem(tasks: tasks, constraints: constraints)

        // Apply conflict resolution strategies
        let resolvedTasks = try await resolveConflictsWithCSP(csp)

        logger.info("Conflict resolution completed")
        return resolvedTasks
    }

    private func resolveConflictsWithCSP(_ csp: ConstraintSatisfactionProblem) async throws -> [PlannerTask] {
        var resolvedTasks = csp.tasks

        // Sort tasks by priority for conflict resolution
        resolvedTasks.sort { $0.priority.numericValue > $1.priority.numericValue }

        // Apply constraints iteratively
        for constraint in csp.constraints {
            resolvedTasks = try await applyConstraint(constraint, to: resolvedTasks)
        }

        // Resolve remaining conflicts
        resolvedTasks = try await resolveRemainingConflicts(resolvedTasks)

        return resolvedTasks
    }

    private func applyConstraint(_ constraint: SchedulingConstraint, to tasks: [PlannerTask]) async throws -> [PlannerTask] {
        var adjustedTasks = tasks

        switch constraint.type {
        case .maxFocusTime:
            adjustedTasks = applyMaxFocusTimeConstraint(constraint, tasks: adjustedTasks)
        case .minBreakTime:
            adjustedTasks = applyMinBreakTimeConstraint(constraint, tasks: adjustedTasks)
        case .energyAlignment:
            adjustedTasks = applyEnergyAlignmentConstraint(constraint, tasks: adjustedTasks)
        case .deadlinePriority:
            adjustedTasks = applyDeadlinePriorityConstraint(constraint, tasks: adjustedTasks)
        case .categoryBalance:
            adjustedTasks = applyCategoryBalanceConstraint(constraint, tasks: adjustedTasks)
        case .maxWorkHours:
            adjustedTasks = applyMaxWorkHoursConstraint(constraint, tasks: adjustedTasks)
        }

        return adjustedTasks
    }

    private func applyMaxFocusTimeConstraint(_ constraint: SchedulingConstraint, tasks: [PlannerTask]) -> [PlannerTask] {
        let maxFocusMinutes = constraint.value
        let focusTasks = tasks.filter { $0.isFocusSessionProtected }

        let totalFocusMinutes = focusTasks.reduce(0) { $0 + Int($1.estimatedDuration / 60) }

        if totalFocusMinutes > maxFocusMinutes {
            // Need to reduce focus time
            let excessMinutes = totalFocusMinutes - maxFocusMinutes
            return reduceFocusTime(tasks: tasks, reductionMinutes: excessMinutes)
        }

        return tasks
    }

    private func applyMinBreakTimeConstraint(_ constraint: SchedulingConstraint, tasks: [PlannerTask]) -> [PlannerTask] {
        let minBreakMinutes = constraint.value
        let totalWorkMinutes = tasks.reduce(0) { $0 + Int($1.estimatedDuration / 60) }

        // Ensure adequate break time (15% of work time minimum)
        let requiredBreakMinutes = max(minBreakMinutes, Int(Double(totalWorkMinutes) * 0.15))

        // This would affect the scheduling algorithm to insert breaks
        return tasks // Return tasks for now - break scheduling handled elsewhere
    }

    private func applyEnergyAlignmentConstraint(_ constraint: SchedulingConstraint, tasks: [PlannerTask]) -> [PlannerTask] {
        // Adjust task scheduling to align with energy patterns
        return tasks.map { task in
            var adjustedTask = task
            if task.preferredEnergyLevel == nil {
                // Set default energy level based on task complexity
                adjustedTask.preferredEnergyLevel = task.complexity > 0.7 ? .high : .medium
            }
            return adjustedTask
        }
    }

    private func applyDeadlinePriorityConstraint(_ constraint: SchedulingConstraint, tasks: [PlannerTask]) -> [PlannerTask] {
        return tasks.map { task in
            var adjustedTask = task

            if let deadline = task.deadline {
                let daysUntilDeadline = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 999

                // Boost priority for tasks with approaching deadlines
                if daysUntilDeadline <= constraint.value {
                    if adjustedTask.priority == .low {
                        adjustedTask.priority = .medium
                    } else if adjustedTask.priority == .medium && daysUntilDeadline <= 3 {
                        adjustedTask.priority = .high
                    }
                }
            }

            return adjustedTask
        }
    }

    private func applyCategoryBalanceConstraint(_ constraint: SchedulingConstraint, tasks: [PlannerTask]) -> [PlannerTask] {
        // Ensure balanced distribution across task categories
        let categoryDistribution = calculateCategoryDistribution(tasks: tasks)

        return tasks.map { task in
            var adjustedTask = task

            // Adjust priority to balance categories
            if let categoryCount = categoryDistribution[task.category],
               categoryCount > tasks.count / 4 { // More than 25% in one category
                // Slightly lower priority for overrepresented categories
                if adjustedTask.priority == .critical {
                    adjustedTask.priority = .high
                } else if adjustedTask.priority == .high {
                    adjustedTask.priority = .medium
                }
            }

            return adjustedTask
        }
    }

    private func applyMaxWorkHoursConstraint(_ constraint: SchedulingConstraint, tasks: [PlannerTask]) -> [PlannerTask] {
        let maxWorkHours = Double(constraint.value) / 60.0 // Convert minutes to hours
        let totalWorkHours = tasks.reduce(0) { $0 + $1.estimatedDuration / 3600 }

        if totalWorkHours > maxWorkHours {
            // Need to reduce work hours by deprioritizing some tasks
            let excessHours = totalWorkHours - maxWorkHours
            return reduceWorkHours(tasks: tasks, reductionHours: excessHours)
        }

        return tasks
    }

    private func reduceFocusTime(tasks: [PlannerTask], reductionMinutes: Int) -> [PlannerTask] {
        var tasksToAdjust = tasks.filter { $0.isFocusSessionProtected && $0.priority != .critical }
        var remainingReduction = reductionMinutes

        // Sort by priority (lowest first) for reduction
        tasksToAdjust.sort { $0.priority.numericValue < $1.priority.numericValue }

        var adjustedTasks = tasks

        for task in tasksToAdjust {
            if remainingReduction <= 0 { break }

            if let index = adjustedTasks.firstIndex(where: { $0.id == task.id }) {
                let taskMinutes = Int(adjustedTasks[index].estimatedDuration / 60)
                let reduction = min(taskMinutes / 2, remainingReduction) // Reduce by up to 50%

                adjustedTasks[index].estimatedDuration = Double((taskMinutes - reduction) * 60)
                remainingReduction -= reduction
            }
        }

        return adjustedTasks
    }

    private func reduceWorkHours(tasks: [PlannerTask], reductionHours: Double) -> [PlannerTask] {
        var tasksToAdjust = tasks.filter { $0.priority != .critical }
        var remainingReduction = reductionHours

        // Sort by priority (lowest first) for reduction
        tasksToAdjust.sort { $0.priority.numericValue < $1.priority.numericValue }

        var adjustedTasks = tasks

        for task in tasksToAdjust {
            if remainingReduction <= 0 { break }

            if let index = adjustedTasks.firstIndex(where: { $0.id == task.id }) {
                let taskHours = adjustedTasks[index].estimatedDuration / 3600
                let reduction = min(taskHours * 0.5, remainingReduction) // Reduce by up to 50%

                adjustedTasks[index].estimatedDuration = Double((taskHours - reduction) * 3600)
                remainingReduction -= reduction
            }
        }

        return adjustedTasks
    }

    private func calculateCategoryDistribution(tasks: [PlannerTask]) -> [TaskCategory: Int] {
        var distribution: [TaskCategory: Int] = [:]

        for task in tasks {
            distribution[task.category, default: 0] += 1
        }

        return distribution
    }

    private func resolveRemainingConflicts(_ tasks: [PlannerTask]) -> [PlannerTask] {
        // Final conflict resolution pass
        var resolvedTasks = tasks

        // Check for time conflicts
        resolvedTasks = resolveTimeConflicts(resolvedTasks)

        // Check for resource conflicts
        resolvedTasks = resolveResourceConflicts(resolvedTasks)

        return resolvedTasks
    }

    private func resolveTimeConflicts(_ tasks: [PlannerTask]) -> [PlannerTask] {
        // In a full implementation, this would resolve scheduling conflicts
        // For now, return tasks as scheduling is handled by TimeBlockOptimizer
        return tasks
    }

    private func resolveResourceConflicts(_ tasks: [PlannerTask]) -> [PlannerTask] {
        // Check for tasks that require similar resources
        var resolvedTasks = tasks

        // Group tasks by required resources
        let tasksByResource = Dictionary(grouping: tasks) { $0.requiredResources }

        for (resource, resourceTasks) in tasksByResource {
            if resourceTasks.count > 1 {
                // Sort by priority and add conflict flags
                let sortedTasks = resourceTasks.sorted { $0.priority.numericValue > $1.priority.numericValue }

                for (index, task) in sortedTasks.enumerated() {
                    if index > 0 { // Not the highest priority task
                        if let taskIndex = resolvedTasks.firstIndex(where: { $0.id == task.id }) {
                            resolvedTasks[taskIndex].hasResourceConflict = true
                        }
                    }
                }
            }
        }

        return resolvedTasks
    }
}

class ReschedulingEngine {
    private let logger = Logger(subsystem: "FocusLock", category: "ReschedulingEngine")
    private var reschedulingStrategies: [ReschedulingStrategy]

    init() {
        reschedulingStrategies = [
            OvertimeReschedulingStrategy(),
            PriorityShiftStrategy(),
            DeadlineAdjustmentStrategy(),
            ResourceReallocationStrategy(),
            FocusSessionProtectionStrategy()
        ]
    }

    func handleOvertime(taskID: UUID, additionalTime: TimeInterval, currentPlan: DailyPlan?) async throws {
        logger.info("Handling overtime for task \(taskID.uuidString.prefix(8)): +\(Int(additionalTime/60))min")

        guard let plan = currentPlan else {
            logger.warning("No current plan available for rescheduling")
            return
        }

        // Find the affected time block
        guard let affectedBlock = plan.timeBlocks.first(where: { $0.taskID == taskID }) else {
            logger.warning("No time block found for task \(taskID)")
            return
        }

        // Calculate rescheduling impact
        let impact = ReschedulingImpact(
            affectedTaskID: taskID,
            additionalTime: additionalTime,
            affectedBlocks: findAffectedBlocks(block: affectedBlock, plan: plan),
            reschedulingRequired: true
        )

        // Apply appropriate rescheduling strategy
        let strategy = selectReschedulingStrategy(impact: impact)
        let rescheduledPlan = try await strategy.apply(to: plan, impact: impact)

        // Update the current plan
        // In a full implementation, this would update the published currentPlan

        logger.info("Rescheduling completed successfully")
    }

    private func findAffectedBlocks(block: TimeBlock, plan: DailyPlan) -> [TimeBlock] {
        let blockIndex = plan.timeBlocks.firstIndex(where: { $0.id == block.id }) ?? 0
        let affectedBlocks = Array(plan.timeBlocks[blockIndex...])

        return affectedBlocks.filter { $0.startTime >= block.startTime }
    }

    private func selectReschedulingStrategy(impact: ReschedulingImpact) -> ReschedulingStrategy {
        // Select strategy based on impact characteristics
        if impact.additionalTime > 3600 { // More than 1 hour overtime
            return PriorityShiftStrategy()
        } else if !impact.affectedBlocks.isEmpty {
            return OvertimeReschedulingStrategy()
        } else {
            return DeadlineAdjustmentStrategy()
        }
    }
}

class CalendarManager {
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "FocusLock", category: "CalendarManager")
    private var calendars: [EKCalendar] = []

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var hasCalendarAccess: Bool {
        authorizationStatus == .authorized
    }

    @discardableResult
    func ensureAuthorization() async -> Bool {
        let status = authorizationStatus

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await requestCalendarAccess()
        case .restricted, .denied:
            logger.error("Calendar access is not available: \(status.rawValue)")
            return false
        @unknown default:
            logger.error("Calendar access returned unknown status: \(status.rawValue)")
            return false
        }
    }

    func exportPlan(_ plan: DailyPlan) async throws {
        logger.info("Exporting plan for \(plan.dateFormatted) to calendar")

        let accessGranted = await ensureAuthorization()
        guard accessGranted else {
            throw CalendarError.accessDenied
        }

        // Get or create FocusLock calendar
        let calendar = try await getOrCreateFocusLockCalendar()

        // Delete existing events for this date
        try await deleteExistingEvents(for: plan.date, in: calendar)

        // Export time blocks as calendar events
        for block in plan.timeBlocks {
            let event = createEventFromTimeBlock(block, in: calendar)
            try await saveEvent(event)
        }

        logger.info("Successfully exported \(plan.timeBlocks.count) events to calendar")
    }

    func loadEvents(for date: Date) async throws -> [CalendarEvent] {
        let accessGranted = await ensureAuthorization()
        guard accessGranted else {
            throw CalendarError.accessDenied
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events.map { event in
            CalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                startTime: event.startDate,
                endTime: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes,
                calendarIdentifier: event.calendar.calendarIdentifier
            )
        }
    }

    func syncWithExternalCalendars() async throws {
        logger.info("Syncing with external calendars")

        let accessGranted = await ensureAuthorization()
        guard accessGranted else {
            throw CalendarError.accessDenied
        }

        // Get all calendars
        calendars = eventStore.calendars(for: .event)

        // Sync with each calendar
        for calendar in calendars {
            try await syncCalendar(calendar)
        }

        logger.info("Calendar sync completed")
    }

    private func requestCalendarAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    self.logger.error("Calendar access request failed: \(error.localizedDescription)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private func getOrCreateFocusLockCalendar() async throws -> EKCalendar {
        // Try to find existing FocusLock calendar
        if let existingCalendar = calendars.first(where: { $0.title == "FocusLock" }) {
            return existingCalendar
        }

        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "FocusLock"
        newCalendar.source = eventStore.defaultCalendarForNewEvents?.source

        try eventStore.saveCalendar(newCalendar, commit: true)
        calendars.append(newCalendar)

        return newCalendar
    }

    private func deleteExistingEvents(for date: Date, in calendar: EKCalendar) async throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate)

        for event in existingEvents {
            try eventStore.remove(event, span: .thisEvent)
        }
    }

    private func createEventFromTimeBlock(_ block: TimeBlock, in calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = block.title
        event.startDate = block.startTime
        event.endDate = block.endTime
        event.calendar = calendar

        // Add block-specific information
        var notes: [String] = []
        notes.append("FocusLock Time Block")
        notes.append("Type: \(block.blockType.rawValue)")
        notes.append("Energy Level: \(block.energyLevel.rawValue)")

        if let taskID = block.taskID {
            notes.append("Task ID: \(taskID.uuidString)")
        }

        if block.isProtected {
            notes.append("Protected: Yes")
        }

        event.notes = notes.joined(separator: "\n")

        // Set alarms
        let alarm = EKAlarm(relativeOffset: -300) // 5 minutes before
        event.addAlarm(alarm)

        return event
    }

    private func saveEvent(_ event: EKEvent) async throws {
        try eventStore.save(event, span: .thisEvent)
    }

    private func syncCalendar(_ calendar: EKCalendar) async throws {
        // Load events from the last 30 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)

        // Process events for synchronization
        for event in events {
            await processCalendarEvent(event)
        }
    }

    private func processCalendarEvent(_ event: EKEvent) async {
        // Process calendar event for scheduling conflicts or opportunities
        logger.debug("Processing calendar event: \(event.title)")

        // Check if this affects FocusLock scheduling
        if event.title.contains("FocusLock") {
            return // Skip our own events
        }

        // Check for conflicts or scheduling opportunities
        // This would integrate with the TimeBlockOptimizer
    }
}

// MARK: - Supporting Models for Enhanced Functionality

struct SchedulingLearningModel {
    private var weights: [Double] = Array(repeating: 0.1, count: 10)

    mutating func train(with performanceHistory: [SchedulingPerformance]) {
        // Train the model with performance data
        // Simplified implementation - would use actual ML in production
        guard performanceHistory.count > 10 else { return }

        // Update weights based on performance patterns
        let recentPerformance = Array(performanceHistory.suffix(50))
        weights = calculateOptimalWeights(from: recentPerformance)
    }

    private func calculateOptimalWeights(from performances: [SchedulingPerformance]) -> [Double] {
        // Simplified weight calculation
        // In production, would use gradient descent or other ML algorithm
        return Array(repeating: 0.1, count: 10)
    }
}

struct GoalAlignmentModel {
    // Simplified goal alignment model
    // In production, would use NLP and semantic analysis
}

struct ConstraintSatisfactionProblem {
    let tasks: [PlannerTask]
    let constraints: [SchedulingConstraint]

    init(tasks: [PlannerTask], constraints: [SchedulingConstraint]) {
        self.tasks = tasks
        self.constraints = constraints
    }
}

struct ReschedulingImpact {
    let affectedTaskID: UUID
    let additionalTime: TimeInterval
    let affectedBlocks: [TimeBlock]
    let reschedulingRequired: Bool
}

protocol ReschedulingStrategy {
    func apply(to plan: DailyPlan, impact: ReschedulingImpact) async throws -> DailyPlan
}

class OvertimeReschedulingStrategy: ReschedulingStrategy {
    func apply(to plan: DailyPlan, impact: ReschedulingImpact) async throws -> DailyPlan {
        var updatedPlan = plan

        // Extend the affected block
        if let blockIndex = updatedPlan.timeBlocks.firstIndex(where: { $0.taskID == impact.affectedTaskID }) {
            let originalBlock = updatedPlan.timeBlocks[blockIndex]
            let extendedBlock = TimeBlock(
                startTime: originalBlock.startTime,
                endTime: originalBlock.endTime.addingTimeInterval(impact.additionalTime),
                taskID: originalBlock.taskID,
                blockType: originalBlock.blockType,
                title: originalBlock.title,
                isProtected: originalBlock.isProtected,
                energyLevel: originalBlock.energyLevel,
                breakBuffer: originalBlock.breakBuffer
            )

            updatedPlan.timeBlocks[blockIndex] = extendedBlock

            // Adjust subsequent blocks
            updatedPlan = adjustSubsequentBlocks(updatedPlan, from: blockIndex, timeShift: impact.additionalTime)
        }

        return updatedPlan
    }

    private func adjustSubsequentBlocks(_ plan: DailyPlan, from index: Int, timeShift: TimeInterval) -> DailyPlan {
        var updatedPlan = plan

        for i in (index + 1)..<updatedPlan.timeBlocks.count {
            let block = updatedPlan.timeBlocks[i]
            updatedPlan.timeBlocks[i] = TimeBlock(
                startTime: block.startTime.addingTimeInterval(timeShift),
                endTime: block.endTime.addingTimeInterval(timeShift),
                taskID: block.taskID,
                blockType: block.blockType,
                title: block.title,
                isProtected: block.isProtected,
                energyLevel: block.energyLevel,
                breakBuffer: block.breakBuffer
            )
        }

        return updatedPlan
    }
}

class PriorityShiftStrategy: ReschedulingStrategy {
    func apply(to plan: DailyPlan, impact: ReschedulingImpact) async throws -> DailyPlan {
        // Implement priority shift strategy
        return plan
    }
}

class DeadlineAdjustmentStrategy: ReschedulingStrategy {
    func apply(to plan: DailyPlan, impact: ReschedulingImpact) async throws -> DailyPlan {
        // Implement deadline adjustment strategy
        return plan
    }
}

class ResourceReallocationStrategy: ReschedulingStrategy {
    func apply(to plan: DailyPlan, impact: ReschedulingImpact) async throws -> DailyPlan {
        // Implement resource reallocation strategy
        return plan
    }
}

class FocusSessionProtectionStrategy: ReschedulingStrategy {
    func apply(to plan: DailyPlan, impact: ReschedulingImpact) async throws -> DailyPlan {
        // Protect focus sessions from being disrupted
        return plan
    }
}

enum CalendarError: Error {
    case accessDenied
    case calendarNotFound
    case eventCreationFailed
}

struct SchedulingPatterns {
    var mostProductiveHours: [Int] = []
    var optimalTaskDurations: [PlannerPriority: TimeInterval] = [:]
    var preferredBreakIntervals: [TimeInterval] = []
    var energyPeakTimes: [Date] = []
    var focusOptimalWindows: [Date] = []
}

struct LearningFactors {
    var dayOfWeekMultiplier: Double = 1.0
    var seasonalAdjustment: Double = 1.0
    var weatherImpact: Double = 1.0
    var taskComplexityAdjustment: Double = 1.0
    var priorityWeighting: Double = 1.0
    var energyAlignmentBonus: Double = 1.0
    var goalAlignmentScore: Double = 1.0
}

struct PerformanceInsight {
    let type: InsightType
    let title: String
    let description: String
    let action: String

    enum InsightType {
        case productivity
        case energy
        case focus
        case timing
    }
}

struct SchedulingPerformance {
    let startTime: Date
    let completionRate: Double
    let energyLevel: Double
    let taskPriority: PlannerPriority
    let actualDuration: TimeInterval
    let wasFocusSession: Bool
    let followedBreak: Bool
    let breakDuration: TimeInterval
}

struct PlannerTaskSource {
    let type: SourceType
    let identifier: String
    let name: String

    enum SourceType {
        case calendar
        case todoist
        case trello
        case asana
        case email
        case suggestedTodos
    }
}

struct CalendarEvent {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarIdentifier: String
}

class TaskImporter {
    private let logger = Logger(subsystem: "FocusLock", category: "TaskImporter")

    static func importTasks(from source: PlannerTaskSource) async throws -> [PlannerTask] {
        let importer = TaskImporter()

        switch source.type {
        case .calendar:
            return try await importer.importFromCalendar(identifier: source.identifier, name: source.name)
        case .todoist:
            return try await importer.importFromTodoist(identifier: source.identifier, name: source.name)
        case .trello:
            return try await importer.importFromTrello(identifier: source.identifier, name: source.name)
        case .asana:
            return try await importer.importFromAsana(identifier: source.identifier, name: source.name)
        case .email:
            return try await importer.importFromEmail(identifier: source.identifier, name: source.name)
        case .suggestedTodos:
            return try await importer.importFromSuggestedTodos(identifier: source.identifier, name: source.name)
        }
    }

    private func importFromCalendar(identifier: String, name: String) async throws -> [PlannerTask] {
        logger.info("Importing tasks from calendar: \(name)")

        let calendarManager = CalendarManager()
        let accessGranted = await calendarManager.ensureAuthorization()
        guard accessGranted else {
            throw CalendarError.accessDenied
        }
        let today = Date()
        let events = try await calendarManager.loadEvents(for: today)

        return events.map { event in
            PlannerTask(
                title: event.title,
                description: event.notes,
                estimatedDuration: event.endTime.timeIntervalSince(event.startTime),
                priority: .medium,
                category: .work,
                deadline: event.endTime,
                sourceIdentifier: identifier,
                externalSource: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }

    private func importFromTodoist(identifier: String, name: String) async throws -> [PlannerTask] {
        logger.info("Importing tasks from Todoist: \(name)")

        // In a real implementation, would use Todoist API
        // For now, return empty array
        return []
    }

    private func importFromTrello(identifier: String, name: String) async throws -> [PlannerTask] {
        logger.info("Importing tasks from Trello: \(name)")

        // In a real implementation, would use Trello API
        // For now, return empty array
        return []
    }

    private func importFromAsana(identifier: String, name: String) async throws -> [PlannerTask] {
        logger.info("Importing tasks from Asana: \(name)")

        // In a real implementation, would use Asana API
        // For now, return empty array
        return []
    }

    private func importFromEmail(identifier: String, name: String) async throws -> [PlannerTask] {
        logger.info("Importing tasks from Email: \(name)")

        // In a real implementation, would parse emails for action items
        // For now, return empty array
        return []
    }

    private func importFromSuggestedTodos(identifier: String, name: String) async throws -> [PlannerTask] {
        logger.info("Importing tasks from SuggestedTodos: \(name)")

        let suggestedTodosEngine = PlannerSuggestedTodosService()
        let suggestions = try await suggestedTodosEngine.fetchSuggestions(for: identifier)

        return suggestions.map { suggestion in
            PlannerTask(
                title: suggestion.title,
                description: suggestion.description,
                estimatedDuration: suggestion.estimatedDuration,
                priority: suggestion.priority,
                category: suggestion.category,
                relatedGoalID: suggestion.relatedGoalID,
                sourceIdentifier: identifier,
                externalSource: true,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
}

class PlannerSuggestedTodosService {
    private let logger = Logger(subsystem: "FocusLock", category: "SuggestedTodosEngine")
    private var apiEndpoint: String?
    private var userPreferences: PlannerUserPreferences

    init() {
        userPreferences = PlannerUserPreferences()
        setupAPIEndpoint()
    }

    func fetchSuggestions(for sourceID: String) async throws -> [PlannerTaskSuggestion] {
        logger.info("Fetching suggestions from source: \(sourceID)")

        guard let endpoint = apiEndpoint else {
            throw SuggestedTodosError.apiNotConfigured
        }

        // In a real implementation, would make API call to SuggestedTodos service
        // For now, generate mock suggestions based on user preferences
        return generateMockSuggestions(for: sourceID)
    }

    func syncWithSuggestedTodos() async throws {
        logger.info("Syncing with SuggestedTodos service")

        // In a real implementation, would sync user preferences and task completion data
        // back to SuggestedTodos service for better recommendations
    }

    func updateSuggestionPreferences(_ preferences: PlannerUserPreferences) {
        userPreferences = preferences
        logger.info("Updated suggestion preferences")
    }

    private func setupAPIEndpoint() {
        // In a real implementation, would read from configuration
        // For now, use mock endpoint
        apiEndpoint = "https://api.suggestedtodos.com/v1"
    }

    private func generateMockSuggestions(for sourceID: String) -> [PlannerTaskSuggestion] {
        var suggestions: [PlannerTaskSuggestion] = []

        // Generate suggestions based on common productivity patterns
        let commonTasks = [
            ("Review daily emails", 900, .low, .productivity),
            ("Plan tomorrow's priorities", 600, .medium, .productivity),
            ("Exercise for 30 minutes", 1800, .high, .health),
            ("Read industry news", 1200, .medium, .learning),
            ("Organize workspace", 900, .low, .productivity),
            ("Practice deep work session", 3600, .high, .productivity),
            ("Update project status", 600, .medium, .career),
            ("Connect with team member", 1800, .medium, .personal)
        ]

        for (title, duration, priority, category) in commonTasks {
            suggestions.append(PlannerTaskSuggestion(
                title: title,
                description: "Suggested based on your productivity patterns",
                estimatedDuration: duration,
                priority: priority,
                category: category,
                relatedGoalID: nil,
                confidence: Double.random(in: 0.6...0.9),
                sourceID: sourceID
            ))
        }

        return suggestions
    }
}

struct PlannerUserPreferences: Codable {
    var preferredWorkHours: WorkHours = WorkHours(startHour: 9, endHour: 17)
    var focusSessionDuration: TimeInterval = 1500 // 25 minutes
    var breakDuration: TimeInterval = 300 // 5 minutes
    var preferredTaskCategories: [TaskCategory] = [.work, .learning]
    var energyAwareScheduling: Bool = true
    var goalAlignment: Bool = true

    struct WorkHours: Codable {
        let startHour: Int
        let endHour: Int
    }
}

struct PlannerTaskSuggestion {
    let title: String
    let description: String
    let estimatedDuration: TimeInterval
    let priority: PlannerPriority
    let category: TaskCategory
    let relatedGoalID: UUID?
    let confidence: Double
    let sourceID: String
}

enum SuggestedTodosError: Error {
    case apiNotConfigured
    case authenticationFailed
    case quotaExceeded
    case invalidResponse
}

class PlannerTaskSuggestionEngine {
    static func generateSuggestions(goals: [PlannerGoal], patterns: CompletionPatterns, existingTasks: [PlannerTask], limit: Int) async -> [PlannerTaskSuggestion] {
        // Generate AI-powered task suggestions
        return [] // Simplified implementation
    }
}

class GoalProgressTracker {
    static func calculateProgress(goals: [PlannerGoal], tasks: [PlannerTask]) async -> [GoalProgress] {
        // Calculate progress towards goals
        return [] // Simplified implementation
    }
}

class PlannerDataStore {
    private let logger = Logger(subsystem: "FocusLock", category: "PlannerDataStore")
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let dataDirectory: URL
    private let encryptionKey: String
    private let privacySettings: PlannerPrivacySettings

    // MARK: - File Paths
    private let tasksFile = "tasks.json"
    private let dailyPlansFile = "daily_plans.json"
    private let goalsFile = "goals.json"
    private let constraintsFile = "constraints.json"
    private let performanceDataFile = "performance.json"
    private let userPreferencesFile = "user_preferences.json"
    private let privacySettingsFile = "privacy_settings.json"

    init() {
        // Get app documents directory
        documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        dataDirectory = documentsURL.appendingPathComponent("FocusLockData")

        // Initialize encryption key (in production, would use Keychain)
        encryptionKey = "focuslock_encryption_key_v1"

        // Load privacy settings
        privacySettings = loadPrivacySettings()

        // Create data directory if needed
        createDataDirectory()

        // Initialize data files with proper permissions
        initializeDataFiles()
    }

    // MARK: - Public Methods - Tasks

    func saveTask(_ task: PlannerTask) async throws {
        let tasks = try await loadAllTasks()
        var updatedTasks = tasks

        if let index = updatedTasks.firstIndex(where: { $0.id == task.id }) {
            updatedTasks[index] = task
        } else {
            updatedTasks.append(task)
        }

        try await saveTasks(updatedTasks)
        logger.info("Saved task: \(task.title)")
    }

    func saveTasks(_ tasks: [PlannerTask]) async throws {
        let filteredTasks = filterTasksForPrivacy(tasks)
        let data = try JSONEncoder().encode(filteredTasks)
        let encryptedData = try encryptData(data)
        try saveDataToFile(encryptedData, fileName: tasksFile)
        logger.info("Saved \(tasks.count) tasks")
    }

    func loadAllTasks() async throws -> [PlannerTask] {
        guard fileManager.fileExists(atPath: dataDirectory.appendingPathComponent(tasksFile).path) else {
            return []
        }

        let encryptedData = try loadDataFromFile(fileName: tasksFile)
        let data = try decryptData(encryptedData)
        let tasks = try JSONDecoder().decode([PlannerTask].self, from: data)

        return filterTasksForPrivacy(tasks)
    }

    func loadActiveTasks() async throws -> [PlannerTask] {
        let allTasks = try await loadAllTasks()
        let today = Calendar.current.startOfDay(for: Date())

        return allTasks.filter { task in
            !task.isCompleted &&
            (task.deadline ?? today.addingTimeInterval(30 * 24 * 3600)) >= today
        }
    }

    func deleteTask(_ taskID: UUID) async throws {
        var tasks = try await loadAllTasks()
        tasks.removeAll { $0.id == taskID }
        try await saveTasks(tasks)
        logger.info("Deleted task: \(taskID.uuidString)")
    }

    // MARK: - Public Methods - Daily Plans

    func saveDailyPlan(_ plan: DailyPlan) async throws {
        let plans = try await loadAllDailyPlans()
        var updatedPlans = plans

        // Remove existing plan for the same date
        updatedPlans.removeAll { Calendar.current.isDate($0.date, inSameDayAs: plan.date) }

        // Add the new plan
        updatedPlans.append(plan)

        // Keep only last 30 days of plans
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        updatedPlans = updatedPlans.filter { $0.date >= thirtyDaysAgo }

        try await saveAllDailyPlans(updatedPlans)
        logger.info("Saved daily plan for \(plan.dateFormatted)")
    }

    func loadDailyPlan(for date: Date) async throws -> DailyPlan? {
        let plans = try await loadAllDailyPlans()
        return plans.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func loadAllDailyPlans() async throws -> [DailyPlan] {
        guard fileManager.fileExists(atPath: dataDirectory.appendingPathComponent(dailyPlansFile).path) else {
            return []
        }

        let encryptedData = try loadDataFromFile(fileName: dailyPlansFile)
        let data = try decryptData(encryptedData)
        let plans = try JSONDecoder().decode([DailyPlan].self, from: data)

        return filterPlansForPrivacy(plans)
    }

    func loadUpcomingPlans() async throws -> [DailyPlan] {
        let allPlans = try await loadAllDailyPlans()
        let today = Calendar.current.startOfDay(for: Date())

        return allPlans
            .filter { $0.date > today }
            .sorted { $0.date < $1.date }
            .prefix(7)
            .map { $0 }
    }

    func deleteDailyPlan(for date: Date) async throws {
        var plans = try await loadAllDailyPlans()
        plans.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        try await saveAllDailyPlans(plans)
        logger.info("Deleted daily plan for \(date.formatted(date: .abbreviated))")
    }

    // MARK: - Public Methods - Goals

    func saveGoals(_ goals: [PlannerGoal]) async throws {
        let filteredGoals = filterGoalsForPrivacy(goals)
        let data = try JSONEncoder().encode(filteredGoals)
        let encryptedData = try encryptData(data)
        try saveDataToFile(encryptedData, fileName: goalsFile)
        logger.info("Saved \(goals.count) goals")
    }

    func loadGoals() async throws -> [PlannerGoal] {
        guard fileManager.fileExists(atPath: dataDirectory.appendingPathComponent(goalsFile).path) else {
            return []
        }

        let encryptedData = try loadDataFromFile(fileName: goalsFile)
        let data = try decryptData(encryptedData)
        let goals = try JSONDecoder().decode([PlannerGoal].self, from: data)

        return filterGoalsForPrivacy(goals)
    }

    // MARK: - Public Methods - Constraints

    func saveConstraints(_ constraints: [SchedulingConstraint]) async throws {
        let data = try JSONEncoder().encode(constraints)
        let encryptedData = try encryptData(data)
        try saveDataToFile(encryptedData, fileName: constraintsFile)
        logger.info("Saved \(constraints.count) constraints")
    }

    func loadConstraints() async throws -> [SchedulingConstraint] {
        guard fileManager.fileExists(atPath: dataDirectory.appendingPathComponent(constraintsFile).path) else {
            return []
        }

        let encryptedData = try loadDataFromFile(fileName: constraintsFile)
        let data = try decryptData(encryptedData)
        return try JSONDecoder().decode([SchedulingConstraint].self, from: data)
    }

    // MARK: - Public Methods - Performance Data

    func savePerformanceData(_ performanceData: [SchedulingPerformance]) async throws {
        guard privacySettings.enablePerformanceTracking else { return }

        let filteredData = filterPerformanceDataForPrivacy(performanceData)
        let data = try JSONEncoder().encode(filteredData)
        let encryptedData = try encryptData(data)
        try saveDataToFile(encryptedData, fileName: performanceDataFile)
        logger.info("Saved performance data: \(performanceData.count) records")
    }

    func loadPerformanceData() async throws -> [SchedulingPerformance] {
        guard privacySettings.enablePerformanceTracking else { return [] }

        guard fileManager.fileExists(atPath: dataDirectory.appendingPathComponent(performanceDataFile).path) else {
            return []
        }

        let encryptedData = try loadDataFromFile(fileName: performanceDataFile)
        let data = try decryptData(encryptedData)
        return try JSONDecoder().decode([SchedulingPerformance].self, from: data)
    }

    // MARK: - Public Methods - User Preferences

    func saveUserPreferences(_ preferences: PlannerUserPreferences) async throws {
        let data = try JSONEncoder().encode(preferences)
        let encryptedData = try encryptData(data)
        try saveDataToFile(encryptedData, fileName: userPreferencesFile)
        logger.info("Saved user preferences")
    }

    func loadUserPreferences() async throws -> PlannerUserPreferences {
        guard fileManager.fileExists(atPath: dataDirectory.appendingPathComponent(userPreferencesFile).path) else {
            return PlannerUserPreferences()
        }

        let encryptedData = try loadDataFromFile(fileName: userPreferencesFile)
        let data = try decryptData(encryptedData)
        return try JSONDecoder().decode(PlannerUserPreferences.self, from: data)
    }

    // MARK: - Public Methods - Privacy Settings

    func savePrivacySettings(_ settings: PlannerPrivacySettings) async throws {
        let data = try JSONEncoder().encode(settings)
        let encryptedData = try encryptData(data)
        try saveDataToFile(encryptedData, fileName: privacySettingsFile)
        logger.info("Updated privacy settings")
    }

    // MARK: - Public Methods - Data Management

    func exportData() async throws -> DataExport {
        logger.info("Exporting user data")

        let tasks = try await loadAllTasks()
        let goals = try await loadGoals()
        let constraints = try await loadConstraints()
        let performanceData = try await loadPerformanceData()
        let userPreferences = try await loadUserPreferences()

        return DataExport(
            tasks: tasks,
            goals: goals,
            constraints: constraints,
            performanceData: performanceData,
            userPreferences: userPreferences,
            exportDate: Date(),
            version: "1.0.0"
        )
    }

    func importData(_ export: DataExport) async throws {
        logger.info("Importing user data")

        try await saveTasks(export.tasks)
        try await saveGoals(export.goals)
        try await saveConstraints(export.constraints)
        try await savePerformanceData(export.performanceData)
        try await saveUserPreferences(export.userPreferences)

        logger.info("Data import completed successfully")
    }

    func clearAllData() async throws {
        logger.info("Clearing all user data")

        let files = [tasksFile, dailyPlansFile, goalsFile, constraintsFile, performanceDataFile, userPreferencesFile, privacySettingsFile]

        for file in files {
            let filePath = dataDirectory.appendingPathComponent(file)
            if fileManager.fileExists(atPath: filePath.path) {
                try fileManager.removeItem(at: filePath)
            }
        }

        // Reinitialize with defaults
        initializeDataFiles()

        logger.info("All data cleared successfully")
    }

    func getDataSize() -> DataSize {
        let files = [tasksFile, dailyPlansFile, goalsFile, constraintsFile, performanceDataFile, userPreferencesFile, privacySettingsFile]
        var totalSize: Int64 = 0

        for file in files {
            let filePath = dataDirectory.appendingPathComponent(file)
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath.path) {
                totalSize += attributes[.size] as? Int64 ?? 0
            }
        }

        return DataSize(totalBytes: totalSize, formattedSize: ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
    }

    // MARK: - Private Methods - File Management

    private func createDataDirectory() {
        if !fileManager.fileExists(atPath: dataDirectory.path) {
            do {
                try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)

                // Set proper file permissions (read/write for owner only)
                let attributes = [FileAttributeKey.posixPermissions: 0o700]
                try fileManager.setAttributes(attributes, ofItemAtPath: dataDirectory.path)

                // Prevent backup if privacy settings require it
                if privacySettings.preventiCloudBackup {
                    try dataDirectory.setResourceValue(true, forKey: .isExcludedFromBackupKey)
                }

                logger.info("Created data directory with privacy settings")
            } catch {
                logger.error("Failed to create data directory: \(error.localizedDescription)")
            }
        }
    }

    private func initializeDataFiles() {
        let files = [tasksFile, dailyPlansFile, goalsFile, constraintsFile, userPreferencesFile, privacySettingsFile]

        for file in files {
            let filePath = dataDirectory.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath.path) {
                createEmptyDataFile(fileName: file)
            }
        }

        // Create privacy settings file if it doesn't exist
        let privacyFilePath = dataDirectory.appendingPathComponent(privacySettingsFile)
        if !fileManager.fileExists(atPath: privacyFilePath.path) {
            let defaultSettings = PlannerPrivacySettings()
            Task {
                do {
                    try await savePrivacySettings(defaultSettings)
                } catch {
                    logger.error("Failed to save default privacy settings: \(error.localizedDescription)")
                }
            }
        }
    }

    private func createEmptyDataFile(fileName: String) {
        let filePath = dataDirectory.appendingPathComponent(fileName)

        do {
            let emptyData = Data()
            try emptyData.write(to: filePath)

            // Set file permissions
            let attributes = [FileAttributeKey.posixPermissions: 0o600]
            try fileManager.setAttributes(attributes, ofItemAtPath: filePath.path)

            // Prevent backup if needed
            if privacySettings.preventiCloudBackup {
                try filePath.setResourceValue(true, forKey: .isExcludedFromBackupKey)
            }
        } catch {
            logger.error("Failed to create empty data file \(fileName): \(error.localizedDescription)")
        }
    }

    private func saveDataToFile(_ data: Data, fileName: String) throws {
        let filePath = dataDirectory.appendingPathComponent(fileName)
        try data.write(to: filePath)
    }

    private func loadDataFromFile(fileName: String) throws -> Data {
        let filePath = dataDirectory.appendingPathComponent(fileName)
        return try Data(contentsOf: filePath)
    }

    // MARK: - Private Methods - Encryption

    private func encryptData(_ data: Data) throws -> Data {
        // In a production app, would use proper encryption like AES-256
        // For now, return data as-is (encryption placeholder)
        return data
    }

    private func decryptData(_ encryptedData: Data) throws -> Data {
        // In a production app, would use proper decryption
        // For now, return data as-is (decryption placeholder)
        return encryptedData
    }

    // MARK: - Private Methods - Privacy

    private func loadPrivacySettings() -> PlannerPrivacySettings {
        let filePath = dataDirectory.appendingPathComponent(privacySettingsFile)

        if fileManager.fileExists(atPath: filePath.path) {
            do {
                let encryptedData = try loadDataFromFile(fileName: privacySettingsFile)
                let data = try decryptData(encryptedData)
                return try JSONDecoder().decode(PlannerPrivacySettings.self, from: data)
            } catch {
                logger.error("Failed to load privacy settings, using defaults: \(error.localizedDescription)")
            }
        }

        // Return default privacy settings
        return PlannerPrivacySettings()
    }

    private func filterTasksForPrivacy(_ tasks: [PlannerTask]) -> [PlannerTask] {
        guard privacySettings.enableDataCollection else { return [] }

        return tasks.map { task in
            var filteredTask = task

            // Remove sensitive information based on privacy settings
            if !privacySettings.storeTaskDescriptions {
                filteredTask.description = nil
            }

            if !privacySettings.storeLocationData {
                filteredTask.location = nil
            }

            if !privacySettings.storeExternalSourceInfo {
                filteredTask.externalSource = false
                filteredTask.sourceIdentifier = nil
            }

            return filteredTask
        }
    }

    private func filterPlansForPrivacy(_ plans: [DailyPlan]) -> [DailyPlan] {
        guard privacySettings.enableDataCollection else { return [] }

        return plans
    }

    private func filterGoalsForPrivacy(_ goals: [PlannerGoal]) -> [PlannerGoal] {
        guard privacySettings.enableDataCollection else { return [] }

        return goals
    }

    private func filterPerformanceDataForPrivacy(_ data: [SchedulingPerformance]) -> [SchedulingPerformance] {
        guard privacySettings.enablePerformanceTracking else { return [] }

        return data.suffix(privacySettings.performanceDataRetentionDays)
    }
}

// MARK: - Supporting Models for Data Store

struct DataExport: Codable {
    let tasks: [PlannerTask]
    let goals: [PlannerGoal]
    let constraints: [SchedulingConstraint]
    let performanceData: [SchedulingPerformance]
    let userPreferences: PlannerUserPreferences
    let exportDate: Date
    let version: String
}

struct DataSize {
    let totalBytes: Int64
    let formattedSize: String
}

struct PlannerPrivacySettings: Codable {
    var enableDataCollection: Bool = true
    var enablePerformanceTracking: Bool = true
    var storeTaskDescriptions: Bool = true
    var storeLocationData: Bool = true
    var storeExternalSourceInfo: Bool = true
    var performanceDataRetentionDays: Int = 90
    var preventiCloudBackup: Bool = true
    var dataAnonymization: Bool = false
    var shareAnalyticsData: Bool = false

    enum PrivacyLevel: String, Codable, CaseIterable {
        case minimal = "minimal"
        case standard = "standard"
        case comprehensive = "comprehensive"
    }
}
