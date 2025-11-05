//
//  EnhancedJournalGenerator.swift
//  FocusLock
//
//  AI-powered journal generator that synthesizes daily summaries from activity data
//  with intelligent pattern recognition and executive coaching insights
//

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class EnhancedJournalGenerator: ObservableObject {
    static let shared = EnhancedJournalGenerator()
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var currentProgress: Double = 0.0
    @Published var progressMessage = ""
    @Published var generatedJournal: EnhancedDailyJournal?
    @Published var generationError: Error?
    @Published var journalHistory: [EnhancedDailyJournal] = []
    
    // MARK: - Dependencies
    private let llmService: LLMServicing
    private let storageManager = StorageManager.shared
    private let memoryStore = HybridMemoryStore.shared
    private let logger = Logger(subsystem: "FocusLock", category: "EnhancedJournalGenerator")
    
    // MARK: - Default Section Order
    private let defaultSectionOrder: [JournalSectionType] = [
        .daySummary,
        .unfinishedTasks,
        .summaryPoints,
        .timeline,
        .conversations,
        .planForNextDay,
        .productivity,
        .personalNotes,
        .decisionLog
    ]
    
    private init(llmService: LLMServicing = LLMService.shared) {
        self.llmService = llmService
        loadJournalHistory()
    }
    
    // MARK: - Public Interface
    
    /// Generate a journal for a specific date
    func generateJournal(for date: Date) async throws -> EnhancedDailyJournal {
        isGenerating = true
        generationError = nil
        currentProgress = 0.0
        progressMessage = "Analyzing your day..."
        
        defer {
            isGenerating = false
            currentProgress = 1.0
        }
        
        do {
            // Step 1: Fetch timeline cards for the day
            progressMessage = "Gathering activity data..."
            currentProgress = 0.1
            let timelineCards = await fetchTimelineCardsForDay(date)
            
            guard !timelineCards.isEmpty else {
                throw JournalGenerationError.noActivityData
            }
            
            // Step 2: Analyze patterns
            progressMessage = "Analyzing patterns..."
            currentProgress = 0.3
            let patterns = await analyzeActivityPatterns(timelineCards)
            
            // Step 3: Extract conversations
            progressMessage = "Identifying conversations..."
            currentProgress = 0.4
            let conversations = await extractConversations(from: timelineCards)
            
            // Step 4: Identify unfinished work
            progressMessage = "Detecting unfinished tasks..."
            currentProgress = 0.5
            let unfinishedTasks = await identifyUnfinishedWork(from: timelineCards)
            
            // Step 5: Generate narrative summary using LLM
            progressMessage = "Generating summary..."
            currentProgress = 0.6
            let daySummary = try await generateDaySummary(timelineCards: timelineCards, patterns: patterns)
            
            // Step 6: Generate summary points (wins/losses/surprises)
            progressMessage = "Extracting insights..."
            currentProgress = 0.7
            let summaryPoints = try await generateSummaryPoints(timelineCards: timelineCards, patterns: patterns)
            
            // Step 7: Calculate execution score
            progressMessage = "Calculating execution score..."
            currentProgress = 0.8
            let executionScore = calculateExecutionScore(patterns: patterns)
            
            // Step 8: Build journal sections
            progressMessage = "Assembling journal..."
            currentProgress = 0.9
            let sections = buildJournalSections(
                daySummary: daySummary,
                timeline: timelineCards,
                summaryPoints: summaryPoints,
                conversations: conversations,
                unfinishedTasks: unfinishedTasks,
                patterns: patterns
            )
            
            // Step 9: Create journal
            let metadata = buildMetadata(from: patterns)
            let journal = EnhancedDailyJournal(
                date: date,
                sections: sections,
                generatedSummary: daySummary,
                executionScore: executionScore,
                metadata: metadata
            )
            
            // Step 10: Save to database and memory
            progressMessage = "Saving journal..."
            try await saveJournal(journal)
            
            // Index in memory for RAG
            try await indexJournalInMemory(journal)
            
            generatedJournal = journal
            journalHistory.insert(journal, at: 0)
            
            logger.info("✅ Generated journal for \(date.formatted())")
            return journal
            
        } catch {
            generationError = error
            logger.error("Failed to generate journal: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get journal for a specific date (from cache or database)
    func getJournal(for date: Date) async throws -> EnhancedDailyJournal? {
        // Check cache first
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let cached = journalHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return cached
        }
        
        // Load from database
        return try await loadJournalFromDatabase(for: startOfDay)
    }
    
    /// Regenerate journal for a specific date
    func regenerateJournal(for date: Date) async throws -> EnhancedDailyJournal {
        // Delete existing
        if let existing = try await getJournal(for: date) {
            try await deleteJournal(existing)
        }
        
        // Generate new
        return try await generateJournal(for: date)
    }
    
    // MARK: - Private Methods
    
    private func fetchTimelineCardsForDay(_ date: Date) async -> [TimelineCard] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let dayString = DateFormatter.yyyyMMdd.string(from: startOfDay)
        return storageManager.fetchTimelineCards(forDay: dayString)
    }
    
    private func analyzeActivityPatterns(_ timelineCards: [TimelineCard]) async -> ActivityPatterns {
        var deepWorkMinutes = 0
        var adminWorkMinutes = 0
        var contextSwitchCount = 0
        var distractions: [String: Int] = [:]
        var apps: [String: Int] = [:]
        
        for (index, card) in timelineCards.enumerated() {
            // Calculate duration
            let duration = calculateDuration(from: card.startTimestamp, to: card.endTimestamp)
            
            // Categorize as deep work or admin
            if isDeepWork(card) {
                deepWorkMinutes += duration
            } else {
                adminWorkMinutes += duration
            }
            
            // Count context switches (different category from previous)
            if index > 0 && timelineCards[index - 1].category != card.category {
                contextSwitchCount += 1
            }
            
            // Track distractions
            if let cardDistractions = card.distractions {
                for distraction in cardDistractions {
                    distractions[distraction.title, default: 0] += 1
                }
            }
            
            // Track apps
            if let appSites = card.appSites {
                if let primary = appSites.primary {
                    apps[primary, default: 0] += 1
                }
                if let secondary = appSites.secondary {
                    apps[secondary, default: 0] += 1
                }
            }
        }
        
        let topDistraction = distractions.max(by: { $0.value < $1.value })?.key ?? ""
        let topApps = apps.sorted(by: { $0.value > $1.value }).prefix(5).map { $0.key }
        
        return ActivityPatterns(
            deepWorkMinutes: deepWorkMinutes,
            adminWorkMinutes: adminWorkMinutes,
            contextSwitchCount: contextSwitchCount,
            topDistraction: topDistraction,
            topApps: topApps,
            totalActivities: timelineCards.count
        )
    }
    
    private func isDeepWork(_ card: TimelineCard) -> Bool {
        // Consider work in development tools, design tools, or focused categories as deep work
        let deepWorkCategories = ["Development", "Design", "Writing", "Research", "Learning"]
        let deepWorkKeywords = ["coding", "programming", "designing", "writing", "studying"]
        
        if deepWorkCategories.contains(card.category) {
            return true
        }
        
        let titleLower = card.title.lowercased()
        return deepWorkKeywords.contains { titleLower.contains($0) }
    }
    
    private func calculateDuration(from start: String, to end: String) -> Int {
        // Parse time strings like "2:30 PM" and calculate duration in minutes
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else {
            return 0
        }
        
        let interval = endDate.timeIntervalSince(startDate)
        return max(0, Int(interval / 60))
    }
    
    private func extractConversations(from timelineCards: [TimelineCard]) async -> [ConversationLog] {
        var conversations: [ConversationLog] = []
        
        let conversationKeywords = ["call", "meeting", "chat", "message", "talk", "discuss", "zoom", "facetime"]
        
        for card in timelineCards {
            let titleLower = card.title.lowercased()
            let summaryLower = card.summary.lowercased()
            
            // Check if this is a conversation
            if conversationKeywords.contains(where: { titleLower.contains($0) || summaryLower.contains($0) }) {
                // Try to extract person name from title
                let personName = extractPersonName(from: card.title) ?? "Unknown"
                
                let conversation = ConversationLog(
                    personName: personName,
                    context: card.category,
                    keyPoints: [card.summary],
                    decisions: [],
                    followUps: [],
                    sentiment: nil,
                    conversationDate: Date()
                )
                
                conversations.append(conversation)
            }
        }
        
        return conversations
    }
    
    private func extractPersonName(from title: String) -> String? {
        // Simple pattern matching - could be improved with NLP
        let patterns = [
            "with ([A-Z][a-z]+ [A-Z][a-z]+)",
            "([A-Z][a-z]+ [A-Z][a-z]+) call",
            "([A-Z][a-z]+) -"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
               let range = Range(match.range(at: 1), in: title) {
                return String(title[range])
            }
        }
        
        return nil
    }
    
    private func identifyUnfinishedWork(from timelineCards: [TimelineCard]) async -> [String] {
        var unfinished: [String] = []
        
        // Look for activities that ended abruptly or had many interruptions
        for card in timelineCards {
            let duration = calculateDuration(from: card.startTimestamp, to: card.endTimestamp)
            
            // Short duration might indicate interrupted work
            if duration < 15 && duration > 0 {
                unfinished.append("Complete: \(card.title)")
            }
            
            // Check for explicit "started" or "began" without "finished"
            let summaryLower = card.summary.lowercased()
            if (summaryLower.contains("start") || summaryLower.contains("began")) && !summaryLower.contains("finish") {
                unfinished.append(card.title)
            }
        }
        
        return Array(Set(unfinished)).prefix(10).map { $0 }
    }
    
    private func generateDaySummary(timelineCards: [TimelineCard], patterns: ActivityPatterns) async throws -> String {
        // Build context for LLM
        let activitiesSummary = timelineCards.prefix(20).map { "- \($0.startTimestamp)-\($0.endTimestamp): \($0.title) (\($0.category))" }.joined(separator: "\n")
        
        let prompt = """
        You are an AI executive coach synthesizing a daily summary. Write a compelling narrative summary of the user's day based on their activities.
        
        Activities:
        \(activitiesSummary)
        
        Stats:
        - Deep work: \(patterns.deepWorkMinutes) minutes
        - Admin work: \(patterns.adminWorkMinutes) minutes
        - Context switches: \(patterns.contextSwitchCount)
        - Total activities: \(patterns.totalActivities)
        
        Write a 2-3 paragraph summary that:
        1. Opens with a vivid description of the day's theme or mood
        2. Highlights major focus areas and accomplishments
        3. Notes any challenges or blockers encountered
        
        Be direct, specific, and use a conversational tone. Avoid generic phrases.
        """
        
        let response = try await llmService.generateText(prompt: prompt, systemPrompt: "You are an executive coach writing daily summaries.")
        return response
    }
    
    private func generateSummaryPoints(timelineCards: [TimelineCard], patterns: ActivityPatterns) async throws -> String {
        let activitiesSummary = timelineCards.prefix(15).map { "\($0.title): \($0.summary)" }.joined(separator: "\n")
        
        let prompt = """
        Based on this day's activities, identify:
        
        **Win:** The biggest accomplishment or breakthrough
        **Loss:** The main challenge, blocker, or setback
        **Surprise:** Something unexpected discovered or learned
        **Progress:** Overall momentum on key projects
        
        Activities:
        \(activitiesSummary)
        
        Be specific and concrete. Reference actual work done.
        """
        
        let response = try await llmService.generateText(prompt: prompt, systemPrompt: "You are analyzing daily work patterns.")
        return response
    }
    
    private func calculateExecutionScore(patterns: ActivityPatterns) -> Double {
        var score: Double = 5.0 // Base score
        
        // Reward deep work (max +2.5)
        let deepWorkHours = Double(patterns.deepWorkMinutes) / 60.0
        score += min(2.5, deepWorkHours * 0.5)
        
        // Penalize excessive context switching (max -2.0)
        let switchPenalty = min(2.0, Double(patterns.contextSwitchCount) * 0.15)
        score -= switchPenalty
        
        // Reward high activity count (engagement) (max +1.0)
        score += min(1.0, Double(patterns.totalActivities) / 30.0)
        
        // Penalize if mostly admin work
        let adminPercentage = Double(patterns.adminWorkMinutes) / Double(patterns.deepWorkMinutes + patterns.adminWorkMinutes)
        if adminPercentage > 0.7 {
            score -= 1.0
        }
        
        return max(0, min(10, score))
    }
    
    private func buildJournalSections(
        daySummary: String,
        timeline: [TimelineCard],
        summaryPoints: String,
        conversations: [ConversationLog],
        unfinishedTasks: [String],
        patterns: ActivityPatterns
    ) -> [JournalSection] {
        var sections: [JournalSection] = []
        var order = 0
        
        // Day Summary
        sections.append(JournalSection(
            type: .daySummary,
            title: JournalSectionType.daySummary.displayName,
            content: daySummary,
            order: order
        ))
        order += 1
        
        // Unfinished Tasks
        let unfinishedContent = unfinishedTasks.isEmpty ? "No unfinished tasks detected." : unfinishedTasks.map { "• \($0)" }.joined(separator: "\n")
        sections.append(JournalSection(
            type: .unfinishedTasks,
            title: JournalSectionType.unfinishedTasks.displayName,
            content: unfinishedContent,
            order: order
        ))
        order += 1
        
        // Summary Points
        sections.append(JournalSection(
            type: .summaryPoints,
            title: JournalSectionType.summaryPoints.displayName,
            content: summaryPoints,
            order: order
        ))
        order += 1
        
        // Timeline
        let timelineContent = timeline.map { card in
            "\(card.startTimestamp) - \(card.endTimestamp): **\(card.title)**\n\(card.summary)"
        }.joined(separator: "\n\n")
        sections.append(JournalSection(
            type: .timeline,
            title: JournalSectionType.timeline.displayName,
            content: timelineContent,
            order: order
        ))
        order += 1
        
        // Conversations
        let conversationsContent = conversations.isEmpty ? "No significant conversations detected." : conversations.map { conv in
            "**\(conv.personName):**\n" + conv.keyPoints.map { "• \($0)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")
        sections.append(JournalSection(
            type: .conversations,
            title: JournalSectionType.conversations.displayName,
            content: conversationsContent,
            order: order
        ))
        order += 1
        
        // Productivity
        let totalMinutes = patterns.deepWorkMinutes + patterns.adminWorkMinutes
        let deepWorkPercent = totalMinutes > 0 ? (Double(patterns.deepWorkMinutes) / Double(totalMinutes) * 100) : 0
        let productivityContent = """
        **Deep Work:** \(patterns.deepWorkMinutes) minutes (\(String(format: "%.1f", deepWorkPercent))%)
        **Admin Work:** \(patterns.adminWorkMinutes) minutes
        **Context Switches:** \(patterns.contextSwitchCount)
        **Top Distraction:** \(patterns.topDistraction)
        """
        sections.append(JournalSection(
            type: .productivity,
            title: JournalSectionType.productivity.displayName,
            content: productivityContent,
            order: order
        ))
        
        return sections
    }
    
    private func buildMetadata(from patterns: ActivityPatterns) -> JournalMetadata {
        let totalMinutes = patterns.deepWorkMinutes + patterns.adminWorkMinutes
        let timeOnP1 = totalMinutes > 0 ? (Double(patterns.deepWorkMinutes) / Double(totalMinutes)) : 0
        
        return JournalMetadata(
            deepWorkMinutes: patterns.deepWorkMinutes,
            adminWorkMinutes: patterns.adminWorkMinutes,
            contextSwitchCount: patterns.contextSwitchCount,
            energyLevel: 5.0,
            timeOnP1Tasks: timeOnP1,
            topDistraction: patterns.topDistraction,
            activitiesCount: patterns.totalActivities,
            conversationsCount: 0,
            decisionsCount: 0
        )
    }
    
    private func saveJournal(_ journal: EnhancedDailyJournal) async throws {
        // Save to database
        _ = try storageManager.saveJournal(journal)
        
        // Update cache
        if let index = journalHistory.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: journal.date) }) {
            journalHistory[index] = journal
        } else {
            journalHistory.insert(journal, at: 0)
        }
        
        // Keep only last 90 days in memory
        journalHistory = Array(journalHistory.prefix(90))
    }
    
    private func indexJournalInMemory(_ journal: EnhancedDailyJournal) async throws {
        // Index journal content in memory store for RAG
        for section in journal.sections {
            let content = "\(section.title): \(section.content)"
            let metadata: [String: Any] = [
                "date": journal.date,
                "section_type": section.type.rawValue,
                "journal_id": journal.id.uuidString
            ]
            
            let memoryItem = MemoryItem(
                content: content,
                source: .journal,
                metadata: metadata
            )
            
            try await memoryStore.index(memoryItem)
        }
    }
    
    private func loadJournalHistory() {
        // Load recent journals from database
        do {
            journalHistory = try storageManager.fetchJournals(limit: 90)
        } catch {
            logger.error("Failed to load journal history: \(error.localizedDescription)")
            journalHistory = []
        }
    }
    
    private func loadJournalFromDatabase(for date: Date) async throws -> EnhancedDailyJournal? {
        return try storageManager.loadJournal(forDate: date)
    }
    
    private func deleteJournal(_ journal: EnhancedDailyJournal) async throws {
        // Delete from database
        try storageManager.deleteJournal(id: journal.id)
        
        // Remove from cache
        journalHistory.removeAll { $0.id == journal.id }
    }
}

// MARK: - Supporting Types

struct ActivityPatterns {
    let deepWorkMinutes: Int
    let adminWorkMinutes: Int
    let contextSwitchCount: Int
    let topDistraction: String
    let topApps: [String]
    let totalActivities: Int
}

enum JournalGenerationError: LocalizedError {
    case noActivityData
    case llmGenerationFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noActivityData:
            return "No activity data available for this date"
        case .llmGenerationFailed:
            return "Failed to generate journal content"
        case .saveFailed:
            return "Failed to save journal"
        }
    }
}

