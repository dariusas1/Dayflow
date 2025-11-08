//
//  StateManager.swift
//  Dayflow
//
//  Simple state management for loading and transitions
//

import SwiftUI

class AppStateManager: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String?
    @Published var activePage: String = "main"
    @Published var isContentReady: [String: Bool] = [:]

    func setLoading(_ loading: Bool, for page: String? = nil, message: String? = nil) {
        if let page = page {
            isContentReady[page] = !loading
        }

        isLoading = loading
        loadingMessage = message

        // Auto-hide loading after reasonable time
        if loading {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if self.isLoading {
                    self.setLoading(false)
                }
            }
        }
    }

    func setPageReady(_ page: String) {
        isContentReady[page] = true
        if activePage == page {
            isLoading = false
            loadingMessage = nil
        }
    }

    func switchToPage(_ page: String) {
        activePage = page
        if !isContentReady[page, default: false] {
            setLoading(true, for: page, message: "Loading \(page)...")
        }
    }
}

struct StateManagedView<Content: View>: View {
    let pageName: String
    let content: Content
    @StateObject private var stateManager = AppStateManager()

    init(
        pageName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.pageName = pageName
        self.content = content()
    }

    var body: some View {
        PageTransition(
            isLoading: stateManager.isLoading && stateManager.activePage == pageName,
            loadingMessage: stateManager.loadingMessage,
            loadingStyle: .dots
        ) {
            content
                .onAppear {
                    stateManager.switchToPage(pageName)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        stateManager.setPageReady(pageName)
                    }
                }
                .onDisappear {
                    // Keep page marked as ready for future visits
                    stateManager.setPageReady(pageName)
                }
        }
    }
}

// MARK: - Simple Loading Wrapper

struct LoadingWrapper<Content: View>: View {
    let isLoading: Bool
    let message: String?
    let content: Content
    @State private var showContent: Bool = false

    init(
        isLoading: Bool,
        message: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.message = message
        self.content = content()
    }

    var body: some View {
        ZStack {
            if showContent {
                content
                    .transition(.opacity.combined(with: .scale))
            }

            if isLoading && !showContent {
                LoadingState(
                    isLoading: true,
                    message: message,
                    style: .dots,
                    size: .medium
                )
            }
        }
        .onChange(of: isLoading) { _, newValue in
            if !newValue {
                withAnimation(DesignAnimation.standard) {
                    showContent = true
                }
            } else {
                showContent = false
            }
        }
        .onAppear {
            if !isLoading {
                showContent = true
            }
        }
    }
}

// MARK: - Quick Page Enhancer

extension View {
    func withLoadingState(_ isLoading: Bool, message: String? = nil) -> some View {
        LoadingWrapper(isLoading: isLoading, message: message) {
            self
        }
    }

    func withPageState(_ pageName: String) -> some View {
        StateManagedView(pageName: pageName) {
            self
        }
    }
}

// MARK: - Preview

#Preview("State Managed View") {
    StateManagedView(pageName: "dashboard") {
        VStack(spacing: DesignSpacing.lg) {
            Text("Dashboard Content")
                .font(.title)
                .foregroundColor(DesignColors.primaryText)

            UnifiedCard(style: .standard) {
                Text("This content is managed by state")
                    .foregroundColor(DesignColors.secondaryText)
            }

            UnifiedButton.primary("Test Button") {
                // Action
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Loading Wrapper") {
    LoadingWrapper(isLoading: false, message: "Loading content...") {
        VStack(spacing: DesignSpacing.lg) {
            Text("Content Loaded")
                .font(.title2)
                .foregroundColor(DesignColors.primaryText)

            Text("This appears after loading completes")
                .foregroundColor(DesignColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColors.warmBackground)
    }
}