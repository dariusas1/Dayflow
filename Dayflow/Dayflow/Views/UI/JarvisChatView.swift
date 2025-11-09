//
//  JarvisChatView.swift
//  Dayflow
//
//  AI-powered chat interface with Jarvis assistant
//

import SwiftUI

struct JarvisChatView: View {
    @StateObject private var jarvisChat = JarvisChat.shared
    @State private var messageInput: String = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        FlowingGradientBackground()
            .overlay(
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Main Content
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // Left side: Chat conversation
                            chatConversationSection
                                .frame(width: geometry.size.width * 0.65)

                            GlassmorphismContainer(style: .card) {
                                Rectangle()
                                    .fill(DesignColors.glassBackground)
                                    .frame(width: 1)
                            }
                            .frame(width: geometry.size.width * 0.35)

                            // Right side: Contextual info and suggested actions
                            contextualSidebar
                                .frame(width: geometry.size.width * 0.35)
                        }
                    }
                }
                .padding(DesignSpacing.lg)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        GlassmorphismContainer(style: .main) {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.primaryOrange)

                    Text("Jarvis Chat")
                        .font(.custom(DesignTypography.headingFont, size: DesignTypography.title2))
                        .foregroundColor(DesignColors.primaryText)

                    Spacer()

                    // New conversation button
                    UnifiedButton.secondary(
                        "New Chat",
                        size: .small,
                        action: startNewConversation
                    )
                }

                Text("AI assistant for productivity insights and task management")
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(DesignColors.secondaryText)
            }
            .padding(DesignSpacing.lg)
        }
    }
    
    // MARK: - Chat Conversation Section
    
    private var chatConversationSection: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let conversation = jarvisChat.currentConversation {
                            ForEach(conversation.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        } else {
                            emptyConversationView
                        }
                        
                        // Processing indicator
                        if jarvisChat.isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Thinking...")
                                    .font(.custom("Nunito", size: 13))
                                    .foregroundColor(.black.opacity(0.5))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: jarvisChat.currentConversation?.messages.count) { _, _ in
                    scrollToBottom()
                }
            }
            
            Divider()
            
            // Input area
            messageInputSection
        }
    }
    
    private var emptyConversationView: some View {
        VStack(spacing: DesignSpacing.xl) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(DesignColors.primaryOrange.opacity(0.3))

            VStack(spacing: DesignSpacing.md) {
                Text("Start a conversation")
                    .font(.custom(DesignTypography.headingFont, size: DesignTypography.title3))
                    .foregroundColor(DesignColors.primaryText)

                Text("Ask about your productivity, tasks, or get insights")
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(DesignColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            // Quick start suggestions
            VStack(spacing: DesignSpacing.sm) {
                quickStartButton("What should I focus on today?")
                quickStartButton("Show my productivity trends")
                quickStartButton("Help me plan my week")
            }
            .padding(.top, DesignSpacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSpacing.xl)
    }
    
    private func quickStartButton(_ text: String) -> some View {
        UnifiedButton.ghost(
            text,
            size: .small,
            action: {
                messageInput = text
                sendMessage()
            }
        )
    }
    
    private var messageInputSection: some View {
        HStack(spacing: DesignSpacing.md) {
            UnifiedTextField(
                "Ask Jarvis anything...",
                text: $messageInput,
                style: .standard
            )
            .focused($isInputFocused)
            .onSubmit {
                sendMessage()
            }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(messageInput.isEmpty ? DesignColors.secondaryText : DesignColors.primaryOrange)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(messageInput.isEmpty || jarvisChat.isProcessing)
        }
        .padding(DesignSpacing.md)
        .padding(.vertical, DesignSpacing.md)
    }
    
    // MARK: - Contextual Sidebar
    
    private var contextualSidebar: some View {
        GlassmorphismContainer(style: .card) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpacing.lg) {
                    // Suggested Actions
                    if !jarvisChat.suggestedActions.isEmpty {
                        suggestedActionsSection
                    }

                    // Contextual Information
                    if !jarvisChat.contextualInfo.isEmpty {
                        contextualInfoSection
                    }
                }
                .padding(DesignSpacing.md)
            }
        }
        .padding(DesignSpacing.md)
    }
    
    private var suggestedActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Suggested Actions")
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                .fontWeight(.semibold)
                .foregroundColor(DesignColors.primaryText)

            ForEach(jarvisChat.suggestedActions) { action in
                SuggestedActionCard(action: action) {
                    executeSuggestedAction(action)
                }
            }
        }
    }
    
    private var contextualInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            Text("Context")
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                .fontWeight(.semibold)
                .foregroundColor(DesignColors.primaryText)

            ForEach(jarvisChat.contextualInfo) { info in
                ContextualInfoCard(info: info)
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageInput
        messageInput = ""
        
        Task {
            await jarvisChat.sendMessage(message)
            scrollToBottom()
        }
    }
    
    private func startNewConversation() {
        jarvisChat.startNewConversation()
        messageInput = ""
    }
    
    private func executeSuggestedAction(_ action: ChatAction) {
        // Execute the suggested action
        Task {
            await jarvisChat.executeSuggestedAction(action)
        }
    }
    
    private func scrollToBottom() {
        guard let conversation = jarvisChat.currentConversation,
              let lastMessage = conversation.messages.last else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: DesignSpacing.xs) {
                // Message content
                Text(message.content)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(message.role == .user ? .white : DesignColors.primaryText)
                    .padding(.horizontal, DesignSpacing.md)
                    .padding(.vertical, DesignSpacing.sm)
                    .background(message.role == .user ?
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DesignColors.primaryOrange,
                                DesignColors.primaryOrange.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [DesignColors.glassBackground, DesignColors.glassBackground]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(DesignRadius.medium)

                // Tool calls and citations
                if !message.toolCalls.isEmpty {
                    toolCallsView
                }

                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .foregroundColor(DesignColors.tertiaryText)
                    .padding(.horizontal, DesignSpacing.xs)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, DesignSpacing.md)
    }
    
    private var toolCallsView: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.xs) {
            ForEach(message.toolCalls.indices, id: \.self) { index in
                HStack(spacing: DesignSpacing.xs) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 10, weight: .medium))
                    Text(message.toolCalls[index].name)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                }
                .foregroundColor(DesignColors.secondaryText)
                .padding(.horizontal, DesignSpacing.sm)
                .padding(.vertical, DesignSpacing.xs)
                .background(DesignColors.glassBackground.opacity(0.5))
                .cornerRadius(DesignRadius.small)
            }
        }
        .padding(.horizontal, DesignSpacing.xs)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Suggested Action Card

