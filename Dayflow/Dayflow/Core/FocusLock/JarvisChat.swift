//
//  JarvisChat.swift
//  FocusLock
//
//  AI assistant with RAG pipeline and tool orchestration for intelligent productivity
//

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class JarvisChat: ObservableObject {
    static let shared = JarvisChat()

    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isProcessing: Bool = false
    @Published var suggestedActions: [ChatAction] = []
    @Published var contextualInfo: [ContextualInfo] = []

    // MARK: - Private Properties
    private let memoryStore: MemoryStore
    private let toolOrchestrator: ToolOrchestrator
    private let contextManager: ConversationContextManager
    private let llmService: LLMServicing

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "FocusLock", category: "JarvisChat")

    // Configuration
    private let maxConversationHistory = 50
    private let maxToolHops = 3
    private let responseTimeout: TimeInterval = 12.0 // Local: 5s, Hybrid: 12s

    private init(llmService: LLMServicing = LLMService.shared) {
        // Initialize components
        self.memoryStore = try! HybridMemoryStore.shared
        self.toolOrchestrator = ToolOrchestrator()
        self.contextManager = ConversationContextManager()
        self.llmService = llmService

        setupBindings()
        loadConversationHistory()
    }

    // MARK: - Public Interface

    func sendMessage(_ message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let startTime = CFAbsoluteTimeGetCurrent()
        isProcessing = true

        do {
            // Create or get current conversation
            if currentConversation == nil {
                currentConversation = Conversation(id: UUID(), messages: [], createdAt: Date())
                conversations.insert(currentConversation!, at: 0)
            }

            // Add user message
            let userMessage = ChatMessage(
                id: UUID(),
                role: .user,
                content: message,
                timestamp: Date(),
                toolCalls: [],
                citations: []
            )
            currentConversation?.messages.append(userMessage)

            // Process message
            let response = try await processUserMessage(message, in: currentConversation!)

            // Add AI response
            let aiMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: response.content,
                timestamp: Date(),
                toolCalls: response.toolCalls,
                citations: response.citations
            )
            currentConversation?.messages.append(aiMessage)

            // Update suggested actions based on context
            updateSuggestedActions()

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("Chat message processed in \(String(format: "%.3f", duration))s")

        } catch {
            logger.error("Failed to process chat message: \(error.localizedDescription)")

            // Add error message
            let errorMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: "I apologize, but I encountered an error while processing your message. Please try again.",
                timestamp: Date(),
                toolCalls: [],
                citations: []
            )
            currentConversation?.messages.append(errorMessage)
        }

        isProcessing = false
    }

    func startNewConversation() {
        var newConversation = Conversation(id: UUID(), messages: [], createdAt: Date())

        // Add welcome message
        let welcomeMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Hello! I'm Jarvis, your AI productivity assistant. I can help you with:\n\n• Searching your activity history and notes\n• Managing tasks and scheduling\n• Providing insights about your work patterns\n• Answering questions about your local data\n\nWhat can I help you with today?",
            timestamp: Date(),
            toolCalls: [],
            citations: []
        )
        newConversation.messages.append(welcomeMessage)

        currentConversation = newConversation
        conversations.insert(newConversation, at: 0)

        // Maintain conversation history limit
        if conversations.count > maxConversationHistory {
            conversations = Array(conversations.prefix(maxConversationHistory))
        }
    }

    func executeAction(_ action: ChatAction) async {
        isProcessing = true

        do {
            let result = try await toolOrchestrator.executeTool(
                name: action.toolName,
                parameters: action.parameters
            )

            let parameterPayload = convertToAnyCodable(action.parameters)

            // Add action result to conversation
            let resultMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: "I've \(action.description.lowercased()): \(result.description)",
                timestamp: Date(),
                toolCalls: [ToolCall(name: action.toolName, parameters: parameterPayload, result: result)],
                citations: []
            )
            currentConversation?.messages.append(resultMessage)

            // Update suggested actions
            updateSuggestedActions()

        } catch {
            logger.error("Failed to execute action \(action.toolName): \(error.localizedDescription)")

            let errorMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: "I couldn't complete that action: \(error.localizedDescription)",
                timestamp: Date(),
                toolCalls: [],
                citations: []
            )
            currentConversation?.messages.append(errorMessage)
        }

        isProcessing = false
    }

    func getContextualInfo() async -> [ContextualInfo] {
        var info: [ContextualInfo] = []

        // Current activity
        if let activity = await ActivityTap.shared.getCurrentActivity() {
            info.append(ContextualInfo(
                type: .currentActivity,
                title: "Current Activity",
                content: "You're currently working on \(activity.category) tasks",
                relevance: 1.0
            ))
        }

        // Recent focus sessions
        let recentSessions = SessionManager.shared.lastSessionSummary.map { [$0] } ?? []
        if !recentSessions.isEmpty {
            info.append(ContextualInfo(
                type: .recentFocus,
                title: "Recent Focus Session",
                content: "Last session: \(recentSessions.first!.taskName) - \(recentSessions.first!.durationFormatted)",
                relevance: 0.8
            ))
        }

        // Upcoming tasks (placeholder - would integrate with todo system)
        info.append(ContextualInfo(
            type: .upcomingTasks,
            title: "Suggested Tasks",
            content: "Based on your recent activity, you might want to follow up on coding tasks",
            relevance: 0.7
        ))

        contextualInfo = info
        return info
    }

    // MARK: - Private Methods

    private func processUserMessage(_ message: String, in conversation: Conversation) async throws -> ChatResponse {
        // Analyze user intent
        let intent = try await analyzeUserIntent(message, context: conversation)

        // Build context
        let context = try await buildConversationContext(message, intent: intent)

        // Determine if tools are needed
        let needsTools = intent.requiresTools

        var toolCalls: [ToolCall] = []
        var citations: [Citation] = []

        // Execute tools if needed
        if needsTools {
            let toolResults = try await executeToolsForIntent(intent, context: context)
            toolCalls = toolResults.map { ToolCall(name: $0.name, parameters: $0.parameters, result: $0.result) }
            citations = toolResults.flatMap { $0.citations }
        }

        // Generate response
        let response = try await generateResponse(
            message: message,
            intent: intent,
            context: context,
            toolCalls: toolCalls,
            citations: citations
        )

        return response
    }

    private func analyzeUserIntent(_ message: String, context: Conversation) async throws -> UserIntent {
        // Use LLM to analyze intent
        let intentPrompt = """
        Analyze the user's message and determine their intent. Consider the conversation context.

        Message: "\(message)"
        Recent messages: \(context.messages.suffix(3).map { "\($0.role.rawValue): \(String($0.content.prefix(100)))" }.joined(separator: "\n"))

        Respond with a JSON object containing:
        {
            "primaryIntent": "search|schedule|task|insight|general",
            "requiresTools": true|false,
            "entities": ["entity1", "entity2"],
            "confidence": 0.0-1.0,
            "suggestedTools": ["tool1", "tool2"]
        }
        """

        let intentResponse = try await llmService.generateResponse(
            prompt: intentPrompt,
            maxTokens: 200,
            temperature: 0.3
        )

        // Parse intent response
        return try parseIntentResponse(intentResponse)
    }

    private func buildConversationContext(_ message: String, intent: UserIntent) async throws -> ConversationContext {
        var context = ConversationContext()

        // Add recent conversation history
        if let currentConversation = currentConversation {
            context.recentMessages = Array(currentConversation.messages.suffix(10))
        }

        // Add relevant memories based on intent
        if intent.primaryIntent == .search || intent.primaryIntent == .insight {
            let searchResults = try await memoryStore.hybridSearch(message, limit: 5)
            context.relevantMemories = searchResults.map { $0.item }
            context.memoryCitations = searchResults.map { Citation(source: "Memory", id: $0.id, content: String($0.item.content.prefix(200))) }
        }

        // Add current activity context
        if let currentActivity = await ActivityTap.shared.getCurrentActivity() {
            context.currentActivity = currentActivity
        }

        // Add time-based context
        let now = Date()
        context.timeOfDay = getTimeOfDay(now)
        context.dayOfWeek = getDayOfWeek(now)
        context.recentActivities = ActivityTap.shared.getActivityHistory(since: now.addingTimeInterval(-2 * 60 * 60), limit: 10)

        return context
    }

    private func executeToolsForIntent(_ intent: UserIntent, context: ConversationContext) async throws -> [ToolExecutionResult] {
        var results: [ToolExecutionResult] = []
        var hops = 0

        for toolName in intent.suggestedTools.prefix(maxToolHops) {
            guard hops < maxToolHops else { break }

            do {
                let parameters = extractToolParameters(for: toolName, intent: intent, context: context)
                let result = try await toolOrchestrator.executeTool(name: toolName, parameters: parameters)
                let encodedParameters = encodeParameters(parameters)

                let parameterPayload = convertToAnyCodable(parameters)

                let executionResult = ToolExecutionResult(
                    name: toolName,
                    parameters: parameterPayload,
                    result: result,
                    citations: extractCitations(from: result)
                )

                results.append(executionResult)
                hops += 1

            } catch {
                logger.warning("Tool execution failed for \(toolName): \(error.localizedDescription)")
            }
        }

        return results
    }

    private func generateResponse(
        message: String,
        intent: UserIntent,
        context: ConversationContext,
        toolCalls: [ToolCall],
        citations: [Citation]
    ) async throws -> ChatResponse {
        // Build response prompt
        let responsePrompt = buildResponsePrompt(
            message: message,
            intent: intent,
            context: context,
            toolCalls: toolCalls
        )

        // Generate response
        let responseContent = try await llmService.generateResponse(
            prompt: responsePrompt,
            maxTokens: 500,
            temperature: 0.7
        )

        return ChatResponse(
            content: responseContent,
            toolCalls: toolCalls,
            citations: citations
        )
    }

    private func buildResponsePrompt(
        message: String,
        intent: UserIntent,
        context: ConversationContext,
        toolCalls: [ToolCall]
    ) -> String {
        var prompt = """
        You are Jarvis, a helpful AI productivity assistant. You have access to the user's local data and can help with various tasks.

        User message: "\(message)"
        Intent: \(intent.primaryIntent)
        """

        // Add context information
        if !context.recentMessages.isEmpty {
            prompt += "\n\nRecent conversation:\n"
            for msg in context.recentMessages.suffix(5) {
                prompt += "\(msg.role.rawValue): \(String(msg.content.prefix(100)))\n"
            }
        }

        if let currentActivity = context.currentActivity {
            prompt += "\n\nCurrent activity: \(currentActivity.category) - \(currentActivity.context)"
        }

        if !context.relevantMemories.isEmpty {
            prompt += "\n\nRelevant information from your activity:\n"
            for memory in context.relevantMemories.prefix(3) {
                prompt += "- \(String(memory.content.prefix(150)))\n"
            }
        }

        if !toolCalls.isEmpty {
            prompt += "\n\nTool results:\n"
            for toolCall in toolCalls {
                prompt += "- \(toolCall.name): \(toolCall.result.description)\n"
            }
        }

        prompt += "\n\nProvide a helpful, concise response. If you used tools, explain what you found. Always be helpful and actionable."

        return prompt
    }

    private func parseIntentResponse(_ response: String) throws -> UserIntent {
        // This is a simplified parser - in practice, you'd want more robust JSON parsing
        let primaryIntent: UserIntent.PrimaryIntent
        if response.contains("search") {
            primaryIntent = .search
        } else if response.contains("schedule") {
            primaryIntent = .schedule
        } else if response.contains("task") {
            primaryIntent = .task
        } else if response.contains("insight") {
            primaryIntent = .insight
        } else {
            primaryIntent = .general
        }

        return UserIntent(
            primaryIntent: primaryIntent,
            requiresTools: response.contains("true"),
            entities: [],
            confidence: 0.8,
            suggestedTools: extractSuggestedTools(from: response)
        )
    }

    private func extractSuggestedTools(from response: String) -> [String] {
        let availableTools = ["search_memories", "get_activity_summary", "create_todo", "schedule_focus_session"]
        return availableTools.filter { response.lowercased().contains($0.lowercased()) }
    }

    private func convertToAnyCodable(_ parameters: [String: Any]) -> [String: AnyCodable] {
        parameters.reduce(into: [String: AnyCodable]()) { partialResult, element in
            partialResult[element.key] = AnyCodable(element.value)
        }
    }

    private func extractToolParameters(for toolName: String, intent: UserIntent, context: ConversationContext) -> [String: Any] {
        switch toolName {
        case "search_memories":
            return ["query": AnyCodable(context.recentMessages.last?.content ?? "")]
        case "get_activity_summary":
            return ["timeRange": AnyCodable("24h")]
        case "create_todo":
            return [
                "title": AnyCodable("Suggested task based on conversation"),
                "priority": AnyCodable("medium")
            ]
        case "schedule_focus_session":
            return [
                "taskName": AnyCodable("Focus session"),
                "duration": AnyCodable(30)
            ]
        default:
            return [:]
        }
    }

    private func encodeParameters(_ parameters: [String: Any]) -> [String: AnyCodable] {
        parameters.mapValues { AnyCodable($0) }
    }

    private func extractCitations(from result: ToolResult) -> [Citation] {
        // Extract citations from tool results
        if let memoryIds = result.metadata["memory_ids"]?.value as? [String] {
            return memoryIds.compactMap { UUID(uuidString: $0) }.map { Citation(source: "Memory", id: $0, content: "") }
        }
        return []
    }

    private func updateSuggestedActions() {
        guard let currentConversation = currentConversation else { return }

        var actions: [ChatAction] = []

        // Analyze last message for action suggestions
        if let lastMessage = currentConversation.messages.last {
            let content = lastMessage.content.lowercased()

            if content.contains("schedule") || content.contains("plan") {
                actions.append(ChatAction(
                    toolName: "schedule_focus_session",
                    description: "Schedule a focus session",
                    parameters: [:]
                ))
            }

            if content.contains("task") || content.contains("todo") {
                actions.append(ChatAction(
                    toolName: "create_todo",
                    description: "Create a new task",
                    parameters: [:]
                ))
            }

            if content.contains("search") || content.contains("find") {
                actions.append(ChatAction(
                    toolName: "search_memories",
                    description: "Search your activity history",
                    parameters: [:]
                ))
            }
        }

        // Always add some general actions
        actions.append(contentsOf: [
            ChatAction(
                toolName: "get_activity_summary",
                description: "Get today's activity summary",
                parameters: ["timeRange": AnyCodable("today")]
            ),
            ChatAction(
                toolName: "get_productivity_insights",
                description: "Get productivity insights",
                parameters: [:]
            )
        ])

        suggestedActions = Array(actions.prefix(4))
    }

    // MARK: - Helper Methods

    private func getTimeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }

    private func getDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func setupBindings() {
        // Monitor conversation changes
        $currentConversation
            .compactMap { $0 }
            .sink { [weak self] conversation in
                self?.contextManager.updateContext(conversation)
            }
            .store(in: &cancellables)

        // Monitor memory store changes
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateContextualInfo()
            }
            .store(in: &cancellables)
    }

    private func loadConversationHistory() {
        // Load conversations from storage (placeholder implementation)
        // In practice, you'd load from persistent storage
    }

    private func updateContextualInfo() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.contextualInfo = await self.getContextualInfo()
        }
    }

    private func saveConversationHistory() {
        // Save conversations to persistent storage (placeholder implementation)
        // In practice, you'd save to database or file system
    }
}

