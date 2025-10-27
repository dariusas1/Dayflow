//
//  JournalView.swift
//  FocusLock
//
//  Main journal interface for viewing and managing AI-generated daily journals
//

import SwiftUI
import Combine

struct JournalView: View {
    @StateObject private var generator = DailyJournalGenerator.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedDate = Date()
    @State private var showingTemplateSelector = false
    @State private var showingExportOptions = false
    @State private var showingPreferences = false
    @State private var selectedTemplate: JournalTemplate = .comprehensive
    @State private var journalPreferences: JournalPreferences
    @State private var journalHistory: [DailyJournal] = []
    @State private var isEditingJournal = false

    // Animation states
    @State private var animateContent = false
    @State private var showingHighlights = true

    init() {
        _journalPreferences = State(initialValue: JournalPreferences())
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection

                    // Date Selector
                    dateSelectorSection

                    // Generation Controls
                    generationControlsSection

                    // Loading State
                    if generator.isGenerating {
                        loadingSection
                    }

                    // Error State
                    if let error = generator.generationError {
                        errorSection(error)
                    }

                    // Journal Content
                    if let journal = generator.generatedJournal {
                        journalContentSection(journal)
                    }

                    // Empty State
                    if !generator.isGenerating && generator.generatedJournal == nil {
                        emptyStateSection
                    }

                    // History Section
                    if !journalHistory.isEmpty {
                        journalHistorySection
                    }
                }
                .padding()
            }
            .navigationTitle("Daily Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Preferences", systemImage: "slider.horizontal.3") {
                            showingPreferences = true
                        }
                        Button("Export", systemImage: "square.and.arrow.up") {
                            showingExportOptions = true
                        }
                        Button("History", systemImage: "clock") {
                            // Show history
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingTemplateSelector) {
                JournalTemplateView(
                    selectedTemplate: $selectedTemplate,
                    preferences: $journalPreferences
                )
            }
            .sheet(isPresented: $showingExportOptions) {
                if let journal = generator.generatedJournal {
                    JournalExportView(journal: journal)
                }
            }
            .sheet(isPresented: $showingPreferences) {
                JournalPreferencesView(preferences: $journalPreferences)
            }
            .onAppear {
                loadJournalHistory()
                animateContent = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Your AI-Powered Journal")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Transform your daily activities into meaningful reflections")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.1), value: animateContent)
    }

    // MARK: - Date Selector Section

    private var dateSelectorSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .fontWeight(.medium)

                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            // Quick date buttons
            HStack(spacing: 12) {
                quickDateButton("Today", isToday: true)
                quickDateButton("Yesterday", isToday: false)
                quickDateButton("This Week", isToday: false)
            }
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateContent)
    }

    private func quickDateButton(_ title: String, isToday: Bool) -> some View {
        Button(action: {
            if isToday {
                selectedDate = Date()
            } else if title == "Yesterday" {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            } else {
                selectedDate = Date()
            }
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(16)
        }
    }

    // MARK: - Generation Controls Section

    private var generationControlsSection: some View {
        VStack(spacing: 16) {
            // Template selection
            HStack {
                Text("Template:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: { showingTemplateSelector = true }) {
                    HStack {
                        Text(selectedTemplate.displayName)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Generate button
            Button(action: {
                Task {
                    await generator.generateJournalWithHighlights(
                        for: selectedDate,
                        template: selectedTemplate,
                        preferences: journalPreferences
                    )
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Journal")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(generator.isGenerating)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateContent)
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: generator.currentProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)

            Text(generator.progressMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Animated loading dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(loadingScale(for: index))
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: generator.isGenerating
                        )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func loadingScale(for index: Int) -> CGFloat {
        return generator.isGenerating ? (index == 1 ? 1.2 : 0.8) : 1.0
    }

    // MARK: - Error Section

    private func errorSection(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)

            Text("Generation Failed")
                .font(.headline)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await generator.generateJournalWithHighlights(
                        for: selectedDate,
                        template: selectedTemplate,
                        preferences: journalPreferences
                    )
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.orange)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Journal Content Section

    private func journalContentSection(_ journal: DailyJournal) -> some View {
        VStack(spacing: 20) {
            // Journal header
            journalHeader(journal)

            // Content
            journalContentView(journal)

            // Highlights
            if !journal.highlights.isEmpty {
                highlightsSection(journal.highlights)
            }

            // Sentiment analysis
            if let sentiment = journal.sentimentAnalysis {
                sentimentSection(sentiment)
            }

            // Actions
            journalActionsSection(journal)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
    }

    private func journalHeader(_ journal: DailyJournal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(journal.date.formatted(date: .long, time: .omitted))
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack {
                    Image(systemName: journal.template.systemImage)
                        .font(.caption)
                    Text(journal.template.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Edit button
            Button(action: { isEditingJournal.toggle() }) {
                Image(systemName: isEditingJournal ? "checkmark" : "pencil")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func journalContentView(_ journal: DailyJournal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditingJournal {
                TextEditor(text: .constant(journal.content))
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            } else {
                Text(journal.content)
                    .font(.body)
                    .lineSpacing(2)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func highlightsSection(_ highlights: [JournalHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { showingHighlights.toggle() }) {
                    HStack {
                        Image(systemName: showingHighlights ? "chevron.down" : "chevron.right")
                        Text("Key Highlights (\(highlights.count))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.primary)
                }

                Spacer()
            }

            if showingHighlights {
                LazyVStack(spacing: 8) {
                    ForEach(highlights.prefix(3)) { highlight in
                        highlightRow(highlight)
                    }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
    }

    private func highlightRow(_ highlight: JournalHighlight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.category.systemImage)
                .foregroundColor(highlight.category.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(highlight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Significance indicator
            Circle()
                .fill(highlight.significanceColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }

    private func sentimentSection(_ sentiment: SentimentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart")
                    .foregroundColor(.pink)

                Text("Emotional Insights")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(sentiment.overallSentiment.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sentiment.overallSentiment.color.opacity(0.2))
                    .foregroundColor(sentiment.overallSentiment.color)
                    .cornerRadius(8)
            }

            // Top emotions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sentiment.emotionScores.prefix(3)) { emotion in
                        HStack(spacing: 4) {
                            Text(emotion.emotion.displayName)
                                .font(.caption2)
                            Text(String(format: "%.0f%%", emotion.intensity * 100))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color.pink.opacity(0.05))
        .cornerRadius(12)
    }

    private func journalActionsSection(_ journal: DailyJournal) -> some View {
        HStack(spacing: 16) {
            Button("Share") {
                showingExportOptions = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            Button("Regenerate") {
                Task {
                    await generator.regenerateJournal(
                        with: selectedTemplate,
                        preferences: journalPreferences
                    )
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Empty State Section

    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Journal Yet")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Generate your first AI-powered journal entry to see your daily reflections come to life")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateContent)
    }

    // MARK: - Journal History Section

    private var journalHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Journals")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("View All") {
                    // Navigate to full history
                }
                .font(.caption)
                .foregroundColor(.blue)
            }

            LazyVStack(spacing: 8) {
                ForEach(journalHistory.prefix(3)) { journal in
                    historyRow(journal)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func historyRow(_ journal: DailyJournal) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(journal.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Image(systemName: journal.template.systemImage)
                        .font(.caption2)
                    Text(journal.template.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let sentiment = journal.sentimentAnalysis {
                Text(sentiment.overallSentiment.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sentiment.overallSentiment.color.opacity(0.2))
                    .foregroundColor(sentiment.overallSentiment.color)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = journal.date
            generator.generatedJournal = journal
        }
    }

    // MARK: - Helper Methods

    private func changeDate(by days: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            // Clear current journal to force regeneration for new date
            generator.generatedJournal = nil
        }
    }

    private func loadJournalHistory() {
        // Load journal history from local storage
        // This would integrate with a data persistence layer
        journalHistory = []
    }
}

// MARK: - Extensions

extension JournalTemplate {
    var displayName: String {
        switch self {
        case .reflective: return "Reflective"
        case .achievement: return "Achievement"
        case .gratitude: return "Gratitude"
        case .growth: return "Growth"
        case .comprehensive: return "Comprehensive"
        case .custom: return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .reflective: return "brain.head.profile"
        case .achievement: return "trophy"
        case .gratitude: return "heart"
        case .growth: return "chart.line.uptrend.xyaxis"
        case .comprehensive: return "doc.text"
        case .custom: return "slider.horizontal.3"
        }
    }
}

extension HighlightCategory {
    var systemImage: String {
        switch self {
        case .achievement: return "trophy"
        case .challenge: return "exclamationmark.triangle"
        case .learning: return "book"
        case .moment: return "star"
        case .insight: return "lightbulb"
        case .gratitude: return "heart"
        }
    }

    var color: Color {
        switch self {
        case .achievement: return .yellow
        case .challenge: return .orange
        case .learning: return .blue
        case .moment: return .green
        case .insight: return .purple
        case .gratitude: return .pink
        }
    }
}

extension SentimentScore {
    var displayName: String {
        switch self {
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .negative: return "Negative"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}

extension EmotionType {
    var displayName: String {
        switch self {
        case .joy: return "Joy"
        case .calm: return "Calm"
        case .focused: return "Focused"
        case .grateful: return "Grateful"
        case .challenged: return "Challenged"
        case .accomplished: return "Accomplished"
        }
    }
}

extension JournalHighlight {
    var significanceColor: Color {
        if significance > 0.7 {
            return .green
        } else if significance > 0.4 {
            return .yellow
        } else {
            return .gray
        }
    }
}

// MARK: - Preview

struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
    }
}
