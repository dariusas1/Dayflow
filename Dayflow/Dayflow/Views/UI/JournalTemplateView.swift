//
//  JournalTemplateView.swift
//  FocusLock
//
//  Template selection and customization interface for journal generation
//

import SwiftUI

struct JournalTemplateView: View {
    @Binding var selectedTemplate: JournalTemplate
    @Binding var preferences: JournalPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var showingPreview = false
    @State private var customizingTemplate = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Template Grid
                    templateGridSection

                    // Template Details
                    templateDetailsSection

                    // Customization Options
                    customizationSection

                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Select Your Journal Style")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose a template that matches your reflection style and goals")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Template Grid Section

    private var templateGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(JournalTemplate.allCases, id: \.self) { template in
                templateCard(template)
            }
        }
    }

    private func templateCard(_ template: JournalTemplate) -> some View {
        VStack(spacing: 12) {
            // Template Icon
            Image(systemName: template.systemImage)
                .font(.system(size: 32))
                .foregroundColor(selectedTemplate == template ? .white : template.primaryColor)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedTemplate == template ? template.primaryColor : template.primaryColor.opacity(0.1))
                )

            // Template Name
            Text(template.displayName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(selectedTemplate == template ? .white : .primary)

            // Template Description
            Text(template.description)
                .font(.caption)
                .foregroundColor(selectedTemplate == template ? .white.opacity(0.9) : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(16)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selectedTemplate == template ? template.primaryColor : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedTemplate == template ? template.primaryColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(selectedTemplate == template ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: selectedTemplate)
        .onTapGesture {
            selectedTemplate = template
        }
    }

    // MARK: - Template Details Section

    private var templateDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About This Template")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                detailRow(
                    icon: "target",
                    title: "Focus",
                    description: selectedTemplate.focus
                )

                detailRow(
                    icon: "clock",
                    title: "Best For",
                    description: selectedTemplate.bestFor
                )

                detailRow(
                    icon: "sparkles",
                    title: "Key Features",
                    description: selectedTemplate.keyFeatures.joined(separator: ", ")
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func detailRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(selectedTemplate.primaryColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Customization Section

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Customize Your Journal")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { customizingTemplate.toggle() }) {
                    Image(systemName: customizingTemplate ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }

            if customizingTemplate {
                VStack(spacing: 20) {
                    // Length Selection
                    lengthSelector

                    // Tone Selection
                    toneSelector

                    // Focus Areas
                    focusAreasSelector

                    // Additional Options
                    additionalOptions
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Length Selector

    private var lengthSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Length")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                ForEach(JournalLength.allCases, id: \.self) { length in
                    lengthButton(length)
                }
            }
        }
    }

    private func lengthButton(_ length: JournalLength) -> some View {
        Button(action: { preferences.length = length }) {
            Text(length.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(preferences.length == length ? selectedTemplate.primaryColor : Color.gray.opacity(0.1))
                )
                .foregroundColor(preferences.length == length ? .white : .primary)
        }
    }

    // MARK: - Tone Selector

    private var toneSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tone")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                ForEach(JournalTone.allCases, id: \.self) { tone in
                    toneButton(tone)
                }
            }
        }
    }

    private func toneButton(_ tone: JournalTone) -> some View {
        Button(action: { preferences.tone = tone }) {
            Text(tone.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(preferences.tone == tone ? selectedTemplate.primaryColor : Color.gray.opacity(0.1))
                )
                .foregroundColor(preferences.tone == tone ? .white : .primary)
        }
    }

    // MARK: - Focus Areas Selector

    private var focusAreasSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Areas")
                .font(.subheadline)
                .fontWeight(.medium)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(FocusArea.allCases, id: \.self) { area in
                    focusAreaButton(area)
                }
            }
        }
    }

    private func focusAreaButton(_ area: FocusArea) -> some View {
        Button(action: {
            if preferences.focusAreas.contains(area) {
                preferences.focusAreas.removeAll { $0 == area }
            } else {
                preferences.focusAreas.append(area)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: preferences.focusAreas.contains(area) ? "checkmark.square.fill" : "square")
                    .font(.caption2)
                Text(area.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(preferences.focusAreas.contains(area) ? selectedTemplate.primaryColor.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .foregroundColor(preferences.focusAreas.contains(area) ? selectedTemplate.primaryColor : .primary)
        }
    }

    // MARK: - Additional Options

    private var additionalOptions: some View {
        VStack(spacing: 12) {
            toggleOption(
                title: "Include Reflective Questions",
                description: "Add personalized questions for deeper reflection",
                isOn: $preferences.includeQuestions
            )

            toggleOption(
                title: "Highlight Key Moments",
                description: "Automatically identify and highlight important events",
                isOn: $preferences.includeHighlights
            )

            toggleOption(
                title: "Show Sentiment Analysis",
                description: "Include emotional insights and patterns",
                isOn: $preferences.includeSentiment
            )
        }
    }

    private func toggleOption(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(selectedTemplate.primaryColor)
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingPreview = true
            }) {
                HStack {
                    Image(systemName: "eye")
                    Text("Preview Template")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(selectedTemplate.primaryColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTemplate.primaryColor.opacity(0.1))
                .cornerRadius(12)
            }

            Button(action: {
                // Save preferences and dismiss
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Apply Template")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedTemplate.primaryColor)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Template Extensions

extension JournalTemplate {
    var primaryColor: Color {
        switch self {
        case .reflective: return .blue
        case .achievement: return .yellow
        case .gratitude: return .pink
        case .growth: return .green
        case .comprehensive: return .purple
        case .custom: return .orange
        }
    }

    var description: String {
        switch self {
        case .reflective:
            return "Deep introspection and personal insights through thoughtful reflection on daily experiences."
        case .achievement:
            return "Celebrate wins and track progress with focus on accomplishments and positive outcomes."
        case .gratitude:
            return "Cultivate appreciation by focusing on positive aspects and moments of thankfulness."
        case .growth:
            return "Emphasize learning, development, and personal growth through challenges and insights."
        case .comprehensive:
            return "Balanced overview covering achievements, challenges, learning, and emotional insights."
        case .custom:
            return "Tailored journal experience based on your unique preferences and goals."
        }
    }

    var focus: String {
        switch self {
        case .reflective: return "Self-discovery and insight"
        case .achievement: return "Successes and accomplishments"
        case .gratitude: return "Appreciation and positivity"
        case .growth: return "Learning and development"
        case .comprehensive: return "Holistic life overview"
        case .custom: return "Personalized focus areas"
        }
    }

    var bestFor: String {
        switch self {
        case .reflective: return "Deep thinkers and introspective users"
        case .achievement: return "Goal-oriented and motivated individuals"
        case .gratitude: return "Those seeking positive mindset"
        case .growth: return "Continuous learners and self-improvers"
        case .comprehensive: return "Users wanting complete life tracking"
        case .custom: return "Users with specific journaling needs"
        }
    }

    var keyFeatures: [String] {
        switch self {
        case .reflective:
            return ["Thoughtful questions", "Pattern recognition", "Self-discovery prompts"]
        case .achievement:
            return ["Win celebration", "Progress tracking", "Motivation boosters"]
        case .gratitude:
            return ["Gratitude lists", "Positive moments", "Appreciation exercises"]
        case .growth:
            return ["Learning insights", "Challenge analysis", "Growth tracking"]
        case .comprehensive:
            return ["Complete overview", "Multiple perspectives", "Balanced reflection"]
        case .custom:
            return ["Flexible structure", "Personalized content", "Adaptive focus"]
        }
    }
}




// MARK: - Preview

struct JournalTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        JournalTemplateView(
            selectedTemplate: .constant(.comprehensive),
            preferences: .constant(JournalPreferences())
        )
    }
}