// MARK: - Data Models

struct Conversation: Identifiable, Codable {
    let id: UUID
    var messages: [ChatMessage]
    let createdAt: Date
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let toolCalls: [ToolCall]
    let citations: [Citation]

    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
}

struct ChatResponse {
    let content: String
    let toolCalls: [ToolCall]
    let citations: [Citation]
}

struct ToolCall: Codable {
    let name: String
    let parameters: [String: AnyCodable]
    let result: ToolResult
}

struct Citation: Codable {
    let source: String
    let id: UUID
    let content: String
}

struct UserIntent {
    let primaryIntent: PrimaryIntent
    let requiresTools: Bool
    let entities: [String]
    let confidence: Double
    let suggestedTools: [String]

    enum PrimaryIntent: String {
        case search = "search"
        case schedule = "schedule"
        case task = "task"
        case insight = "insight"
        case general = "general"
    }
}

struct ConversationContext {
    var recentMessages: [ChatMessage] = []
    var relevantMemories: [MemoryItem] = []
    var memoryCitations: [Citation] = []
    var currentActivity: Activity?
    var timeOfDay: String = ""
    var dayOfWeek: String = ""
    var recentActivities: [Activity] = []
}

struct ChatAction: Identifiable {
    let id = UUID()
    let toolName: String
    let description: String
    let parameters: [String: AnyCodable]
}

