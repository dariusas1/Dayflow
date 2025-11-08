//
//  UnifiedCard.swift
//  Dayflow
//
//  Consistent card components with glassmorphism effects
//

import SwiftUI

struct UnifiedCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    let size: CardSize
    let padding: CGFloat
    let shadow: Bool
    let animated: Bool

    @State private var isVisible: Bool = false

    init(
        style: CardStyle = .standard,
        size: CardSize = .medium,
        padding: CGFloat = DesignSpacing.cardPadding,
        shadow: Bool = true,
        animated: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.size = size
        self.padding = padding
        self.shadow = shadow
        self.animated = animated
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Glass background
            cardBackground

            // Card content
            content
                .padding(padding)
        }
        .clipShape(cardShape)
        .shadow(
            color: shadow ? cardShadow.color : .clear,
            radius: shadow ? cardShadow.radius : 0,
            x: shadow ? cardShadow.x : 0,
            y: shadow ? cardShadow.y : 0
        )
        .scaleEffect(animated ? (isVisible ? 1.0 : 0.95) : 1.0)
        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
        .onAppear {
            if animated {
                withAnimation(DesignAnimation.reveal) {
                    isVisible = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(getAccessibilityHint())
    }

    private func getAccessibilityHint() -> String {
        switch style {
        case .standard:
            return "Standard information card"
        case .elevated:
            return "Important information card"
        case .minimal:
            return "Simple card"
        case .interactive:
            return "Interactive card, double tap to activate"
        }
    }

    // MARK: - Card Background

    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .standard:
            standardCardBackground
        case .elevated:
            elevatedCardBackground
        case .minimal:
            minimalCardBackground
        case .interactive:
            interactiveCardBackground
        }
    }

    private var standardCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(DesignColors.cardBackground)
                .background(.regularMaterial)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7),
                            DesignColors.glassBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var elevatedCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(DesignColors.cardBackground)
                .background(.thinMaterial)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            DesignColors.lightOrange.opacity(0.1),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 30,
                        endRadius: 150
                    )
                )
        }
    }

    private var minimalCardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(DesignColors.cardBackground.opacity(0.8))
            .background(.ultraThinMaterial)
    }

    private var interactiveCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(DesignColors.cardBackground)
                .background(.regularMaterial)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.8),
                            DesignColors.glassBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Orange accent
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            DesignColors.lightOrange.opacity(0.05),
                            Color.clear
                        ]),
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
        }
    }

    // MARK: - Card Shape

    private var cardShape: some Shape {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }

    private var cardCornerRadius: CGFloat {
        switch size {
        case .small:
            return DesignRadius.small
        case .medium:
            return DesignRadius.medium
        case .large:
            return DesignRadius.large
        case .xlarge:
            return DesignRadius.xl
        }
    }

    // MARK: - Card Shadow

    private var cardShadow: DesignShadows.ShadowStyle {
        switch style {
        case .standard:
            return DesignShadows.cardShadow
        case .elevated:
            return DesignShadows.elevatedShadow
        case .minimal:
            return DesignShadows.ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        case .interactive:
            return DesignShadows.hoverShadow
        }
    }
}

// MARK: - Card Styles

enum CardStyle {
    case standard    // Standard glass card
    case elevated    // Elevated with orange accent
    case minimal     // Minimal background
    case interactive  // Interactive with hover effects
}

enum CardSize {
    case small
    case medium
    case large
    case xlarge
}

// MARK: - Specialized Cards

struct UnifiedMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let style: CardStyle
    let animated: Bool
    let animationDelay: Double

    @State private var isVisible: Bool = false

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        style: CardStyle = .standard,
        animated: Bool = true,
        animationDelay: Double = 0.0
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.style = style
        self.animated = animated
        self.animationDelay = animationDelay
    }

    var body: some View {
        UnifiedCard(style: style, size: .medium, animated: false) {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(DesignColors.primaryOrange)
                            .frame(width: 24, height: 24)
                            .scaleEffect(animated ? (isVisible ? 1.0 : 0.8) : 1.0)
                            .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(value)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(DesignColors.primaryText)
                            .scaleEffect(animated ? (isVisible ? 1.0 : 0.95) : 1.0)
                            .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(DesignColors.secondaryText)
                                .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
                        }
                    }
                }

                Spacer()

                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignColors.primaryText)
                    .lineLimit(1)
                    .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
            }
        }
        .scaleEffect(animated ? (isVisible ? 1.0 : 0.95) : 1.0)
        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
        .onAppear {
            if animated {
                withAnimation(DesignAnimation.stagger.delay(animationDelay)) {
                    isVisible = true
                }
            }
        }
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(subtitle ?? "")
        .accessibilityElement(children: .combine)
    }
}

