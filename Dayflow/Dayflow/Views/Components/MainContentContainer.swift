//
//  MainContentContainer.swift
//  Dayflow
//
//  Main content container with glassmorphism effect for consistent UI
//

import SwiftUI

struct MainContentContainer<Content: View>: View {
    let content: Content
    let showShadow: Bool
    let maxWidth: CGFloat?

    init(
        showShadow: Bool = true,
        maxWidth: CGFloat? = DesignSpacing.containerWidth,
        @ViewBuilder content: () -> Content
    ) {
        self.showShadow = showShadow
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Background glass effect
            backgroundGlass

            // Main content
            content
                .padding(DesignSpacing.contentPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous))
        .shadow(
            color: showShadow ? DesignShadows.elevatedShadow.color : .clear,
            radius: showShadow ? DesignShadows.elevatedShadow.radius : 0,
            x: showShadow ? DesignShadows.elevatedShadow.x : 0,
            y: showShadow ? DesignShadows.elevatedShadow.y : 0
        )
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backgroundGlass: some View {
        ZStack {
            // Primary glass background
            RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous)
                .fill(DesignColors.cardBackground)
                .background(.ultraThinMaterial)

            // Gradient overlay for depth
            RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.3),
                            DesignColors.glassBackground
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle orange accent
            RoundedRectangle(cornerRadius: DesignRadius.large, style: .continuous)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            DesignColors.lightOrange.opacity(0.05),
                            Color.clear
                        ]),
                        center: .topTrailing,
                        startRadius: 50,
                        endRadius: 300
                    )
                )
        }
    }
}

// MARK: - Convenience Modifiers

extension View {
    func mainContentContainer(
        showShadow: Bool = true,
        maxWidth: CGFloat? = DesignSpacing.containerWidth
    ) -> some View {
        MainContentContainer(showShadow: showShadow, maxWidth: maxWidth) {
            self
        }
    }
}

#Preview {
    ZStack {
        FlowingGradientBackground()
            .ignoresSafeArea()

        MainContentContainer {
            VStack {
                Text("Main Content Container")
                    .font(.title)
                    .foregroundColor(DesignColors.primaryText)
                    .padding()

                Text("This container provides consistent glassmorphism styling for main content areas across all pages.")
                    .font(.body)
                    .foregroundColor(DesignColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
        }
        .frame(width: 600, height: 400)
    }
}