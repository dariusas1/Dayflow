//
//  DailyJournalGenerator.swift
//  FocusLock
//
//  AI-powered daily journal generator with intelligent synthesis
//  and personalized content creation
//

import Foundation
import SwiftUI
import Combine
import os.log

private enum DailyJournalGenerationError: LocalizedError {
    case failedToGenerateResponse
    case contextDataUnavailable
    case templateError

    var errorDescription: String? {
        switch self {
        case .failedToGenerateResponse:
            return "Failed to generate journal response"
        case .contextDataUnavailable:
            return "Context data is unavailable"
        case .templateError:
            return "Template error occurred"
        }
    }
}

@MainActor
class DailyJournalGenerator: ObservableObject {
    static let shared = DailyJournalGenerator()

    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var currentProgress: Double = 0.0
    @Published var progressMessage = ""
    @Published var generatedJournal: DailyJournal?
    @Published var generationError: Error?

    // MARK: - Dependencies
    private let jarvisChat = JarvisChat.shared
    private let sessionManager = SessionManager.shared
    private let settingsManager = FocusLockSettingsManager.shared
    private let logger = Logger(subsystem: "FocusLock", category: "DailyJournalGenerator")

    // MARK: - User Learning
    private var userLearningData: UserLearningData = UserLearningData()
    private var lastGenerationDate: Date?
    
    // MARK: - Automatic Generation
    private var midnightTimer: Timer?
    private var lastAutoGenerationDate: Date?

    // MARK: - Templates and Prompts
    private let templatePrompts: [JournalTemplate: String] = [
        .reflective: """
        Create a reflective journal entry that helps the user understand their day more deeply.
        Focus on insights, patterns, and personal growth moments. Use a thoughtful, introspective tone.
        """,

        .achievement: """
        Create an achievement-focused journal entry that celebrates progress and wins.
        Highlight accomplishments, milestones reached, and positive outcomes. Use an encouraging, motivating tone.
        """,

        .gratitude: """
        Create a gratitude-focused journal entry that emphasizes appreciation and positive aspects.
        Focus on things to be grateful for, positive interactions, and joyful moments. Use a warm, appreciative tone.
        """,

        .growth: """
        Create a growth-oriented journal entry that focuses on learning and development.
        Highlight lessons learned, challenges overcome, and skills improved. Use an inspiring, developmental tone.
        """,

        .comprehensive: """
        Create a comprehensive journal entry that covers all aspects of the day.
        Include achievements, challenges, learning moments, gratitude, and insights. Use a balanced, holistic tone.
        """,

        .custom: """
        Create a personalized journal entry based on the user's preferences and focus areas.
        Adapt the tone and content to match their stated interests and engagement patterns.
        """
    ]

    // MARK: - Initialization
    private init() {
        loadUserLearningData()
        startMidnightTimer()
    }
    
    deinit {
        midnightTimer?.invalidate()
        midnightTimer = nil
    }

    // MARK: - Public Methods

    /// Generate a daily journal entry based on user's activities and preferences
    func generateJournal(
        for date: Date = Date(),
        template: JournalTemplate = .comprehensive,
        preferences: JournalPreferences? = nil
    ) async {
        await MainActor.run {
            isGenerating = true
            currentProgress = 0.0
            progressMessage = "Starting journal generation..."
            generationError = nil
        }

        do {
            let prefs = preferences ?? loadOrCreatePreferences()
            let journal = try await performJournalGeneration(
                for: date,
                template: template,
                preferences: prefs
            )

            await MainActor.run {
                generatedJournal = journal
                currentProgress = 1.0
                progressMessage = "Journal generated successfully"
                isGenerating = false

                // Update user learning data
                updateUserLearningData(with: journal, engagement: .completed)
                saveUserLearningData()
            }

        } catch {
            await MainActor.run {
                generationError = error
                progressMessage = "Generation failed: \(error.localizedDescription)"
                isGenerating = false

                // Update learning data with failure
                updateUserLearningData(with: nil, engagement: .abandoned)
            }

            logger.error("Journal generation failed: \(error.localizedDescription)")
        }
    }

