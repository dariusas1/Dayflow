//
//  TimelineView.swift
//  FocusLock
//
//  Visual timeline with drag-and-drop time blocks
//  and interactive scheduling
//

import SwiftUI
import Foundation

struct TimelineView: View {
    let plan: DailyPlan?
    @Binding var selectedDate: Date
    @Binding var draggedBlock: TimeBlock?
    let onBlockTapped: (TimeBlock) -> Void
    let onBlockDropped: (TimeBlock, Date) -> Void

    @State private var currentTime: Date = Date()
    @State private var draggedOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var zoomLevel: Double = 1.0
    @State private var scrollOffset: CGFloat = 0

    private let hourHeight: CGFloat = 80
    private let timelineWidth: CGFloat = 60
    private let contentWidth: CGFloat = 800

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Timeline header
                    timelineHeader

                    // Time blocks
                    timeBlocksContent
                }
                .frame(minHeight: calculateTotalHeight(for: plan))
                .background(Color(.systemBackground))
            }
            .coordinateSpace(name: "timeline")
            .onReceive(Timer.publish(every: 1).autoconnect().compactMap { _ in Date() }) { newTime in
                currentTime = newTime
            }
        }
        .overlay(alignment: .topLeading) {
            // Current time indicator
            if plan?.date.isToday == true {
                currentTimeIndicator
            }
        }
    }

    // MARK: - Timeline Header

    private var timelineHeader: some View {
        HStack(spacing: 0) {
            // Time labels column
            VStack(spacing: 0) {
                ForEach(8...20, id: \.self) { hour in
                    HStack {
                        Text(String(format: "%02d:00", hour))
                            .font(.custom("Nunito", size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: timelineWidth)

                        Spacer()
                    }
                    .frame(height: hourHeight)
                }
            }

            // Content header
            HStack {
                Text("Schedule")
                    .font(.custom("InstrumentSerif-Regular", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: { zoomLevel = max(0.5, zoomLevel - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(zoomLevel <= 0.5)

                    Text("\(Int(zoomLevel * 100))%")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 40)

                    Button(action: { zoomLevel = min(2.0, zoomLevel + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(zoomLevel >= 2.0)
                }
                .padding(.horizontal)
            }
            .frame(height: hourHeight)
            .padding(.horizontal)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Time Blocks Content

    private var timeBlocksContent: some View {
        ZStack(alignment: .topLeading) {
            // Hour grid lines
            hourGridLines

            // Current time line
            if plan?.date.isToday == true {
                currentTimeLine
            }

            // Time blocks
            if let plan = plan {
                ForEach(plan.timeBlocks, id: \.id) { block in
                    TimelineBlockView(
                        block: block,
                        tasks: plan.tasks,
                        hourHeight: hourHeight,
                        timelineWidth: timelineWidth,
                        zoomLevel: zoomLevel,
                        isDragging: draggedBlock?.id == block.id,
                        draggedOffset: draggedBlock?.id == block.id ? draggedOffset : .zero,
                        onTap: { onBlockTapped(block) },
                        onDragStart: {
                            draggedBlock = block
                            isDragging = true
                        },
                        onDragChanged: { offset in
                            draggedOffset = offset
                        },
                        onDragEnd: { offset in
                            let newTime = calculateTimeForOffset(offset, from: block.startTime)
                            onBlockDropped(block, at: newTime)
                            draggedBlock = nil
                            isDragging = false
                            draggedOffset = .zero
                        }
                    )
                }
            }
        }
        .frame(minHeight: calculateTotalHeight(for: plan))
    }

    // MARK: - Helper Views

    private var hourGridLines: some View {
        VStack(spacing: 0) {
            ForEach(8...20, id: \.self) { _ in
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var currentTimeLine: View {
        let currentHour = Calendar.current.component(.hour, from: currentTime)
        let currentMinute = Calendar.current.component(.minute, from: currentTime)
        let yOffset = calculateYOffset(for: currentHour, minute: currentMinute)

        return HStack {
            Rectangle()
                .fill(Color.red)
                .frame(width: 4)
                .frame(height: 1)

            Rectangle()
                .fill(Color.red.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
        .offset(y: yOffset)
        .zIndex(1000)
    }

    private var currentTimeIndicator: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red.opacity(0.3), radius: 4)

            Text("Now")
                .font(.custom("Nunito", size: 10))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .cornerRadius(4)
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }

    // MARK: - Helper Methods

    private func calculateTotalHeight(for plan: DailyPlan?) -> CGFloat {
        guard let plan = plan else { return 13 * hourHeight }

        let endHour = plan.timeBlocks
            .map { Calendar.current.component(.hour, from: $0.endTime) }
            .max() ?? 20

        return CGFloat(max(endHour, 20) - 8) * hourHeight + 100 // Extra padding
    }

    private func calculateYOffset(for hour: Int, minute: Int = 0) -> CGFloat {
        let adjustedHour = hour - 8
        let minuteOffset = CGFloat(minute) / 60.0 * hourHeight
        return CGFloat(adjustedHour) * hourHeight + minuteOffset
    }

    private func calculateTimeForOffset(_ offset: CGSize, from originalTime: Date) -> Date {
        let minutesMoved = (offset.height / (hourHeight * zoomLevel)) * 60
        return originalTime.addingTimeInterval(TimeInterval(minutesMoved * 60))
    }
}

// MARK: - Timeline Block View

struct TimelineBlockView: View {
    let block: TimeBlock
    let tasks: [PlannerTask]
    let hourHeight: CGFloat
    let timelineWidth: CGFloat
    let zoomLevel: Double
    let isDragging: Bool
    let draggedOffset: CGSize
    let onTap: () -> Void
    let onDragStart: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnd: (CGSize) -> Void

    @State private var isHovered = false

    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: block.startTime)
        let startMinute = calendar.component(.minute, from: block.startTime)
        return calculateYOffset(for: startHour, minute: startMinute)
    }

    private var blockHeight: CGFloat {
        return CGFloat(block.duration / 3600) * hourHeight * zoomLevel
    }

    private var blockWidth: CGFloat {
        return 800 - timelineWidth - 40 // Account for padding
    }

    private var task: PlannerTask? {
        guard let taskID = block.taskID else { return nil }
        return tasks.first { $0.id == taskID }
    }

    var body: some View {
        Group {
            // Main block
            RoundedRectangle(cornerRadius: 8)
                .fill(blockColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(blockColor.opacity(0.3), lineWidth: isDragging ? 2 : 1)
                )
                .frame(width: blockWidth, height: blockHeight)
                .offset(x: timelineWidth + 20, y: yOffset)
                .offset(draggedOffset)
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .shadow(color: .black.opacity(isDragging ? 0.3 : 0.1), radius: isDragging ? 8 : 4)
                .onTapGesture {
                    onTap()
                }
                .onLongPressGesture {
                    onDragStart()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            onDragChanged(value.translation)
                        }
                        .onEnded { value in
                            onDragEnd(value.translation)
                        }
                )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let task = task {
                        // Priority indicator
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 6, height: 6)
                    }

                    Text(blockTitle)
                        .font(.custom("Nunito", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    if block.isProtected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                if let task = task {
                    Text(task.description)
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: blockWidth - 60, alignment: .leading)
                }

                // Time info
                HStack {
                    Text(block.startTime.formatted(date: .omitted))
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.white.opacity(0.8))

                    Text("•")
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.white.opacity(0.6))

                    Text(block.endTime.formatted(date: .omitted))
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text(block.durationFormatted)
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
            .offset(x: timelineWidth + 20, y: yOffset)
            .offset(draggedOffset)
            .scaleEffect(isDragging ? 1.05 : 1.0)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8).offset(x: timelineWidth + 20, y: yOffset))
    }

    private var blockTitle: String {
        if !block.title.isEmpty {
            return block.title
        } else if let task = task {
            return task.title
        } else {
            return "Block"
        }
    }

    private var blockColor: Color {
        if isDragging {
            return blockTypeColor.opacity(0.8)
        }
        return blockTypeColor
    }

    private var blockTypeColor: Color {
        switch block.blockType {
        case .task:
            return .blue
        case .focus:
            return .red
        case .break:
            return .green
        case .buffer:
            return .gray
        case .meeting:
            return .purple
        case .deepWork:
            return .orange
        }
    }

    private var priorityColor: Color {
        guard let task = task else { return .gray }
        switch task.priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func calculateYOffset(for hour: Int, minute: Int) -> CGFloat {
        let adjustedHour = hour - 8
        let minuteOffset = CGFloat(minute) / 60.0 * hourHeight
        return CGFloat(adjustedHour) * hourHeight + minuteOffset
    }
}

// MARK: - Supporting Views

extension TimeBlock {
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: endTime)
    }
}

// MARK: - Task List View

struct TaskListView: View {
    let tasks: [PlannerTask]
    @Binding var selectedTask: PlannerTask?
    let onTaskTapped: (PlannerTask) -> Void
    let onTaskCompleted: (PlannerTask) -> Void

    var body: some View {
        List {
            ForEach(tasks.filter { !$0.isCompleted }, id: \.id) { task in
                TaskRowView(
                    task: task,
                    isSelected: selectedTask?.id == task.id,
                    onTap: { onTaskTapped(task) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Complete") {
                        onTaskCompleted(task)
                    }
                    .tint(.green)
                }
            }

            Section("Completed") {
                ForEach(tasks.filter { $0.isCompleted }, id: \.id) { task in
                    TaskRowView(
                        task: task,
                        isCompleted: true,
                        onTap: { onTaskTapped(task) }
                    )
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct TaskRowView: View {
    let task: PlannerTask
    let isSelected: Bool
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(isCompleted ? .regular : .medium)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(task.durationFormatted)
                        .font(.custom("Nunito", size: 11))
                        .foregroundColor(.secondary)

                    if task.isFocusSessionProtected {
                        Label("Focus", systemImage: "target")
                            .font(.custom("Nunito", size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }

                    if let deadline = task.deadline {
                        Label(deadline.formatted(date: .abbreviated), systemImage: "clock")
                            .font(.custom("Nunito", size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.isOverdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                            .foregroundColor(task.isOverdue ? .red : .blue)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @Binding var selectedDate: Date
    let currentPlan: DailyPlan?
    let onDateSelected: (Date) -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .onChange(of: selectedDate) { newDate in
                        onDateSelected(newDate)
                    }

                if let plan = currentPlan {
                    Divider()

                    Text("Tasks for \(selectedDate.formatted(date: .full))")
                        .font(.custom("InstrumentSerif-Regular", size: 18))
                        .padding()

                    LazyVStack(spacing: 8) {
                        ForEach(plan.tasks, id: \.id) { task in
                            CalendarTaskRow(task: task)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct CalendarTaskRow: View {
    let task: PlannerTask

    var body: some View {
        HStack {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(task.durationFormatted)
                        .font(.custom("Nunito", size: 11))
                        .foregroundColor(.secondary)

                    if task.isFocusSessionProtected {
                        Label("Focus", systemImage: "target")
                            .font(.custom("Nunito", size: 9))
                    }
                }
            }

            Spacer()

            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    let plan: DailyPlan?
    let metrics: PlanningMetrics

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let plan = plan {
                    // Productivity Score
                    AnalyticsMetricCard(
                        title: "Productivity Score",
                        value: Int(plan.productivityScore * 100),
                        unit: "%",
                        color: scoreColor(plan.productivityScore)
                    )

                    // Completion Rate
                    AnalyticsMetricCard(
                        title: "Completion Rate",
                        value: Int(plan.completionRate * 100),
                        unit: "%",
                        color: scoreColor(plan.completionRate)
                    )

                    // Time Distribution
                    TimeDistributionChart(plan: plan)
                }

                if metrics.tasksScheduled > 0 {
                    HStack {
                        AnalyticsMetricCard(
                            title: "Tasks Scheduled",
                            value: metrics.tasksScheduled,
                            unit: "",
                            color: .blue
                        )

                        AnalyticsMetricCard(
                            title: "Focus Time",
                            value: Int(metrics.focusTimeHours),
                            unit: "hrs",
                            color: .red
                        )

                        AnalyticsMetricCard(
                            title: "Break Time",
                            value: Int(metrics.breakTimeHours),
                            unit: "hrs",
                            color: .green
                        )
                    }
                }
            }
        }
        .padding()
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .blue }
        if score >= 0.4 { return .orange }
        return .red
    }
}

struct AnalyticsMetricCard: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(unit)
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TimeDistributionChart: View {
    let plan: DailyPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Distribution")
                .font(.custom("InstrumentSerif-Regular", size: 18))
                .fontWeight(.medium)

            HStack(alignment: .bottom, spacing: 16) {
                // Focus Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.secondary)

                    Text("\(Int(plan.totalFocusTime / 60)) min")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }

                Rectangle()
                    .fill(Color.red)
                    .frame(height: 20)
                    .frame(width: calculateBarWidth(plan.totalFocusTime, total: plan.totalScheduledTime))

                // Regular Tasks
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasks")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.secondary)

                    Text("\(Int((plan.totalScheduledTime - plan.totalFocusTime - plan.totalBreakTime) / 60)) min")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }

                Rectangle()
                    .fill(Color.blue)
                    .frame(height: 20)
                    .frame(width: calculateBarWidth(plan.totalScheduledTime - plan.totalFocusTime - plan.totalBreakTime, total: plan.totalScheduledTime))

                // Breaks
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breaks")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.secondary)

                    Text("\(Int(plan.totalBreakTime / 60)) min")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }

                Rectangle()
                    .fill(Color.green)
                    .frame(height: 20)
                    .frame(width: calculateBarWidth(plan.totalBreakTime, total: plan.totalScheduledTime))
            }

            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func calculateBarWidth(_ duration: TimeInterval, total: TimeInterval) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(duration / total) * 200
    }
}

// MARK: - Task Suggestions View

struct TaskSuggestionsView: View {
    let suggestions: [TaskSuggestion]
    let onTaskSelected: (TaskSuggestion) -> Void

    var body: some View {
        NavigationView {
            List(suggestions, id: \.title) { suggestion in
                TaskSuggestionRow(
                    suggestion: suggestion,
                    onSelect: {
                        onTaskSelected(suggestion)
                    }
                )
            }
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct TaskSuggestionRow: View {
    let suggestion: TaskSuggestion
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)

                Text(suggestion.description)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(suggestion.durationFormatted)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.secondary)

                Text("\(Int(suggestion.confidence * 100))%")
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Task Details View

struct TaskDetailsView: View {
    let task: PlannerTask
    @Binding var isPresented: Bool
    let onTaskUpdated: (PlannerTask) -> Void
    let onTaskCompleted: (Int, String) -> Void

    @State private var rating: Int = 5
    @State private var feedback: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    Text(task.title)
                        .font(.custom("InstrumentSerif-Regular", size: 18))
                        .fontWeight(.bold)

                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Timing") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(task.durationFormatted)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Priority")
                        Spacer()
                        Text(task.priority.rawValue.capitalized)
                            .foregroundColor(priorityColor)
                    }

                    if task.isFocusSessionProtected {
                        HStack {
                            Text("Focus Session")
                            Spacer()
                            Text("Protected")
                                .foregroundColor(.red)
                        }
                    }
                }

                Section("Scheduling") {
                    if let scheduledStart = task.scheduledStartTime {
                        HStack {
                            Text("Scheduled Start")
                            Spacer()
                            Text(scheduledStart.formatted(date: .short))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let scheduledEnd = task.scheduledEndTime {
                        HStack {
                            Text("Scheduled End")
                            Spacer()
                            Text(scheduledEnd.formatted(date: .short))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let deadline = task.deadline {
                        HStack {
                            Text("Deadline")
                            Spacer()
                            Text(deadline.formatted(date: .short))
                                .foregroundColor(deadline < Date() ? .red : .primary)
                        }
                    }

                    if let preferredEnergy = task.preferredEnergyLevel {
                        HStack {
                            Text("Preferred Energy")
                            Spacer()
                            Text(preferredEnergy.rawValue.capitalized)
                                .foregroundColor(energyColor)
                        }
                    }
                }

                Section("Feedback") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How well did this task go?")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.medium)

                        HStack {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: {
                                    self.rating = rating
                                }) {
                                    Image(systemName: rating <= self.rating ? "star.fill" : "star")
                                        .foregroundColor(rating <= self.rating ? .yellow : .gray)
                                }
                            }
                        }

                        TextField("Add feedback (optional)", text: $feedback, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.custom("Nunito", size: 14))
                            .lineLimit(3...6)
                    }
                }

                Section {
                    Button("Complete Task") {
                        onTaskCompleted(rating, feedback)
                        isPresented = false
                    }
                    .disabled(task.isCompleted)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // In production, would update task with any changes
                        isPresented = false
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private var energyColor: Color {
        switch task.preferredEnergyLevel {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .peak: return .red
        case .none: return .secondary
        }
    }
}

#Preview {
    TimelineView(
        plan: nil,
        selectedDate: .constant(Date()),
        draggedBlock: .constant(nil),
        onBlockTapped: { _ in },
        onBlockDropped: { _, _ in }
    )
}