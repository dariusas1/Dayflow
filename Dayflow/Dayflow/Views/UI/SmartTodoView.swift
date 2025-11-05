//
//  SmartTodoView.swift
//  FocusLock
//
//  Smart todo management view with P0/P1/P2 prioritization and project grouping
//

import SwiftUI

struct SmartTodoView: View {
    @StateObject private var todoEngine = TodoExtractionEngine.shared
    @State private var focusManager: FocusSessionManager?
    @State private var selectedProject: TodoProject?  = nil
    @State private var selectedPriority: TodoPriority? = nil
    @State private var showingAddTodo = false
    @State private var showingP0Only = false
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var contentOpacity: Double = 0
    @State private var isInitialized = false
    
    var body: some View {
        ZStack {
            // Background gradient matching main platform
            Image("MainUIBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern header
                todoHeader
                    .opacity(headerOpacity)
                    .offset(y: headerOffset)
                
                // Todos list
                todosList
                    .opacity(contentOpacity)
            }
        }
        .task {
            // Async-safe initialization: Initialize FocusSessionManager without blocking UI
            if !isInitialized {
                focusManager = FocusSessionManager.shared
                isInitialized = true
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                headerOpacity = 1
                headerOffset = 0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1
            }
        }
        .sheet(isPresented: $showingAddTodo) {
            AddTodoSheet()
        }
    }
    
    // MARK: - Header
    
