//
//  LoadingState.swift
//  Dayflow
//
//  Loading and transition states with smooth animations
//

import SwiftUI

struct LoadingState: View {
    let isLoading: Bool
    let message: String?
    let style: LoadingStyle
    let size: LoadingSize

    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var isVisible: Bool = false

    init(
        isLoading: Bool,
        message: String? = nil,
        style: LoadingStyle = .standard,
        size: LoadingSize = .medium
    ) {
        self.isLoading = isLoading
        self.message = message
        self.style = style
        self.size = size
    }

    var body: some View {
        if isLoading {
            VStack(spacing: DesignSpacing.md) {
                loadingIndicator

                if let message = message {
                    Text(message)
                        .font(messageFont)
                        .foregroundColor(DesignColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .opacity(isVisible ? 1.0 : 0.0)
                }
            }
            .padding(DesignSpacing.lg)
            .background(
                GlassmorphismContainer(style: .card) {
                    RoundedRectangle(cornerRadius: DesignRadius.large)
                        .fill(DesignColors.cardBackground)
                        .frame(minWidth: size.minWidth, minHeight: size.minHeight)
                }
            )
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                withAnimation(DesignAnimation.reveal) {
                    isVisible = true
                }
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading indicator")
            .accessibilityValue(message ?? "Loading...")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        switch style {
        case .standard:
            standardLoader
        case .dots:
            dotsLoader
        case .pulse:
            pulseLoader
        case .gradient:
            gradientLoader
        }
    }

    private var standardLoader: some View {
        ZStack {
            Circle()
                .stroke(DesignColors.lightOrange.opacity(0.3), lineWidth: size.strokeWidth)
                .frame(width: size.dimension, height: size.dimension)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            DesignColors.primaryOrange,
                            DesignColors.lightOrange
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round)
                )
                .frame(width: size.dimension, height: size.dimension)
                .rotationEffect(.degrees(rotationAngle))
        }
    }

    private var dotsLoader: some View {
        HStack(spacing: DesignSpacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(DesignColors.primaryOrange)
                    .frame(width: size.dotSize, height: size.dotSize)
                    .scaleEffect(pulseScale(for: index))
                    .opacity(pulseOpacity)
            }
        }
    }

    private var pulseLoader: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        DesignColors.primaryOrange.opacity(0.8),
                        DesignColors.primaryOrange.opacity(0.3),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 10,
                    endRadius: size.dimension / 2
                )
            )
            .frame(width: size.dimension, height: size.dimension)
            .scaleEffect(pulseOpacity)
    }

    private var gradientLoader: some View {
        RoundedRectangle(cornerRadius: DesignRadius.medium)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        DesignColors.primaryOrange,
                        DesignColors.lightOrange,
                        DesignColors.primaryOrange
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.dimension * 1.5, height: size.strokeWidth * 2)
            .rotationEffect(.degrees(rotationAngle))
            .mask(
                RoundedRectangle(cornerRadius: DesignRadius.medium)
                    .fill(Color.black)
                    .frame(width: size.dimension * 1.5, height: size.strokeWidth * 2)
            )
    }

    private func pulseScale(for index: Int) -> CGFloat {
        let phase = (rotationAngle.truncatingRemainder(dividingBy: 120)) / 120
        let offset = Double(index) * 0.33
        let adjustedPhase = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.8 + 0.4 * sin(adjustedPhase * 2 * .pi)
    }

    private var messageFont: Font {
        switch size {
        case .small:
            return .custom(DesignTypography.bodyFont, size: DesignTypography.caption)
        case .medium:
            return .custom(DesignTypography.bodyFont, size: DesignTypography.body)
        case .large:
            return .custom(DesignTypography.bodyFont, size: DesignTypography.callout)
        }
    }

    private func startAnimation() {
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.3
        }
    }

    private func stopAnimation() {
        // Animations will automatically stop when view disappears
    }
}

// MARK: - Loading Styles

