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
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
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
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)

            Text("Choose a template that matches your reflection style and goals")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.6))
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
        let isSelected = selectedTemplate == template
        
        return VStack(spacing: 12) {
            templateIcon(template, isSelected: isSelected)
            templateName(template, isSelected: isSelected)
            templateDescription(template, isSelected: isSelected)
        }
        .padding(16)
        .frame(height: 180)
        .background(cardBackground(template, isSelected: isSelected))
        .overlay(cardBorder(template, isSelected: isSelected))
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: selectedTemplate)
        .onTapGesture {
            selectedTemplate = template
        }
    }
    
    private func templateIcon(_ template: JournalTemplate, isSelected: Bool) -> some View {
        Image(systemName: template.icon)
            .font(.system(size: 32))
            .foregroundColor(isSelected ? .white : template.primaryColor)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? template.primaryColor : template.primaryColor.opacity(0.1))
            )
    }
    
    private func templateName(_ template: JournalTemplate, isSelected: Bool) -> some View {
        Text(template.displayName)
            .font(.custom("Nunito", size: 16))
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .white : .black)
    }
    
    private func templateDescription(_ template: JournalTemplate, isSelected: Bool) -> some View {
        Text(template.templateDescription)
            .font(.custom("Nunito", size: 11))
            .foregroundColor(isSelected ? .white.opacity(0.9) : .black.opacity(0.6))
            .multilineTextAlignment(.center)
            .lineLimit(3)
    }
    
    private func cardBackground(_ template: JournalTemplate, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? template.primaryColor : Color.gray.opacity(0.05))
    }
    
    private func cardBorder(_ template: JournalTemplate, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(isSelected ? template.primaryColor : Color.clear, lineWidth: 2)
    }

    // MARK: - Template Details Section

    private var templateDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About This Template")
                .font(.custom("Nunito", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black)

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
        .padding(20)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func detailRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(Color(red: 0.62, green: 0.44, blue: 0.36))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                Text(description)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
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
        Button {
            preferences.lengthPreference = length
        } label: {
            Text(length.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(preferences.lengthPreference == length ? selectedTemplate.primaryColor : Color.gray.opacity(0.1))
                )
                .foregroundColor(preferences.lengthPreference == length ? .white : .primary)
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
        Button {
            preferences.tonePreference = tone
        } label: {
            Text(tone.description)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(preferences.tonePreference == tone ? selectedTemplate.primaryColor : Color.gray.opacity(0.1))
                )
                .foregroundColor(preferences.tonePreference == tone ? .white : .primary)
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
                ForEach(JournalFocusArea.allCases, id: \.self) { area in
                    focusAreaButton(area)
                }
            }
        }
    }

    private func focusAreaButton(_ area: JournalFocusArea) -> some View {
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
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                    Text("Preview Template")
                        .fontWeight(.semibold)
                }
                .font(.custom("Nunito", size: 16))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        Color.white.opacity(0.69)
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 1, green: 0.77, blue: 0.34), location: 0.00),
                                Gradient.Stop(color: Color(red: 1, green: 0.98, blue: 0.95).opacity(0), location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 1.15, y: 3.61),
                            endPoint: UnitPoint(x: 0.02, y: 0)
                        )
                    }
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                // Save preferences and dismiss
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                    Text("Apply Template")
                        .fontWeight(.semibold)
                }
                .font(.custom("Nunito", size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(red: 1, green: 0.42, blue: 0.02))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
                .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Template Extensions

extension JournalTemplate {
    var primaryColor: Color {
        switch self {
        case .concise: return Color(red: 0.62, green: 0.44, blue: 0.36)
        case .balanced: return Color(red: 1, green: 0.42, blue: 0.02)
        case .detailed: return Color(red: 0.62, green: 0.44, blue: 0.36)
        case .reflective: return Color(red: 1, green: 0.42, blue: 0.02)
        case .achievement: return Color(red: 1, green: 0.77, blue: 0.34)
        case .gratitude: return Color(red: 0.62, green: 0.44, blue: 0.36)
        case .growth: return Color(red: 1, green: 0.42, blue: 0.02)
        case .comprehensive: return Color(red: 0.62, green: 0.44, blue: 0.36)
        case .custom: return Color(red: 1, green: 0.42, blue: 0.02)
        }
    }

    var focus: String {
        switch self {
        case .concise: return "Quick summary"
        case .balanced: return "Balanced overview"
        case .detailed: return "Comprehensive details"
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
        case .concise: return "Quick daily check-ins"
        case .balanced: return "Balanced daily reflection"
        case .detailed: return "Thorough life documentation"
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
        case .concise:
            return ["Brief summary", "Key highlights only", "Quick capture"]
        case .balanced:
            return ["Balanced perspective", "Key moments", "Moderate detail"]
        case .detailed:
            return ["Comprehensive review", "Detailed analysis", "Full documentation"]
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