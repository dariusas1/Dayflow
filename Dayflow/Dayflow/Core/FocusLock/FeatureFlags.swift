//
//  FeatureFlags.swift
//  FocusLock
//
//  Comprehensive feature flag system for controlled rollout of new FocusLock capabilities
//

import Foundation
import SwiftUI
import Combine

// MARK: - Feature Flag Definitions
enum FeatureFlag: String, CaseIterable, Codable {
    // Core FocusLock Features
    case suggestedTodos = "suggested_todos"
    case planner = "planner"
    case dailyJournal = "daily_journal"
    case enhancedDashboard = "enhanced_dashboard"
    case jarvisChat = "jarvis_chat"

    // Advanced Features
    case focusSessions = "focus_sessions"
    case emergencyBreaks = "emergency_breaks"
    case taskDetection = "task_detection"
    case performanceAnalytics = "performance_analytics"
    case smartNotifications = "smart_notifications"
    case bedtimeEnforcement = "bedtime_enforcement"

    // UI/UX Enhancements
    case adaptiveInterface = "adaptive_interface"
    case advancedOnboarding = "advanced_onboarding"
    case dataInsights = "data_insights"
    case gamification = "gamification"

    var displayName: String {
        switch self {
        case .suggestedTodos: return "Suggested Todos"
        case .planner: return "Smart Planner"
        case .dailyJournal: return "Daily Journal"
        case .enhancedDashboard: return "Enhanced Dashboard"
        case .jarvisChat: return "Jarvis AI Assistant"
        case .focusSessions: return "Focus Sessions"
        case .emergencyBreaks: return "Emergency Breaks"
        case .taskDetection: return "Task Detection"
        case .performanceAnalytics: return "Performance Analytics"
        case .smartNotifications: return "Smart Notifications"
        case .bedtimeEnforcement: return "Bedtime Enforcement"
        case .adaptiveInterface: return "Adaptive Interface"
        case .advancedOnboarding: return "Advanced Onboarding"
        case .dataInsights: return "Data Insights"
        case .gamification: return "Gamification"
        }
    }

    var description: String {
        switch self {
        case .suggestedTodos: return "AI-powered task suggestions based on your activity patterns"
        case .planner: return "Intelligent planning tools with timeline integration"
        case .dailyJournal: return "Automated journaling with mood and productivity tracking"
        case .enhancedDashboard: return "Advanced analytics and insights dashboard"
        case .jarvisChat: return "AI assistant for productivity guidance and support"
        case .focusSessions: return "Structured focus sessions with app blocking"
        case .emergencyBreaks: return "Quick break system for urgent interruptions"
        case .taskDetection: return "Automatic task detection and categorization"
        case .performanceAnalytics: return "Detailed performance metrics and trends"
        case .smartNotifications: return "Context-aware notifications and reminders"
        case .bedtimeEnforcement: return "Enforce healthy sleep habits with automatic bedtime shutdown"
        case .adaptiveInterface: return "Interface that adapts to your usage patterns"
        case .advancedOnboarding: return "Comprehensive onboarding for all features"
        case .dataInsights: return "Deep insights into your productivity patterns"
        case .gamification: return "Achievements and rewards for productivity milestones"
        }
    }

    var category: FeatureCategory {
        switch self {
        case .suggestedTodos, .planner, .dailyJournal, .enhancedDashboard, .jarvisChat:
            return .core
        case .focusSessions, .emergencyBreaks, .taskDetection, .bedtimeEnforcement:
            return .productivity
        case .performanceAnalytics, .smartNotifications, .dataInsights:
            return .analytics
        case .adaptiveInterface, .advancedOnboarding, .gamification:
            return .experience
        }
    }

    var isDefaultEnabled: Bool {
        // ALL FEATURES ENABLED BY DEFAULT FOR BETA LAUNCH
        // Users can still disable individual features if desired
        return true
    }

    var requiresOnboarding: Bool {
        switch self {
        case .suggestedTodos, .planner, .dailyJournal, .jarvisChat:
            return true
        default:
            return false
        }
    }

    var dependencies: [FeatureFlag] {
        switch self {
        case .enhancedDashboard:
            return [.suggestedTodos, .planner, .dailyJournal]
        case .performanceAnalytics:
            return [.focusSessions, .taskDetection]
        case .smartNotifications:
            return [.taskDetection, .dailyJournal]
        case .gamification:
            return [.focusSessions, .performanceAnalytics]
        default:
            return []
        }
    }

