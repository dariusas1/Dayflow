//
//  SettingsView.swift
//  Dayflow
//
//  Settings screen with onboarding-inspired styling and split layout
//

import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var featureFlagManager = FeatureFlagManager.shared
    
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case storage
        case providers
        case focuslock
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .storage: return "Storage"
            case .providers: return "Providers"
            case .focuslock: return "FocusLock"
            case .other: return "Other"
            }
        }

        var subtitle: String {
            switch self {
            case .storage: return "Recording status and disk usage"
            case .providers: return "Manage LLM providers and customize prompts"
            case .focuslock: return "Focus sessions and productivity features"
            case .other: return "General preferences & support"
            }
        }
    }

    // Tab + analytics state
    @State private var selectedTab: SettingsTab = .storage
    @State private var analyticsEnabled: Bool = AnalyticsService.shared.isOptedIn

    // Provider state
    @State private var currentProvider: String = "gemini"
    @State private var setupModalProvider: String? = nil
    @State private var hasLoadedProvider = false
    @State private var selectedGeminiModel: GeminiModel = GeminiModelPreference.load().primary
    @State private var savedGeminiModel: GeminiModel = GeminiModelPreference.load().primary

    // Gemini prompt customization
    @State private var geminiPromptOverridesLoaded = false
    @State private var isUpdatingGeminiPromptState = false
    @State private var useCustomGeminiTitlePrompt = false
    @State private var useCustomGeminiSummaryPrompt = false
    @State private var useCustomGeminiDetailedPrompt = false
    @State private var geminiTitlePromptText = GeminiPromptDefaults.titleBlock
    @State private var geminiSummaryPromptText = GeminiPromptDefaults.summaryBlock
    @State private var geminiDetailedPromptText = GeminiPromptDefaults.detailedSummaryBlock

    // Ollama prompt customization
    @State private var ollamaPromptOverridesLoaded = false
    @State private var isUpdatingOllamaPromptState = false
    @State private var useCustomOllamaTitlePrompt = false
    @State private var useCustomOllamaSummaryPrompt = false
    @State private var ollamaTitlePromptText = OllamaPromptDefaults.titleBlock
    @State private var ollamaSummaryPromptText = OllamaPromptDefaults.summaryBlock

    // Local provider cached settings
    @State private var localBaseURL: String = UserDefaults.standard.string(forKey: "llmLocalBaseURL") ?? "http://localhost:11434"
    @State private var localModelId: String = UserDefaults.standard.string(forKey: "llmLocalModelId") ?? "qwen2.5vl:3b"
    @State private var localEngine: LocalEngine = {
        let raw = UserDefaults.standard.string(forKey: "llmLocalEngine") ?? "ollama"
        return LocalEngine(rawValue: raw) ?? .ollama
    }()

    // Storage metrics
    @State private var isRefreshingStorage = false
    @State private var storagePermissionGranted: Bool?
    @State private var lastStorageCheck: Date?
    @State private var recordingsUsageBytes: Int64 = 0
    @State private var timelapseUsageBytes: Int64 = 0
    @State private var recordingsLimitBytes: Int64 = StoragePreferences.recordingsLimitBytes
    @State private var timelapsesLimitBytes: Int64 = StoragePreferences.timelapsesLimitBytes
    @State private var recordingsLimitIndex: Int = 0
    @State private var timelapsesLimitIndex: Int = 0
    @State private var showLimitConfirmation = false
    @State private var pendingLimit: PendingLimit?
    
    // Data management state
    @State private var showExportDialog = false
    @State private var showClearConfirmation = false
    @State private var showResetConfirmation = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportError = false

    // Providers – debug log copy feedback

    private let usageFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        contentWithLifecycle
            .preferredColorScheme(.light)
            .modifier(AlertsModifier(
                showClearConfirmation: $showClearConfirmation,
                showResetConfirmation: $showResetConfirmation,
                showExportError: $showExportError,
                exportError: exportError,
                clearAnalytics: { Task { await clearAnalytics() } },
                resetSettings: { Task { await resetSettings() } }
            ))
            .sheet(item: Binding(
                get: { setupModalProvider.map { ProviderSetupWrapper(id: $0) } },
                set: { setupModalProvider = $0?.id }
            )) { wrapper in
                LLMProviderSetupView(
                    providerType: wrapper.id,
                    onBack: { setupModalProvider = nil },
                    onComplete: {
                        completeProviderSwitch(wrapper.id)
                        setupModalProvider = nil
                    }
                )
                .frame(minWidth: 900, minHeight: 650)
            }
            .alert(isPresented: $showLimitConfirmation) {
                if let pending = pendingLimit,
                   Self.storageOptions.indices.contains(pending.index) {
                    let option = Self.storageOptions[pending.index]
                    let categoryName = pending.category.displayName
                    return Alert(
                        title: Text("Lower \(categoryName) limit?"),
                        message: Text("Reducing the \(categoryName) limit to \(option.label) will immediately delete the oldest \(categoryName) data to stay under the new cap."),
                        primaryButton: .destructive(Text("Confirm")) {
                            applyLimit(for: pending.category, index: pending.index)
                        },
                        secondaryButton: .cancel {
                            pendingLimit = nil
                            showLimitConfirmation = false
                        }
                    )
                } else {
                    return Alert(title: Text("Adjust storage limit"), dismissButton: .default(Text("OK")))
                }
            }
            .modifier(PromptChangeHandlersModifier(
                useCustomGeminiTitlePrompt: $useCustomGeminiTitlePrompt,
                useCustomGeminiSummaryPrompt: $useCustomGeminiSummaryPrompt,
                useCustomGeminiDetailedPrompt: $useCustomGeminiDetailedPrompt,
                geminiTitlePromptText: $geminiTitlePromptText,
                geminiSummaryPromptText: $geminiSummaryPromptText,
                geminiDetailedPromptText: $geminiDetailedPromptText,
                useCustomOllamaTitlePrompt: $useCustomOllamaTitlePrompt,
                useCustomOllamaSummaryPrompt: $useCustomOllamaSummaryPrompt,
                ollamaTitlePromptText: $ollamaTitlePromptText,
                ollamaSummaryPromptText: $ollamaSummaryPromptText,
                persistGemini: { persistGeminiPromptOverridesIfReady() },
                persistOllama: { persistOllamaPromptOverridesIfReady() }
            ))
    }
    
    private var contentWithLifecycle: some View {
        mainContent
            .onAppear(perform: handleAppear)
            .onChange(of: analyticsEnabled) { oldValue, newValue in
                AnalyticsService.shared.setOptIn(newValue)
            }
            .onChange(of: currentProvider) { oldValue, newValue in
                handleProviderChange(newValue)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == .storage {
                    refreshStorageIfNeeded()
                }
            }
    }
}

