//
//  FeatureFlagsSettingsView.swift
//  FocusLock
//
//  Settings view for managing FocusLock feature flags
//

import SwiftUI

struct FeatureFlagsSettingsView: View {
    @ObservedObject private var featureFlagManager: FeatureFlagManager
    @State private var selectedCategory: FeatureCategory = .core
    @State private var showRecommended = false
    @State private var searchTerm = ""

    private var filteredFeatures: [FeatureFlag] {
        let allFeatures = showRecommended ? featureFlagManager.getRecommendedFeatures() : FeatureFlag.allCases

        return allFeatures
            .filter { $0.category == selectedCategory }
            .filter { searchTerm.isEmpty || $0.displayName.lowercased().contains(searchTerm.lowercased()) }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FocusLock Features")
                        .font(.custom("InstrumentSerif-Regular", size: 28))
                        .foregroundColor(.black.opacity(0.9))

                    Spacer()

                    Button(action: { showRecommended.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text(showRecommended ? "All" : "Recommended")
                                .font(.custom("Nunito", size: 12))
                        }
                        .foregroundColor(showRecommended ? Color(red: 0.25, green: 0.17, blue: 0) : .black.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showRecommended ? Color(red: 0.25, green: 0.17, blue: 0).opacity(0.1) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("Manage FocusLock capabilities and personalize your experience")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }

            // Search and Categories
            VStack(alignment: .leading, spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black.opacity(0.4))
                        .font(.system(size: 14))

                    TextField("Search features...", text: $searchTerm)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.custom("Nunito", size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.6))
                .cornerRadius(8)

                // Category Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FeatureCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Text(category.displayName)
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedCategory == category ? .white : .black.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Feature Cards
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(filteredFeatures, id: \.self) { feature in
                        FeatureFlagCard(flag: feature)
                            .environmentObject(featureFlagManager)
                            .onTapGesture {
                                featureFlagManager.recordFeatureUsage(feature, action: .viewed)
                            }
                    }
                }
                .padding(.trailing, 4)
            }

            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Enhanced Views (these would be implemented as separate files)

struct EnhancedDashboardView: View {
    @ObservedObject private var featureFlagManager: FeatureFlagManager
    @State private var selectedTab: DashboardTab = .overview

    enum DashboardTab: String, CaseIterable {
        case overview = "overview"
        case productivity = "productivity"
        case analytics = "analytics"
        case insights = "insights"

        var displayName: String {
            switch self {
            case .overview: return "Overview"
            case .productivity: return "Productivity"
            case .analytics: return "Analytics"
            case .insights: return "Insights"
            }
        }

        var icon: String {
            switch self {
            case .overview: return "chart.pie.fill"
            case .productivity: return "target"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .insights: return "lightbulb"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Dashboard Header
            VStack(spacing: 16) {
                HStack {
                    Text("Enhanced Dashboard")
                        .font(.custom("InstrumentSerif-Regular", size: 24))
                        .foregroundColor(.black.opacity(0.9))

                    Spacer()

                    // Tab Navigation
                    HStack(spacing: 1) {
                        ForEach(DashboardTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 14))
                                    Text(tab.displayName)
                                        .font(.custom("Nunito", size: 13))
                                }
                                .foregroundColor(selectedTab == tab ? .white : .black.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Tab-specific content
                dashboardTabContent
            }
            .padding(20)
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)

            // Main content area would go here
            Spacer()
        }
    }

    @ViewBuilder
    private var dashboardTabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .productivity:
            productivityContent
        case .analytics:
            analyticsContent
        case .insights:
            insightsContent
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Overview")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            Text("Enhanced insights powered by AI analysis")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.5))
        }
    }

    @ViewBuilder
    private var productivityContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Metrics")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            if featureFlagManager.isEnabled(.suggestedTodos) {
                SuggestedTodosPreview()
            }

            if featureFlagManager.isEnabled(.planner) {
                PlannerPreview()
            }
        }
    }

    @ViewBuilder
    private var analyticsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced Analytics")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            if featureFlagManager.isEnabled(.performanceAnalytics) {
                PerformanceAnalyticsPreview()
            }
        }
    }

    @ViewBuilder
    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            if featureFlagManager.isEnabled(.dataInsights) {
                DataInsightsPreview()
            }
        }
    }
}

struct DailyJournalView: View {
    @ObservedObject private var featureFlagManager: FeatureFlagManager
    @State private var journalEntry: String = ""
    @State private var selectedMood: JournalMood = .neutral
    @State private var journalEntries: [JournalEntry] = []

    enum JournalMood: String, CaseIterable, Codable {
        case productive = "productive"
        case focused = "focused"
        case tired = "tired"
        case stressed = "stressed"
        case creative = "creative"
        case neutral = "neutral"

        var emoji: String {
            switch self {
            case .productive: return "🚀"
            case .focused: return "🎯"
            case .tired: return "😴"
            case .stressed: return "😰"
            case .creative: return "💡"
            case .neutral: return "😐"
            }
        }