    var icon: String {
        switch self {
        case .suggestedTodos: return "checklist"
        case .planner: return "calendar.badge.clock"
        case .dailyJournal: return "book.closed"
        case .enhancedDashboard: return "chart.bar.doc.horizontal"
        case .jarvisChat: return "brain.head.profile"
        case .focusSessions: return "lock.shield"
        case .emergencyBreaks: return "exclamationmark.triangle"
        case .taskDetection: return "eye"
        case .performanceAnalytics: return "speedometer"
        case .smartNotifications: return "bell.badge"
        case .bedtimeEnforcement: return "moon.zzz.fill"
        case .adaptiveInterface: return "paintbrush"
        case .advancedOnboarding: return "graduationcap"
        case .dataInsights: return "lightbulb"
        case .gamification: return "trophy"
        }
    }
}

// MARK: - Feature Categories
enum FeatureCategory: String, CaseIterable, Codable {
    case core = "core"
    case productivity = "productivity"
    case analytics = "analytics"
    case experience = "experience"

    var displayName: String {
        switch self {
        case .core: return "Core Features"
        case .productivity: return "Productivity"
        case .analytics: return "Analytics"
        case .experience: return "User Experience"
        }
    }

    var description: String {
        switch self {
        case .core: return "Essential FocusLock functionality"
        case .productivity: return "Focus and task management tools"
        case .analytics: return "Data analysis and insights"
        case .experience: return "Interface and interaction enhancements"
        }
    }
}

