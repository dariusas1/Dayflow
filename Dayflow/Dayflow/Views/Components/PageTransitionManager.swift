//
//  PageTransitionManager.swift
//  Dayflow
//
//  Manages smooth page transitions and loading states across the app
//

import SwiftUI

class PageTransitionManager: ObservableObject {
    @Published var currentPage: PageType = .main
    @Published var isTransitioning: Bool = false
    @Published var loadingMessage: String?
    @Published var loadingStyle: LoadingStyle = .standard

    private var transitionDuration: Double = 0.3

    enum PageType {
        case main
        case settings
        case suggestedTodos
        case focusLock
        case dashboard
        case jarvisChat
        case journal
        case insights

        var title: String {
            switch self {
            case .main: return "Dayflow"
            case .settings: return "Settings"
            case .suggestedTodos: return "Suggested Todos"
            case .focusLock: return "Focus Lock"
            case .dashboard: return "Dashboard"
            case .jarvisChat: return "Jarvis Chat"
            case .journal: return "Journal"
            case .insights: return "Insights"
            }
        }

        var loadingMessage: String {
            switch self {
            case .main: return "Loading dashboard..."
            case .settings: return "Loading settings..."
            case .suggestedTodos: return "Loading todos..."
            case .focusLock: return "Initializing focus mode..."
            case .dashboard: return "Preparing analytics..."
            case .jarvisChat: return "Connecting to Jarvis..."
            case .journal: return "Loading journal..."
            case .insights: return "Analyzing data..."
            }
        }
    }

    func transition(to page: PageType, customLoadingMessage: String? = nil) {
        guard currentPage != page else { return }

        isTransitioning = true
        loadingMessage = customLoadingMessage ?? page.loadingMessage

        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
            self.currentPage = page

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTransitioning = false
                self.loadingMessage = nil
            }
        }
    }

    func setLoading(_ loading: Bool, message: String? = nil, style: LoadingStyle = .standard) {
        isTransitioning = loading
        loadingMessage = message
        loadingStyle = style
    }
}

struct TransitioningPage<Content: View>: View {
    let pageType: PageTransitionManager.PageType
    let content: Content
    @ObservedObject private var transitionManager = PageTransitionManager()

    init(
        pageType: PageTransitionManager.PageType,
        @ViewBuilder content: () -> Content
    ) {
        self.pageType = pageType
        self.content = content()
    }

    var body: some View {
        PageTransition(
            isLoading: transitionManager.isTransitioning,
            loadingMessage: transitionManager.loadingMessage,
            loadingStyle: transitionManager.loadingStyle
        ) {
            content
        }
        .onAppear {
            transitionManager.currentPage = pageType
        }
    }
}

// MARK: - Enhanced Page Container

struct PageContainer<Content: View>: View {
    let title: String
    let showLoadingIndicator: Bool
    let content: Content
    @State private var isLoaded: Bool = false

    init(
        title: String,
        showLoadingIndicator: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showLoadingIndicator = showLoadingIndicator
        self.content = content()
    }

    var body: some View {
        FlowingGradientBackground()
            .overlay(
                VStack(spacing: 0) {
                    // Header with smooth transition
                    headerSection
                        .opacity(isLoaded ? 1.0 : 0.0)
                        .offset(y: isLoaded ? 0 : -20)

                    // Main content with loading state
                    if showLoadingIndicator {
                        PageTransition(
                            isLoading: !isLoaded,
                            loadingMessage: "Loading \(title.lowercased())...",
                            loadingStyle: .dots
                        ) {
                            content
                                .opacity(isLoaded ? 1.0 : 0.0)
                                .scaleEffect(isLoaded ? 1.0 : 0.98)
                        }
                    } else {
                        content
                            .opacity(isLoaded ? 1.0 : 0.0)
                            .scaleEffect(isLoaded ? 1.0 : 0.98)
                    }
                }
                .padding(DesignSpacing.lg)
            )
            .onAppear {
                withAnimation(DesignAnimation.reveal) {
                    isLoaded = true
                }
            }
    }

    private var headerSection: some View {
        GlassmorphismContainer(style: .main) {
            HStack {
                Text(title)
                    .font(.custom(DesignTypography.headingFont, size: DesignTypography.title2))
                    .foregroundColor(DesignColors.primaryText)

                Spacer()

                // Quick loading indicator in header
                if showLoadingIndicator && !isLoaded {
                    QuickLoader(size: 16)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(DesignSpacing.lg)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Navigation Enhancer

struct NavigationEnhancer: ViewModifier {
    let currentPage: PageTransitionManager.PageType
    @State private var isNavigating: Bool = false

    func body(content: Content) -> some View {
        content
            .onChange(of: currentPage) { _, _ in
                isNavigating = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: DesignAnimation.standard)) {
                        isNavigating = false
                    }
                }
            }
            .overlay(
                isNavigating ?
                VStack {
                    HStack {
                        Spacer()
                        QuickLoader(size: 20)
                            .padding()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
                : nil
            )
    }
}

extension View {
    func withNavigationEnhancement(for page: PageTransitionManager.PageType) -> some View {
        modifier(NavigationEnhancer(currentPage: page))
    }
}

// MARK: - Smooth List Transitions

struct SmoothList<Content: View, Data: RandomAccessCollection>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    @State private var visibleItems: Set<Data.Element.ID> = []

    var body: some View {
        LazyVStack(spacing: DesignSpacing.md) {
            ForEach(data) { item in
                content(item)
                    .opacity(visibleItems.contains(item.id) ? 1.0 : 0.0)
                    .offset(y: visibleItems.contains(item.id) ? 0 : 20)
                    .onAppear {
                        let delay = Double(visibleItems.count) * 0.05
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                            visibleItems.insert(item.id)
                        }
                    }
            }
        }
    }
}

// MARK: - Content Loader for Data

struct ContentLoader<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let isLoading: Bool
    let loadingMessage: String?
    let content: (Data.Element) -> Content

    var body: some View {
        if isLoading {
            VStack {
                Spacer()
                LoadingState(
                    isLoading: isLoading,
                    message: loadingMessage,
                    style: .dots,
                    size: .medium
                )
                Spacer()
            }
        } else {
            SmoothList(data: data, content: content)
        }
    }
}

// MARK: - Preview

#Preview("Page Container") {
    PageContainer(title: "Dashboard", showLoadingIndicator: true) {
        VStack(spacing: DesignSpacing.lg) {
            UnifiedMetricCard(
                title: "Focus Time",
                value: "4h 32m",
                subtitle: "Today",
                icon: "clock",
                style: .elevated
            )

            UnifiedMetricCard(
                title: "Tasks Completed",
                value: "12",
                subtitle: "This week",
                icon: "checkmark.circle",
                style: .standard
            )

            Spacer()
        }
    }
}

#Preview("Content Loader") {
    struct MockItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
    }

    let mockData = [
        MockItem(title: "Item 1", subtitle: "Description 1"),
        MockItem(title: "Item 2", subtitle: "Description 2"),
        MockItem(title: "Item 3", subtitle: "Description 3")
    ]

    return ContentLoader(
        data: mockData,
        isLoading: false,
        loadingMessage: "Loading items..."
    ) { item in
        UnifiedCard(style: .standard) {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(DesignColors.secondaryText)
            }
        }
    }
    .padding()
    .background(DesignColors.warmBackground)
}