        var color: String {
            switch self {
            case .productive: return "52C41A"
            case .focused: return "007AFF"
            case .tired: return "FF9500"
            case .stressed: return "FF3B30"
            case .creative: return "AF52DE"
            case .neutral: return "8E8E93"
            }
        }
    }

    struct JournalEntry: Identifiable, Codable {
        let id: UUID
        let date: Date
        let content: String
        let mood: JournalMood
        let tags: [String]

        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Daily Journal")
                    .font(.custom("InstrumentSerif-Regular", size: 24))
                    .foregroundColor(.black.opacity(0.9))

                Spacer()

                Button(action: { saveJournalEntry() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Save")
                            .font(.custom("Nunito", size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(journalEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Mood Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("How are you feeling?")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))

                HStack(spacing: 12) {
                    ForEach(JournalMood.allCases, id: \.self) { mood in
                        Button(action: { selectedMood = mood }) {
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.system(size: 24))
                                Text(mood.rawValue.capitalized)
                                    .font(.custom("Nunito", size: 10))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedMood == mood ? Color(hex: mood.color).opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedMood == mood ? Color(hex: mood.color) : Color.clear, lineWidth: selectedMood == mood ? 2 : 0)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Journal Entry
            VStack(alignment: .leading, spacing: 8) {
                Text("What's on your mind?")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.7))

                TextEditor(text: $journalEntry)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.8))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )
            }

            // Previous Entries
            if !journalEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Previous Entries")
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.7))

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(journalEntries.sorted(by: { $0.date > $1.date }), id: \.id) { entry in
                                JournalEntryCard(entry: entry)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(maxHeight: 200)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }

    private func saveJournalEntry() {
        let trimmedEntry = journalEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEntry.isEmpty else { return }

        let entry = JournalEntry(
            id: UUID(),
            date: Date(),
            content: trimmedEntry,
            mood: selectedMood,
            tags: extractTags(from: trimmedEntry)
        )

        journalEntries.insert(entry, at: 0)
        journalEntry = ""
        selectedMood = .neutral

        // Track usage
        featureFlagManager.recordFeatureUsage(.dailyJournal, action: .interacted)
    }

    private func extractTags(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { $0.hasPrefix("#") }.map { String($0.dropFirst()) }
    }
}

struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.mood.emoji)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.formattedDate)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.6))

                    Text(entry.mood.rawValue.capitalized)
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(Color(hex: entry.mood.color))
                }

                Spacer()
            }

            Text(entry.content)
                .font(.custom("Nunito", size: 13))
                .foregroundColor(.black.opacity(0.7))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if !entry.tags.isEmpty {
                HStack {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.custom("Nunito", size: 10))
                            .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.25, green: 0.17, blue: 0).opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

// MARK: - Feature Onboarding View

struct FeatureOnboardingFlowView: View {
    let feature: FeatureFlag
    let onComplete: () -> Void
    @State private var currentStep: Int = 0
    @State private var isCompleted = false

    private var steps: [OnboardingStep] {
        switch feature {
        case .suggestedTodos:
            return [
                OnboardingStep(
                    title: "Welcome to Suggested Todos",
                    description: "AI-powered task suggestions based on your activity patterns",
                    icon: "checklist",
                    content: "Learn how the system analyzes your timeline to suggest relevant tasks"
                ),
                OnboardingStep(
                    title: "Smart Suggestions",
                    description: "Context-aware recommendations that fit your workflow",
                    icon: "brain",
                    content: "Get personalized suggestions based on your recent activities and patterns"
                ),
                OnboardingStep(
                    title: "Integration",
                    description: "Seamlessly integrate with your existing workflow",
                    icon: "link",
                    content: "Suggestions appear right where you need them in your timeline"
                )
            ]
        case .planner:
            return [
                OnboardingStep(
                    title: "Smart Planning",
                    description: "Intelligent planning tools with timeline integration",
                    icon: "calendar.badge.clock",
                    content: "Plan your day with AI-powered insights and recommendations"
                ),
                OnboardingStep(
                    title: "Timeline Integration",
                    description: "Your plans connect directly with your activity timeline",
                    icon: "link",
                    content: "See how your plans align with actual time spent"
                ),
                OnboardingStep(
                    title: "Progress Tracking",
                    description: "Monitor your planning effectiveness",
                    icon: "chart.bar",
                    content: "Track completed plans and improve your planning over time"
                )
            ]
        case .dailyJournal:
            return [
                OnboardingStep(
                    title: "Daily Reflection",
                    description: "Automated journaling with mood and productivity tracking",
                    icon: "book.closed",
                    content: "Capture your thoughts and feelings throughout the day"
                ),
                OnboardingStep(
                    title: "Mood Tracking",
                    description: "Track your emotional state alongside productivity",
                    icon: "heart",
                    content: "Understand patterns in your mood and performance"
                ),
                OnboardingStep(
                    title: "Personal Growth",
                    description: "Build a record of your personal and professional journey",
                    icon: "growth_chart",
                    content: "Look back on your progress and growth over time"
                )
            ]
        case .enhancedDashboard:
            return [
                OnboardingStep(
                    title: "Enhanced Insights",
                    description: "Advanced analytics and insights dashboard",
                    icon: "chart.bar.doc.horizontal",
                    content: "Get deeper insights into your productivity patterns"
                ),
                OnboardingStep(
                    title: "Data Visualization",
                    description: "Beautiful charts and visual representations",
                    icon: "chart.pie.fill",
                    content: "Understand your data at a glance with interactive visualizations"
                ),
                OnboardingStep(
                    title: "Actionable Insights",
                    description: "Turn data into actionable improvements",
                    icon: "lightbulb",
                    content: "Get specific recommendations to enhance your productivity"
                )
            ]
        case .jarvisChat:
            return [
                OnboardingStep(
                    title: "Meet Jarvis",
                    description: "Your AI productivity assistant",
                    icon: "brain.head.profile",
                    content: "Get personalized guidance and support for your productivity journey"
                ),
                OnboardingStep(
                    title: "Smart Conversations",
                    description: "Context-aware assistance based on your data",
                    icon: "message",
                    content: "Jarvis understands your work patterns and provides relevant help"
                ),
                OnboardingStep(
                    title: "Continuous Learning",
                    description: "Gets smarter as it learns from you",
                    icon: "graduationcap",
                    content: "Your assistant improves over time with personalized insights"
                )
            ]
        default:
            return [
                OnboardingStep(
                    title: "New Feature",
                    description: "Discover a new way to enhance your productivity",
                    icon: feature.icon,
                    content: feature.description
                )
            ]
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))