// MARK: - Feature Flag Manager
@MainActor
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()

    @Published private var flags: [FeatureFlag: Bool] = [:]
    @Published private var rolloutStrategies: [FeatureFlag: RolloutStrategy] = [:]
    @Published private var onboardingStatus: [FeatureFlag: OnboardingStatus] = [:]
    @Published private var usageMetrics: [FeatureFlag: FeatureUsageMetrics] = [:]

    private let userDefaults = UserDefaults.standard
    private let flagsKey = "focuslock_feature_flags"
    private let onboardingKey = "focuslock_onboarding_status"
    private let metricsKey = "focuslock_feature_metrics"

    // MARK: - Initialization
    private init() {
        loadFlags()
        loadOnboardingStatus()
        loadUsageMetrics()
        setupDefaultRolloutStrategies()
    }

    // MARK: - Flag Access
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        // Check dependencies first
        guard areDependenciesEnabled(for: flag) else {
            return false
        }

        // Check rollout strategy
        if let strategy = rolloutStrategies[flag] {
            return strategy.shouldEnable(for: getCurrentUserSegment())
        }

        // Return stored value or default
        return flags[flag] ?? flag.isDefaultEnabled
    }

    func setEnabled(_ flag: FeatureFlag, enabled: Bool) {
        // Check dependencies when enabling
        if enabled && !areDependenciesEnabled(for: flag) {
            print("⚠️ Cannot enable \(flag.displayName): dependencies not met")
            return
        }

        flags[flag] = enabled
        saveFlags()

        // Track usage when enabled
        if enabled {
            recordFeatureUsage(flag, action: .enabled)
        }
    }

    // MARK: - Dependency Management
    internal func areDependenciesEnabled(for flag: FeatureFlag) -> Bool {
        return flag.dependencies.allSatisfy { dependency in
            isEnabled(dependency)
        }
    }

    func getDependencyStatus(for flag: FeatureFlag) -> [FeatureFlag: Bool] {
        var status: [FeatureFlag: Bool] = [:]
        for dependency in flag.dependencies {
            status[dependency] = isEnabled(dependency)
        }
        return status
    }

    // MARK: - Onboarding Management
    func needsOnboarding(for flag: FeatureFlag) -> Bool {
        return flag.requiresOnboarding && onboardingStatus[flag] != .completed
    }

    func setOnboardingStatus(for flag: FeatureFlag, status: OnboardingStatus) {
        onboardingStatus[flag] = status
        saveOnboardingStatus()

        if status == .completed {
            recordFeatureUsage(flag, action: .onboardingCompleted)
        }
    }

    func getOnboardingStatus(for flag: FeatureFlag) -> OnboardingStatus {
        return onboardingStatus[flag] ?? .notStarted
    }

    // MARK: - Rollout Strategy Management
    func setRolloutStrategy(_ strategy: RolloutStrategy, for flag: FeatureFlag) {
        rolloutStrategies[flag] = strategy
    }

    func getRolloutStrategy(for flag: FeatureFlag) -> RolloutStrategy? {
        return rolloutStrategies[flag]
    }

    private func getCurrentUserSegment() -> UserSegment {
        // Simple segment based on app usage patterns
        let daysSinceFirstLaunch = getDaysSinceFirstLaunch()
        let totalUsageHours = getTotalUsageHours()

        if totalUsageHours > 100 {
            return .powerUser
        } else if daysSinceFirstLaunch > 7 {
            return .regularUser
        } else {
            return .newUser
        }
    }

    // MARK: - Usage Analytics
    func recordFeatureUsage(_ flag: FeatureFlag, action: FeatureUsageAction) {
        var metrics = usageMetrics[flag] ?? FeatureUsageMetrics()
        metrics.recordUsage(action: action)
        usageMetrics[flag] = metrics
        saveUsageMetrics()

        // Send to analytics service
        AnalyticsService.shared.capture("feature_flag_usage", [
            "feature": flag.rawValue,
            "action": action.rawValue,
            "enabled": isEnabled(flag)
        ])
    }

    func getUsageMetrics(for flag: FeatureFlag) -> FeatureUsageMetrics? {
        return usageMetrics[flag]
    }

    func getAllEnabledFeatures() -> [FeatureFlag] {
        return FeatureFlag.allCases.filter { isEnabled($0) }
    }

    func getEnabledFeatures(in category: FeatureCategory) -> [FeatureFlag] {
        return FeatureFlag.allCases
            .filter { $0.category == category && isEnabled($0) }
    }

    // MARK: - Feature Discovery
    func getAvailableFeatures() -> [FeatureFlag] {
        return FeatureFlag.allCases.filter { flag in
            !isEnabled(flag) && areDependenciesEnabled(for: flag)
        }
    }

    func getRecommendedFeatures() -> [FeatureFlag] {
        let userSegment = getCurrentUserSegment()
        let enabledFeatures = Set(getAllEnabledFeatures())

        switch userSegment {
        case .newUser:
            return [.suggestedTodos, .planner, .dailyJournal]
                .filter { !enabledFeatures.contains($0) }
        case .regularUser:
            return [.enhancedDashboard, .jarvisChat, .focusSessions]
                .filter { !enabledFeatures.contains($0) }
        case .powerUser:
            return [.performanceAnalytics, .smartNotifications, .taskDetection]
                .filter { !enabledFeatures.contains($0) }
        }
    }

    // MARK: - Persistence
    private func loadFlags() {
        if let data = userDefaults.data(forKey: flagsKey),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
            flags = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                FeatureFlag(rawValue: key).map { ($0, value) }
            })
        } else {
            // Initialize with defaults
            flags = Dictionary(uniqueKeysWithValues: FeatureFlag.allCases.map { ($0, $0.isDefaultEnabled) })
        }
    }

    private func saveFlags() {
        let encoded = Dictionary(uniqueKeysWithValues: flags.map { ($0.rawValue, $1) })
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: flagsKey)
        }
    }

    private func loadOnboardingStatus() {
        if let data = userDefaults.data(forKey: onboardingKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            onboardingStatus = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let flag = FeatureFlag(rawValue: key),
                      let status = OnboardingStatus(rawValue: value) else { return nil }
                return (flag, status)
            })
        }
    }

    private func saveOnboardingStatus() {
        let encoded = Dictionary(uniqueKeysWithValues: onboardingStatus.map { ($0.rawValue, $1.rawValue) })
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: onboardingKey)
        }
    }

    private func loadUsageMetrics() {
        if let data = userDefaults.data(forKey: metricsKey),
           let decoded = try? JSONDecoder().decode([String: FeatureUsageMetrics].self, from: data) {
            usageMetrics = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                FeatureFlag(rawValue: key).map { ($0, value) }
            })
        }
    }

    private func saveUsageMetrics() {
        let encoded = Dictionary(uniqueKeysWithValues: usageMetrics.map { ($0.rawValue, $1) })
        if let data = try? JSONEncoder().encode(encoded) {
            userDefaults.set(data, forKey: metricsKey)
        }
    }

    // MARK: - Helper Methods
    private func setupDefaultRolloutStrategies() {
        // Core features: immediate rollout
        for flag in FeatureFlag.allCases where flag.category == .core {
            rolloutStrategies[flag] = ImmediateRollout()
        }

        // Productivity features: gradual rollout
        for flag in FeatureFlag.allCases where flag.category == .productivity {
            rolloutStrategies[flag] = GradualRollout(
                enabledPercentage: 0.3, // Start with 30% of users
                rampUpPeriod: 14 // Ramp up over 2 weeks
            )
        }

        // Experimental features: beta rollout
        for flag in FeatureFlag.allCases where flag.category == .experience {
            rolloutStrategies[flag] = BetaRollout(
                betaTestersOnly: true,
                requiresExplicitOptIn: true
            )
        }
    }

    private func getDaysSinceFirstLaunch() -> Int {
        let firstLaunch = userDefaults.object(forKey: "first_launch_date") as? Date ?? Date()
        return Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
    }

    private func getTotalUsageHours() -> Double {
        // This would be calculated from actual usage tracking
        // For now, return a placeholder
        return Double(getDaysSinceFirstLaunch()) * 2.0 // Assume 2 hours/day
    }
}