    /// Generate journal with enhanced highlights extraction
    func generateJournalWithHighlights(
        for date: Date = Date(),
        template: JournalTemplate,
        preferences: JournalPreferences
    ) async {
        await MainActor.run {
            isGenerating = true
            currentProgress = 0.1
            progressMessage = "Analyzing daily activities..."
        }

        do {
            // Step 1: Extract highlights from activities and memories
            let highlights = try await extractHighlights(for: date, preferences: preferences)

            await MainActor.run {
                currentProgress = 0.4
                progressMessage = "Synthesizing insights..."
            }

            // Step 2: Generate content based on highlights and template
            let content = try await generateContent(
                for: date,
                template: template,
                preferences: preferences,
                highlights: highlights
            )

            await MainActor.run {
                currentProgress = 0.7
                progressMessage = "Creating journal entry..."
            }

            // Step 3: Analyze sentiment
            let sentiment = await analyzeSentiment(content: content)

            // Step 4: Create final journal
            let journal = DailyJournal(
                date: date,
                content: content,
                template: template,
                highlights: highlights,
                sentiment: sentiment,
                userPreferences: preferences
            )

            await MainActor.run {
                generatedJournal = journal
                currentProgress = 1.0
                progressMessage = "Journal completed successfully"
                isGenerating = false

                updateUserLearningData(with: journal, engagement: .completed)
                saveUserLearningData()
            }

        } catch {
            await MainActor.run {
                generationError = error
                progressMessage = "Generation failed: \(error.localizedDescription)"
                isGenerating = false
            }

            logger.error("Enhanced journal generation failed: \(error.localizedDescription)")
        }
    }

    /// Regenerate journal with different template or preferences
    func regenerateJournal(
        with template: JournalTemplate,
        preferences: JournalPreferences
    ) async {
        guard let journal = generatedJournal else {
            await generateJournal(template: template, preferences: preferences)
            return
        }

        await generateJournalWithHighlights(
            for: journal.date,
            template: template,
            preferences: preferences
        )
    }

    // MARK: - Private Methods

    /// Perform the complete journal generation process
    private func performJournalGeneration(
        for date: Date,
        template: JournalTemplate,
        preferences: JournalPreferences
    ) async throws -> DailyJournal {

        // Step 1: Gather context data
        await MainActor.run {
            currentProgress = 0.1
            progressMessage = "Gathering daily context..."
        }

        let contextData = try await gatherContextData(for: date)

        // Step 2: Extract meaningful highlights
        await MainActor.run {
            currentProgress = 0.3
            progressMessage = "Identifying key moments..."
        }

        let highlights = try await extractHighlightsFromContext(contextData, preferences: preferences)

        // Step 3: Generate journal content
        await MainActor.run {
            currentProgress = 0.6
            progressMessage = "Crafting journal entry..."
        }

        let content = try await generateJournalContent(
            context: contextData,
            highlights: highlights,
            template: template,
            preferences: preferences
        )

        // Step 4: Analyze sentiment
        await MainActor.run {
            currentProgress = 0.8
            progressMessage = "Analyzing emotional patterns..."
        }

        let sentiment = await analyzeSentiment(content: content)

        // Step 5: Create final journal entry
        await MainActor.run {
            currentProgress = 0.9
            progressMessage = "Finalizing journal..."
        }

        let journal = DailyJournal(
            date: date,
            content: content,
            template: template,
            highlights: highlights,
            sentiment: sentiment,
            userPreferences: preferences
        )

        return journal
    }

    /// Gather context data from various sources
    private func gatherContextData(for date: Date) async throws -> JournalContextData {
        let calendar = Calendar.current

        // Get session data for the day
        let sessions = await getSessionsForDay(date)

        // Get activity data from ActivityTap
        let activities = await getActivitiesForDay(date)

        // Get relevant memories from MemoryStore
        let memories = try await getRelevantMemories(for: date)

        // Get user preferences and patterns
        let userPatterns = Dictionary(
            uniqueKeysWithValues: userLearningData.engagementPatterns.map { pattern in
                (pattern.template.rawValue, pattern.avgEngagementScore)
            }
        )

        return JournalContextData(
            date: date,
            sessions: sessions,
            activities: activities,
            memories: memories,
            userPatterns: userPatterns,
            weather: await getWeatherForDay(date), // Optional enhancement
            dayOfWeek: calendar.component(.weekday, from: date),
            isWeekend: calendar.component(.weekday, from: date) >= 6 // Saturday=7, Sunday=1
        )
    }

