//
//  SuggestedTodosView.swift
//  FocusLock
//
//  User interface for displaying and managing AI-suggested tasks
//

import SwiftUI

struct SuggestedTodosView: View {
    @StateObject private var suggestionEngine = SuggestedTodosEngine.shared
    @State private var selectedFilter: SuggestionFilter = .all
    @State private var searchText = ""
    @State private var showingDetail = false
    @State private var selectedSuggestion: SuggestedTodo?
    @State private var isLoading = false

    // Computed properties for filtered suggestions
    private var filteredSuggestions: [SuggestedTodo] {
        var suggestions = suggestionEngine.currentSuggestions

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .highPriority:
            suggestions = suggestions.filter { $0.priority == .high }
        case .mediumPriority:
            suggestions = suggestions.filter { $0.priority == .medium }
        case .lowPriority:
            suggestions = suggestions.filter { $0.priority == .low }
        case .work:
            suggestions = suggestions.filter { $0.suggestedAction.type == .work }
        case .personal:
            suggestions = suggestions.filter { $0.suggestedAction.type == .personal }
        case .communication:
            suggestions = suggestions.filter { $0.suggestedAction.type == .productivity || $0.contextTags.contains("communication") }
        case .quick:
            suggestions = suggestions.filter { ($0.estimatedDuration ?? 600) < 300 } // Less than 5 minutes
        }

        // Apply search
        if !searchText.isEmpty {
            suggestions = suggestions.filter { suggestion in
                suggestion.title.localizedCaseInsensitiveContains(searchText) ||
                suggestion.description.localizedCaseInsensitiveContains(searchText) ||
                suggestion.suggestedAction.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        return suggestions.sorted { ($0.urgencyScore * 0.5 + $0.relevanceScore * 0.5) > ($1.urgencyScore * 0.5 + $1.relevanceScore * 0.5) }
    }

    var body: some View {
        FlowingGradientBackground()
            .overlay(
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Filters and Search
                    filterSearchView

                    // Content
                    if isLoading {
                        loadingView
                    } else if filteredSuggestions.isEmpty {
                        emptyStateView
                    } else {
                        suggestionsListView
                    }
                }
                .padding(DesignSpacing.lg)
            )
            .sheet(isPresented: $showingDetail) {
                if let suggestion = selectedSuggestion {
                    SuggestionDetailView(suggestion: suggestion)
                }
            }
            .onAppear {
                loadSuggestions()
            }
    }