    private var todoHeader: some View {
        Group {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Todos")
                        .font(.custom("InstrumentSerif-Regular", size: 36))
                        .foregroundColor(.black)
                    
                    Text("\(getFilteredTodos().count) active tasks")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: {
                    showingAddTodo = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Add Todo")
                            .font(.custom("Nunito", size: 14))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F96E00"))
                    .cornerRadius(10)
                    .shadow(color: Color(hex: "F96E00").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            
            // Modern filter pills
            HStack(spacing: 12) {
                // Priority filter
                Menu {
                    Button(action: { selectedPriority = nil }) {
                        Label("All Priorities", systemImage: selectedPriority == nil ? "checkmark" : "")
                    }
                    Divider()
                    ForEach(TodoPriority.allCases, id: \.self) { priority in
                        Button(action: { selectedPriority = priority }) {
                            Label(priority.displayName, systemImage: selectedPriority == priority ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12))
                        Text(selectedPriority?.displayName ?? "All Priorities")
                            .font(.custom("Nunito", size: 13))
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                // Project filter
                Menu {
                    Button(action: { selectedProject = nil }) {
                        Label("All Projects", systemImage: selectedProject == nil ? "checkmark" : "")
                    }
                    Divider()
                    ForEach(TodoProject.allCases, id: \.self) { project in
                        Button(action: { selectedProject = project }) {
                            Label(project.displayName, systemImage: selectedProject == project ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                        Text(selectedProject?.displayName ?? "All Projects")
                            .font(.custom("Nunito", size: 13))
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                // P0 Only toggle
                Toggle(isOn: $showingP0Only) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("P0 Only")
                            .font(.custom("Nunito", size: 13))
                            .fontWeight(.medium)
                    }
                }
                .toggleStyle(.button)
                .foregroundColor(showingP0Only ? .white : .black.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(showingP0Only ? Color.red : Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                
                Spacer()
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        }
    }
    
    // MARK: - Todos List
    
    private var todosList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                let filteredTodos = getFilteredTodos()
                
                if filteredTodos.isEmpty {
                    emptyStateView
                } else {
                    // Group by priority
                    ForEach(TodoPriority.allCases.reversed(), id: \.self) { priority in
                        let priorityTodos = filteredTodos.filter { $0.priority == priority }
                        
                        if !priorityTodos.isEmpty {
                            prioritySection(priority: priority, todos: priorityTodos)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
    }
    
    private func prioritySection(priority: TodoPriority, todos: [SmartTodo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorForPriority(priority))
                    .frame(width: 10, height: 10)
                Text(priority.displayName)
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Text("(\(todos.count))")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.5))
            }
            .padding(.leading, 4)
            
            ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                AnimatedCard(index: index, animationDelay: 0.05) {
                    todoRow(todo)
                }
            }
        }
    }
    
    private func todoRow(_ todo: SmartTodo) -> some View {
        HStack(spacing: 16) {
            // Status checkbox - larger and more modern
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    toggleTodoStatus(todo)
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(todo.status == .completed ? Color.green : colorForPriority(todo.priority), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if todo.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(todo.title)
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .strikethrough(todo.status == .completed)
                    .opacity(todo.status == .completed ? 0.5 : 1.0)
                
                // Description (if present)
                if let description = todo.description {
                    Text(description)
                        .font(.custom("Nunito", size: 13))
                        .foregroundColor(.black.opacity(0.6))
                        .lineLimit(2)
                }
                
                // Metadata row
                HStack(spacing: 10) {
                    // Project badge
                    projectBadge(todo.project)
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(todo.formattedDuration)
                            .font(.custom("Nunito", size: 12))
                    }
                    .foregroundColor(.black.opacity(0.5))
                    
                    // Context
                    HStack(spacing: 4) {
                        Image(systemName: todo.context.icon)
                            .font(.system(size: 11))
                        Text(todo.context.rawValue)
                            .font(.custom("Nunito", size: 12))
                    }
                    .foregroundColor(.black.opacity(0.5))
                    
                    // Scheduled time
                    if let scheduled = todo.scheduledTime {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(scheduled.formatted(date: .abbreviated, time: .shortened))
                                .font(.custom("Nunito", size: 12))
                        }
                        .foregroundColor(.black.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Source badge
                    sourceBadge(todo.source)
                }
            }
            
            Spacer()
            
            // Urgency indicator
            if todo.urgencyScore > 0.7 {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: "F96E00"))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(16)
    }
    
    private func projectBadge(_ project: TodoProject) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorForProject(project))
                .frame(width: 6, height: 6)
            Text(project.displayName)
                .font(.custom("Nunito", size: 11))
                .fontWeight(.medium)
        }
        .foregroundColor(colorForProject(project))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorForProject(project).opacity(0.12))
        .cornerRadius(12)
    }
    
    private func sourceBadge(_ source: TodoSource) -> some View {
        let (icon, color): (String, Color)
        switch source {
        case .manual: (icon, color) = ("hand.raised.fill", .blue)
        case .jarvis: (icon, color) = ("brain", .purple)
        case .journal: (icon, color) = ("book.fill", .green)
        case .activity: (icon, color) = ("chart.line.uptrend.xyaxis", Color(hex: "F96E00"))
        case .proactive: (icon, color) = ("sparkles", .pink)
        }
        
        return Image(systemName: icon)
            .font(.system(size: 12))
            .foregroundColor(color.opacity(0.7))
    }
    
    private var emptyStateView: some View {
        UnifiedCard {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 8) {
                    Text("All caught up!")
                        .font(.custom("InstrumentSerif-Regular", size: 24))
                        .foregroundColor(.black)
                    
                    Text("No pending todos matching these filters")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Helpers
    
    private func getFilteredTodos() -> [SmartTodo] {
        let todos = todoEngine.getTodos(
            status: .pending,
            priority: showingP0Only ? .p0 : selectedPriority,
            project: selectedProject
        )
        
        return todos
    }
    
    private func toggleTodoStatus(_ todo: SmartTodo) {
        let newStatus: TodoStatus = todo.status == .completed ? .pending : .completed
        todoEngine.updateTodoStatus(todo.id, status: newStatus)
    }
    
    private func colorForPriority(_ priority: TodoPriority) -> Color {
        switch priority {
        case .p0: return .red
        case .p1: return .orange
        case .p2: return .gray
        }
    }
    
    private func colorForProject(_ project: TodoProject) -> Color {
        switch project {
        case .m3rcuryAgent: return .purple
        case .precisionDetail: return .blue
        case .windowWashing: return .cyan
        case .acneAI: return .green
        case .school: return .orange
        case .personal: return .pink
        case .selfCare: return .mint
        }
    }
    
}

// MARK: - Add Todo Sheet

struct AddTodoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var todoEngine = TodoExtractionEngine.shared
    
    @State private var title = ""
    @State private var description = ""
    @State private var project: TodoProject = .personal
    @State private var priority: TodoPriority = .p1
    @State private var duration: Double = 30 // minutes
    @State private var context: TodoContext = .laptop
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "FFF8F1"), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Todo")
                        .font(.custom("InstrumentSerif-Regular", size: 32))
                        .foregroundColor(.black)
                    
                    Text("Create a new task to stay organized")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Form content
                ScrollView {
                    VStack(spacing: 20) {
                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.custom("Nunito", size: 13))
                                .fontWeight(.semibold)
                                .foregroundColor(.black.opacity(0.7))
                            
                            TextField("Enter task title", text: $title)
                                .textFieldStyle(.plain)
                                .font(.custom("Nunito", size: 15))
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        // Description field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (Optional)")
                                .font(.custom("Nunito", size: 13))
                                .fontWeight(.semibold)
                                .foregroundColor(.black.opacity(0.7))
                            
                            TextField("Add more details", text: $description)
                                .textFieldStyle(.plain)
                                .font(.custom("Nunito", size: 15))
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        HStack(spacing: 16) {
                            // Project picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Project")
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black.opacity(0.7))
                                
                                Picker("Project", selection: $project) {
                                    ForEach(TodoProject.allCases, id: \.self) { proj in
                                        Text(proj.displayName).tag(proj)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.custom("Nunito", size: 14))
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(10)
                            }
                            
                            // Priority picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Priority")
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black.opacity(0.7))
                                
                                Picker("Priority", selection: $priority) {
                                    ForEach(TodoPriority.allCases, id: \.self) { pri in
                                        Text(pri.displayName).tag(pri)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .font(.custom("Nunito", size: 14))
                            }
                        }
                        
                        // Duration slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Duration")
                                    .font(.custom("Nunito", size: 13))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black.opacity(0.7))
                                Spacer()
                                Text("\(Int(duration)) minutes")
                                    .font(.custom("Nunito", size: 13))
                                    .foregroundColor(Color(hex: "F96E00"))
                                    .fontWeight(.semibold)
                            }
                            