    /// Extract highlights from context data
    private func extractHighlightsFromContext(
        _ contextData: JournalContextData,
        preferences: JournalPreferences
    ) async throws -> [JournalHighlight] {
        var highlights: [JournalHighlight] = []

        // Extract from focus sessions
        for session in contextData.sessions {
            if let summary = sessionManager.lastSessionSummary {
                let sessionHighlight = JournalHighlight(
                    id: UUID(),
                    title: "Focus Session: \(session.taskName)",
                    content: "Completed focus session with duration \(summary.durationFormatted)",
                    category: .achievement,
                    significance: calculateSignificance(session: session, preferences: preferences),
                    timestamp: session.startTime
                )
                highlights.append(sessionHighlight)
            }
        }

        // Extract from activities (achievements, challenges, learning)
        for activity in contextData.activities {
            let significance = calculateSignificance(activity: activity, preferences: preferences)

            if significance > 0.3 { // Only include significant activities
                let category = determineCategory(for: activity)
                let highlight = JournalHighlight(
                    id: UUID(),
                    title: activity.title,
                    content: activity.description,
                    category: category,
                    significance: significance,
                    timestamp: activity.timestamp
                )
                highlights.append(highlight)
            }
        }

        // Extract from memories (insights, gratitude)
        for memory in contextData.memories.prefix(3) {
            let highlight = JournalHighlight(
                id: UUID(),
                title: "Memory: \(memory.title)",
                content: memory.content,
                category: .insight,
                significance: 0.7,
                timestamp: memory.timestamp
            )
            highlights.append(highlight)
        }

        // Sort by significance and limit to top highlights
        highlights.sort { $0.significance > $1.significance }
        return Array(highlights.prefix(5))
    }

    /// Generate journal content using AI
    private func generateJournalContent(
        context: JournalContextData,
        highlights: [JournalHighlight],
        template: JournalTemplate,
        preferences: JournalPreferences
    ) async throws -> String {

        let prompt = createGenerationPrompt(
            context: context,
            highlights: highlights,
            template: template,
            preferences: preferences
        )

        // Use JarvisChat for AI generation
        await jarvisChat.sendMessage(prompt)

        // Get the last message from current conversation
        guard let lastMessage = jarvisChat.currentConversation?.messages.last,
              lastMessage.role == .assistant else {
            throw DailyJournalGenerationError.failedToGenerateResponse
        }

        return lastMessage.content
    }

    /// Create the generation prompt
    private func createGenerationPrompt(
        context: JournalContextData,
        highlights: [JournalHighlight],
        template: JournalTemplate,
        preferences: JournalPreferences
    ) -> String {

        var prompt = """
        Generate a personalized journal entry for \(context.date.formatted(date: .abbreviated, time: .omitted)) using the \(template.rawValue) template.

        User Preferences:
        - Focus Areas: \(preferences.focusAreas.map(\.rawValue).joined(separator: ", "))
        - Length: \(preferences.lengthPreference.rawValue)
        - Tone: \(preferences.tonePreference.rawValue)
        - Include Questions: \(preferences.includeQuestions ? "Yes" : "No")

        Key Highlights from the Day:
        """

        for highlight in highlights {
            prompt += "\n- \(highlight.title): \(highlight.content)"
        }

        prompt += "\n\nSession Summary:\n"
        if let summary = sessionManager.lastSessionSummary {
            prompt += "- Total focus time: \(summary.durationFormatted)\n"
            prompt += "- Session completed: \(summary.isCompleted ? "Yes" : "No")\n"
        }

        prompt += "\n\nTemplate Guidance:\n\(templatePrompts[template] ?? "")"

        if preferences.includeQuestions {
            prompt += "\n\nEnd with 2-3 reflective questions based on the day's events."
        }

        return prompt
    }