// MARK: - Modifiers

private struct AlertsModifier: ViewModifier {
    @Binding var showClearConfirmation: Bool
    @Binding var showResetConfirmation: Bool
    @Binding var showExportError: Bool
    let exportError: String?
    let clearAnalytics: () -> Void
    let resetSettings: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Clear Analytics Data", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive, action: clearAnalytics)
            } message: {
                Text("This will permanently remove all analytics and usage statistics. This action cannot be undone.")
            }
            .alert("Reset Focus Settings", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive, action: resetSettings)
            } message: {
                Text("This will reset all FocusLock settings to their default values. Your data will not be deleted, but all preferences will be restored to defaults.")
            }
            .alert("Export Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = exportError {
                    Text(error)
                }
            }
    }
}

private struct PromptChangeHandlersModifier: ViewModifier {
    @Binding var useCustomGeminiTitlePrompt: Bool
    @Binding var useCustomGeminiSummaryPrompt: Bool
    @Binding var useCustomGeminiDetailedPrompt: Bool
    @Binding var geminiTitlePromptText: String
    @Binding var geminiSummaryPromptText: String
    @Binding var geminiDetailedPromptText: String
    @Binding var useCustomOllamaTitlePrompt: Bool
    @Binding var useCustomOllamaSummaryPrompt: Bool
    @Binding var ollamaTitlePromptText: String
    @Binding var ollamaSummaryPromptText: String
    let persistGemini: () -> Void
    let persistOllama: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: useCustomGeminiTitlePrompt) { _, _ in persistGemini() }
            .onChange(of: useCustomGeminiSummaryPrompt) { _, _ in persistGemini() }
            .onChange(of: useCustomGeminiDetailedPrompt) { _, _ in persistGemini() }
            .onChange(of: geminiTitlePromptText) { _, _ in persistGemini() }
            .onChange(of: geminiSummaryPromptText) { _, _ in persistGemini() }
            .onChange(of: geminiDetailedPromptText) { _, _ in persistGemini() }
            .onChange(of: useCustomOllamaTitlePrompt) { _, _ in persistOllama() }
            .onChange(of: useCustomOllamaSummaryPrompt) { _, _ in persistOllama() }
            .onChange(of: ollamaTitlePromptText) { _, _ in persistOllama() }
            .onChange(of: ollamaSummaryPromptText) { _, _ in persistOllama() }
    }
}

