//
//  EnhancedJournalView.swift
//  FocusLock
//
//  Enhanced journal view with two-column layout and comprehensive daily summaries
//

import SwiftUI

struct EnhancedJournalView: View {
    @StateObject private var generator = EnhancedJournalGenerator.shared
    @State private var selectedDate = Date()
    @State private var isGenerating = false
    @State private var currentJournal: EnhancedDailyJournal?
    @State private var showingSectionEditor = false
    @State private var isLoadingJournal = false
    
    var body: some View {
        ZStack {
            // Background matching MainView
            Image("MainUIBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            HStack(spacing: 15) {
                // Left column: Journal content in white panel
            mainContentView
                .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 0)
                        }
                    )
                
                // Right column: History sidebar in white panel
            historySidebar
                .frame(width: 300)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 0)
                        }
                    )
            }
            .padding([.top, .trailing, .bottom], 15)
        }
        .task(id: selectedDate) {
            await loadJournal(for: selectedDate)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                journalHeader
                
                // Journal sections
                if let journal = currentJournal {
                    journalContent(journal)
                } else if isGenerating {
                    generatingView
                } else {
                    emptyStateView
                }
            }
            .padding(30)
        }
    }
    
    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.custom("InstrumentSerif-Regular", size: 32))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                        
                        Text("Auto-generated at midnight")
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if let journal = currentJournal {
                    executionScoreBadge(score: journal.executionScore)
                }
            }
            
            // Date navigation
            HStack(spacing: 16) {
                Button(action: { changeDate(by: -1) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { selectedDate = Date() }) {
                    Text("Today")
                        .font(.custom("Nunito", size: 13))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(red: 1, green: 0.42, blue: 0.02))
                        .cornerRadius(8)
                        .shadow(color: Color(red: 1, green: 0.42, blue: 0.02).opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { changeDate(by: 1) }) {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if currentJournal != nil {
                    Button(action: { showingSectionEditor = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2")
                            Text("Edit Sections")
                        }
                        .font(.custom("Nunito", size: 13))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func journalContent(_ journal: EnhancedDailyJournal) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(journal.sections.sorted(by: { $0.order < $1.order })) { section in
                sectionView(section)
            }
        }
    }
    
    private func sectionView(_ section: JournalSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: section.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                Text(section.title)
                    .font(.custom("Nunito", size: 20))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }
            
            if section.type.isListBased {
                // Render as list with enhanced spacing
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.content.components(separatedBy: "\n"), id: \.self) { line in
                        if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.custom("Nunito", size: 14))
                                    .foregroundColor(Color(red: 1, green: 0.42, blue: 0.02))
                                    .fontWeight(.bold)
                                Text(line)
                                    .font(.custom("Nunito", size: 15))
                                    .foregroundColor(.black.opacity(0.85))
                                    .lineSpacing(3)
                            }
                        }
                    }
                }
            } else {
                // Render as text with improved readability
                Text(section.content)
                    .font(.custom("Nunito", size: 15))
                    .foregroundColor(.black.opacity(0.85))
                    .lineSpacing(6)
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
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
    
    private func executionScoreBadge(score: Double) -> some View {
        return HStack(spacing: 6) {
            Text("Execution Score:")
                .font(.custom("Nunito", size: 12))
                .fontWeight(.medium)
                .foregroundColor(.black.opacity(0.6))
            Text(String(format: "%.1f/10", score))
                .font(.custom("Nunito", size: 16))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 1, green: 0.42, blue: 0.02))
        }
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
        .cornerRadius(8)
    }
    
    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(red: 1, green: 0.42, blue: 0.02))
            Text(generator.progressMessage)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var emptyStateView: some View {
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
                
                Text("Use the date navigation above to view past entries")
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.05))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
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
    }
    
    // MARK: - History Sidebar
    
    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Journal History")
                .font(.custom("Nunito", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(20)
            
            Divider()
                .background(Color.black.opacity(0.1))
            
            // History list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(generator.journalHistory) { journal in
                        historyItem(journal)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private func historyItem(_ journal: EnhancedDailyJournal) -> some View {
        let isSelected = Calendar.current.isDate(journal.date, inSameDayAs: selectedDate)
        
        return Button(action: {
            selectedDate = journal.date
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(journal.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text(journal.generatedSummary.prefix(60) + "...")
                    .font(.custom("Nunito", size: 11))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
                
                HStack {
                    Text("Score: \(String(format: "%.1f", journal.executionScore))")
                        .font(.custom("Nunito", size: 10))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 1, green: 0.42, blue: 0.02))
                    Spacer()
                    Text("\(journal.sections.count) sections")
                        .font(.custom("Nunito", size: 10))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
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
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
    
    // MARK: - Actions
    
    @MainActor
    private func loadJournal(for date: Date) async {
        // Prevent concurrent loads
        guard !isLoadingJournal else { return }
        
        isLoadingJournal = true
        defer { isLoadingJournal = false }
        
        if let journal = try? await generator.getJournal(for: date) {
            currentJournal = journal
        } else {
            currentJournal = nil
        }
    }
    
    private func changeDate(by days: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            // .task(id: selectedDate) will automatically handle loading
        }
    }
}

struct EnhancedJournalView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedJournalView()
            .frame(width: 1200, height: 800)
    }
}