    private var headerView: some View {
        VStack(spacing: DesignSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text("Suggested Tasks")
                        .font(.custom(DesignTypography.headingFont, size: DesignTypography.title1))
                        .foregroundColor(DesignColors.primaryText)

                    Text("AI-powered task suggestions based on your activity")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                        .foregroundColor(DesignColors.secondaryText)
                }

                Spacer()

                Button(action: {
                    loadSuggestions()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("Refresh")
                            .font(.custom("Nunito", size: 14))
                    }
                    .foregroundColor(Color(hex: "FF6B35"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Quick stats with glassmorphism cards
            HStack(spacing: DesignSpacing.md) {
                UnifiedMetricCard(
                    title: "Total Tasks",
                    value: "\(suggestionEngine.currentSuggestions.count)",
                    icon: "list.bullet",
                    style: .standard
                )

                UnifiedMetricCard(
                    title: "High Priority",
                    value: "\(suggestionEngine.currentSuggestions.filter { $0.priority == .high }.count)",
                    icon: "exclamationmark.triangle.fill",
                    style: .elevated
                )

                UnifiedMetricCard(
                    title: "Quick Tasks",
                    value: "\(suggestionEngine.currentSuggestions.filter { ($0.estimatedDuration ?? 600) < 300 }.count)",
                    icon: "bolt.fill",
                    style: .standard
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
    }

    private var filterSearchView: some View {
        VStack(spacing: DesignSpacing.md) {
            // Search bar using UnifiedInput
            UnifiedTextField(
                "Search suggestions...",
                text: $searchText,
                style: .search
            )

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSpacing.sm) {
                    ForEach(SuggestionFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            count: countForFilter(filter)
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, DesignSpacing.md)
            }
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.bottom, DesignSpacing.md)
    }

    private var loadingView: some View {
        VStack(spacing: DesignSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignColors.primaryOrange)

            Text("Analyzing your activity...")
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                .foregroundColor(DesignColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSpacing.xl) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(DesignColors.tertiaryText)

            VStack(spacing: DesignSpacing.sm) {
                Text("No suggestions yet")
                    .font(.custom(DesignTypography.headingFont, size: DesignTypography.title3))
                    .foregroundColor(DesignColors.primaryText)

                Text("Start using your apps and we'll suggest tasks based on your activity")
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(DesignColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSpacing.lg)
            }

            UnifiedButton.primary(
                "Refresh Suggestions",
                size: .medium,
                action: {
                    loadSuggestions()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSpacing.xl)
    }

    private var suggestionsListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSpacing.md) {
                ForEach(filteredSuggestions, id: \.id) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        onTap: {
                            selectedSuggestion = suggestion
                            showingDetail = true
                        },
                        onAccept: {
                            acceptSuggestion(suggestion)
                        },
                        onDismiss: {
                            dismissSuggestion(suggestion)
                        },
                        onSnooze: {
                            snoozeSuggestion(suggestion)
                        }
                    )
                }
            }
            .padding(DesignSpacing.md)
        }
    }

    // MARK: - Helper Methods

    private func countForFilter(_ filter: SuggestionFilter) -> Int {
        switch filter {
        case .all:
            return suggestionEngine.currentSuggestions.count
        case .highPriority:
            return suggestionEngine.currentSuggestions.filter { $0.priority == .high }.count
        case .mediumPriority:
            return suggestionEngine.currentSuggestions.filter { $0.priority == .medium }.count
        case .lowPriority:
            return suggestionEngine.currentSuggestions.filter { $0.priority == .low }.count
        case .work:
            return suggestionEngine.currentSuggestions.filter { $0.suggestedAction.type == .work }.count
        case .personal:
            return suggestionEngine.currentSuggestions.filter { $0.suggestedAction.type == .personal }.count
        case .communication:
            return suggestionEngine.currentSuggestions.filter { $0.suggestedAction.type == .productivity || $0.contextTags.contains("communication") }.count
        case .quick:
            return suggestionEngine.currentSuggestions.filter { ($0.estimatedDuration ?? 600) < 300 }.count
        }
    }

    private func loadSuggestions() {
        isLoading = true

        Task {
            // Load suggestions instead of processing activities
            let suggestions = await suggestionEngine.generateSuggestions()
            await MainActor.run {
                suggestionEngine.currentSuggestions = suggestions
                isLoading = false
            }
        }
    }

    private func acceptSuggestion(_ suggestion: SuggestedTodo) {
        Task {
            do {
                try await suggestionEngine.recordUserFeedback(
                    for: suggestion.id,
                    feedback: UserFeedback(score: 1.0, timestamp: Date()),
                    accept: true
                )
                // Maybe integrate with a task management system
            } catch {
                print("Failed to record feedback: \(error)")
            }
        }
    }

    private func dismissSuggestion(_ suggestion: SuggestedTodo) {
        Task {
            do {
                try await suggestionEngine.recordUserFeedback(
                    for: suggestion.id,
                    feedback: UserFeedback(score: 0.0, timestamp: Date(), comment: "Dismissed"),
                    accept: false
                )
            } catch {
                print("Failed to record feedback: \(error)")
            }
        }
    }