struct ContextualInfo: Identifiable {
    let id = UUID()
    let type: ContextType
    let title: String
    let content: String
    let relevance: Double

    enum ContextType {
        case currentActivity
        case recentFocus
        case upcomingTasks
        case timeContext
        case productivity
    }
}

struct ToolExecutionResult {
    let name: String
    let parameters: [String: AnyCodable]
    let result: ToolResult
    let citations: [Citation]
}

// MARK: - Tool Orchestrator

class ToolOrchestrator {
    private let logger = Logger(subsystem: "FocusLock", category: "ToolOrchestrator")

    func executeTool(name: String, parameters: [String: AnyCodable]) async throws -> ToolResult {
        logger.info("Executing tool: \(name)")

        switch name {
        case "search_memories":
            return try await searchMemories(parameters: parameters)
        case "get_activity_summary":
            return try await getActivitySummary(parameters: parameters)
        case "create_todo":
            return try await createTodo(parameters: parameters)
        case "schedule_focus_session":
            return try await scheduleFocusSession(parameters: parameters)
        case "get_productivity_insights":
            return try await getProductivityInsights(parameters: parameters)
        default:
            throw ToolError.unknownTool(name)
        }
    }

    private func searchMemories(parameters: [String: AnyCodable]) async throws -> ToolResult {
        let query = parameters["query"]?.stringValue ?? ""
        let memoryStore = try! HybridMemoryStore.shared
        let results = try await memoryStore.hybridSearch(query, limit: 5)

        let content = results.map { "• \(String($0.item.content.prefix(200)))" }.joined(separator: "\n")

        return ToolResult(
            success: true,
            description: "Found \(results.count) relevant memories",
            content: content,
            metadata: [
                "memory_ids": AnyCodable(results.map { $0.id.uuidString })
            ]
        )
    }