extension SettingsView {
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 32) {
            sidebar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    tabContent
                }
                .padding(.top, 24)
                .padding(.trailing, 16)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 600, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func handleAppear() {
        loadCurrentProvider()
        analyticsEnabled = AnalyticsService.shared.isOptedIn
        refreshStorageIfNeeded()
        reloadLocalProviderSettings()
        loadGeminiPromptOverridesIfNeeded()
        loadOllamaPromptOverridesIfNeeded()
        let recordingsLimit = StoragePreferences.recordingsLimitBytes
        recordingsLimitBytes = recordingsLimit
        recordingsLimitIndex = indexForLimit(recordingsLimit)
        let timelapseLimit = StoragePreferences.timelapsesLimitBytes
        timelapsesLimitBytes = timelapseLimit
        timelapsesLimitIndex = indexForLimit(timelapseLimit)
        AnalyticsService.shared.capture("settings_opened")
    }
    
    private func handleProviderChange(_ newValue: String) {
        reloadLocalProviderSettings()
        if newValue == "gemini" {
            loadGeminiPromptOverridesIfNeeded(force: true)
        } else if newValue == "ollama" {
            loadOllamaPromptOverridesIfNeeded(force: true)
        }
    }
    

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            Text("Settings")
                .font(.custom(DesignTypography.displayFont, size: DesignTypography.display))
                .foregroundColor(DesignColors.primaryText)
                .padding(.leading, DesignSpacing.sm)

            Text("Manage how Dayflow runs")
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                .foregroundColor(DesignColors.secondaryText)
                .padding(.leading, DesignSpacing.sm)
                .padding(.bottom, DesignSpacing.md)

            ForEach(SettingsTab.allCases) { tab in
                sidebarButton(for: tab)
            }

            Spacer()

            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text("Dayflow v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .foregroundColor(DesignColors.tertiaryText)
                    .padding(.leading, DesignSpacing.sm)
                Button {
                    NotificationCenter.default.post(name: .showWhatsNew, object: nil)
                } label: {
                    HStack(spacing: DesignSpacing.xs) {
                        Text("View release notes")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(DesignColors.primaryOrange)
                .padding(.leading, DesignSpacing.sm)
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 16)
        .padding(.horizontal, 4)
        .frame(width: 198, alignment: .topLeading)
    }

    private func sidebarButton(for tab: SettingsTab) -> some View {
        Button {
            withAnimation(DesignAnimation.spring) {
                selectedTab = tab
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(tab.title)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.subheadline))
                    .fontWeight(.semibold)
                    .foregroundColor(selectedTab == tab ? DesignColors.primaryText : DesignColors.secondaryText)
                Text(tab.subtitle)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    .foregroundColor(selectedTab == tab ? DesignColors.tertiaryText : DesignColors.tertiaryText.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSpacing.md)
            .padding(.horizontal, DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                    .fill(selectedTab == tab ? DesignColors.cardBackground : Color.white.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                            .stroke(selectedTab == tab ? DesignColors.primaryOrange : Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: selectedTab == tab ? DesignColors.shadowColor : Color.clear, radius: DesignRadius.medium, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .storage:
            storageContent
        case .providers:
            providersContent
        case .focuslock:
            focusLockContent
        case .other:
            otherContent
        }
    }

    // MARK: - Storage Tab

    private var storageContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsCard(title: "Recording Status", subtitle: "Ensure Dayflow can capture your screen") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        statusPill(icon: storagePermissionGranted == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                                   tint: storagePermissionGranted == true ? Color(red: 0.35, green: 0.7, blue: 0.32) : Color(hex: "E91515"),
                                   text: storagePermissionGranted == true ? "Screen recording permission granted" : "Screen recording permission missing")

                        statusPill(icon: AppState.shared.isRecording ? "dot.radiowaves.left.and.right" : "pause.circle",
                                   tint: AppState.shared.isRecording ? Color(hex: "FF7506") : Color.black.opacity(0.25),
                                   text: AppState.shared.isRecording ? "Recorder active" : "Recorder idle")
                    }

                    HStack(spacing: DesignSpacing.sm) {
                        HStack(spacing: DesignSpacing.xs) {
                            if isRefreshingStorage {
                                ProgressView().scaleEffect(0.75)
                            }
                            UnifiedButton.primary(
                                isRefreshingStorage ? "Checking…" : "Run status check",
                                size: .small,
                                disabled: isRefreshingStorage,
                                icon: isRefreshingStorage ? nil : "arrow.clockwise",
                                action: refreshStorageMetrics
                            )
                        }

                        if let last = lastStorageCheck {
                            Text("Last checked \(relativeDate(last))")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(.black.opacity(0.45))
                        }
                    }
                }
            }

            SettingsCard(title: "Disk usage", subtitle: "Open folders or adjust per-type storage caps") {
                VStack(alignment: .leading, spacing: 18) {
                    usageRow(
                        category: .recordings,
                        label: "Recordings",
                        size: recordingsUsageBytes,
                        tint: Color(hex: "FF7506"),
                        limitIndex: recordingsLimitIndex,
                        limitBytes: recordingsLimitBytes,
                        actionTitle: "Open",
                        action: openRecordingsFolder
                    )
                    usageRow(
                        category: .timelapses,
                        label: "Timelapses",
                        size: timelapseUsageBytes,
                        tint: Color(hex: "1D7FFE"),
                        limitIndex: timelapsesLimitIndex,
                        limitBytes: timelapsesLimitBytes,
                        actionTitle: "Open",
                        action: openTimelapseFolder
                    )

                    Text(storageFooterText())
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func usageRow(category: StorageCategory, label: String, size: Int64, tint: Color, limitIndex: Int, limitBytes: Int64, actionTitle: String, action: @escaping () -> Void) -> some View {
        let usageString = usageFormatter.string(fromByteCount: size)
        let progress: Double? = limitBytes == Int64.max || limitBytes == 0 ? nil : min(Double(size) / Double(limitBytes), 1.0)
        let percentString: String? = progress.map { value in
            String(format: "%.0f%% of limit", value * 100)
        }
        let option = Self.storageOptions[limitIndex]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.75))
                    HStack(spacing: 6) {
                        Text(usageString)
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.55))
                        if let percentString {
                            Text(percentString)
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(.black.opacity(0.45))
                        }
                    }
                }
                Spacer()
                UnifiedButton.secondary(
                    actionTitle,
                    size: .small,
                    icon: "folder",
                    action: action
                )

                Menu {
                    ForEach(Self.storageOptions) { candidate in
                        Button(candidate.label) {
                            handleLimitSelection(for: category, index: candidate.id)
                        }
                    }
                } label: {
                    HStack(spacing: DesignSpacing.xs) {
                        Image(systemName: "slider.horizontal.3")
                        Text(option.label)
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                    }
                    .foregroundColor(DesignColors.primaryOrange)
                    .padding(.horizontal, DesignSpacing.sm)
                    .padding(.vertical, DesignSpacing.xs)
                    .background(DesignColors.cardBackground)
                    .cornerRadius(DesignRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.small)
                            .stroke(DesignColors.primaryOrange, lineWidth: 1)
                    )
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }

            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: tint))
            }
        }
    }

    private func statusPill(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: DesignSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
            Text(text)
                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                .foregroundColor(DesignColors.secondaryText)
        }
        .padding(.horizontal, DesignSpacing.sm)
        .padding(.vertical, DesignSpacing.xs)
        .background(
            Capsule()
                .fill(DesignColors.cardBackground)
                .overlay(Capsule().stroke(DesignColors.glassBorder, lineWidth: 0.8))
        )
    }

    // MARK: - Providers Tab

    private var providersContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsCard(title: "Current configuration", subtitle: "Active provider and runtime details") {
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    providerSummary
                    UnifiedButton.primary(
                        "Edit configuration",
                        size: .small,
                        icon: "slider.horizontal.3",
                        action: { setupModalProvider = currentProvider }
                    )
                }
            }

            SettingsCard(title: "Connection health", subtitle: "Run a quick test for the active provider") {
                VStack(alignment: .leading, spacing: DesignSpacing.md) {
                    Text(currentProvider == "gemini" ? "Gemini API" : "Local API")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.subheadline))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)

                    if currentProvider == "gemini" {
                        TestConnectionView(onTestComplete: { _ in })
                    } else if currentProvider == "ollama" {
                        LocalLLMTestView(
                            baseURL: $localBaseURL,
                            modelId: $localModelId,
                            engine: localEngine,
                            showInputs: false,
                            onTestComplete: { _ in
                                UserDefaults.standard.set(localBaseURL, forKey: "llmLocalBaseURL")
                                UserDefaults.standard.set(localModelId, forKey: "llmLocalModelId")
                            }
                        )
                    } else {
                        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                            Text("Dayflow Pro diagnostics coming soon")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                                .foregroundColor(DesignColors.secondaryText)
                        }
                    }
                }
            }

            if currentProvider == "gemini" {
                SettingsCard(title: "Gemini model preference", subtitle: "Choose which Gemini model Dayflow should prioritize") {
                    GeminiModelSettingsCard(selectedModel: $selectedGeminiModel) { model in
                        persistGeminiModelSelection(model, source: "settings")
                    }
                }

                SettingsCard(title: "Gemini prompt customization", subtitle: "Override Dayflow's defaults to tailor card generation") {
                    geminiPromptCustomizationView
                }
            } else if currentProvider == "ollama" {
                SettingsCard(title: "Local prompt customization", subtitle: "Adjust the prompts used for local timeline summaries") {
                    ollamaPromptCustomizationView
                }
            }

            SettingsCard(title: "Provider options", subtitle: "Switch providers at any time") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(providerCards, id: \.id) { card in
                            card
                                .frame(width: 340)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private var geminiPromptCustomizationView: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Overrides apply only when their toggle is on. Unchecked sections fall back to Dayflow's defaults.")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            promptSection(
                heading: "Card titles",
                description: "Shape how card titles read and tweak the example list.",
                isEnabled: $useCustomGeminiTitlePrompt,
                text: $geminiTitlePromptText,
                defaultText: GeminiPromptDefaults.titleBlock
            )

            promptSection(
                heading: "Card summaries",
                description: "Control tone and style for the summary field.",
                isEnabled: $useCustomGeminiSummaryPrompt,
                text: $geminiSummaryPromptText,
                defaultText: GeminiPromptDefaults.summaryBlock
            )

            promptSection(
                heading: "Detailed summaries",
                description: "Define the minute-by-minute breakdown format and examples.",
                isEnabled: $useCustomGeminiDetailedPrompt,
                text: $geminiDetailedPromptText,
                defaultText: GeminiPromptDefaults.detailedSummaryBlock
            )

            HStack {
                Spacer()
                DayflowSurfaceButton(
                    action: resetGeminiPromptOverrides,
                    content: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Dayflow defaults")
                                .font(.custom("Nunito", size: 13))
                        }
                        .padding(.horizontal, 2)
                    },
                    background: Color.white,
                    foreground: Color(red: 0.25, green: 0.17, blue: 0),
                    borderColor: Color(hex: "FFE0A5"),
                    cornerRadius: 8,
                    horizontalPadding: 18,
                    verticalPadding: 9,
                    showOverlayStroke: true
                )
            }
        }
    }

    private var ollamaPromptCustomizationView: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Customize the local model prompts for summary and title generation.")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            promptSection(
                heading: "Timeline summaries",
                description: "Control how the local model writes its 2-3 sentence card summaries.",
                isEnabled: $useCustomOllamaSummaryPrompt,
                text: $ollamaSummaryPromptText,
                defaultText: OllamaPromptDefaults.summaryBlock
            )

            promptSection(
                heading: "Card titles",
                description: "Adjust the tone and examples for local title generation.",
                isEnabled: $useCustomOllamaTitlePrompt,
                text: $ollamaTitlePromptText,
                defaultText: OllamaPromptDefaults.titleBlock
            )

            HStack {
                Spacer()
                DayflowSurfaceButton(
                    action: resetOllamaPromptOverrides,
                    content: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Dayflow defaults")
                                .font(.custom("Nunito", size: 13))
                        }
                        .padding(.horizontal, 2)
                    },
                    background: Color.white,
                    foreground: Color(red: 0.25, green: 0.17, blue: 0),
                    borderColor: Color(hex: "FFE0A5"),
                    cornerRadius: 8,
                    horizontalPadding: 18,
                    verticalPadding: 9,
                    showOverlayStroke: true
                )
            }
        }
    }

    @ViewBuilder
    private func promptSection(heading: String,
                               description: String,
                               isEnabled: Binding<Bool>,
                               text: Binding<String>,
                               defaultText: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.75))
                    Text(description)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))

            promptEditorBlock(title: "Prompt text", text: text, isEnabled: isEnabled.wrappedValue, defaultText: defaultText)
        }
        .padding(16)
        .background(Color.white.opacity(0.95))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 0.8)
        )
    }

    private func promptEditorBlock(title: String,
                                   text: Binding<String>,
                                   isEnabled: Bool,
                                   defaultText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Nunito", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.6))
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(defaultText)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(isEnabled ? 0.85 : 0.45))
                    .scrollContentBackground(.hidden)
                    .disabled(!isEnabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: isEnabled ? 140 : 120)
                    .background(Color.white)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .cornerRadius(8)
            .opacity(isEnabled ? 1 : 0.6)
        }
    }

    @ViewBuilder
    private var providerSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryRow(label: "Active provider", value: providerDisplayName(currentProvider))

            switch currentProvider {
            case "ollama":
                summaryRow(label: "Engine", value: localEngine.displayName)
                summaryRow(label: "Model", value: localModelId.isEmpty ? "Not configured" : localModelId)
                summaryRow(label: "Endpoint", value: localBaseURL)
            case "gemini":
                summaryRow(label: "Model preference", value: selectedGeminiModel.displayName)
                summaryRow(label: "API key", value: KeychainManager.shared.retrieve(for: "gemini") != nil ? "Stored safely in Keychain" : "Not set")
            default:
                summaryRow(label: "Status", value: "Coming soon")
            }
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.custom("Nunito", size: 13))
                .foregroundColor(.black.opacity(0.55))
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.custom("Nunito", size: 14))
                .foregroundColor(.black.opacity(0.78))
        }
    }

    private func providerDisplayName(_ id: String) -> String {
        switch id {
        case "ollama": return "Use local AI"
        case "gemini": return "Bring your own API keys"
        case "dayflow": return "Dayflow Pro"
        default: return id.capitalized
        }
    }

    // MARK: - FocusLock Tab

    private var focusLockContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsCard(title: "Focus Session Settings", subtitle: "Configure your focus work sessions") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Focus sessions help you stay on task by blocking distractions and tracking your time.")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    // Default Session Duration
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Default Session Duration")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Set the default length for focus sessions")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        Text("25 min")
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                            .foregroundColor(DesignColors.secondaryText)
                            .padding(.horizontal, DesignSpacing.sm)
                            .padding(.vertical, DesignSpacing.xs)
                            .background(DesignColors.glassBackground)
                            .cornerRadius(DesignRadius.small)
                    }

                    // Auto-start Breaks
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Auto-start Breaks")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Automatically start breaks after focus sessions")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                }
            }

            SettingsCard(title: "Emergency Break Settings", subtitle: "Configure break duration and behavior") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Emergency breaks give you short pauses during intense focus sessions.")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    // Break Duration
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Break Duration")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Set the length of emergency breaks")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        Text("5 min")
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                            .foregroundColor(DesignColors.secondaryText)
                            .padding(.horizontal, DesignSpacing.sm)
                            .padding(.vertical, DesignSpacing.xs)
                            .background(DesignColors.glassBackground)
                            .cornerRadius(DesignRadius.small)
                    }

                    // Daily Break Limit
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Daily Break Limit")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Maximum number of emergency breaks per day")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        Text("3 breaks")
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                            .foregroundColor(DesignColors.secondaryText)
                            .padding(.horizontal, DesignSpacing.sm)
                            .padding(.vertical, DesignSpacing.xs)
                            .background(DesignColors.glassBackground)
                            .cornerRadius(DesignRadius.small)
                    }

                    // Break Reason Required
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Require Break Reason")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Require a reason when taking emergency breaks")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                    }
                }
            }

            SettingsCard(title: "Data & Privacy", subtitle: "Manage your FocusLock data") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Control how your focus data is stored and used.")
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                        .foregroundColor(DesignColors.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    // Export Data
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Export FocusLock Data")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Download your focus sessions and productivity data")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        UnifiedButton.primary(
                            "Export",
                            size: .small,
                            disabled: isExporting,
                            action: {
                                Task {
                                    await performExport()
                                }
                            }
                        )
                    }

                    // Clear Analytics Data
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Clear Analytics Data")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Remove all analytics and usage statistics")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        UnifiedButton.ghost(
                            "Clear",
                            size: .small,
                            action: {
                                showClearConfirmation = true
                            }
                        )
                    }

                    // Reset Settings
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Reset Focus Settings")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.callout))
                                .fontWeight(.medium)
                                .foregroundColor(DesignColors.primaryText)

                            Text("Reset all FocusLock settings to defaults")
                                .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                                .foregroundColor(DesignColors.secondaryText)
                        }

                        Spacer()

                        UnifiedButton.secondary(
                            "Reset",
                            size: .small,
                            action: {
                                showResetConfirmation = true
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Other Tab

    private var otherContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            SettingsCard(title: "App preferences", subtitle: "General toggles and telemetry settings") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $analyticsEnabled) {
                        Text("Share crash reports and anonymous usage data")
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .toggleStyle(.switch)

                    Text("Dayflow v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.45))
                }
            }
        }
    }

    // MARK: - Storage helpers

    private func refreshStorageIfNeeded() {
        if storagePermissionGranted == nil && selectedTab == .storage {
            refreshStorageMetrics()
        }
    }

    private func refreshStorageMetrics() {
        guard !isRefreshingStorage else { return }
        isRefreshingStorage = true

        Task.detached(priority: .utility) {
            let permission = CGPreflightScreenCaptureAccess()
            let recordingsURL = StorageManager.shared.recordingsRoot

            let recordingsSize = await MainActor.run { SettingsView.directorySize(at: recordingsURL) }
            let timelapseSize = TimelapseStorageManager.shared.currentUsageBytes()

            await MainActor.run {
                self.storagePermissionGranted = permission
                self.recordingsUsageBytes = recordingsSize
                self.timelapseUsageBytes = timelapseSize
                self.lastStorageCheck = Date()
                self.isRefreshingStorage = false

                let recordingsLimit = StoragePreferences.recordingsLimitBytes
                let timelapseLimit = StoragePreferences.timelapsesLimitBytes
                self.recordingsLimitBytes = recordingsLimit
                self.timelapsesLimitBytes = timelapseLimit
                self.recordingsLimitIndex = indexForLimit(recordingsLimit)
                self.timelapsesLimitIndex = indexForLimit(timelapseLimit)
            }
        }
    }

    private func openRecordingsFolder() {
        let url = StorageManager.shared.recordingsRoot
        ensureDirectoryExists(url)
        NSWorkspace.shared.open(url)
    }

    private func openTimelapseFolder() {
        let url = TimelapseStorageManager.shared.rootURL
        ensureDirectoryExists(url)
        NSWorkspace.shared.open(url)
    }

    private func ensureDirectoryExists(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("⚠️ Failed to ensure directory exists at \(url.path): \(error)")
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadGeminiPromptOverridesIfNeeded(force: Bool = false) {
        if geminiPromptOverridesLoaded && !force { return }
        isUpdatingGeminiPromptState = true
        let overrides = GeminiPromptPreferences.load()

        let trimmedTitle = overrides.titleBlock?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = overrides.summaryBlock?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetailed = overrides.detailedBlock?.trimmingCharacters(in: .whitespacesAndNewlines)

        useCustomGeminiTitlePrompt = trimmedTitle?.isEmpty == false
        useCustomGeminiSummaryPrompt = trimmedSummary?.isEmpty == false
        useCustomGeminiDetailedPrompt = trimmedDetailed?.isEmpty == false

        geminiTitlePromptText = trimmedTitle ?? GeminiPromptDefaults.titleBlock
        geminiSummaryPromptText = trimmedSummary ?? GeminiPromptDefaults.summaryBlock
        geminiDetailedPromptText = trimmedDetailed ?? GeminiPromptDefaults.detailedSummaryBlock

        isUpdatingGeminiPromptState = false
        geminiPromptOverridesLoaded = true
    }

    private func persistGeminiPromptOverridesIfReady() {
        guard geminiPromptOverridesLoaded, !isUpdatingGeminiPromptState else { return }
        persistGeminiPromptOverrides()
    }

    private func persistGeminiPromptOverrides() {
        let overrides = GeminiPromptOverrides(
            titleBlock: normalizedOverride(text: geminiTitlePromptText, enabled: useCustomGeminiTitlePrompt),
            summaryBlock: normalizedOverride(text: geminiSummaryPromptText, enabled: useCustomGeminiSummaryPrompt),
            detailedBlock: normalizedOverride(text: geminiDetailedPromptText, enabled: useCustomGeminiDetailedPrompt)
        )

        if overrides.isEmpty {
            GeminiPromptPreferences.reset()
        } else {
            GeminiPromptPreferences.save(overrides)
        }
    }

    private func resetGeminiPromptOverrides() {
        isUpdatingGeminiPromptState = true
        useCustomGeminiTitlePrompt = false
        useCustomGeminiSummaryPrompt = false
        useCustomGeminiDetailedPrompt = false
        geminiTitlePromptText = GeminiPromptDefaults.titleBlock
        geminiSummaryPromptText = GeminiPromptDefaults.summaryBlock
        geminiDetailedPromptText = GeminiPromptDefaults.detailedSummaryBlock
        GeminiPromptPreferences.reset()
        isUpdatingGeminiPromptState = false
        geminiPromptOverridesLoaded = true
    }

    private func loadOllamaPromptOverridesIfNeeded(force: Bool = false) {
        if ollamaPromptOverridesLoaded && !force { return }
        isUpdatingOllamaPromptState = true
        let overrides = OllamaPromptPreferences.load()

        let trimmedSummary = overrides.summaryBlock?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = overrides.titleBlock?.trimmingCharacters(in: .whitespacesAndNewlines)

        useCustomOllamaSummaryPrompt = trimmedSummary?.isEmpty == false
        useCustomOllamaTitlePrompt = trimmedTitle?.isEmpty == false

        ollamaSummaryPromptText = trimmedSummary ?? OllamaPromptDefaults.summaryBlock
        ollamaTitlePromptText = trimmedTitle ?? OllamaPromptDefaults.titleBlock

        isUpdatingOllamaPromptState = false
        ollamaPromptOverridesLoaded = true
    }

    private func persistOllamaPromptOverridesIfReady() {
        guard ollamaPromptOverridesLoaded, !isUpdatingOllamaPromptState else { return }
        persistOllamaPromptOverrides()
    }

    private func persistOllamaPromptOverrides() {
        let overrides = OllamaPromptOverrides(
            summaryBlock: normalizedOverride(text: ollamaSummaryPromptText, enabled: useCustomOllamaSummaryPrompt),
            titleBlock: normalizedOverride(text: ollamaTitlePromptText, enabled: useCustomOllamaTitlePrompt)
        )

        if overrides.isEmpty {
            OllamaPromptPreferences.reset()
        } else {
            OllamaPromptPreferences.save(overrides)
        }
    }

    private func resetOllamaPromptOverrides() {
        isUpdatingOllamaPromptState = true
        useCustomOllamaSummaryPrompt = false
        useCustomOllamaTitlePrompt = false
        ollamaSummaryPromptText = OllamaPromptDefaults.summaryBlock
        ollamaTitlePromptText = OllamaPromptDefaults.titleBlock
        OllamaPromptPreferences.reset()
        isUpdatingOllamaPromptState = false
        ollamaPromptOverridesLoaded = true
    }

    private func normalizedOverride(text: String, enabled: Bool) -> String? {
        guard enabled else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            } catch {
                continue
            }
        }
        return total
    }

    // MARK: - Providers helpers

    // Storage limit helpers

    private func storageFooterText() -> String {
        let recordingsText = recordingsLimitBytes == Int64.max ? "Unlimited" : usageFormatter.string(fromByteCount: recordingsLimitBytes)
        let timelapsesText = timelapsesLimitBytes == Int64.max ? "Unlimited" : usageFormatter.string(fromByteCount: timelapsesLimitBytes)
        return "Recording cap: \(recordingsText) • Timelapse cap: \(timelapsesText). Lowering a cap immediately deletes the oldest files for that type. Timeline card text stays preserved. Please avoid deleting files manually so you do not remove Dayflow's database."
    }

    private func handleLimitSelection(for category: StorageCategory, index: Int) {
        guard Self.storageOptions.indices.contains(index) else { return }
        let newBytes = Self.storageOptions[index].resolvedBytes
        let currentBytes = limitBytes(for: category)
        guard newBytes != currentBytes else { return }

        if newBytes < currentBytes {
            pendingLimit = PendingLimit(category: category, index: index)
            showLimitConfirmation = true
        } else {
            applyLimit(for: category, index: index)
        }
    }

    private func applyLimit(for category: StorageCategory, index: Int) {
        guard Self.storageOptions.indices.contains(index) else { return }
        let option = Self.storageOptions[index]
        let newBytes = option.resolvedBytes
        let previousBytes = limitBytes(for: category)

        switch category {
        case .recordings:
            StorageManager.shared.updateStorageLimit(bytes: newBytes)
            recordingsLimitBytes = newBytes
            recordingsLimitIndex = index
        case .timelapses:
            TimelapseStorageManager.shared.updateLimit(bytes: newBytes)
            timelapsesLimitBytes = newBytes
            timelapsesLimitIndex = index
        }

        pendingLimit = nil
        showLimitConfirmation = false

        AnalyticsService.shared.capture("storage_limit_changed", [
            "category": category.analyticsKey,
            "previous_limit_bytes": previousBytes,
            "new_limit_bytes": newBytes
        ])

        refreshStorageMetrics()
    }

    private func limitBytes(for category: StorageCategory) -> Int64 {
        switch category {
        case .recordings: return recordingsLimitBytes
        case .timelapses: return timelapsesLimitBytes
        }
    }

    private func indexForLimit(_ bytes: Int64) -> Int {
        if bytes >= Int64.max {
            return Self.storageOptions.count - 1
        }
        if let exact = Self.storageOptions.firstIndex(where: { $0.resolvedBytes == bytes }) {
            return exact
        }
        for option in Self.storageOptions where option.bytes != nil {
            if bytes <= option.resolvedBytes {
                return option.id
            }
        }
        return Self.storageOptions.count - 1
    }

    // Debug log copy helpers removed per design request

    private func reloadLocalProviderSettings() {
        localBaseURL = UserDefaults.standard.string(forKey: "llmLocalBaseURL") ?? localBaseURL
        localModelId = UserDefaults.standard.string(forKey: "llmLocalModelId") ?? localModelId
        let raw = UserDefaults.standard.string(forKey: "llmLocalEngine") ?? localEngine.rawValue
        localEngine = LocalEngine(rawValue: raw) ?? localEngine
    }

    private func loadCurrentProvider() {
        guard !hasLoadedProvider else { return }

        if let data = UserDefaults.standard.data(forKey: "llmProviderType"),
           let providerType = try? JSONDecoder().decode(LLMProviderType.self, from: data) {
            switch providerType {
            case .geminiDirect:
                currentProvider = "gemini"
                let preference = GeminiModelPreference.load()
                selectedGeminiModel = preference.primary
                savedGeminiModel = preference.primary
            case .dayflowBackend:
                currentProvider = "dayflow"
            case .ollamaLocal:
                currentProvider = "ollama"
            case .chatGPTClaude:
                // ChatGPT/Claude integration is currently disabled;
                // fall back to Gemini so the app keeps functioning.
                currentProvider = "gemini"
                let fallback = LLMProviderType.geminiDirect
                if let encoded = try? JSONEncoder().encode(fallback) {
                    UserDefaults.standard.set(encoded, forKey: "llmProviderType")
                }
                UserDefaults.standard.set("gemini", forKey: "selectedLLMProvider")
                let preference = GeminiModelPreference.load()
                selectedGeminiModel = preference.primary
                savedGeminiModel = preference.primary
            }
        }
        hasLoadedProvider = true
    }

    private func switchToProvider(_ providerId: String) {
        if providerId == "dayflow" { return }

        let isEditingCurrent = providerId == currentProvider
        if isEditingCurrent {
            AnalyticsService.shared.capture("provider_edit_initiated", ["provider": providerId])
        } else {
            AnalyticsService.shared.capture("provider_switch_initiated", ["from": currentProvider, "to": providerId])
        }

        setupModalProvider = providerId
    }

    private func completeProviderSwitch(_ providerId: String) {
        let providerType: LLMProviderType
        switch providerId {
        case "ollama":
            let endpoint = UserDefaults.standard.string(forKey: "llmLocalBaseURL") ?? "http://localhost:11434"
            providerType = .ollamaLocal(endpoint: endpoint)
        case "gemini":
            providerType = .geminiDirect
        case "dayflow":
            providerType = .dayflowBackend()
        default:
            return
        }

        if let encoded = try? JSONEncoder().encode(providerType) {
            UserDefaults.standard.set(encoded, forKey: "llmProviderType")
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            currentProvider = providerId
        }

        if providerId == "gemini" {
            let preference = GeminiModelPreference.load()
            selectedGeminiModel = preference.primary
            savedGeminiModel = preference.primary
        }

        var props: [String: Any] = ["provider": providerId]
        if providerId == "ollama" {
            let localEngine = UserDefaults.standard.string(forKey: "llmLocalEngine") ?? "ollama"
            let localModelId = UserDefaults.standard.string(forKey: "llmLocalModelId") ?? "unknown"
            let localBaseURL = UserDefaults.standard.string(forKey: "llmLocalBaseURL") ?? "unknown"
            props["local_engine"] = localEngine
            props["model_id"] = localModelId
            props["base_url"] = localBaseURL
        }
        AnalyticsService.shared.capture("provider_setup_completed", props)
        AnalyticsService.shared.setPersonProperties(["current_llm_provider": providerId])
    }

    private func persistGeminiModelSelection(_ model: GeminiModel, source: String) {
        guard model != savedGeminiModel else { return }
        savedGeminiModel = model
        GeminiModelPreference(primary: model).save()

        Task { @MainActor in
            AnalyticsService.shared.capture("gemini_model_selected", [
                "source": source,
                "model": model.rawValue
            ])
        }
    }

    private var providerCards: [FlexibleProviderCard] {
        [
            FlexibleProviderCard(
                id: "ollama",
                title: "Use local AI",
                badgeText: "MOST PRIVATE",
                badgeType: .green,
                icon: "desktopcomputer",
                features: [
                    ("100% private - everything's processed on your computer", true),
                    ("Works completely offline", true),
                    ("Significantly less intelligence", false),
                    ("Requires the most setup", false),
                    ("16GB+ of RAM recommended", false),
                    ("Can be battery-intensive", false)
                ],
                isSelected: currentProvider == "ollama",
                buttonMode: .settings(onSwitch: { switchToProvider("ollama") }),
                showCurrentlySelected: true,
                customStatusText: statusText(for: "ollama")
            ),
            FlexibleProviderCard(
                id: "gemini",
                title: "Bring your own API keys",
                badgeText: "RECOMMENDED",
                badgeType: .orange,
                icon: "key.fill",
                features: [
                    ("Utilizes more intelligent AI via Google's Gemini models", true),
                    ("Uses Gemini's generous free tier (no credit card needed)", true),
                    ("Faster, more accurate than local models", true),
                    ("Requires getting an API key (takes 2 clicks)", false)
                ],
                isSelected: currentProvider == "gemini",
                buttonMode: .settings(onSwitch: { switchToProvider("gemini") }),
                showCurrentlySelected: true,
                customStatusText: statusText(for: "gemini")
            )
        ].filter { !$0.isSelected }
    }

    private func statusText(for providerId: String) -> String? {
        guard currentProvider == providerId else { return nil }

        switch providerId {
        case "ollama":
            let engineName: String
            switch localEngine {
            case .ollama: engineName = "Ollama"
            case .lmstudio: engineName = "LM Studio"
            case .custom: engineName = "Custom"
            }
            let displayModel = localModelId.isEmpty ? "qwen2.5vl:3b" : localModelId
            let truncatedModel = displayModel.count > 30 ? String(displayModel.prefix(27)) + "..." : displayModel
            return "\(engineName) - \(truncatedModel)"
        case "gemini":
            return selectedGeminiModel.displayName
        default:
            return nil
        }
    }
}