struct StatusCard: View {
    let status: StatusType
    let title: String
    let message: String
    let action: (() -> Void)?
    let animated: Bool
    let animationDelay: Double

    @State private var isVisible: Bool = false

    init(
        status: StatusType,
        title: String,
        message: String,
        action: (() -> Void)? = nil,
        animated: Bool = true,
        animationDelay: Double = 0.0
    ) {
        self.status = status
        self.title = title
        self.message = message
        self.action = action
        self.animated = animated
        self.animationDelay = animationDelay
    }

    var body: some View {
        UnifiedCard(style: .elevated, size: .medium, animated: false) {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                HStack(spacing: DesignSpacing.sm) {
                    statusIcon
                        .frame(width: 20, height: 20)
                        .scaleEffect(animated ? (isVisible ? 1.0 : 0.8) : 1.0)
                        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignColors.primaryText)
                        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)

                    Spacer()

                    Text(status.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
                }

                Text(message)
                    .font(.body)
                    .foregroundColor(DesignColors.secondaryText)
                    .lineLimit(3)
                    .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)

                if let action = action {
                    UnifiedButton.ghost("Learn More", size: .small, action: action)
                        .padding(.top, DesignSpacing.sm)
                        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
                }
            }
        }
        .scaleEffect(animated ? (isVisible ? 1.0 : 0.95) : 1.0)
        .opacity(animated ? (isVisible ? 1.0 : 0.0) : 1.0)
        .onAppear {
            if animated {
                withAnimation(DesignAnimation.stagger.delay(animationDelay)) {
                    isVisible = true
                }
            }
        }
        .accessibilityLabel("\(title): \(status.rawValue)")
        .accessibilityHint(action != nil ? "Double tap for action" : "")
        .accessibilityElement(children: .combine)
    }

    private var statusIcon: some View {
        Image(systemName: status.systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .success:
            return DesignColors.successGreen
        case .warning:
            return DesignColors.warningYellow
        case .error:
            return DesignColors.errorRed
        case .info:
            return DesignColors.primaryOrange
        }
    }
}

enum StatusType: String {
    case success = "Success"
    case warning = "Warning"
    case error = "Error"
    case info = "Info"

    var systemName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - Convenience Modifiers

extension View {
    func cardContainer(
        style: CardStyle = .standard,
        size: CardSize = .medium,
        padding: CGFloat = DesignSpacing.cardPadding
    ) -> some View {
        UnifiedCard(style: style, size: size, padding: padding) {
            self
        }
    }

    func standardCard() -> some View {
        cardContainer(style: .standard)
    }

    func elevatedCard() -> some View {
        cardContainer(style: .elevated)
    }

    func minimalCard() -> some View {
        cardContainer(style: .minimal)
    }

    func interactiveCard() -> some View {
        cardContainer(style: .interactive)
    }
}

// MARK: - Preview

#Preview("Card Styles") {
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            UnifiedCard(style: .standard, size: .small) {
                Text("Small Standard")
                    .font(.caption)
                    .foregroundColor(DesignColors.primaryText)
            }

            UnifiedCard(style: .elevated, size: .medium) {
                Text("Medium Elevated")
                    .font(.callout)
                    .foregroundColor(DesignColors.primaryText)
            }

            UnifiedCard(style: .minimal, size: .large) {
                Text("Large Minimal")
                    .font(.title3)
                    .foregroundColor(DesignColors.primaryText)
            }

            UnifiedCard(style: .interactive, size: .xlarge) {
                Text("XLarge Interactive")
                    .font(.title2)
                    .foregroundColor(DesignColors.primaryText)
            }
        }

        HStack(spacing: 15) {
            UnifiedMetricCard(
                title: "Focus Time",
                value: "4h 32m",
                subtitle: "Today",
                icon: "clock",
                style: .elevated,
                animated: true,
                animationDelay: 0.1
            )

            StatusCard(
                status: .success,
                title: "Great Progress!",
                message: "You've completed all your focus sessions for today.",
                action: { },
                animated: true,
                animationDelay: 0.2
            )
        }
    }
    .padding()
    .background(DesignColors.warmBackground)
}