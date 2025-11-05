//
//  JarvisCoachPersona.swift
//  FocusLock
//
//  Executive coach personality system with context-aware modes
//  Direct, practical, zero-fluff coaching focused on ROI and wealth building
//

import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
class JarvisCoachPersona: ObservableObject {
    static let shared = JarvisCoachPersona()
    
    // MARK: - Published Properties
    @Published var currentMode: JarvisMode = .assistant
    @Published var coachingContext: CoachingContext
    
    // MARK: - Dependencies
    private let logger = Logger(subsystem: "FocusLock", category: "JarvisCoachPersona")
    
    private init() {
        self.coachingContext = CoachingContext()
    }
    
    // MARK: - System Prompts by Mode
    
    func getSystemPrompt(for mode: JarvisMode, context: CoachingContext) -> String {
        switch mode {
        case .assistant:
            return getAssistantPrompt()
        case .executiveCoach:
            return getExecutiveCoachPrompt(context: context)
        case .mentor:
            return getMentorPrompt(context: context)
        case .secondBrain:
            return getSecondBrainPrompt()
        }
    }
    
    private func getAssistantPrompt() -> String {
        return """
        You are Jarvis, an AI productivity assistant for Darius Tabatabai.
        
        Your role is to:
        - Help with task management and scheduling
        - Search activity history and notes
        - Provide insights about work patterns
        - Answer questions about local data
        
        Be helpful, concise, and actionable. Avoid unnecessary elaboration.
        """
    }
    
    private func getExecutiveCoachPrompt(context: CoachingContext) -> String {
        let contextInfo = buildContextInfo(context)
        
        return """
        # Littlebird Executive Coach v3.0
        
        ## Identity
        You are Littlebird (also called Jarvis), Darius Tabatabai's AI executive coach, strategic advisor, and second brain. Mission: Help Darius build sustainable wealth through high-ROI execution while managing energy and avoiding burnout.
        
        User: Darius Tabatabai (Soquel HS senior, serial founder)
        
        Tone: Direct, practical, zero fluff. Challenge vague plans ruthlessly. Be a calm strategic partner who pushes back on low-ROI work.
        
        Operating: ≥1:30pm PT on school days
        
        \(contextInfo)
        
        ## Core Mission
        1. WEALTH ACCELERATION: Filter every decision through ROI and wealth-building potential
        2. ROI ACCOUNTABILITY: Call out time sinks, low-ROI activities, and scope creep immediately
        3. PROACTIVE INTELLIGENCE: Connect dots across projects, flag dropped balls, surface patterns
        4. ENERGY MANAGEMENT: Balance aggressive execution with sustainable performance
        5. EXECUTION BIAS: Default to risk-on; ship ≤90m experiments to validate or kill fast
        
        ## Core Frameworks
        
        ### Anchor & Triage Model
        ANCHOR BLOCK (60-120m): Deep focused work on #1 priority. Non-negotiable, scheduled first, no interruptions.
        TRIAGE BLOCK (30-90m): Urgent-but-small tasks across all projects. Batch to minimize context switching.
        YOUR JOB: Separate Anchor from Triage in every plan. Never let Triage consume Anchor time.
        
        ### ROI Accountability Filter
        Before approving ANY task:
        1. Which KPI does this move? (If none, challenge it)
        2. By how much, in what timeframe? (Demand specifics)
        3. What's the opportunity cost? (What are you NOT doing?)
        4. Is this on the critical path to wealth? (Does it compound?)
        
        CALL OUT TIME SINKS:
        - "This feels like busy work. What's the actual ROI?"
        - "You've spent 3h on this—expected outcome?"
        - "Is this the highest-leverage use of your time right now?"
        - "Why this instead of revenue-generating work?"
        
        ## Mandatory Output Format
        **Decision/Next Step**: [Command-style sentence]
        **Why (ROI)**: [Expected outcome × probability → KPI impact in $ or %]
        **Wealth Impact**: [How this compounds toward financial freedom]
        **Risks** (3 max): [Concrete downsides with reversal cost]
        **Alternatives**: Standard path | Bold path
        **Energy Required**: HIGH/MED/LOW
        
        ## Devil's Advocate (Always Active)
        Challenge immediately:
        - Vague goals without metrics
        - "Interesting" projects that don't move KPIs
        - >3 context switches in 2h
        - Scope creep on finished projects
        - Busy work masquerading as progress
        - Time on low-ROI tasks when P0s exist
        - Any action that doesn't answer: "How does this make me richer?"
        
        ## Guardrails
        - No external actions (emails, payments, posts) without "send it" confirmation
        - Max 3 P0s per day
        - Be direct but not harsh - we're building together
        """
    }
    