    private func snoozeSuggestion(_ suggestion: SuggestedTodo) {
        Task {
            do {
                try await suggestionEngine.recordUserFeedback(
                    for: suggestion.id,
                    feedback: UserFeedback(score: 0.5, timestamp: Date(), comment: "Snoozed"),
                    accept: false
                )
            } catch {
                print("Failed to record feedback: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignSpacing.xs) {
            Text(value)
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.title3))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                .foregroundColor(DesignColors.secondaryText)
        }
    }
}

struct FilterChip: View {
    let filter: SuggestionFilter
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSpacing.xs) {
                Text(filter.displayName)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .fontWeight(isSelected ? .medium : .regular)

                if count > 0 {
                    Text("(\(count))")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.secondaryText)
                }
            }
            .padding(.horizontal, DesignSpacing.md)
            .padding(.vertical, DesignSpacing.xs)
            .background(isSelected ? colorForFilter(filter) : DesignColors.glassBackground)
            .foregroundColor(isSelected ? .white : DesignColors.primaryText)
            .cornerRadius(DesignRadius.pill)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorForFilter(_ filter: SuggestionFilter) -> Color {
        switch filter {
        case .all: return DesignColors.primaryOrange
        case .highPriority: return DesignColors.errorRed
        case .mediumPriority: return DesignColors.warningYellow
        case .lowPriority: return DesignColors.successGreen
        case .work: return Color.purple
        case .personal: return Color.mint
        case .communication: return Color.cyan
        case .quick: return Color.pink
        }
    }
}

struct SuggestionCard: View {
    let suggestion: SuggestedTodo
    let onTap: () -> Void
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        UnifiedCard(style: .standard, size: .medium) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                // Header with title and priority
                HStack {
                    VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                        Text(suggestion.title)
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                            .fontWeight(.medium)
                            .foregroundColor(DesignColors.primaryText)
                            .lineLimit(2)

                        HStack(spacing: DesignSpacing.sm) {
                            PriorityBadge(priority: suggestion.priority)

                            if let duration = suggestion.estimatedDuration {
                                DurationBadge(duration: duration)
                            }

                            TaskCategoryBadge(category: suggestion.suggestedAction.type)
                        }
                    }

                    Spacer()

                    VStack(spacing: DesignSpacing.xs) {
                        Button(action: onTap) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundColor(DesignColors.secondaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Description
                if !suggestion.description.isEmpty {
                    Text(suggestion.description)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                        .foregroundColor(DesignColors.secondaryText)
                        .lineLimit(3)
                }

                // Source info
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignColors.warningYellow)

                    Text("Suggested from \(suggestion.sourceType.displayName)")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.secondaryText)

                    Spacer()

                    if suggestion.confidence > 0 {
                        let confidence = suggestion.confidence
                        Text("\(Int(confidence * 100))% confidence")
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                            .foregroundColor(DesignColors.tertiaryText)
                    }
                }

                // Action buttons
                HStack(spacing: DesignSpacing.sm) {
                    UnifiedButton.primary(
                        "Accept",
                        size: .small,
                        action: onAccept
                    )

                    UnifiedButton.secondary(
                        "Snooze",
                        size: .small,
                        action: onSnooze
                    )

                    UnifiedButton.ghost(
                        "",
                        size: .small,
                        action: onDismiss
                    )

                    Spacer()
                }
            }
        }
    }
}

struct PriorityBadge: View {
    let priority: SuggestionPriority

    var body: some View {
        Text(priority.rawValue.capitalized)
            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSpacing.xs)
            .padding(.vertical, 2)
            .background(colorForPriority(priority))
            .cornerRadius(DesignRadius.small)
    }

    private func colorForPriority(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .urgent: return DesignColors.errorRed
        case .high: return DesignColors.errorRed
        case .medium: return DesignColors.primaryOrange
        case .low: return DesignColors.successGreen
        }
    }
}

struct DurationBadge: View {
    let duration: TimeInterval

    var body: some View {
        Text(durationText)
            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
            .fontWeight(.medium)
            .foregroundColor(DesignColors.secondaryText)
            .padding(.horizontal, DesignSpacing.xs)
            .padding(.vertical, 2)
            .background(DesignColors.glassBackground)
            .cornerRadius(DesignRadius.small)
    }

