//
//  PrivacyConsentView.swift
//  FocusLock
//
//  Privacy-first consent screen for analytics and crash reporting
//  Shown during onboarding to ensure explicit user consent
//

import SwiftUI

struct PrivacyConsentView: View {
    @Binding var analyticsConsent: Bool
    @Binding var hasSeenConsent: Bool
    let onContinue: () -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))

                Text("Your Privacy Matters")
                    .font(.custom("Nunito", size: 32))
                    .fontWeight(.bold)
                    .foregroundColor(.black.opacity(0.9))

                Text("FocusLock is privacy-first by design")
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black.opacity(0.6))
            }

            // Privacy principles
            VStack(alignment: .leading, spacing: 20) {
                PrivacyPrincipleRow(
                    icon: "checkmark.shield.fill",
                    title: "Local by Default",
                    description: "All screen recordings and AI analysis stay on your Mac"
                )

                PrivacyPrincipleRow(
                    icon: "hand.raised.fill",
                    title: "You Control Your Data",
                    description: "Choose your AI provider. Use local models for complete privacy"
                )

                PrivacyPrincipleRow(
                    icon: "eye.slash.fill",
                    title: "No Tracking Without Consent",
                    description: "Analytics and crash reporting are OFF by default"
                )
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.vertical, 8)

            // Optional consent section
            VStack(alignment: .leading, spacing: 16) {
                Text("Help us improve FocusLock (Optional)")
                    .font(.custom("Nunito", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))

                Toggle(isOn: $analyticsConsent) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send anonymous analytics and crash reports")
                            .font(.custom("Nunito", size: 15))
                            .foregroundColor(.black.opacity(0.8))

                        Text("No screen content or personal data is ever sent")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                if showDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What we collect:")
                            .font(.custom("Nunito", size: 13))
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.7))

                        BulletPoint(text: "App usage statistics (which features you use)")
                        BulletPoint(text: "Performance metrics (memory, CPU)")
                        BulletPoint(text: "Crash logs (to fix bugs)")

                        Text("What we NEVER collect:")
                            .font(.custom("Nunito", size: 13))
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.top, 8)

                        BulletPoint(text: "Screen recordings or screenshots")
                        BulletPoint(text: "Window titles or app names")
                        BulletPoint(text: "Any personally identifiable information")
                        BulletPoint(text: "File paths or URLs")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }

                Button(action: { showDetails.toggle() }) {
                    HStack {
                        Text(showDetails ? "Hide Details" : "Show Details")
                            .font(.custom("Nunito", size: 13))
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 40)

            Spacer()

            // Continue button
            Button(action: {
                hasSeenConsent = true
                AnalyticsService.shared.setOptIn(analyticsConsent)
                onContinue()
            }) {
                Text("Continue")
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.25, green: 0.17, blue: 0))
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.95))
    }
}

struct PrivacyPrincipleRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.35, green: 0.7, blue: 0.32))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))

                Text(description)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))

            Text(text)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyConsentView(
        analyticsConsent: .constant(false),
        hasSeenConsent: .constant(false),
        onContinue: {}
    )
}
