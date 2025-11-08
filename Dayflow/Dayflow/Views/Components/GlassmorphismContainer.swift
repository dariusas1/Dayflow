//
//  GlassmorphismContainer.swift
//  Dayflow
//
//  Glassmorphism container system with flowing gradient background
//

import SwiftUI

struct GlassmorphismContainer<Content: View>: View {
    let content: Content
    let style: GlassStyle
    let padding: CGFloat

    init(
        style: GlassStyle = .main,
        padding: CGFloat = DesignSpacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Glass background with blur effect
            glassBackground

            // Content
            content
                .padding(padding)
        }
        .clipShape(containerShape)
        .shadow(
            color: containerShadow.color,
            radius: containerShadow.radius,
            x: containerShadow.x,
            y: containerShadow.y
        )
    }

    // MARK: - Glass Background

    @ViewBuilder
    private var glassBackground: some View {
        switch style {
        case .main:
            mainGlassBackground
        case .card:
            cardGlassBackground
        case .sidebar:
            sidebarGlassBackground
        case .floating:
            floatingGlassBackground
        }
    }

    private var mainGlassBackground: some View {
        ZStack {
            // Base glass effect
            RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous)
                .fill(DesignColors.glassBackground)
                .background(.ultraThinMaterial)

            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            DesignColors.gradientStart.opacity(0.1),
                            DesignColors.gradientEnd.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var cardGlassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                .fill(DesignColors.cardBackground.opacity(0.9))
                .background(.regularMaterial)

            RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var sidebarGlassBackground: some View {
        RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
            .fill(DesignColors.sidebarBackground)
            .background(.thinMaterial)
    }

    private var floatingGlassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignRadius.xl, style: .continuous)
                .fill(DesignColors.glassBackground)
                .background(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: DesignRadius.xl, style: .continuous)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            DesignColors.lightOrange.opacity(0.1),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
        }
    }

    // MARK: - Container Shape

    private var containerShape: some Shape {
        switch style {
        case .main:
            return RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous)
        case .card:
            return RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
        case .sidebar:
            return RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
        case .floating:
            return RoundedRectangle(cornerRadius: DesignRadius.xl, style: .continuous)
        }
    }

    // MARK: - Container Shadow

    private var containerShadow: DesignShadows.ShadowStyle {
        switch style {
        case .main:
            return DesignShadows.elevatedShadow
        case .card:
            return DesignShadows.cardShadow
        case .sidebar:
            return DesignShadows.cardShadow
        case .floating:
            return DesignShadows.hoverShadow
        }
    }
}

// MARK: - Glass Styles

enum GlassStyle {
    case main        // Main content containers
    case card        // Standard card containers
    case sidebar     // Sidebar containers
    case floating    // Floating modal/popup containers
}

// MARK: - Convenience Modifiers

extension View {
    func glassContainer(
        style: GlassStyle = .main,
        padding: CGFloat = DesignSpacing.cardPadding
    ) -> some View {
        GlassmorphismContainer(style: style, padding: padding) {
            self
        }
    }

    func mainGlassContainer() -> some View {
        glassContainer(style: .main)
    }

    func cardGlassContainer() -> some View {
        glassContainer(style: .card)
    }

    func sidebarGlassContainer() -> some View {
        glassContainer(style: .sidebar)
    }

    func floatingGlassContainer() -> some View {
        glassContainer(style: .floating)
    }
}

// MARK: - Preview

#Preview("Glass Container Styles") {
    VStack(spacing: 20) {
        GlassmorphismContainer(style: .main) {
            Text("Main Container")
                .font(.title2)
                .foregroundColor(DesignColors.primaryText)
        }
        .frame(height: 100)

        HStack {
            GlassmorphismContainer(style: .card) {
                Text("Card")
                    .font(.headline)
                    .foregroundColor(DesignColors.primaryText)
            }
            .frame(width: 120, height: 80)

            GlassmorphismContainer(style: .sidebar) {
                Text("Sidebar")
                    .font(.caption)
                    .foregroundColor(DesignColors.primaryText)
            }
            .frame(width: 80, height: 80)

            GlassmorphismContainer(style: .floating) {
                Text("Floating")
                    .font(.callout)
                    .foregroundColor(DesignColors.primaryText)
            }
            .frame(width: 100, height: 60)
        }
    }
    .padding()
    .background(
        FlowingGradientBackground()
            .ignoresSafeArea()
    )
}