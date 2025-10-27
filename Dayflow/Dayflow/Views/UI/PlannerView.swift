//
//  PlannerView.swift
//  FocusLock
//
//  Main planner interface with drag-and-drop timeline
//  and intelligent scheduling controls
//

import SwiftUI
import Combine

struct PlannerView: View {
    @StateObject private var plannerEngine = PlannerEngine.shared
    @StateObject private var sessionManager = SessionManager.shared
    @State private var selectedDate: Date = Date()
    @State private var showingTaskCreation = false
    @State private var showingSuggestions = false
    @State private var showingSettings = false
    @State private var draggedBlock: TimeBlock?
    @State private var isOptimizing = false
    @State private var optimizationProgress: Double = 0.0

    // UI State
    @State private var selectedTask: PlannerTask?
    @State private var showingTaskDetails = false
    @State private var showingDatePicker = false
    @State private var viewMode: PlannerViewMode = .timeline

    enum PlannerViewMode: String, CaseIterable {
        case timeline = "timeline"
        case list = "list"
        case calendar = "calendar"
        case analytics = "analytics"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView

                // View Mode Selector
                viewModeSelector

                // Main Content
                mainContentView

                // Bottom Action Bar
                actionBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTaskCreation) {
            TaskCreationView(
                isPresented: $showingTaskCreation,
                onTaskCreated: { task in
                    plannerEngine.addTask(task)
                }
            )
        }
        .sheet(isPresented: $showingSuggestions) {
            TaskSuggestionsView(
                suggestions: [],
                onTaskSelected: { suggestion in
                    // Convert suggestion to task and add
                    let task = PlannerTask(
                        title: suggestion.title,
                        description: suggestion.description,
                        estimatedDuration: suggestion.estimatedDuration,
                        priority: suggestion.priority
                    )
                    plannerEngine.addTask(task)
                    showingSuggestions = false
                }
            )
        }
        .sheet(isPresented: $showingTaskDetails) {
            if let task = selectedTask {
                TaskDetailsView(
                    task: task,
                    isPresented: $showingTaskDetails,
                    onTaskUpdated: { updatedTask in
                        plannerEngine.updateTask(updatedTask)
                    },
                    onTaskCompleted: { rating, feedback in
                        plannerEngine.completeTask(task, rating: rating, feedback: feedback)
                    }
                )
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(
                selectedDate: $selectedDate,
                isPresented: $showingDatePicker
            )
        }
        .overlay {
            if isOptimizing {
                OptimizingOverlay(progress: optimizationProgress)
            }
        }
        .onAppear {
            // Initialize with today's plan
            Task {
                if plannerEngine.currentPlan == nil {
                    try? await plannerEngine.generateDailyPlan(for: selectedDate)
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plannerEngine.currentPlan?.dateFormatted ?? selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom("InstrumentSerif-Regular", size: 24))
                        .foregroundColor(Color(.label))

                    if let plan = plannerEngine.currentPlan {
                        HStack(spacing: 12) {
                            ProductivityScoreView(score: plan.productivityScore)
                            CompletionRateView(rate: plan.completionRate)
                            FocusTimeView(hours: plan.totalFocusTime / 3600)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.custom("Nunito", size: 14))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Button(action: {
                        Task {
                            await regeneratePlan()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Optimize")
                                .font(.custom("Nunito", size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(isOptimizing)
                }
            }

            // Quick Stats
            if let plan = plannerEngine.currentPlan {
                HStack(spacing: 20) {
                    StatCard(
                        title: "Tasks",
                        value: "\(plan.tasks.filter { !$0.isCompleted }.count)",
                        subtitle: "of \(plan.tasks.count) total",
                        color: .blue
                    )

                    StatCard(
                        title: "Focus Time",
                        value: "\(Int(plan.totalFocusTime / 3600))h",
                        subtitle: "planned",
                        color: .red
                    )

                    StatCard(
                        title: "Productivity",
                        value: "\(Int(plan.productivityScore * 100))%",
                        subtitle: "score",
                        color: .green
                    )

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - View Mode Selector

    private var viewModeSelector: View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlannerViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring()) {
                            viewMode = mode
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 16, weight: .medium))
                            Text(mode.displayName)
                                .font(.custom("Nunito", size: 12))
                        }
                        .foregroundColor(viewMode == mode ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewMode == mode ? Color.blue : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        Group {
            switch viewMode {
            case .timeline:
                TimelineView(
                    plan: plannerEngine.currentPlan,
                    selectedDate: $selectedDate,
                    draggedBlock: $draggedBlock,
                    onBlockTapped: handleBlockTapped,
                    onBlockDropped: handleBlockDropped
                )
            case .list:
                TaskListView(
                    tasks: plannerEngine.tasks,
                    selectedTask: $selectedTask,
                    onTaskTapped: { task in
                        selectedTask = task
                        showingTaskDetails = true
                    },
                    onTaskCompleted: { task in
                        plannerEngine.completeTask(task)
                    }
                )
            case .calendar:
                CalendarView(
                    selectedDate: $selectedDate,
                    currentPlan: plannerEngine.currentPlan,
                    onDateSelected: { date in
                        selectedDate = date
                        Task {
                            try? await plannerEngine.generateDailyPlan(for: date)
                        }
                    }
                )
            case .analytics:
                AnalyticsView(
                    plan: plannerEngine.currentPlan,
                    metrics: plannerEngine.optimizationMetrics
                )
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: View {
        HStack(spacing: 16) {
            Button(action: {
                showingTaskCreation = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Task")
                }
                .font(.custom("Nunito", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }

            Button(action: {
                showingSuggestions = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.circle")
                    Text("Suggestions")
                }
                .font(.custom("Nunito", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(8)
            }

            Spacer()

            if let plan = plannerEngine.currentPlan,
               !plan.timeBlocks.isEmpty {
                Button(action: {
                    Task {
                        try? await plannerEngine.exportToCalendar(plan: plan)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Export")
                    }
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Helper Methods

    private func handleBlockTapped(_ block: TimeBlock) {
        guard let taskID = block.taskID,
              let task = plannerEngine.tasks.first(where: { $0.id == taskID }) else { return }

        selectedTask = task
        showingTaskDetails = true

        // If this is a focus block, ask if user wants to start session
        if block.blockType == .focus && !task.isCompleted {
            // Could show a dialog to start focus session
        }
    }

    private func handleBlockDropped(_ block: TimeBlock, at newTime: Date) {
        guard let plan = plannerEngine.currentPlan,
              let index = plan.timeBlocks.firstIndex(where: { $0.id == block.id }) else { return }

        var updatedBlock = block
        let duration = block.duration
        updatedBlock.startTime = newTime
        updatedBlock.endTime = newTime.addingTimeInterval(duration)

        // Check for conflicts
        let hasConflicts = plan.timeBlocks.contains { otherBlock in
            guard otherBlock.id != block.id else { return false }
            return updatedBlock.startTime < otherBlock.endTime && updatedBlock.endTime > otherBlock.startTime
        }

        if !hasConflicts {
            // Update the block in the plan
            var updatedPlan = plan
            updatedPlan.timeBlocks[index] = updatedBlock
            // In production, would update the plan in the engine

            withAnimation(.spring()) {
                // Update UI
            }
        }
    }

    private func regeneratePlan() async {
        isOptimizing = true

        do {
            let progress = Timer.publish(every: 0.1)
                .autoconnect()
                .sink { _ in
                    if optimizationProgress < 0.9 {
                        optimizationProgress += 0.1
                    }
                }

            try await plannerEngine.generateDailyPlan(for: selectedDate)
            optimizationProgress = 1.0

            // Delay to show completion
            try await Task.sleep(nanoseconds: 500_000_000)
            isOptimizing = false
            optimizationProgress = 0.0

        } catch {
            print("Failed to regenerate plan: \(error)")
            isOptimizing = false
            optimizationProgress = 0.0
        }
    }
}

// MARK: - Supporting Views

extension PlannerView.PlannerViewMode {
    var displayName: String {
        switch self {
        case .timeline: return "Timeline"
        case .list: return "List"
        case .calendar: return "Calendar"
        case .analytics: return "Analytics"
        }
    }

    var iconName: String {
        switch self {
        case .timeline: return "timeline.selection"
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        case .analytics: return "chart.bar"
        }
    }
}

struct ProductivityScoreView: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(scoreColor)
                .font(.system(size: 12))

            Text("\(Int(score * 100))")
                .font(.custom("Nunito", size: 12))
                .fontWeight(.medium)
                .foregroundColor(scoreColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(scoreColor.opacity(0.1))
        .cornerRadius(6)

        private var scoreColor: Color {
            if score >= 0.8 { return .green }
            if score >= 0.6 { return .blue }
            if score >= 0.4 { return .orange }
            return .red
        }
    }
}

struct CompletionRateView: View {
    let rate: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
                .font(.system(size: 12))

            Text("\(Int(rate * 100))%")
                .font(.custom("Nunito", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
}

struct FocusTimeView: View {
    let hours: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .foregroundColor(.red)
                .font(.system(size: 12))

            Text("\(String(format: "%.1f", hours))h")
                .font(.custom("Nunito", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.secondary)

            Text(value)
                .font(.custom("Nunito", size: 16))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.custom("Nunito", size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct OptimizingOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)

                Text("Optimizing Your Schedule")
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.white)

                Text("\(Int(progress * 100))%")
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .cornerRadius(16)
        }
    }
}

// MARK: - Task Creation View

struct TaskCreationView: View {
    @Binding var isPresented: Bool
    let onTaskCreated: (PlannerTask) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var estimatedDuration: Double = 3600 // 1 hour
    @State private var priority: PlannerPriority = .medium
    @State private var deadline: Date?
    @State private var isFocusProtected = false
    @State private var selectedEnergyLevel: PlannerEnergyLevel?

    var body: some View {
        NavigationView {
            Form {
                Section(header: "Task Details") {
                    TextField("Title", text: $title)
                        .font(.custom("Nunito", size: 16))

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .font(.custom("Nunito", size: 14))
                        .lineLimit(3...6)
                }

                Section(header: "Timing") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("Duration", selection: $estimatedDuration) {
                            Text("15 min").tag(900)
                            Text("30 min").tag(1800)
                            Text("1 hour").tag(3600)
                            Text("2 hours").tag(7200)
                            Text("4 hours").tag(14400)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())

                    Toggle("Focus Session Protected", isOn: $isFocusProtected)
                }

                Section(header: "Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(PlannerPriority.low)
                        Text("Medium").tag(PlannerPriority.medium)
                        Text("High").tag(PlannerPriority.high)
                        Text("Critical").tag(PlannerPriority.critical)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: "Energy Level (Optional)") {
                    Picker("Energy Level", selection: $selectedEnergyLevel) {
                        Text("None").tag(nil as PlannerEnergyLevel?)
                        Text("Low").tag(PlannerEnergyLevel.low)
                        Text("Medium").tag(PlannerEnergyLevel.medium)
                        Text("High").tag(PlannerEnergyLevel.high)
                        Text("Peak").tag(PlannerEnergyLevel.peak)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    private func createTask() {
        let task = PlannerTask(
            title: title,
            description: description,
            estimatedDuration: estimatedDuration,
            priority: priority,
            deadline: deadline,
            isFocusSessionProtected: isFocusProtected,
            preferredEnergyLevel: selectedEnergyLevel
        )

        onTaskCreated(task)
        isPresented = false

        // Reset form
        title = ""
        description = ""
        estimatedDuration = 3600
        priority = .medium
        deadline = nil
        isFocusProtected = false
        selectedEnergyLevel = nil
    }
}

// MARK: - Date Picker View

struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()

            Spacer()

            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

#Preview {
    PlannerView()
}