struct SuggestedActionCard: View {
    let action: ChatAction
    let onTap: () -> Void

    var body: some View {
        UnifiedCard(style: .interactive, size: .medium) {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                HStack {
                    Image(systemName: getIconForTool(action.toolName))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.primaryOrange)

                    Text(action.toolName)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .fontWeight(.medium)
                        .foregroundColor(DesignColors.primaryText)

                    Spacer()
                }

                Text(action.description)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .foregroundColor(DesignColors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private func getIconForTool(_ toolName: String) -> String {
        switch toolName.lowercased() {
        case let name where name.contains("task"):
            return "checkmark.circle"
        case let name where name.contains("schedule"):
            return "calendar"
        case let name where name.contains("search"):
            return "magnifyingglass"
        case let name where name.contains("insight"):
            return "lightbulb"
        default:
            return "sparkles"
        }
    }
}

// MARK: - Contextual Info Card

struct ContextualInfoCard: View {
    let info: ContextualInfo

    var body: some View {
        UnifiedCard(style: .minimal, size: .medium) {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                HStack {
                    Image(systemName: getIconForType(info.type))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(getColorForType(info.type))

                    Text(info.title)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .fontWeight(.medium)
                        .foregroundColor(DesignColors.primaryText)

                    Spacer()

                    // Relevance indicator
                    Circle()
                        .fill(getRelevanceColor(info.relevance))
                        .frame(width: 6, height: 6)
                }

                Text(info.content)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .foregroundColor(DesignColors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
        }
    }
    
    private func getIconForType(_ type: ContextualInfo.ContextType) -> String {
        switch type {
        case .currentActivity:
            return "app.badge"
        case .recentFocus:
            return "clock.arrow.circlepath"
        case .upcomingTasks:
            return "list.bullet.circle"
        case .timeContext:
            return "clock"
        case .productivity:
            return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func getColorForType(_ type: ContextualInfo.ContextType) -> Color {
        switch type {
        case .currentActivity:
            return Color.blue
        case .recentFocus:
            return Color.purple
        case .upcomingTasks:
            return DesignColors.primaryOrange
        case .timeContext:
            return Color.green
        case .productivity:
            return DesignColors.primaryOrange
        }
    }
    
    private func getRelevanceColor(_ relevance: Double) -> Color {
        if relevance > 0.75 {
            return DesignColors.successGreen
        } else if relevance > 0.5 {
            return DesignColors.primaryOrange
        } else {
            return DesignColors.secondaryText
        }
    }
}

// MARK: - Preview

#Preview {
    JarvisChatView()
        .frame(width: 900, height: 600)
}

