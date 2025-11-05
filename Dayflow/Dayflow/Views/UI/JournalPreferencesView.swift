//
//  JournalPreferencesView.swift
//  FocusLock
//
//  User preferences and settings for journal generation
//

import SwiftUI

struct JournalPreferencesView: View {
    @Binding var preferences: JournalPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var showingAdvancedOptions = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Default Settings
                    defaultSettingsSection

                    // Generation Preferences
                    generationPreferencesSection

                    // Privacy Settings
                    privacySection

                    // Advanced Options
                    advancedOptionsSection

                    // Reset Section
                    resetSection
                }
                .padding()
            }
            .navigationTitle("Journal Preferences")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Reset Preferences", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetPreferences()
                }
            } message: {
                Text("This will reset all journal preferences to their default values. This action cannot be undone.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Customize Your Experience")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Fine-tune your journal generation to match your personal style and preferences")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Default Settings Section

    private var defaultSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default Settings")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                // Default Template
                settingRow(
                    title: "Default Template",
                    description: "Template used when generating journals",
                    value: preferences.preferredTemplate.displayName,
                    action: {
                        // Template selection would be handled here
                    }
                )

                // Default Length
                settingRow(
                    title: "Default Length",
                    description: "Preferred journal length",
                    value: preferences.lengthPreference.displayName,
                    action: {
                        // Length selection would be handled here
                    }
                )

                // Default Tone
                settingRow(
                    title: "Default Tone",
                    description: "Writing style for your journals",
                    value: preferences.tonePreference.description,
                    action: {
                        // Tone selection would be handled here
                    }
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Generation Preferences Section

    private var generationPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generation Preferences")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                // Note: Auto-generate feature would need to be implemented in the generator

                // Include questions
                toggleSetting(
                    title: "Include Reflective Questions",
                    description: "Add personalized questions for deeper reflection",
                    isOn: $preferences.includeQuestions
                )

                // Include highlights
                toggleSetting(
                    title: "Extract Key Highlights",
                    description: "Automatically identify and highlight important moments",
                    isOn: $preferences.includeHighlights
                )

                // Include sentiment
                toggleSetting(
                    title: "Analyze Emotional Patterns",
                    description: "Include sentiment analysis and emotional insights",
                    isOn: $preferences.includeSentiment
                )

                // Note: Max highlights would be a generator setting
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy & Security")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                // Note: Privacy settings would be managed at the app level
                Text("Privacy settings are managed at the application level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Advanced Options Section

    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced Options")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingAdvancedOptions.toggle() }) {
                    Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }

            if showingAdvancedOptions {
                VStack(spacing: 12) {
                    // Custom prompts
                    textAreaSetting(
                        title: "Custom Instructions",
                        description: "Additional instructions for journal generation",
                        text: Binding(
                            get: { preferences.customPrompts.joined(separator: "\n") },
                            set: { preferences.customPrompts = $0.components(separatedBy: "\n").filter { !$0.isEmpty } }
                        )
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Default")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Setting UI Components

    private func settingRow(title: String, description: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

                HStack(spacing: 4) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func toggleSetting(title: String, description: String, isOn: Binding<Bool>) -> some View {
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
                .tint(.blue)
        }
    }

    private func stepperSetting(title: String, description: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

                Stepper(value: value, in: range, step: step) {
                    Text("\(value.wrappedValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private func sliderSetting(title: String, description: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(String(format: "%.0f%%", value.wrappedValue * 100))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)

            Slider(value: value, in: range)
                .tint(.blue)
        }
    }

    private func pickerSetting<T: CaseIterable & Hashable>(title: String, description: String, selection: Binding<T>) -> some View where T: CustomStringConvertible {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker(selection: selection, label: EmptyView()) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private func textAreaSetting(title: String, description: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: text)
                .font(.body)
                .padding(8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .frame(minHeight: 80)
        }
    }

    // MARK: - Helper Methods

    private func savePreferences() {
        // Save preferences to UserDefaults or other storage
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "JournalPreferences")
        }
    }

    private func resetPreferences() {
        preferences = JournalPreferences()
        savePreferences()
    }
}

// MARK: - Extensions

extension JournalRetentionPeriod: CustomStringConvertible {
    var description: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        case .forever: return "Forever"
        default: return "1 Month" // Fallback for any other cases
        }
    }
}

// MARK: - Preview

struct JournalPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        JournalPreferencesView(preferences: .constant(JournalPreferences()))
    }
}