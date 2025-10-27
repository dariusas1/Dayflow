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
            suggestions = suggestions.filter { $0.suggestedAction.type == .communication }
        case .quick:
            suggestions = suggestions.filter { $0.estimatedDuration < 300 } // Less than 5 minutes
        }

        // Apply search
        if !searchText.isEmpty {
            suggestions = suggestions.filter { suggestion in
                suggestion.title.localizedCaseInsensitiveContains(searchText) ||
                suggestion.description.localizedCaseInsensitiveContains(searchText) ||
                suggestion.suggestedAction.verb.localizedCaseInsensitiveContains(searchText)
            }
        }

        return suggestions.sorted { $0.priorityScore > $1.priorityScore }
    }

    var body: some View {
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
        .background(Color(.systemBackground))
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
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested Tasks")
                        .font(.custom("InstrumentSerif-Regular", size: 24))
                        .foregroundColor(Color.black)

                    Text("AI-powered task suggestions based on your activity")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(Color.gray)
                }

                Spacer()

                Button(action: {
                    loadSuggestions()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(Color.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Quick stats
            HStack(spacing: 20) {
                StatItem(
                    title: "Total",
                    value: "\(suggestionEngine.currentSuggestions.count)",
                    color: .blue
                )

                StatItem(
                    title: "High Priority",
                    value: "\(suggestionEngine.currentSuggestions.filter { $0.priority == .high }.count)",
                    color: .red
                )

                StatItem(
                    title: "Quick Tasks",
                    value: "\(suggestionEngine.currentSuggestions.filter { $0.estimatedDuration < 300 }.count)",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
    }

    private var filterSearchView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.gray)

                TextField("Search suggestions...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("Nunito", size: 14))

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Analyzing your activity...")
                .font(.custom("Nunito", size: 16))
                .foregroundColor(Color.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(Color.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No suggestions yet")
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(Color.black)

                Text("Start using your apps and we'll suggest tasks based on your activity")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color.gray)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                loadSuggestions()
            }) {
                Text("Refresh Suggestions")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var suggestionsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
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
            .padding()
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
            return suggestionEngine.currentSuggestions.filter { $0.suggestedAction.type == .communication }.count
        case .quick:
            return suggestionEngine.currentSuggestions.filter { $0.estimatedDuration < 300 }.count
        }
    }

    private func loadSuggestions() {
        isLoading = true

        Task {
            do {
                try await suggestionEngine.processPendingActivities()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error - maybe show an alert
                }
            }
        }
    }

    private func acceptSuggestion(_ suggestion: SuggestedTodo) {
        Task {
            await suggestionEngine.recordUserFeedback(suggestionId: suggestion.id, feedback: .accepted)
            // Maybe integrate with a task management system
        }
    }

    private func dismissSuggestion(_ suggestion: SuggestedTodo) {
        Task {
            await suggestionEngine.recordUserFeedback(suggestionId: suggestion.id, feedback: .dismissed)
        }
    }

    private func snoozeSuggestion(_ suggestion: SuggestedTodo) {
        Task {
            await suggestionEngine.recordUserFeedback(suggestionId: suggestion.id, feedback: .snoozed)
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Nunito", size: 18))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(Color.gray)
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
            HStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(isSelected ? .medium : .regular)

                if count > 0 {
                    Text("(\(count))")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(Color.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? colorForFilter(filter) : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : Color.primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func colorForFilter(_ filter: SuggestionFilter) -> Color {
        switch filter {
        case .all: return .blue
        case .highPriority: return .red
        case .mediumPriority: return .orange
        case .lowPriority: return .green
        case .work: return .purple
        case .personal: return .mint
        case .communication: return .cyan
        case .quick: return .pink
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
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and priority
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color.black)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        PriorityBadge(priority: suggestion.priority)

                        DurationBadge(duration: suggestion.estimatedDuration)

                        TypeBadge(type: suggestion.suggestedAction.type)
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Button(action: onTap) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Description
            if !suggestion.description.isEmpty {
                Text(suggestion.description)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color.gray)
                    .lineLimit(3)
            }

            // Source info
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.yellow)

                Text("Suggested from \(suggestion.sourceType.displayName)")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(Color.gray)

                Spacer()

                if let confidence = suggestion.extractionConfidence {
                    Text("\(Int(confidence * 100))% confidence")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(Color.gray)
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onSnooze) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Snooze")
                    }
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(Color.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(Color.gray)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
}

struct PriorityBadge: View {
    let priority: SuggestionPriority

    var body: some View {
        Text(priority.displayName)
            .font(.custom("Nunito", size: 10))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForPriority(priority))
            .cornerRadius(4)
    }

    private func colorForPriority(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

struct DurationBadge: View {
    let duration: TimeInterval

    var body: some View {
        Text(durationText)
            .font(.custom("Nunito", size: 10))
            .fontWeight(.medium)
            .foregroundColor(Color.gray)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.systemGray6))
            .cornerRadius(4)
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

struct TypeBadge: View {
    let type: ActionType

    var body: some View {
        Text(type.displayName)
            .font(.custom("Nunito", size: 10))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForType(type))
            .cornerRadius(4)
    }

    private func colorForType(_ type: ActionType) -> Color {
        switch type {
        case .work: return .purple
        case .personal: return .mint
        case .communication: return .cyan
        case .health: return .pink
        case .finance: return .orange
        case .learning: return .blue
        case .other: return .gray
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
                            DurationBadge(duration: suggestion.estimatedDuration)
                            TypeBadge(type: suggestion.suggestedAction.type)
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

                        Text(suggestion.suggestedAction.verb + " " + suggestion.suggestedAction.object)
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(Color.gray)
                            .padding()
                            .background(Color(.systemGray6))
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

                            if let confidence = suggestion.extractionConfidence {
                                HStack {
                                    Text("Confidence:")
                                        .font(.custom("Nunito", size: 14))
                                        .foregroundColor(Color.gray)
                                    Text("\(Int(confidence * 100))%")
                                        .font(.custom("Nunito", size: 14))
                                        .fontWeight(.medium)
                                }
                            }

                            if let score = suggestion.priorityScore {
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

                            if let expiresAt = suggestion.expiresAt {
                                HStack {
                                    Text("Expires:")
                                        .font(.custom("Nunito", size: 14))
                                        .foregroundColor(Color.gray)
                                    Text(expiresAt, style: .relative)
                                        .font(.custom("Nunito", size: 14))
                                        .fontWeight(.medium)
                                        .foregroundColor(expiresAt < Date() ? .red : .primary)
                                }
                            }

                            if let sourceId = suggestion.sourceActivityId {
                                HStack {
                                    Text("Source ID:")
                                        .font(.custom("Nunito", size: 14))
                                        .foregroundColor(Color.gray)
                                    Text(sourceId.uuidString.prefix(8) + "...")
                                        .font(.custom("Nunito", size: 14))
                                        .fontWeight(.medium)
                                        .font(.system(.monospaced, size: 12))
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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

// MARK: - Filter Enum

enum SuggestionFilter: CaseIterable {
    case all
    case highPriority
    case mediumPriority
    case lowPriority
    case work
    case personal
    case communication
    case quick

    var displayName: String {
        switch self {
        case .all: return "All"
        case .highPriority: return "High Priority"
        case .mediumPriority: return "Medium Priority"
        case .lowPriority: return "Low Priority"
        case .work: return "Work"
        case .personal: return "Personal"
        case .communication: return "Communication"
        case .quick: return "Quick (< 5m)"
        }
    }
}

// MARK: - Extensions

extension SuggestionPriority {
    var displayName: String {
        switch self {
        case .high: return "HIGH"
        case .medium: return "MED"
        case .low: return "LOW"
        }
    }
}

extension SuggestionSourceType {
    var displayName: String {
        switch self {
        case .ocr: return "Screen Content"
        case .accessibility: return "App Usage"
        case .fusion: return "Activity Pattern"
        case .userInput: return "Manual Entry"
        case .learning: return "Smart Suggestion"
        }
    }
}

extension ActionType {
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .personal: return "Personal"
        case .communication: return "Communication"
        case .health: return "Health"
        case .finance: return "Finance"
        case .learning: return "Learning"
        case .other: return "Other"
        }
    }
}

#Preview {
    SuggestedTodosView()
}