    /// Analyze sentiment of generated content
    private func analyzeSentiment(content: String) async -> SentimentAnalysis {
        // Simple sentiment analysis (can be enhanced with actual NLP)
        let positiveWords = ["accomplished", "successful", "grateful", "happy", "productive", "focused", "achieved", "completed", "learned"]
        let negativeWords = ["failed", "frustrated", "difficult", "challenging", "struggled", "tired", "overwhelmed"]

        let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let positiveCount = words.filter { positiveWords.contains($0) }.count
        let negativeCount = words.filter { negativeWords.contains($0) }.count
        let totalSentimentWords = positiveCount + negativeCount

        let sentimentScore = totalSentimentWords > 0 ?
            Double(positiveCount - negativeCount) / Double(totalSentimentWords) : 0.1

        let overallSentiment: SentimentScore
        switch sentimentScore {
        case 0.3...: overallSentiment = SentimentScore(emotion: "positive", score: sentimentScore)
        case -0.3..<0.3: overallSentiment = SentimentScore(emotion: "neutral", score: sentimentScore)
        default: overallSentiment = SentimentScore(emotion: "negative", score: sentimentScore)
        }

        let emotions = analyzeEmotions(in: content)

        return SentimentAnalysis(
            overallSentiment: overallSentiment,
            emotionalBreakdown: emotions,
            confidence: 0.75,
            keyEmotions: extractKeywords(content: content)
        )
    }

    // MARK: - Data Gathering Methods

    private func getSessionsForDay(_ date: Date) async -> [FocusSession] {
        // Get sessions from SessionManager for the specific day
        return sessionManager.currentSession != nil ? [sessionManager.currentSession!] : []
    }

    private func getActivitiesForDay(_ date: Date) async -> [ActivityRecord] {
        // Integrate with ActivityTap to get activity data for the day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Get activity history from ActivityTap for the day
        let activities = ActivityTap.shared.getActivityHistory(since: startOfDay, limit: 1000)
            .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        
        // Convert Activity to ActivityRecord
        return activities.map { activity in
            ActivityRecord(
                id: activity.id,
                title: activity.fusionResult.context.isEmpty ? "Activity" : activity.fusionResult.context,
                description: activity.windowInfo.title.isEmpty ? activity.windowInfo.bundleIdentifier : activity.windowInfo.title,
                category: mapActivityCategory(activity.fusionResult.primaryCategory),
                timestamp: activity.timestamp,
                duration: activity.duration
            )
        }
    }
    
    private func mapActivityCategory(_ category: String) -> ActivityCategory {
        let lowercased = category.lowercased()
        
        if lowercased.contains("work") || lowercased.contains("code") || lowercased.contains("productivity") {
            return .work
        } else if lowercased.contains("health") || lowercased.contains("exercise") || lowercased.contains("fitness") {
            return .health
        } else if lowercased.contains("learn") || lowercased.contains("study") || lowercased.contains("education") {
            return .learning
        } else if lowercased.contains("social") || lowercased.contains("message") || lowercased.contains("chat") {
            return .social
        } else if lowercased.contains("leisure") || lowercased.contains("entertainment") || lowercased.contains("game") {
            return .leisure
        } else {
            return .other
        }
    }

    private func getRelevantMemories(for date: Date) async throws -> [MemoryRecord] {
        // Use MemoryStore to get relevant memories for the day
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let query = "activities experiences memories \(dateFormatter.string(from: date))"
        
        // Use hybrid search to get relevant memories
        let searchResults = try await HybridMemoryStore.shared.hybridSearch(query, limit: 10)

        // Convert MemorySearchResult to MemoryRecord, filtering by relevance date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return searchResults
            .filter { result in
                let itemDate = result.item.timestamp
                return itemDate >= startOfDay && itemDate < endOfDay
            }
            .map { result in
                MemoryRecord(
                    id: result.id,
                    title: "Memory from \(dateFormatter.string(from: result.item.timestamp))",
                    content: result.item.content,
                    timestamp: result.item.timestamp,
                    relevance: result.score
                )
            }
    }

    private func getWeatherForDay(_ date: Date) async -> String? {
        // Optional: Add weather integration
        return nil
    }

    // MARK: - Helper Methods

    private func calculateSignificance(session: FocusSession, preferences: JournalPreferences) -> Double {
        let duration = session.duration
        let baseSignificance = min(duration / 3600.0, 1.0) // Normalize to 0-1 based on hours

        // Boost if focus areas match
        let focusMatch = preferences.focusAreas.contains(.productivity) ? 1.2 : 1.0

        return min(baseSignificance * focusMatch, 1.0)
    }