                            Slider(value: $duration, in: 15...240, step: 15)
                                .tint(Color(hex: "F96E00"))
                        }
                        
                        // Context picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Context")
                                .font(.custom("Nunito", size: 13))
                                .fontWeight(.semibold)
                                .foregroundColor(.black.opacity(0.7))
                            
                            Picker("Context", selection: $context) {
                                ForEach(TodoContext.allCases, id: \.self) { ctx in
                                    Text(ctx.rawValue).tag(ctx)
                                }
                            }
                            .pickerStyle(.segmented)
                            .font(.custom("Nunito", size: 14))
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.7))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    
                    Button("Add Todo") {
                        addTodo()
                    }
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(title.isEmpty ? Color.gray.opacity(0.5) : Color(hex: "F96E00"))
                    .cornerRadius(10)
                    .shadow(color: title.isEmpty ? .clear : Color(hex: "F96E00").opacity(0.3), radius: 8, x: 0, y: 4)
                    .disabled(title.isEmpty)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .frame(width: 600, height: 650)
    }
    
    private func addTodo() {
        _ = todoEngine.createTodo(
            title: title,
            description: description.isEmpty ? nil : description,
            project: project,
            priority: priority,
            duration: TimeInterval(duration * 60),
            context: context
        )
        dismiss()
    }
}

struct SmartTodoView_Previews: PreviewProvider {
    static var previews: some View {
        SmartTodoView()
            .frame(width: 900, height: 700)
    }
}


