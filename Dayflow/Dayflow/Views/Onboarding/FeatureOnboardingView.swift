//
//  FeatureOnboardingView.swift
//  Dayflow
//
//  Individual feature onboarding view
//

import SwiftUI

struct FeatureOnboardingView: View {
    let feature: FeatureFlag
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: featureIcon)
                .font(.system(size: 64))
                .foregroundColor(featureColor)

            // Content
            VStack(spacing: 16) {
                Text(featureTitle)
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                Text(featureDescription)
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Got it button
            Button(action: onComplete) {
                Text("Got it!")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
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

    private var featureIcon: String {
        switch feature {
        case .suggestedTodos:
            return "lightbulb.fill"
        case .planner:
            return "calendar.badge.clock"
        case .enhancedDashboard:
            return "chart.bar.fill"
        case .dailyJournal:
            return "book.fill"
        case .focusSessions:
            return "timer"
        case .emergencyBreaks:
            return "pause.circle.fill"
        default:
            return "star.fill"
        }
    }

    private var featureColor: Color {
        switch feature {
        case .suggestedTodos:
            return .yellow
        case .planner:
            return .green
        case .enhancedDashboard:
            return .blue
        case .dailyJournal:
            return .purple
        case .focusSessions:
            return .blue
        case .emergencyBreaks:
            return .orange
        default:
            return Color(red: 0.25, green: 0.17, blue: 0)
        }
    }

    private var featureTitle: String {
        switch feature {
        case .suggestedTodos:
            return "AI-Powered Suggestions"
        case .planner:
            return "Smart Planning"
        case .enhancedDashboard:
            return "Enhanced Dashboard"
        case .dailyJournal:
            return "Daily Journal"
        case .focusSessions:
            return "Focus Sessions"
        case .emergencyBreaks:
            return "Emergency Breaks"
        default:
            return "New Feature"
        }
    }

    private var featureDescription: String {
        switch feature {
        case .suggestedTodos:
            return "Get intelligent task suggestions based on your work patterns and priorities."
        case .planner:
            return "Plan your day with intelligent scheduling and timeline optimization."
        case .enhancedDashboard:
            return "Advanced analytics and insights to track your productivity."
        case .dailyJournal:
            return "Reflect on your day with guided journaling prompts."
        case .focusSessions:
            return "Dedicated focus time with distraction blocking and time tracking."
        case .emergencyBreaks:
            return "Take managed breaks when you need them without losing focus."
        default:
            return "A new feature to help you be more productive."
        }
    }
}

#Preview {
    FeatureOnboardingView(feature: .suggestedTodos) {}
        .frame(width: 600, height: 500)
}