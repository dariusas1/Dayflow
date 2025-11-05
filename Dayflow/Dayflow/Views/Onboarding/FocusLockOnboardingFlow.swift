//
//  FocusLockOnboardingFlow.swift
//  Dayflow
//
//  FocusLock feature onboarding experience
//

import SwiftUI

struct FocusLockOnboardingFlow: View {
    @AppStorage("focusLockOnboardingCompleted") private var onboardingCompleted = false
    @AppStorage("focusLockOnboardingStep") private var currentStepRawValue = 0
    @State private var currentStep: Step = .welcome
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    var body: some View {
        ZStack {
            switch currentStep {
            case .welcome:
                WelcomeStep(
                    onNext: advanceToNextStep
                )

            case .focusSessions:
                FocusSessionsStep(
                    onNext: advanceToNextStep,
                    onBack: goToPreviousStep
                )

            case .suggestedTodos:
                SuggestedTodosStep(
                    onNext: advanceToNextStep,
                    onBack: goToPreviousStep
                )
                .environmentObject(featureFlagManager)

            case .planner:
                PlannerStep(
                    onNext: advanceToNextStep,
                    onBack: goToPreviousStep
                )
                .environmentObject(featureFlagManager)

            case .emergencyBreak:
                EmergencyBreakStep(
                    onNext: completeOnboarding,
                    onBack: goToPreviousStep
                )

            case .completion:
                CompletionStep(
                    onFinish: completeOnboarding
                )
            }
        }
        .background {
            Color.white.ignoresSafeArea()
        }
        .onAppear {
            restoreCurrentStep()
        }
    }

    private func restoreCurrentStep() {
        if let savedStep = Step(rawValue: currentStepRawValue) {
            currentStep = savedStep
        }
    }

    private func setStep(_ step: Step) {
        currentStep = step
        currentStepRawValue = step.rawValue
    }

    private func advanceToNextStep() {
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        setStep(nextStep)
    }

    private func goToPreviousStep() {
        guard let previousStep = Step(rawValue: currentStep.rawValue - 1) else { return }
        setStep(previousStep)
    }

    private func completeOnboarding() {
        onboardingCompleted = true
        currentStepRawValue = 0
        dismiss()
    }
}

// MARK: - Onboarding Steps
private enum Step: Int, CaseIterable {
    case welcome = 0
    case focusSessions
    case suggestedTodos
    case planner
    case emergencyBreak
    case completion
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))

            // Content
            VStack(spacing: 16) {
                Text("Welcome to FocusLock")
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text("Your personal productivity companion that helps you stay focused, manage tasks intelligently, and achieve your goals.")
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Start button
            Button(action: onNext) {
                HStack {
                    Text("Get Started")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color(red: 0.25, green: 0.17, blue: 0))
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Focus Sessions Step
struct FocusSessionsStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingPageLayout(
            iconName: "timer",
            iconColor: Color.blue,
            title: "Focus Sessions",
            description: "Dedicated time blocks to help you concentrate on important tasks without distractions.",
            features: [
                "Track your focus time automatically",
                "Block distracting apps and websites",
                "Monitor your productivity patterns"
            ],
            onNext: onNext,
            onBack: onBack
        )
    }
}

// MARK: - Suggested Todos Step
struct SuggestedTodosStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager

    var body: some View {
        OnboardingPageLayout(
            iconName: "lightbulb.fill",
            iconColor: Color.yellow,
            title: "AI-Powered Task Suggestions",
            description: "Get intelligent task recommendations based on your work patterns and priorities.",
            features: [
                "AI analyzes your work habits",
                "Contextual task suggestions",
                "Priority-based recommendations",
                "Smart task categorization"
            ],
            onNext: onNext,
            onBack: onBack
        )
    }
}

// MARK: - Planner Step
struct PlannerStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager

    var body: some View {
        OnboardingPageLayout(
            iconName: "calendar.badge.clock",
            iconColor: Color.green,
            title: "Smart Planning",
            description: "Plan your day and week with intelligent scheduling and optimization.",
            features: [
                "Timeline and calendar views",
                "Drag-and-drop task scheduling",
                "Automatic time allocation",
                "Progress tracking and analytics"
            ],
            onNext: onNext,
            onBack: onBack
        )
    }
}

// MARK: - Emergency Break Step
struct EmergencyBreakStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingPageLayout(
            iconName: "pause.circle.fill",
            iconColor: Color.orange,
            title: "Emergency Break",
            description: "Take short, managed breaks when you need them without breaking your focus completely.",
            features: [
                "Quick break access during focus sessions",
                "Customizable break duration",
                "Daily break limits",
                "Break reason tracking"
            ],
            onNext: onNext,
            onBack: onBack
        )
    }
}

// MARK: - Completion Step
struct CompletionStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.green)

            // Content
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text("FocusLock is now ready to help you achieve your goals. Start your first focus session and experience the difference!")
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Complete button
            Button(action: onFinish) {
                HStack {
                    Text("Start Focusing")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color(red: 0.25, green: 0.17, blue: 0))
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Reusable Layout
struct OnboardingPageLayout: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    let features: [String]
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            // Navigation
            HStack {
                Button("Back", action: onBack)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()

                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index <= 2 ? Color(red: 0.25, green: 0.17, blue: 0) : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundColor(iconColor)

            // Content
            VStack(spacing: 16) {
                Text(title)
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }

            // Features
            VStack(spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.green)

                        Text(feature)
                            .font(.custom("Nunito", size: 14))
                            .foregroundColor(.black.opacity(0.8))

                        Spacer()
                    }
                    .padding(.horizontal, 40)
                }
            }

            Spacer()

            // Next button
            Button(action: onNext) {
                HStack {
                    Text("Next")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color(red: 0.25, green: 0.17, blue: 0))
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FocusLockOnboardingFlow()
        .environmentObject(FeatureFlagManager.shared)
        .frame(width: 800, height: 600)
}