    private func getActivitySummary(parameters: [String: AnyCodable]) async throws -> ToolResult {
        let timeRange = parameters["timeRange"]?.stringValue ?? "24h"
        let dateRange = getDateRange(from: timeRange)
        let summary = ActivityTap.shared.getActivitySummary(for: dateRange)

        let content = """
        Activity Summary (\(timeRange)):
        • Total activities: \(summary.totalActivities)
        • Average confidence: \(String(format: "%.1f", summary.averageConfidence * 100))%
        • Top category: \(summary.topCategories.first?.0 ?? "None")
        • Context switches: \(summary.contextSwitches)
        • Focus time: \(String(format: "%.1f", summary.totalFocusTime / 60)) minutes
        """

        return ToolResult(
            success: true,
            description: "Generated activity summary",
            content: content,
            metadata: [
                "timeRange": AnyCodable(timeRange)
            ]
        )
    }

    private func createTodo(parameters: [String: AnyCodable]) async throws -> ToolResult {
        let title = parameters["title"]?.stringValue ?? "New Task"
        let priority = parameters["priority"]?.stringValue ?? "medium"

        // This would integrate with your todo system
        // For now, return a placeholder result

        return ToolResult(
            success: true,
            description: "Created todo: \(title)",
            content: "✅ Task created: \(title) (Priority: \(priority))",
            metadata: [
                "title": AnyCodable(title),
                "priority": AnyCodable(priority)
            ]
        )
    }