private struct ProviderSetupWrapper: Identifiable {
    let id: String
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        UnifiedCard(style: .standard, size: .large) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(title)
                        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.headline))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.custom(DesignTypography.bodyFont, size: DesignTypography.caption))
                            .foregroundColor(DesignColors.tertiaryText)
                    }
                }
                content()
            }
        }
    }
}

private struct GeminiModelSettingsCard: View {
    @Binding var selectedModel: GeminiModel
    let onSelectionChanged: (GeminiModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gemini model")
                .font(.custom("Nunito", size: 13))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))

            Picker("Gemini model", selection: $selectedModel) {
                ForEach(GeminiModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .environment(\.colorScheme, .light)

            Text(GeminiModelPreference(primary: selectedModel).fallbackSummary)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.5))

            Text("Dayflow automatically downgrades if your chosen model is rate limited or unavailable.")
                .font(.custom("Nunito", size: 11))
                .foregroundColor(.black.opacity(0.45))
        }
        .onChange(of: selectedModel) { oldValue, newValue in
            onSelectionChanged(newValue)
        }
    }
}

private extension LocalEngine {
    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        case .custom: return "Custom"
        }
    }
}

private extension SettingsView {
    // MARK: - Data Management Functions
    
    func performExport() async {
        isExporting = true
        exportError = nil
        
        do {
            // Collect all data to export
            let sessions = SessionLogger.shared.loadSessions()
            
            // Get planner data if available
            var plannerData: DataExport? = nil
            let plannerDataStore = PlannerDataStore()
            plannerData = try? await plannerDataStore.exportData()
            
            // Get preferences
            let _ = UserPreferencesManager.shared
            
            // Create comprehensive export structure
            struct FocusLockExport: Codable {
                let sessions: [FocusSession]
                let plannerData: DataExport?
                let preferences: [String: AnyCodable]
                let exportDate: Date
                let version: String
                
                enum CodingKeys: String, CodingKey {
                    case sessions, plannerData, preferences, exportDate, version
                }
                
                init(sessions: [FocusSession], plannerData: DataExport?, preferences: [String: AnyCodable], exportDate: Date, version: String) {
                    self.sessions = sessions
                    self.plannerData = plannerData
                    self.preferences = preferences
                    self.exportDate = exportDate
                    self.version = version
                }
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    sessions = try container.decode([FocusSession].self, forKey: .sessions)
                    plannerData = try container.decodeIfPresent(DataExport.self, forKey: .plannerData)
                    preferences = try container.decode([String: AnyCodable].self, forKey: .preferences)
                    exportDate = try container.decode(Date.self, forKey: .exportDate)
                    version = try container.decode(String.self, forKey: .version)
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(sessions, forKey: .sessions)
                    try container.encodeIfPresent(plannerData, forKey: .plannerData)
                    try container.encode(preferences, forKey: .preferences)
                    try container.encode(exportDate, forKey: .exportDate)
                    try container.encode(version, forKey: .version)
                }
            }
            
            // Use NSSavePanel to get save location
            await MainActor.run {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.json]
                savePanel.nameFieldStringValue = "FocusLockExport_\(dateFormatter.string(from: Date()))"
                savePanel.title = "Export FocusLock Data"
                savePanel.prompt = "Export"
                
                savePanel.begin { response in
                    Task {
                        if response == .OK, let url = savePanel.url {
                            do {
                                let encoder = JSONEncoder()
                                encoder.dateEncodingStrategy = .iso8601
                                encoder.outputFormatting = .prettyPrinted
                                
                                // Create a simplified export structure
                                struct SimpleExport: Codable {
                                    let sessions: [FocusSession]
                                    let plannerData: DataExport?
                                    let exportDate: Date
                                    let version: String
                                }
                                
                                let simpleExport = SimpleExport(
                                    sessions: sessions,
                                    plannerData: plannerData,
                                    exportDate: Date(),
                                    version: "1.0.0"
                                )
                                
                                let data = try encoder.encode(simpleExport)
                                try data.write(to: url)
                                
                                AnalyticsService.shared.capture("data_exported", ["format": "json"])
                            } catch {
                                await MainActor.run {
                                    exportError = "Failed to export data: \(error.localizedDescription)"
                                    showExportError = true
                                }
                            }
                        }
                        
                        await MainActor.run {
                            isExporting = false
                        }
                    }
                }
            }
        }
    }
    
    func clearAnalytics() async {
        // Clear AnalyticsService
        AnalyticsService.shared.setOptIn(false)
        
        // Clear session logs
        let sessions: [FocusSession] = []
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "FocusLockSessions")
        }
        UserDefaults.standard.removeObject(forKey: "FocusLockLastSummary")
        
        // Clear analytics keys
        let analyticsKeys = [
            "FocusLockAnalytics",
            "FocusLockUsageHistory",
            "analyticsOptIn",
            "analyticsDistinctId"
        ]
        
        for key in analyticsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear Keychain analytics ID if possible
        _ = KeychainManager.shared.delete(for: "analyticsDistinctId")
        
        AnalyticsService.shared.capture("analytics_cleared")
        
        await MainActor.run {
            analyticsEnabled = false
        }
    }
    
    func resetSettings() async {
        // Reset UserPreferencesManager
        UserPreferencesManager.shared.resetToDefaults()
        
        // Clear FocusLock-specific UserDefaults
        let focusLockKeys = [
            "FocusLockSettings",
            "FocusLockUserPreferences",
            "llmLocalBaseURL",
            "llmLocalModelId",
            "llmLocalEngine",
            "geminiPromptOverrides",
            "ollamaPromptOverrides"
        ]
        
        for key in focusLockKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Reload settings in UI
        await MainActor.run {
            loadCurrentProvider()
            reloadLocalProviderSettings()
            loadGeminiPromptOverridesIfNeeded()
            loadOllamaPromptOverridesIfNeeded()
        }
        
        AnalyticsService.shared.capture("settings_reset")
    }
    
    static let storageOptions: [StorageLimitOption] = [
        StorageLimitOption(id: 0, label: "1 GB", bytes: 1_000_000_000),
        StorageLimitOption(id: 1, label: "2 GB", bytes: 2_000_000_000),
        StorageLimitOption(id: 2, label: "3 GB", bytes: 3_000_000_000),
        StorageLimitOption(id: 3, label: "5 GB", bytes: 5_000_000_000),
        StorageLimitOption(id: 4, label: "10 GB", bytes: 10_000_000_000),
        StorageLimitOption(id: 5, label: "20 GB", bytes: 20_000_000_000),
        StorageLimitOption(id: 6, label: "Unlimited", bytes: nil)
    ]
}

private struct StorageLimitOption: Identifiable {
    let id: Int
    let label: String
    let bytes: Int64?

    var resolvedBytes: Int64 { bytes ?? Int64.max }
    var shortLabel: String {
        if bytes == nil { return "∞" }
        return label.replacingOccurrences(of: " GB", with: "")
    }
}

private enum StorageCategory {
    case recordings
    case timelapses

    var analyticsKey: String {
        switch self {
        case .recordings: return "recordings"
        case .timelapses: return "timelapses"
        }
    }

    var displayName: String {
        switch self {
        case .recordings: return "Recordings"
        case .timelapses: return "Timelapses"
        }
    }
}

private struct PendingLimit {
    let category: StorageCategory
    let index: Int
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UpdaterManager.shared)
            .frame(width: 1400, height: 860)
    }
}