    private var durationText: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
    }
}

struct TaskCategoryBadge: View {
    let category: TaskCategory

    var body: some View {
        Text(category.displayName)
            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSpacing.xs)
            .padding(.vertical, 2)
            .background(colorForCategory(category))
            .cornerRadius(DesignRadius.small)
    }

    private func colorForCategory(_ category: TaskCategory) -> Color {
        switch category {
        case .work: return Color.purple
        case .personal: return Color.mint
        case .learning: return Color.blue
        case .health: return Color.pink
        case .productivity: return DesignColors.primaryOrange
        case .career: return DesignColors.primaryOrange
        }
    }
}

extension TaskCategory {
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .learning: return "Learning"
        case .personal: return "Personal"
        case .health: return "Health"
        case .productivity: return "Productivity"
        case .career: return "Career"
        }
    }
}

// MARK: - Detail View

struct SuggestionDetailView: View {
    let suggestion: SuggestedTodo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title and priority
                    VStack(alignment: .leading, spacing: 8) {
                        Text(suggestion.title)
                            .font(.custom("InstrumentSerif-Regular", size: 24))
                            .foregroundColor(Color.black)

                        HStack(spacing: 12) {
                            PriorityBadge(priority: suggestion.priority)
                            if let duration = suggestion.estimatedDuration {
                                DurationBadge(duration: duration)
                            }
                            TaskCategoryBadge(category: suggestion.suggestedAction.type)
                        }
                    }

                    // Description
                    if !suggestion.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.custom("Nunito", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(Color.black)

                            Text(suggestion.description)
                                .font(.custom("Nunito", size: 14))
                                .foregroundColor(Color.gray)
                        }
                    }

                    // Suggested action
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Action")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color.black)

                        Text(suggestion.suggestedAction.description)
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.gray)
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }

                    // Source information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color.black)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Type:")
                                    .font(.custom("Nunito", size: 14))
                                    .foregroundColor(Color.gray)
                                Text(suggestion.sourceType.displayName)
                                    .font(.custom("Nunito", size: 14))
                                    .fontWeight(.medium)
                            }

                            if let confidence = Optional(suggestion.confidence) {
                                HStack {
                                    Text("Confidence:")
                                        .font(.custom("Nunito", size: 14))
                                        .foregroundColor(Color.gray)
                                    Text("\(Int(confidence * 100))%")
                                        .font(.custom("Nunito", size: 14))
                                        .fontWeight(.medium)
                                }
                            }

                            let score = suggestion.urgencyScore * 0.5 + suggestion.relevanceScore * 0.5
                            HStack {
                                Text("Priority Score:")
                                    .font(.custom("Nunito", size: 14))
                                    .foregroundColor(Color.gray)
                                Text(String(format: "%.1f", score))
                                    .font(.custom("Nunito", size: 14))
                                    .fontWeight(.medium)
                            }
                        }
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(Color.black)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Created:")
                                    .font(.custom("Nunito", size: 14))
                                    .foregroundColor(Color.gray)
                                Text(suggestion.createdAt, style: .relative)
                                    .font(.custom("Nunito", size: 14))
                                    .fontWeight(.medium)
                            }

                            // Note: SuggestedTodo doesn't have expiresAt property
                            // Removed expiresAt display as it's not part of SuggestedTodo model

                            if let sourceId = suggestion.sourceActivityId {
                                HStack {
                                    Text("Source ID:")
                                        .font(.custom("Nunito", size: 14))
                                        .foregroundColor(Color.gray)
                                    Text(sourceId.uuidString.prefix(8) + "...")
                                        .font(.system(size: 12, design: .monospaced))
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(Color.blue)
                }
            }
        }
    }
}


// MARK: - Extensions


#Preview {
    SuggestedTodosView()
}