    private func scheduleFocusSession(parameters: [String: AnyCodable]) async throws -> ToolResult {
        let taskName = parameters["taskName"]?.stringValue ?? "Focus Session"
        let duration = parameters["duration"]?.intValue ?? 30

        // This would integrate with your FocusLock system
        // For now, return a placeholder result

        return ToolResult(
            success: true,
            description: "Scheduled focus session: \(taskName)",
            content: "🎯 Focus session scheduled: \(taskName) for \(duration) minutes",
            metadata: [
                "taskName": AnyCodable(taskName),
                "duration": AnyCodable(duration)
            ]
        )
    }

    private func getProductivityInsights(parameters: [String: AnyCodable]) async throws -> ToolResult {
        let stats = ActivityTap.shared.getActivityStatistics()

        let content = """
        Productivity Insights:
        • Total activities today: \(stats.totalActivities)
        • Average confidence: \(String(format: "%.1f", stats.averageConfidence * 100))%
        • Top category: \(stats.topCategories.first?.0 ?? "None")
        • Context switches: \(stats.contextSwitches)
        • Processing health: \(stats.isHealthy ? "Good" : "Needs attention")
        """

        return ToolResult(
            success: true,
            description: "Generated productivity insights",
            content: content,
            metadata: [:]
        )
    }

    private func getDateRange(from timeRange: String) -> DateInterval {
        let now = Date()
        let calendar = Calendar.current

        switch timeRange {
        case "today":
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)
        case "24h":
            return DateInterval(start: now.addingTimeInterval(-24 * 60 * 60), end: now)
        case "7d":
            return DateInterval(start: now.addingTimeInterval(-7 * 24 * 60 * 60), end: now)
        default:
            return DateInterval(start: now.addingTimeInterval(-24 * 60 * 60), end: now)
        }
    }

    enum ToolError: Error {
        case unknownTool(String)
        case toolExecutionFailed(String)
    }
}

struct ToolResult: Codable {
    let success: Bool
    let description: String
    let content: String
    let metadata: [String: AnyCodable]
}

class ConversationContextManager {
    private var contexts: [UUID: ConversationContext] = [:]

    func updateContext(_ conversation: Conversation) {
        // Store or update context for conversation
        // This is a simplified implementation
    }

    func getContext(for conversationId: UUID) -> ConversationContext? {
        return contexts[conversationId]
    }
}