// MARK: - Rollout Strategies
protocol RolloutStrategy {
    func shouldEnable(for segment: UserSegment) -> Bool
}

struct ImmediateRollout: RolloutStrategy {
    func shouldEnable(for segment: UserSegment) -> Bool {
        return true
    }
}

struct GradualRollout: RolloutStrategy {
    let enabledPercentage: Double
    let rampUpPeriod: Int // days

    func shouldEnable(for segment: UserSegment) -> Bool {
        // Simple implementation: power users get early access
        switch segment {
        case .powerUser: return true
        case .regularUser: return enabledPercentage >= 0.5
        case .newUser: return enabledPercentage >= 0.8
        }
    }
}

struct BetaRollout: RolloutStrategy {
    let betaTestersOnly: Bool
    let requiresExplicitOptIn: Bool

    func shouldEnable(for segment: UserSegment) -> Bool {
        if requiresExplicitOptIn {
            return false // User must explicitly opt in
        }
        if betaTestersOnly {
            return segment == .powerUser
        }
        return false
    }
}

// MARK: - User Segments
enum UserSegment: String {
    case newUser = "new_user"
    case regularUser = "regular_user"
    case powerUser = "power_user"
}

// MARK: - Onboarding Status
enum OnboardingStatus: String, Codable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case skipped = "skipped"
    case completed = "completed"

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .skipped: return "Skipped"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Feature Usage Metrics
struct FeatureUsageMetrics: Codable {
    var totalUsageCount: Int = 0
    var lastUsed: Date?
    var firstUsed: Date?
    var usageActions: [FeatureUsageAction: Int] = [:]
    var weeklyUsage: [String: Int] = [:] // weekKey -> count

    mutating func recordUsage(action: FeatureUsageAction) {
        totalUsageCount += 1
        lastUsed = Date()

        if firstUsed == nil {
            firstUsed = Date()
        }

        usageActions[action, default: 0] += 1

        // Track weekly usage
        let weekKey = getCurrentWeekKey()
        weeklyUsage[weekKey, default: 0] += 1
    }

    private func getCurrentWeekKey() -> String {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-WW"
        return formatter.string(from: startOfWeek)
    }

    var weeklyUsageAverage: Double {
        let weekCount = Double(weeklyUsage.count)
        return weekCount > 0 ? Double(totalUsageCount) / weekCount : 0.0
    }

    var usageFrequency: UsageFrequency {
        guard let firstUsed = firstUsed else { return .never }
        let daysSinceFirstUse = Calendar.current.dateComponents([.day], from: firstUsed, to: Date()).day ?? 0
        guard daysSinceFirstUse > 0 else { return .once }

        let usagePerDay = Double(totalUsageCount) / Double(daysSinceFirstUse)

        if usagePerDay >= 1.0 {
            return .daily
        } else if usagePerDay >= 0.5 {
            return .weekly
        } else if usagePerDay >= 0.1 {
            return .monthly
        } else {
            return .rarely
        }
    }
}

enum FeatureUsageAction: String, Codable {
    case enabled = "enabled"
    case disabled = "disabled"
    case onboardingCompleted = "onboarding_completed"
    case viewed = "viewed"
    case interacted = "interacted"
    case shared = "shared"

