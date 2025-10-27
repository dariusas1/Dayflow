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
    private let memoryStore = MemoryStore.shared
    private let sessionManager = SessionManager.shared
    private let settingsManager = SettingsManager.shared
    private let logger = Logger(subsystem: "FocusLock", category: "DailyJournalGenerator")

    // MARK: - User Learning
    private var userLearningData: UserLearningData = UserLearningData()
    private var lastGenerationDate: Date?

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
                id: UUID(),
                date: date,
                content: content,
                template: template,
                highlights: highlights,
                sentimentAnalysis: sentiment,
                userPreferences: preferences,
                createdAt: Date(),
                updatedAt: Date()
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
            id: UUID(),
            date: date,
            content: content,
            template: template,
            highlights: highlights,
            sentimentAnalysis: sentiment,
            userPreferences: preferences,
            createdAt: Date(),
            updatedAt: Date()
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
        let userPatterns = userLearningData.engagementPatterns

        return JournalContextData(
            date: date,
            sessions: sessions,
            activities: activities,
            memories: memories,
            userPatterns: userPatterns,
            weather: await getWeatherForDay(date), // Optional enhancement
            dayOfWeek: calendar.component(.weekday, from: date),
            isWeekend: calendar.isWeekend(date)
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
                    category: .achievement,
                    title: "Focus Session: \(session.taskName)",
                    description: "Completed focus session with duration \(summary.durationFormatted)",
                    significance: calculateSignificance(session: session, preferences: preferences),
                    relatedActivities: [],
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
                    category: category,
                    title: activity.title,
                    description: activity.description,
                    significance: significance,
                    relatedActivities: [activity.id],
                    timestamp: activity.timestamp
                )
                highlights.append(highlight)
            }
        }

        // Extract from memories (insights, gratitude)
        for memory in contextData.memories.prefix(3) {
            let highlight = JournalHighlight(
                id: UUID(),
                category: .insight,
                title: "Memory: \(memory.title)",
                description: memory.content,
                significance: 0.7,
                relatedActivities: [],
                timestamp: memory.timestamp
            )
            highlights.append(highlight)
        }

        // Sort by significance and limit to top highlights
        highlights.sort { $0.significance > $1.significance }
        return Array(highlights.prefix(preferences.maxHighlights))
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
        let response = try await jarvisChat.sendMessage(
            prompt,
            systemMessage: "You are an empathetic AI journal assistant that creates personalized, meaningful journal entries. Focus on insights, growth, and authentic reflection."
        )

        return response.content
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
        - Length: \(preferences.length.rawValue)
        - Tone: \(preferences.tone.rawValue)
        - Include Questions: \(preferences.includeQuestions ? "Yes" : "No")

        Key Highlights from the Day:
        """

        for highlight in highlights {
            prompt += "\n- \(highlight.title): \(highlight.description)"
        }

        prompt += "\n\nSession Summary:\n"
        if let summary = sessionManager.lastSessionSummary {
            prompt += "- Total focus time: \(summary.durationFormatted)\n"
            prompt += "- Sessions completed: \(summary.sessionCount)\n"
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
        case 0.3...: overallSentiment = .positive
        case -0.3..<0.3: overallSentiment = .neutral
        default: overallSentiment = .negative
        }

        let emotions = analyzeEmotions(in: content)

        return SentimentAnalysis(
            overallSentiment: overallSentiment,
            sentimentScore: sentimentScore,
            emotionScores: emotions,
            confidence: 0.75,
            keywords: extractKeywords(content: content)
        )
    }

    // MARK: - Data Gathering Methods

    private func getSessionsForDay(_ date: Date) async -> [FocusSession] {
        // Get sessions from SessionManager for the specific day
        return sessionManager.currentSession != nil ? [sessionManager.currentSession!] : []
    }

    private func getActivitiesForDay(_ date: Date) async -> [ActivityRecord] {
        // This would integrate with ActivityTap data
        // For now, return empty array
        return []
    }

    private func getRelevantMemories(for date: Date) async throws -> [MemoryRecord] {
        // Use MemoryStore to get relevant memories for the day
        let query = "activities experiences memories \(date.formatted(date: .abbreviated))"
        return try await memoryStore.search(query, limit: 5)
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
        if preferences.focusAreas.contains(.wellbeing) && activity.category == .health {
            significance += 0.3
        }
        if preferences.focusAreas.contains(.productivity) && activity.category == .work {
            significance += 0.3
        }

        return min(significance, 1.0)
    }

    private func determineCategory(for activity: ActivityRecord) -> HighlightCategory {
        // Determine highlight category based on activity type
        switch activity.category {
        case .work:
            return .achievement
        case .health:
            return .moment
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
            .joy: ["happy", "joyful", "excited", "pleased", "grateful"],
            .calm: ["calm", "peaceful", "relaxed", "serene", "tranquil"],
            .focused: ["focused", "concentrated", "attentive", "engaged", "productive"],
            .grateful: ["grateful", "thankful", "appreciative", "blessed"],
            .challenged: ["challenged", "difficult", "hard", "struggled"],
            .accomplished: ["accomplished", "achieved", "completed", "successful", "proud"]
        ]

        var emotionScores: [EmotionScore] = []
        let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for (emotion, keywords) in emotionWords {
            let count = words.filter { keywords.contains($0) }.count
            let score = Double(count) / Double(words.count)

            if score > 0 {
                emotionScores.append(EmotionScore(
                    emotion: emotion,
                    intensity: min(score * 10, 1.0),
                    confidence: 0.7
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

    private func saveUserLearningData() {
        if let data = try? JSONEncoder().encode(userLearningData) {
            UserDefaults.standard.set(data, forKey: "JournalUserLearningData")
        }
    }

    private func updateUserLearningData(with journal: DailyJournal?, engagement: JournalEngagement) {
        userLearningData.totalJournalsGenerated += 1

        if let journal = journal {
            userLearningData.engagementPatterns[journal.template.rawValue] =
                (userLearningData.engagementPatterns[journal.template.rawValue] ?? 0) + 1

            // Update last engagement
            userLearningData.lastEngagement = JournalEngagementData(
                date: Date(),
                engagementType: engagement,
                template: journal.template,
                feedback: nil
            )
        }

        userLearningData.lastGeneratedDate = Date()
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
            userPatterns: userLearningData.engagementPatterns,
            weather: nil,
            dayOfWeek: Calendar.current.component(.weekday, from: date),
            isWeekend: Calendar.current.isWeekend(date)
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
    let userPatterns: [String: Int]
    let weather: String?
    let dayOfWeek: Int
    let isWeekend: Bool
}

// MARK: - Activity Record Model (placeholder for ActivityTap integration)
private struct ActivityRecord {
    let id: UUID
    let title: String
    let description: String
    let category: ActivityCategory
    let timestamp: Date
    let duration: TimeInterval?
}

private enum ActivityCategory {
    case work, health, learning, social, leisure, other
}

// MARK: - Memory Record Model (placeholder for MemoryStore integration)
private struct MemoryRecord {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
    let relevance: Double
}