enum LoadingStyle {
    case standard    // Circular progress indicator
    case dots        // Three dots animation
    case pulse       // Pulsing circle
    case gradient    // Animated gradient bar
}

enum LoadingSize {
    case small
    case medium
    case large

    var dimension: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 40
        case .large: return 60
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }

    var dotSize: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        }
    }

    var minWidth: CGFloat {
        switch self {
        case .small: return 120
        case .medium: return 180
        case .large: return 240
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 120
        case .large: return 160
        }
    }
}

// MARK: - Page Transition Wrapper

struct PageTransition<Content: View>: View {
    let content: Content
    let isLoading: Bool
    let loadingMessage: String?
    let loadingStyle: LoadingStyle

    @State private var contentOpacity: Double = 1.0
    @State private var loadingOpacity: Double = 0.0

    init(
        isLoading: Bool,
        loadingMessage: String? = nil,
        loadingStyle: LoadingStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.loadingMessage = loadingMessage
        self.loadingStyle = loadingStyle
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(contentOpacity)
                .scaleEffect(contentOpacity)

            if isLoading {
                LoadingState(
                    isLoading: isLoading,
                    message: loadingMessage,
                    style: loadingStyle,
                    size: .medium
                )
                .opacity(loadingOpacity)
                .scaleEffect(loadingOpacity)
            }
        }
        .onChange(of: isLoading) { _, newValue in
            if newValue {
                // Show loading state
                withAnimation(.easeInOut(duration: DesignAnimation.standard)) {
                    contentOpacity = 0.3
                    loadingOpacity = 1.0
                }
            } else {
                // Hide loading state
                withAnimation(.easeInOut(duration: DesignAnimation.standard)) {
                    contentOpacity = 1.0
                    loadingOpacity = 0.0
                }
            }
        }
        .animation(.easeInOut(duration: DesignAnimation.standard), value: isLoading)
    }
}

// MARK: - Quick Loading Components

struct QuickLoader: View {
    let size: CGFloat
    let color: Color

    @State private var rotation: Double = 0

    init(size: CGFloat = 20, color: Color = DesignColors.primaryOrange) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Circle()
            .stroke(color.opacity(0.3), lineWidth: 2)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading indicator")
    }
}

struct LoadingDots: View {
    let count: Int
    let color: Color

    @State private var animationPhase: Double = 0

    init(count: Int = 3, color: Color = DesignColors.primaryOrange) {
        self.count = count
        self.color = color
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(scale(for: index))
                    .opacity(opacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading animation with \(count) dots")
    }

    private func scale(for index: Int) -> CGFloat {
        let phase = animationPhase + Double(index) / Double(count)
        return 0.5 + 0.5 * sin(phase * 2 * .pi)
    }

    private func opacity(for index: Int) -> Double {
        let phase = animationPhase + Double(index) / Double(count)
        return 0.3 + 0.7 * sin(phase * 2 * .pi)
    }
}

// MARK: - Preview

#Preview("Loading States") {
    VStack(spacing: 30) {
        LoadingState(isLoading: true, message: "Loading your data...", style: .standard)

        LoadingState(isLoading: true, message: "Processing...", style: .dots)

        LoadingState(isLoading: true, message: "Almost there...", style: .pulse)

        LoadingState(isLoading: true, message: "Initializing...", style: .gradient)

        HStack(spacing: 20) {
            QuickLoader(size: 16)
            QuickLoader(size: 24)
            QuickLoader(size: 32)
        }

        LoadingDots(count: 4)
    }
    .padding()
    .background(DesignColors.warmBackground)
}

#Preview("Page Transition") {
    PageTransition(
        isLoading: false,
        loadingMessage: "Loading content...",
        loadingStyle: .dots
    ) {
        VStack {
            Text("Page Content")
                .font(.title)
                .foregroundColor(DesignColors.primaryText)

            Text("This is the main content of the page")
                .foregroundColor(DesignColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColors.warmBackground)
    }
}