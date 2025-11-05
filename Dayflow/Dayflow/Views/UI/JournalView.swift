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
        ZStack {
            // Background matching MainView
            Image("MainUIBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Main white panel container
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section - matching MainView style
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
                .padding(30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 0)
                }
            )
            .padding([.top, .trailing, .bottom], 15)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Journal")
                    .font(.custom("InstrumentSerif-Regular", size: 36))
                    .foregroundColor(.black)

                Spacer()

                // Toolbar actions integrated into header
                HStack(spacing: 12) {
                    Button(action: { showingPreferences = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
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
                            .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Text("Your daily activities transformed into meaningful reflections")
                .font(.custom("Nunito", size: 16))
                .foregroundColor(.black.opacity(0.7))
                .fontWeight(.medium)
        }
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.1), value: animateContent)
    }
    
    // MARK: - Auto-Generation Info Banner
    
    private var autoGenerationInfoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Automatic Journal Generation")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Text("Your journal is automatically created each day at midnight based on your activities")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.7))
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.08), location: 0.00),
                        Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.15), value: animateContent)
    }

    // MARK: - Date Selector Section

    private var dateSelectorSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { changeDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                VStack(spacing: 4) {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.6))
                }

                Spacer()

                Button(action: { changeDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)

            // Quick date buttons
            HStack(spacing: 12) {
                quickDateButton("Today", isToday: true)
                quickDateButton("Yesterday", isToday: false)
                quickDateButton("This Week", isToday: false)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                .font(.custom("Nunito", size: 12))
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        Color.white.opacity(0.69)
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 1, green: 0.77, blue: 0.34), location: 0.00),
                                Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 1.15, y: 3.61),
                            endPoint: UnitPoint(x: 0.02, y: 0)
                        )
                    }
                )
                .foregroundColor(.black)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }


    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 20) {
            // Enhanced progress indicator
                        ZStack {
                Circle()
                    .stroke(Color(red: 1, green: 0.42, blue: 0.02).opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: generator.currentProgress)
                    .stroke(Color(red: 1, green: 0.42, blue: 0.02), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: generator.currentProgress)
                
                    Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 1, green: 0.42, blue: 0.02))
            }

            VStack(spacing: 8) {
                Text("Generating Your Journal")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

            Text(generator.progressMessage)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
            }

            // Animated loading dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(red: 1, green: 0.42, blue: 0.02))
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
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95), location: 0.00),
                        Gradient.Stop(color: Color.white, location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func loadingScale(for index: Int) -> CGFloat {
        return generator.isGenerating ? (index == 1 ? 1.2 : 0.8) : 1.0
    }

    // MARK: - Error Section

    private func errorSection(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(Color(red: 1, green: 0.42, blue: 0.02))

            Text("Generation Failed")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black)

            Text(error.localizedDescription)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
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
            .font(.custom("Nunito", size: 14))
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(red: 1, green: 0.42, blue: 0.02))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(journal.date.formatted(date: .long, time: .omitted))
                    .font(.custom("InstrumentSerif-Regular", size: 22))
                    .foregroundColor(.black)

                HStack(spacing: 8) {
                    Image(systemName: journal.template.icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                    Text(journal.template.displayName)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.6))
                        .fontWeight(.medium)
                }
            }

            Spacer()

            // Edit button
            Button(action: { isEditingJournal.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: isEditingJournal ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 20))
                    Text(isEditingJournal ? "Done" : "Edit")
                        .font(.custom("Nunito", size: 13))
                        .fontWeight(.semibold)
                }
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(red: 1, green: 0.77, blue: 0.34).opacity(0.05), location: 0.00),
                        Gradient.Stop(color: Color.white, location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }

    private func journalContentView(_ journal: DailyJournal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditingJournal {
                TextEditor(text: .constant(journal.content))
                    .font(.custom("Nunito", size: 15))
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                Text(journal.content)
                    .font(.custom("Nunito", size: 15))
                    .foregroundColor(.black.opacity(0.85))
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0.3), location: 0.00),
                        Gradient.Stop(color: Color.white, location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func highlightsSection(_ highlights: [JournalHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { showingHighlights.toggle() }) {
                    HStack {
                        Image(systemName: showingHighlights ? "chevron.down" : "chevron.right")
                            .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                        Text("Key Highlights (\(highlights.count))")
                            .font(.custom("Nunito", size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
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
        .padding(20)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(red: 1, green: 0.77, blue: 0.34).opacity(0.05), location: 0.00),
                        Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func highlightRow(_ highlight: JournalHighlight) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 1, green: 0.42, blue: 0.02).opacity(0.1))
                    .frame(width: 36, height: 36)
                
            Image(systemName: highlight.category.icon)
                    .font(.system(size: 16))
                .foregroundColor(Color(red: 1, green: 0.42, blue: 0.02))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(highlight.title)
                    .font(.custom("Nunito", size: 15))
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text(highlight.content)
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.7))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))

                Text("Emotional Insights")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Spacer()

                Text(sentiment.overallSentiment.emotion.capitalized)
                    .font(.custom("Nunito", size: 11))
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        ZStack {
                            Color.white.opacity(0.69)
                            LinearGradient(
                                stops: [
                                    Gradient.Stop(color: Color(red: 1, green: 0.77, blue: 0.34), location: 0.00),
                                    Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                                ],
                                startPoint: UnitPoint(x: 1.15, y: 3.61),
                                endPoint: UnitPoint(x: 0.02, y: 0)
                            )
                        }
                    )
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }

            // Top emotions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sentiment.emotionalBreakdown.prefix(3), id: \.emotion) { emotion in
                        HStack(spacing: 4) {
                            Text(emotion.emotion.capitalized)
                                .font(.custom("Nunito", size: 11))
                            Text(String(format: "%.0f%%", emotion.intensity * 100))
                                .font(.custom("Nunito", size: 11))
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.1))
                        .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func journalActionsSection(_ journal: DailyJournal) -> some View {
        HStack(spacing: 16) {
            Button("Share Journal") {
                showingExportOptions = true
            }
            .font(.custom("Nunito", size: 14))
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                ZStack {
                    Color(red: 1, green: 0.42, blue: 0.02)
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(0.2), location: 0.00),
                            Gradient.Stop(color: Color.clear, location: 1.00),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(10)
            .shadow(color: Color(red: 1, green: 0.42, blue: 0.02).opacity(0.3), radius: 4, x: 0, y: 2)
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Empty State Section

    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.1), location: 0.00),
                                Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.5))
            }

            VStack(spacing: 12) {
                Text("No Journal for This Date")
                    .font(.custom("InstrumentSerif-Regular", size: 24))
                    .foregroundColor(.black)

                Text("Journals are automatically generated at midnight each day.\n\nYour daily reflections will appear here once the system processes your activities and creates a personalized summary.")
                    .font(.custom("Nunito", size: 15))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 60)
            }
            
            // Info box
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                
                Text("Use the date selector above to view past journal entries")
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.05))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95), location: 0.00),
                        Gradient.Stop(color: Color.white, location: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .opacity(animateContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateContent)
    }

    // MARK: - Journal History Section

    private var journalHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Journals")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Spacer()

                Button("View All") {
                    // Navigate to full history
                }
                .font(.custom("Nunito", size: 12))
                .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                .buttonStyle(PlainButtonStyle())
            }

            LazyVStack(spacing: 8) {
                ForEach(journalHistory.prefix(3)) { journal in
                    historyRow(journal)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func historyRow(_ journal: DailyJournal) -> some View {
        Button(action: {
            selectedDate = journal.date
            generator.generatedJournal = journal
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(journal.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    HStack {
                        Image(systemName: journal.template.icon)
                            .font(.custom("Nunito", size: 10))
                            .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                        Text(journal.template.displayName)
                            .font(.custom("Nunito", size: 10))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }

                Spacer()

                if !journal.sentiment.emotionalBreakdown.isEmpty {
                    Text(journal.sentiment.overallSentiment.displayName)
                        .font(.custom("Nunito", size: 10))
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                Color.white.opacity(0.69)
                                LinearGradient(
                                    stops: [
                                        Gradient.Stop(color: Color(red: 1, green: 0.77, blue: 0.34), location: 0.00),
                                        Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                                    ],
                                    startPoint: UnitPoint(x: 1.15, y: 3.61),
                                    endPoint: UnitPoint(x: 0.02, y: 0)
                                )
                            }
                        )
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.5))
            .cornerRadius(8)
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