    var displayName: String {
        switch self {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .onboardingCompleted: return "Onboarding Completed"
        case .viewed: return "Viewed"
        case .interacted: return "Interacted"
        case .shared: return "Shared"
        }
    }
}

enum UsageFrequency: String {
    case never = "never"
    case once = "once"
    case rarely = "rarely"
    case monthly = "monthly"
    case weekly = "weekly"
    case daily = "daily"

    var displayName: String {
        switch self {
        case .never: return "Never Used"
        case .once: return "Used Once"
        case .rarely: return "Rarely Used"
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .daily: return "Daily"
        }
    }
}

// MARK: - SwiftUI Integration
extension FeatureFlagManager {
    func binding(for flag: FeatureFlag) -> Binding<Bool> {
        Binding(
            get: { self.isEnabled(flag) },
            set: { self.setEnabled(flag, enabled: $0) }
        )
    }
}

// MARK: - Feature Flag Views
struct FeatureFlagToggle: View {
    let flag: FeatureFlag
    @ObservedObject private var flagManager = FeatureFlagManager.shared

    var body: some View {
        Toggle(flag.displayName, isOn: flagManager.binding(for: flag))
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))
            .disabled(!flagManager.areDependenciesEnabled(for: flag))
    }
}

struct FeatureFlagCard: View {
    let flag: FeatureFlag
    @ObservedObject private var flagManager = FeatureFlagManager.shared
    @State private var showDetails = false

    private var isEnabled: Bool {
        flagManager.isEnabled(flag)
    }

    private var dependenciesStatus: [FeatureFlag: Bool] {
        flagManager.getDependencyStatus(for: flag)
    }

    private var onboardingStatus: OnboardingStatus {
        flagManager.getOnboardingStatus(for: flag)
    }

    private var usageMetrics: FeatureUsageMetrics? {
        flagManager.getUsageMetrics(for: flag)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: flag.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isEnabled ? Color(red: 0.25, green: 0.17, blue: 0) : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(flag.displayName)
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.8))

                    Text(flag.description)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()

                FeatureFlagToggle(flag: flag)
            }

            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    if !dependenciesStatus.isEmpty {
                        dependencyStatusView
                    }

                    if flag.requiresOnboarding {
                        onboardingStatusView
                    }

                    if let metrics = usageMetrics {
                        usageMetricsView(metrics)
                    }
                }
                .padding(.top, 8)
            }

            Button(action: { showDetails.toggle() }) {
                HStack {
                    Text(showDetails ? "Hide Details" : "Show Details")
                        .font(.custom("Nunito", size: 12))
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled ? Color(hex: "FFE0A5") : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var dependencyStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dependencies:")
                .font(.custom("Nunito", size: 11))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.6))

            HStack {
                ForEach(Array(dependenciesStatus.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { dependency in
                    let isDepEnabled = dependenciesStatus[dependency] ?? false

                    HStack(spacing: 4) {
                        Image(systemName: isDepEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isDepEnabled ? Color(red: 0.35, green: 0.7, blue: 0.32) : .red)

                        Text(dependency.displayName)
                            .font(.custom("Nunito", size: 10))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var onboardingStatusView: some View {
        HStack {
            Image(systemName: onboardingStatusIcon)
                .font(.system(size: 12))
                .foregroundColor(onboardingStatusColor)

            Text("Onboarding: \(onboardingStatus.displayName)")
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.6))

            Spacer()

            if onboardingStatus != .completed && isEnabled {
                Button("Start") {
                    // Trigger onboarding flow
                }
                .font(.custom("Nunito", size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.25, green: 0.17, blue: 0))
                .foregroundColor(.white)
                .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func usageMetricsView(_ metrics: FeatureUsageMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Usage: \(metrics.usageFrequency.displayName)")
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.6))

            if let lastUsed = metrics.lastUsed {
                Text("Last used: \(relativeDate(lastUsed))")
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }

    private var onboardingStatusIcon: String {
        switch onboardingStatus {
        case .notStarted: return "circle"
        case .inProgress: return "play.circle"
        case .skipped: return "skip.forward.circle"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private var onboardingStatusColor: Color {
        switch onboardingStatus {
        case .notStarted: return .gray
        case .inProgress: return Color(hex: "FF7506")
        case .skipped: return .orange
        case .completed: return Color(red: 0.35, green: 0.7, blue: 0.32)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}