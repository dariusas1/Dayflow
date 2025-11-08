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
    @StateObject private var settingsManager = FocusLockSettingsManager.shared
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
        FlowingGradientBackground()
            .overlay(
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSpacing.xl) {
                        // Header Section
                        headerSection

                        // Auto-generation info banner
                        autoGenerationInfoBanner

                        // Date Selector
                        dateSelectorSection

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
                    .padding(DesignSpacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Header Section

    private var headerSection: some View {
        GlassmorphismContainer(style: .main) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                HStack {
                    Text("Daily Journal")
                        .font(.custom(DesignTypography.headingFont, size: DesignTypography.title1))
                        .foregroundColor(DesignColors.primaryText)

                    Spacer()

                    // Toolbar actions integrated into header
                    HStack(spacing: DesignSpacing.md) {
                        Button(action: { showingPreferences = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DesignColors.primaryOrange)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Preferences")

                        Menu {
                            Button("Export", systemImage: "square.and.arrow.up") {
                                showingExportOptions = true
                            }
                            Button("History", systemImage: "clock") {
                                // Show history
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DesignColors.primaryOrange)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Text("Your daily activities transformed into meaningful reflections")
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(DesignColors.secondaryText)
                    .fontWeight(.medium)
            }
            .padding(DesignSpacing.lg)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.1), value: animateContent)
    }
    
    // MARK: - Auto-Generation Info Banner
    
    private var autoGenerationInfoBanner: some View {
        UnifiedCard(style: .minimal, size: .medium) {
            HStack(spacing: DesignSpacing.md) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignColors.primaryOrange)

                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text("Automatic Journal Generation")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)

                    Text("Your journal is automatically created each day at midnight based on your activities")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.secondaryText)
                        .lineSpacing(2)
                }

                Spacer()
            }
            .padding(DesignSpacing.lg)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.15), value: animateContent)
    }

    // MARK: - Date Selector Section

    private var dateSelectorSection: some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(spacing: DesignSpacing.md) {
                HStack {
                    Button(action: { changeDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignColors.primaryOrange)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    VStack(spacing: DesignSpacing.xs) {
                        Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                            .fontWeight(.semibold)
                            .foregroundColor(DesignColors.primaryText)

                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                            .foregroundColor(DesignColors.secondaryText)
                    }

                    Spacer()

                    Button(action: { changeDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignColors.primaryOrange)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Quick date buttons
                HStack(spacing: DesignSpacing.md) {
                    quickDateButton("Today", isToday: true)
                    quickDateButton("Yesterday", isToday: false)
                    quickDateButton("This Week", isToday: false)
                }
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
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                .fontWeight(.medium)
                .padding(.horizontal, DesignSpacing.md)
                .padding(.vertical, DesignSpacing.sm)
                .background(
                    ZStack {
                        DesignColors.glassBackground.opacity(0.7)
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: DesignColors.gradientStart, location: 0.00),
                                Gradient.Stop(color: DesignColors.gradientEnd.opacity(0), location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 1.15, y: 3.61),
                            endPoint: UnitPoint(x: 0.02, y: 0)
                        )
                    }
                )
                .foregroundColor(DesignColors.primaryText)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }


    // MARK: - Loading Section

    private var loadingSection: some View {
        UnifiedCard(style: .elevated, size: .large) {
            VStack(spacing: DesignSpacing.lg) {
                // Enhanced progress indicator
                ZStack {
                    Circle()
                        .stroke(DesignColors.primaryOrange.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: generator.currentProgress)
                        .stroke(DesignColors.primaryOrange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: generator.currentProgress)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.primaryOrange)
                }

                VStack(spacing: DesignSpacing.sm) {
                    Text("Generating Your Journal")
                        .font(.custom(DesignTypography.headingFont, size: DesignTypography.title3))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)

                    Text(generator.progressMessage)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                        .foregroundColor(DesignColors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                // Animated loading dots
                HStack(spacing: DesignSpacing.sm) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(DesignColors.primaryOrange)
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
        }
    }

    private func loadingScale(for index: Int) -> CGFloat {
        return generator.isGenerating ? (index == 1 ? 1.2 : 0.8) : 1.0
    }

    // MARK: - Error Section

    private func errorSection(_ error: Error) -> some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(spacing: DesignSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(DesignColors.errorRed)

                Text("Generation Failed")
                    .font(.custom(DesignTypography.headingFont, size: DesignTypography.title3))
                    .fontWeight(.semibold)
                    .foregroundColor(DesignColors.primaryText)

                Text(error.localizedDescription)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(DesignColors.secondaryText)
                    .multilineTextAlignment(.center)

                UnifiedButton.primary(
                    "Try Again",
                    size: .medium,
                    action: {
                        Task {
                            await generator.generateJournalWithHighlights(
                                for: selectedDate,
                                template: selectedTemplate,
                                preferences: journalPreferences
                            )
                        }
                    }
                )
            }
        }
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
            sentimentSection(journal.sentiment)

            // Actions
            journalActionsSection(journal)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
    }

    private func journalHeader(_ journal: DailyJournal) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text(journal.date.formatted(date: .long, time: .omitted))
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.title1))
                    .foregroundColor(DesignColors.primaryText)

                HStack(spacing: DesignSpacing.sm) {
                    Image(systemName: journal.template.icon)
                        .font(.system(size: 12))
                        .foregroundColor(DesignColors.primaryOrange)
                    Text(journal.template.displayName)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.secondaryText)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            // Edit button
            Button(action: { isEditingJournal.toggle() }) {
                HStack(spacing: DesignSpacing.xs) {
                    Image(systemName: isEditingJournal ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 16))
                    Text(isEditingJournal ? "Done" : "Edit")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .fontWeight(.semibold)
                }
                .foregroundColor(DesignColors.primaryOrange)
                .padding(.horizontal, DesignSpacing.sm)
                .padding(.vertical, DesignSpacing.xs)
                .background(DesignColors.primaryOrange.opacity(0.1))
                .cornerRadius(DesignRadius.small)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DesignSpacing.lg)
        .background(
            ZStack {
                DesignColors.cardBackground
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: DesignColors.gradientStart.opacity(0.05), location: 0.00),
                        Gradient.Stop(color: DesignColors.cardBackground, location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(DesignRadius.medium)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }

    private func journalContentView(_ journal: DailyJournal) -> some View {
        UnifiedCard(style: .minimal, size: .large) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                if isEditingJournal {
                    TextEditor(text: .constant(journal.content))
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                        .padding(DesignSpacing.md)
                        .background(DesignColors.cardBackground)
                        .cornerRadius(DesignRadius.small)
                } else {
                    Text(journal.content)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                        .foregroundColor(DesignColors.secondaryText)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(DesignSpacing.lg)
        .background(
            ZStack {
                DesignColors.cardBackground
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: DesignColors.gradientEnd.opacity(0.3), location: 0.00),
                        Gradient.Stop(color: DesignColors.cardBackground, location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(DesignRadius.medium)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func highlightsSection(_ highlights: [JournalHighlight]) -> some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                HStack {
                    Button(action: { showingHighlights.toggle() }) {
                        HStack {
                            Image(systemName: showingHighlights ? "chevron.down" : "chevron.right")
                                .foregroundColor(DesignColors.primaryOrange)
                            Text("Key Highlights (\(highlights.count))")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.semibold)
                                .foregroundColor(DesignColors.primaryText)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

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
            .padding(DesignSpacing.lg)
            .background(
                ZStack {
                    DesignColors.cardBackground
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: DesignColors.gradientStart.opacity(0.05), location: 0.00),
                            Gradient.Stop(color: DesignColors.gradientEnd.opacity(0), location: 1.00),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(DesignRadius.medium)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }

    private func highlightRow(_ highlight: JournalHighlight) -> some View {
        HStack(spacing: DesignSpacing.md) {
            ZStack {
                Circle()
                    .fill(DesignColors.primaryOrange.opacity(0.1))
                    .frame(width: 36, height: 36)

            Image(systemName: highlight.category.icon)
                    .font(.system(size: 16))
                .foregroundColor(DesignColors.primaryOrange)
            }

            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(highlight.title)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                    .fontWeight(.bold)
                    .foregroundColor(DesignColors.primaryText)

                Text(highlight.content)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .foregroundColor(DesignColors.secondaryText)
                    .lineSpacing(2)
                    .lineLimit(2)
            }

            Spacer()

            // Significance indicator with label
            VStack(spacing: 4) {
            Circle()
                .fill(highlight.significanceColor)
                    .frame(width: 10, height: 10)
                
                Text(highlight.significance > 0.7 ? "High" : highlight.significance > 0.4 ? "Med" : "Low")
                    .font(.custom("Nunito", size: 9))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.5))
        .cornerRadius(10)
    }

    private func sentimentSection(_ sentiment: SentimentAnalysis) -> some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(DesignColors.primaryOrange)

                    Text("Emotional Insights")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)

                    Spacer()

                    Text(sentiment.overallSentiment.emotion.capitalized)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .fontWeight(.medium)
                        .padding(.horizontal, DesignSpacing.sm)
                        .padding(.vertical, DesignSpacing.xs)
                        .background(
                            ZStack {
                                DesignColors.glassBackground.opacity(0.7)
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(color: DesignColors.gradientStart, location: 0.00),
                                        Gradient.Stop(color: DesignColors.gradientEnd.opacity(0), location: 1.00),
                                    ],
                                    startPoint: UnitPoint(x: 1.15, y: 3.61),
                                    endPoint: UnitPoint(x: 0.02, y: 0)
                                )
                            }
                        )
                        .foregroundColor(DesignColors.primaryText)
                        .cornerRadius(DesignRadius.small)
                }

                // Top emotions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSpacing.sm) {
                        ForEach(sentiment.emotionalBreakdown.prefix(3), id: \.emotion) { emotion in
                            HStack(spacing: DesignSpacing.xs) {
                                Text(emotion.emotion.capitalized)
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                Text(String(format: "%.0f%%", emotion.intensity * 100))
                                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, DesignSpacing.sm)
                            .padding(.vertical, DesignSpacing.xs)
                            .background(DesignColors.primaryOrange.opacity(0.1))
                            .foregroundColor(DesignColors.primaryOrange)
                            .cornerRadius(DesignRadius.small)
                        }
                    }
                }
            }
        }
    }

    private func journalActionsSection(_ journal: DailyJournal) -> some View {
        HStack(spacing: DesignSpacing.md) {
            UnifiedButton.primary(
                "Share Journal",
                size: .medium,
                action: {
                    showingExportOptions = true
                }
            )
        }
    }

    // MARK: - Empty State Section

    private var emptyStateSection: some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(spacing: DesignSpacing.xl) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    Gradient.Stop(color: DesignColors.primaryOrange.opacity(0.1), location: 0.00),
                                    Gradient.Stop(color: DesignColors.gradientEnd.opacity(0), location: 1.00),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DesignColors.primaryOrange.opacity(0.5))
                }

                VStack(spacing: DesignSpacing.md) {
                    Text("No Journal for This Date")
                        .font(.custom(DesignTypography.headingFont, size: DesignTypography.title2))
                        .foregroundColor(DesignColors.primaryText)

                    Text("Journals are automatically generated at midnight each day.\n\nYour daily reflections will appear here once the system processes your activities and creates a personalized summary.")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                        .foregroundColor(DesignColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, DesignSpacing.xl)
                }

                // Info box
                HStack(spacing: DesignSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignColors.primaryOrange)

                    Text("Use the date selector above to view past journal entries")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.secondaryText)
                }
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.vertical, DesignSpacing.sm)
                .background(DesignColors.primaryOrange.opacity(0.05))
                .cornerRadius(DesignRadius.small)
            }
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateContent)
    }

    // MARK: - Journal History Section

    private var journalHistorySection: some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                HStack {
                    Text("Recent Journals")
                        .font(.custom(DesignTypography.headingFont, size: DesignTypography.callout))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)

                    Spacer()

                    UnifiedButton.ghost(
                        "View All",
                        size: .small,
                        action: {
                            // Navigate to full history
                        }
                    )
                }

                LazyVStack(spacing: DesignSpacing.sm) {
                    ForEach(journalHistory.prefix(3)) { journal in
                        historyRow(journal)
                    }
                }
            }
        }
    }

    private func historyRow(_ journal: DailyJournal) -> some View {
        Button(action: {
            selectedDate = journal.date
            generator.generatedJournal = journal
        }) {
            HStack(spacing: DesignSpacing.md) {
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(journal.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)

                    HStack {
                        Image(systemName: journal.template.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignColors.primaryOrange)
                        Text(journal.template.displayName)
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                            .foregroundColor(DesignColors.secondaryText)
                    }
                }

                Spacer()

                if !journal.sentiment.emotionalBreakdown.isEmpty {
                    Text(journal.sentiment.overallSentiment.displayName)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .fontWeight(.medium)
                        .padding(.horizontal, DesignSpacing.sm)
                        .padding(.vertical, DesignSpacing.xs)
                        .background(
                            ZStack {
                                DesignColors.glassBackground.opacity(0.8)
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        DesignColors.primaryOrange.opacity(0.7),
                                        DesignColors.gradientEnd.opacity(0)
                                    ]),
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            }
                        )
                        .foregroundColor(DesignColors.primaryText)
                        .cornerRadius(DesignRadius.small)
                }
            }
            .padding(.vertical, DesignSpacing.sm)
            .padding(.horizontal, DesignSpacing.md)
            .background(DesignColors.glassBackground.opacity(0.5))
            .cornerRadius(DesignRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
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

// Note: JournalTemplate properties (displayName, systemImage, etc.) are defined in FocusLockModels.swift

extension JournalHighlight.HighlightCategory {
    var systemImage: String {
        return icon
    }
    
    var colorValue: Color {
        let colorStr = self.color // Get the String color property
        switch colorStr {
        case "yellow": return .yellow
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        default: return .gray
        }
    }
}

extension SentimentScore {
    var displayName: String {
        return emotion.capitalized
    }

    var color: Color {
        switch sentimentType {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}

extension JournalTemplate {
    var systemImage: String {
        return icon
    }
}

// Note: EmotionType properties are defined in FocusLockModels.swift

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
