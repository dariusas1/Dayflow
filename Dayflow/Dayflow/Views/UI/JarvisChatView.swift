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
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Main Content
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left side: Chat conversation
                    chatConversationSection
                        .frame(width: geometry.size.width * 0.65)
                    
                    Divider()
                    
                    // Right side: Contextual info and suggested actions
                    contextualSidebar
                        .frame(width: geometry.size.width * 0.35)
                }
            }
        }
        .background(Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                
                Text("Jarvis Chat")
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(.black)
                
                Spacer()
                
                // New conversation button
                Button(action: startNewConversation) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 14))
                        Text("New Chat")
                            .font(.custom("Nunito", size: 13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("AI assistant for productivity insights and task management")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0).opacity(0.3))
            
            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(.custom("InstrumentSerif-Regular", size: 22))
                    .foregroundColor(.black)
                
                Text("Ask about your productivity, tasks, or get insights")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // Quick start suggestions
            VStack(spacing: 8) {
                quickStartButton("What should I focus on today?")
                quickStartButton("Show my productivity trends")
                quickStartButton("Help me plan my week")
            }
            .padding(.top, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
    
    private func quickStartButton(_ text: String) -> some View {
        Button(action: {
            messageInput = text
            sendMessage()
        }) {
            HStack {
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                Text(text)
                    .font(.custom("Nunito", size: 13))
                Spacer()
            }
            .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var messageInputSection: some View {
        HStack(spacing: 12) {
            TextField("Ask Jarvis anything...", text: $messageInput)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.custom("Nunito", size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(messageInput.isEmpty ? .gray : Color(red: 0.25, green: 0.17, blue: 0))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(messageInput.isEmpty || jarvisChat.isProcessing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    // MARK: - Contextual Sidebar
    
    private var contextualSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Suggested Actions
                if !jarvisChat.suggestedActions.isEmpty {
                    suggestedActionsSection
                }
                
                // Contextual Information
                if !jarvisChat.contextualInfo.isEmpty {
                    contextualInfoSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.02))
    }
    
    private var suggestedActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Actions")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))
            
            ForEach(jarvisChat.suggestedActions) { action in
                SuggestedActionCard(action: action) {
                    executeSuggestedAction(action)
                }
            }
        }
    }
    
    private var contextualInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Context")
                .font(.custom("Nunito", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.8))
            
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
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Message content
                Text(message.content)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(message.role == .user ? .white : .black.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? Color(red: 0.25, green: 0.17, blue: 0)
                            : Color.black.opacity(0.08)
                    )
                    .cornerRadius(12)
                
                // Tool calls and citations
                if !message.toolCalls.isEmpty {
                    toolCallsView
                }
                
                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.custom("Nunito", size: 11))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 4)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var toolCallsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(message.toolCalls.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 10))
                    Text(message.toolCalls[index].name)
                        .font(.custom("Nunito", size: 11))
                }
                .foregroundColor(.black.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 4)
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: getIconForTool(action.toolName))
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                    
                    Text(action.toolName)
                        .font(.custom("Nunito", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.8))
                    
                    Spacer()
                }
                
                Text(action.description)
                    .font(.custom("Nunito", size: 11))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: getIconForType(info.type))
                    .font(.system(size: 12))
                    .foregroundColor(getColorForType(info.type))
                
                Text(info.title)
                    .font(.custom("Nunito", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
                
                // Relevance indicator
                Circle()
                    .fill(getRelevanceColor(info.relevance))
                    .frame(width: 6, height: 6)
            }
            
            Text(info.content)
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
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
            return Color.orange
        case .timeContext:
            return Color.green
        case .productivity:
            return Color(red: 0.25, green: 0.17, blue: 0)
        }
    }
    
    private func getRelevanceColor(_ relevance: Double) -> Color {
        if relevance > 0.75 {
            return Color.green
        } else if relevance > 0.5 {
            return Color.orange
        } else {
            return Color.gray
        }
    }
}

// MARK: - Preview

#Preview {
    JarvisChatView()
        .frame(width: 900, height: 600)
}