                Text(steps[currentStep].title)
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(.black.opacity(0.9))

                Text(steps[currentStep].description)
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Content
            Text(steps[currentStep].content)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Progress Indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Navigation
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Previous") {
                        currentStep -= 1
                    }
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        currentStep += 1
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button("Get Started") {
                        isCompleted = true
                        onComplete()
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(32)
        .frame(width: 500, height: 400)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let content: String
}

// MARK: - Preview Components

struct SuggestedTodosPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested for Today")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            VStack(spacing: 8) {
                SuggestedTodoItem(title: "Review code changes from yesterday", priority: .high)
                SuggestedTodoItem(title: "Prepare presentation slides", priority: .medium)
                SuggestedTodoItem(title: "Answer team emails", priority: .low)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct PlannerPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Plan")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            VStack(spacing: 8) {
                PlannerItem(title: "Morning: Code Review", time: "9:00 AM - 11:00 AM", status: .completed)
                PlannerItem(title: "Afternoon: Client Meeting", time: "2:00 PM - 3:00 PM", status: .inProgress)
                PlannerItem(title: "Evening: Documentation", time: "4:00 PM - 5:00 PM", status: .pending)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct PerformanceAnalyticsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            // Simple chart placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 100)
                .cornerRadius(4)
                .overlay(
                    Text("Performance Chart")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.5))
                )
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct DataInsightsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))

            VStack(spacing: 8) {
                InsightCard(
                    title: "Peak Productivity",
                    insight: "You're most productive between 10 AM - 12 PM",
                    confidence: 0.85
                )
                InsightCard(
                    title: "Focus Pattern",
                    insight: "Music helps you stay focused longer",
                    confidence: 0.72
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(8)
    }
}

struct SuggestedTodoItem: View {
    let title: String
    let priority: Priority

    enum Priority: String {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var color: String {
            switch self {
            case .high: return "FF3B30"
            case .medium: return "FF9500"
            case .low: return "52C41A"
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: priority.color))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.7))

            Spacer()

            Text(priority.rawValue.uppercased())
                .font(.custom("Nunito", size: 10))
                .fontWeight(.medium)
                .foregroundColor(Color(hex: priority.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: priority.color).opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.4))
        .cornerRadius(6)
    }
}

struct PlannerItem: View {
    let title: String
    let time: String
    let status: Status

    enum Status: String {
        case completed = "completed"
        case inProgress = "in_progress"
        case pending = "pending"

        var color: String {
            switch self {
            case .completed: return "34C759"
            case .inProgress: return "007AFF"
            case .pending: return "8E8E93"
            }
        }

        var displayName: String {
            switch self {
            case .completed: return "Completed"
            case .inProgress: return "In Progress"
            case .pending: return "Pending"
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: status.color))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(1)

                Text(time)
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.black.opacity(0.5))
            }

            Spacer()

            Text(status.displayName)
                .font(.custom("Nunito", size: 10))
                .fontWeight(.medium)
                .foregroundColor(Color(hex: status.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: status.color).opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.4))
        .cornerRadius(6)
    }
}

struct InsightCard: View {
    let title: String
    let insight: String
    let confidence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.custom("Nunito", size: 12))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.7))

                Spacer()

                Text("\(Int(confidence * 100))%")
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.black.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(insight)
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.6))
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.4))
        .cornerRadius(6)
    }
}