    private func calculateSignificance(activity: ActivityRecord, preferences: JournalPreferences) -> Double {
        // Calculate significance based on activity properties and user preferences
        var significance: Double = 0.5 // Base significance

        // Boost based on focus areas
        if preferences.focusAreas.contains(.health) && activity.category == .health {
            significance += 0.3
        }
        if preferences.focusAreas.contains(.productivity) && activity.category == .work {
            significance += 0.3
        }

        return min(significance, 1.0)
    }

    private func determineCategory(for activity: ActivityRecord) -> JournalHighlight.HighlightCategory {
        // Determine highlight category based on activity type
        switch activity.category {
        case .work:
            return .achievement
        case .health:
            return .gratitude
        case .learning:
            return .learning
        case .social:
            return .gratitude
        default:
            return .insight
        }
    }

    private func analyzeEmotions(in content: String) -> [EmotionScore] {
        // Simple emotion analysis (can be enhanced)
        let emotionWords: [EmotionType: [String]] = [
            .happy: ["happy", "joyful", "excited", "pleased", "grateful"],
            .calm: ["calm", "peaceful", "relaxed", "serene", "tranquil"],
            .excited: ["excited", "enthusiastic", "energetic", "thrilled"],
            .grateful: ["grateful", "thankful", "appreciative", "blessed"],
            .proud: ["accomplished", "achieved", "completed", "successful", "proud"],
            .frustrated: ["challenged", "difficult", "hard", "struggled", "frustrated"]
        ]

        var emotionScores: [EmotionScore] = []
        let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for (emotion, keywords) in emotionWords {
            let count = words.filter { keywords.contains($0) }.count
            let score = Double(count) / Double(words.count)

            if score > 0 {
                emotionScores.append(EmotionScore(
                    emotion: emotion.rawValue,
                    score: min(score * 10, 1.0),
                    intensity: min(score * 10, 1.0)
                ))
            }
        }

        return emotionScores.sorted { $0.intensity > $1.intensity }
    }

    private func extractKeywords(content: String) -> [String] {
        // Extract key keywords from content
        let words = content.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }

        // Simple frequency-based keyword extraction
        let wordFrequencies = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }

        return Array(wordFrequencies)
    }

    // MARK: - User Learning Management

    private func loadOrCreatePreferences() -> JournalPreferences {
        // Load from UserDefaults or create default
        if let data = UserDefaults.standard.data(forKey: "JournalPreferences"),
           let preferences = try? JSONDecoder().decode(JournalPreferences.self, from: data) {
            return preferences
        }

        return JournalPreferences()
    }

    private func loadUserLearningData() {
        if let data = UserDefaults.standard.data(forKey: "JournalUserLearningData"),
           let learningData = try? JSONDecoder().decode(UserLearningData.self, from: data) {
            userLearningData = learningData
        }
    }

    // MARK: - Automatic Generation
    
    func startMidnightTimer() {
        stopMidnightTimer()
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        guard let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) else {
            logger.error("Failed to calculate next midnight")
            return
        }
        
        let timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        
        // Schedule timer for next midnight
        // No DispatchQueue.main.async needed - we're already @MainActor isolated
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleMidnightGeneration()
                
                // Schedule recurring daily timer after first generation
                self?.scheduleRecurringMidnightTimer()
            }
        }
        
        logger.info("Midnight auto-generation timer scheduled for \(nextMidnight)")
    }
    
    func stopMidnightTimer() {
        midnightTimer?.invalidate()
        midnightTimer = nil
    }
    
    private func scheduleRecurringMidnightTimer() {
        stopMidnightTimer()
        
        // Recurring timer fires every 24 hours at midnight
        let calendar = Calendar.current
        let now = Date()
        
        guard let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) else {
            return
        }
        
        let interval: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
        let timeUntilMidnight = nextMidnight.timeIntervalSince(now)
        
        // Use Task.sleep for delay instead of DispatchQueue - we're already @MainActor isolated
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Wait until midnight
            try? await Task.sleep(nanoseconds: UInt64(timeUntilMidnight * 1_000_000_000))
            
            // First generation at midnight
            await self.handleMidnightGeneration()
            
            // Then set up recurring timer for daily generation
            self.midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleMidnightGeneration()
                }
            }
        }
    }
    
    private func handleMidnightGeneration() async {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        // Check if we've already generated for yesterday
        if let lastDate = lastAutoGenerationDate, calendar.isDate(lastDate, inSameDayAs: yesterday) {
            logger.info("Journal already auto-generated for \(yesterday), skipping")
            return
        }
        
        logger.info("Auto-generating journal for yesterday: \(yesterday)")
        
        let preferences = loadOrCreatePreferences()
        
        // Generate journal for yesterday with comprehensive template
        await generateJournal(
            for: yesterday,
            template: .comprehensive,
            preferences: preferences
        )
        
        lastAutoGenerationDate = yesterday
        logger.info("Auto-generation completed for \(yesterday)")
    }
    
    private func saveUserLearningData() {
        if let data = try? JSONEncoder().encode(userLearningData) {
            UserDefaults.standard.set(data, forKey: "JournalUserLearningData")
        }
    }

    private func updateUserLearningData(with journal: DailyJournal?, engagement: JournalEngagement) {
        if let journal = journal {
            // Find existing engagement pattern for this template or create new one
            if let existingIndex = userLearningData.engagementPatterns.firstIndex(where: { $0.template == journal.template }) {
                // Update existing pattern - increment usage count
                userLearningData.engagementPatterns[existingIndex] = EngagementPattern(
                    template: journal.template,
                    avgEngagementScore: userLearningData.engagementPatterns[existingIndex].avgEngagementScore,
                    usageCount: userLearningData.engagementPatterns[existingIndex].usageCount + 1,
                    lastUsed: Date()
                )
            } else {
                // Create new engagement pattern
                let newPattern = EngagementPattern(
                    template: journal.template,
                    avgEngagementScore: 0.5, // Default engagement score
                    usageCount: 1,
                    lastUsed: Date()
                )
                userLearningData.engagementPatterns.append(newPattern)
            }

            // Record this interaction
            let interaction = JournalInteraction(
                journalId: journal.id,
                engagementScore: engagement == .completed ? 1.0 : (engagement == .partial ? 0.7 : 0.3),
                actions: [],
                feedback: nil
            )
            userLearningData.recordInteraction(interaction)
        }
    }

    // MARK: - Enhanced Generation Methods

    private func extractHighlights(for date: Date, preferences: JournalPreferences) async throws -> [JournalHighlight] {
        let contextData = try await gatherContextData(for: date)
        return try await extractHighlightsFromContext(contextData, preferences: preferences)
    }

    private func generateContent(
        for date: Date,
        template: JournalTemplate,
        preferences: JournalPreferences,
        highlights: [JournalHighlight]
    ) async throws -> String {
        let context = JournalContextData(
            date: date,
            sessions: await getSessionsForDay(date),
            activities: await getActivitiesForDay(date),
            memories: try await getRelevantMemories(for: date),
            userPatterns: Dictionary(
                uniqueKeysWithValues: userLearningData.engagementPatterns.map { pattern in
                    (pattern.template.rawValue, pattern.avgEngagementScore)
                }
            ),
            weather: nil as String?,
            dayOfWeek: Calendar.current.component(.weekday, from: date),
            isWeekend: Calendar.current.component(.weekday, from: date) >= 6
        )

        return try await generateJournalContent(
            context: context,
            highlights: highlights,
            template: template,
            preferences: preferences
        )
    }
}

// MARK: - Supporting Models

private struct JournalContextData {
    let date: Date
    let sessions: [FocusSession]
    let activities: [ActivityRecord]
    let memories: [MemoryRecord]
    let userPatterns: [String: Double]
    let weather: String?
    let dayOfWeek: Int
    let isWeekend: Bool
}

// MARK: - Activity Record Model (integrated with ActivityTap)
private struct ActivityRecord {
    let id: UUID
    let title: String
    let description: String
    let category: ActivityCategory
    let timestamp: Date
    let duration: TimeInterval?
    
    init(id: UUID, title: String, description: String, category: ActivityCategory, timestamp: Date, duration: TimeInterval?) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.timestamp = timestamp
        self.duration = duration
    }
}

private enum ActivityCategory {
    case work, health, learning, social, leisure, other
}

// MARK: - Memory Record Model (integrated with MemoryStore)
private struct MemoryRecord {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
    let relevance: Double
    
    init(id: UUID, title: String, content: String, timestamp: Date, relevance: Double) {
        self.id = id
        self.title = title
        self.content = content
        self.timestamp = timestamp
        self.relevance = relevance
    }
}