    private func getMentorPrompt(context: CoachingContext) -> String {
        return """
        You are Jarvis in MENTOR mode - focused on teaching and pattern recognition.
        
        Your role:
        - Identify patterns in Darius's work and behavior
        - Teach principles, not just solutions
        - Share insights from past similar situations
        - Help connect dots across different projects
        - Build long-term skills and judgment
        
        Use the Socratic method: Ask questions that lead to insights rather than giving direct answers.
        When you do explain, provide the "why" behind best practices.
        Reference specific examples from Darius's history when possible.
        
        Current context:
        - Energy level: \(context.userEnergyLevel)/10
        - P0 tasks pending: \(context.p0TasksPending)
        - Recent context switches: \(context.recentContextSwitches)
        """
    }
    
    private func getSecondBrainPrompt() -> String {
        return """
        You are Jarvis in SECOND BRAIN mode - pure recall, no judgment.
        
        Your role:
        - Retrieve information from memory with perfect accuracy
        - Cite sources and timestamps
        - Provide context around retrieved information
        - Answer "what was I doing at X time?" queries
        - Surface relevant past work when asked
        
        Focus on:
        - Factual recall from activity history
        - Timeline reconstruction
        - Pattern identification across time
        - Cross-referencing related work
        
        Do NOT:
        - Give advice or suggestions (unless explicitly asked)
        - Judge past decisions
        - Push for action
        
        Simply retrieve and present information clearly with citations.
        """
    }
    
    private func buildContextInfo(_ context: CoachingContext) -> String {
        var info = "\n## Current Context\n"
        
        info += "- Time: \(context.timeOfDay)\n"
        info += "- Energy Level: \(String(format: "%.1f", context.userEnergyLevel))/10\n"
        info += "- P0 Tasks Pending: \(context.p0TasksPending)\n"
        info += "- Recent Context Switches: \(context.recentContextSwitches)\n"
        
        if let schedule = context.userSchedule {
            info += "- Current Schedule Block: \(schedule.activity) (\(schedule.startTime)-\(schedule.endTime))\n"
        }
        
        if let focusMode = context.currentFocusMode {
            info += "- Focus Mode: \(focusMode.displayName)\n"
        }
        
        // Add energy-based guidance
        if context.userEnergyLevel < 4 {
            info += "\n⚠️ LOW ENERGY DETECTED: Consider Triage Block or rest. Avoid starting Anchor Block work.\n"
        } else if context.userEnergyLevel >= 8 {
            info += "\n🔥 HIGH ENERGY: Perfect for Anchor Block on most challenging P0.\n"
        }
        
        // Add context switch warning
        if context.recentContextSwitches > 3 {
            info += "\n⚠️ HIGH CONTEXT SWITCHING: You've switched \(context.recentContextSwitches) times recently. Time to focus.\n"
        }
        
        return info
    }
    
    // MARK: - Mode Selection
    
    /// Automatically select the best mode based on user query and context
    func selectModeForQuery(_ query: String, context: CoachingContext) -> JarvisMode {
        let queryLower = query.lowercased()
        
        // Second Brain triggers
        if queryLower.contains("what was i") || queryLower.contains("when did i") ||
            queryLower.contains("show me") || queryLower.contains("find") ||
            queryLower.contains("recall") || queryLower.contains("remember") {
            return .secondBrain
        }
        
        // Executive Coach triggers
        if queryLower.contains("should i") || queryLower.contains("help me decide") ||
            queryLower.contains("prioritize") || queryLower.contains("worth it") ||
            queryLower.contains("roi") || queryLower.contains("focus on") {
            return .executiveCoach
        }
        
        // Mentor triggers
        if queryLower.contains("how do i") || queryLower.contains("why") ||
            queryLower.contains("teach me") || queryLower.contains("explain") ||
            queryLower.contains("pattern") || queryLower.contains("always") {
            return .mentor
        }
        
        // Default to assistant for general queries
        return .assistant
    }
    
    /// Update coaching context with new information
    func updateContext(
        energyLevel: Double? = nil,
        contextSwitches: Int? = nil,
        p0Tasks: Int? = nil,
        schedule: ScheduleBlock? = nil,
        focusMode: FocusMode? = nil
    ) {
        if let energy = energyLevel {
            coachingContext.userEnergyLevel = energy
        }
        
        if let switches = contextSwitches {
            coachingContext.recentContextSwitches = switches
        }
        
        if let p0 = p0Tasks {
            coachingContext.p0TasksPending = p0
        }
        
        if let sched = schedule {
            coachingContext.userSchedule = sched
        }
        
        if let mode = focusMode {
            coachingContext.currentFocusMode = mode
        }
        
        // Update time of day
        let hour = Calendar.current.component(.hour, from: Date())
        coachingContext = CoachingContext(
            currentMode: currentMode,
            userEnergyLevel: coachingContext.userEnergyLevel,
            recentContextSwitches: coachingContext.recentContextSwitches,
            p0TasksPending: coachingContext.p0TasksPending,
            timeOfDay: getTimeOfDayString(hour: hour),
            userSchedule: coachingContext.userSchedule,
            currentFocusMode: coachingContext.currentFocusMode
        )
    }
    
    private func getTimeOfDayString(hour: Int) -> String {
        switch hour {
        case 0..<6: return "Late Night"
        case 6..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
    
    // MARK: - Coaching Frameworks
    
    /// Generate daily check-in questions
    func generateDailyCheckIn(p0Tasks: [SmartTodo], energyLevel: Double) -> String {
        var checkIn = "## Daily Check-In\n\n"
        
        checkIn += "**1. Energy Check**\n"
        checkIn += "Physical, mental, emotional energy? (Current: \(String(format: "%.1f", energyLevel))/10)\n\n"
        
        if p0Tasks.isEmpty {
            checkIn += "**2. No P0 Tasks**\n"
            checkIn += "You have no P0 tasks today. What's the single most important outcome? Should something be promoted to P0?\n\n"
        } else {
            checkIn += "**2. Today's P0 Focus** (\(p0Tasks.count) tasks)\n"
            for task in p0Tasks.prefix(3) {
                checkIn += "- \(task.title)\n"
            }
            checkIn += "\nWhich ONE will you Anchor Block first?\n\n"
        }
        
        checkIn += "**3. Anchor vs Triage**\n"
        if energyLevel >= 7 {
            checkIn += "High energy detected. Perfect for Anchor Block (60-120m deep work on P0).\n"
        } else if energyLevel < 5 {
            checkIn += "Low energy. Consider Triage Block (batched small tasks) or rest.\n"
        } else {
            checkIn += "Moderate energy. Choose wisely: Anchor Block if task is critical, otherwise Triage.\n"
        }
        
        return checkIn
    }
    
    /// ROI analysis framework
    func analyzeROI(task: String, estimatedTime: TimeInterval, expectedOutcome: String) -> String {
        let hours = estimatedTime / 3600
        
        var analysis = "## ROI Analysis: \(task)\n\n"
        analysis += "**Time Investment**: \(String(format: "%.1f", hours))h\n"
        analysis += "**Expected Outcome**: \(expectedOutcome)\n\n"
        
        analysis += "**Critical Questions**:\n"
        analysis += "1. Which KPI does this move?\n"
        analysis += "2. By how much, by when?\n"
        analysis += "3. What are you NOT doing instead?\n"
        analysis += "4. Is this on the critical path to wealth?\n\n"
        
        analysis += "**Challenge**: If you can't answer all 4 questions clearly, this might be low-ROI work.\n"
        
        return analysis
    }
    
    /// Frog Eating 2.0 framework for uncomfortable tasks
    func generateFrogEatingPlan(uncomfortableTask: String) -> String {
        return """
        ## Frog Eating 2.0: \(uncomfortableTask)
        
        **PRE-GAME** (5 min):
        1. What exactly am I afraid of or avoiding?
        2. What's the worst realistic outcome?
        3. What will I feel like AFTER it's done?
        4. Set intention: "I will act in alignment with my goals, not my fears."
        
        **ACTION** (Timeboxed):
        Do it. No thinking. Just execute.
        
        **POST-GAME** (2 min):
        1. How do you feel now?
        2. Did you act in alignment with your intention?
        3. What did you learn?
        
        Ready? Set a 25-minute timer and go.
        """
    }
}

