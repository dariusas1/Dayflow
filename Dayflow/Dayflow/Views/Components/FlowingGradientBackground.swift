//
//  FlowingGradientBackground.swift
//  Dayflow
//
//  Animated flowing orange-to-white gradient background
//

import SwiftUI

struct FlowingGradientBackground: View {
    @State private var gradientRotation: Double = 0
    @State private var gradientOffset: CGSize = .zero
    @State private var colorPhase: Double = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var floatingOffset: CGSize = .zero

    // Animation timer for continuous flowing effect
    private let animationTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Base gradient layer with enhanced animation
            LinearGradient(
                gradient: Gradient(colors: [
                    DesignColors.gradientStart,
                    DesignColors.gradientMid,
                    DesignColors.gradientEnd
                ]),
                startPoint: gradientStartPoint,
                endPoint: gradientEndPoint
            )
            .opacity(pulseOpacity)
            .onReceive(animationTimer) { _ in
                updateGradientAnimation()
            }

            // Secondary flowing layer for depth
            LinearGradient(
                gradient: Gradient(colors: [
                    DesignColors.lightOrange.opacity(0.3),
                    DesignColors.vibrantOrange.opacity(0.2),
                    DesignColors.primaryOrange.opacity(0.3)
                ]),
                startPoint: secondaryStartPoint,
                endPoint: secondaryEndPoint
            )
            .onReceive(animationTimer) { _ in
                updateSecondaryGradientAnimation()
            }

            // Warm overlay for subtle texture with floating effect
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    DesignColors.warmBackground.opacity(0.1),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .offset(floatingOffset)
        }
        .animation(.easeInOut(duration: 1.0), value: gradientRotation)
        .animation(.easeInOut(duration: 1.0), value: gradientOffset)
        .animation(.easeInOut(duration: 2.0), value: pulseOpacity)
        .animation(.easeInOut(duration: 3.0), value: floatingOffset)
    }

    // MARK: - Gradient Animation Logic

    private var gradientStartPoint: UnitPoint {
        UnitPoint(
            x: 0.5 + 0.3 * sin(gradientRotation),
            y: 0.5 + 0.3 * cos(gradientRotation)
        )
    }

    private var gradientEndPoint: UnitPoint {
        UnitPoint(
            x: 0.5 - 0.3 * sin(gradientRotation),
            y: 0.5 - 0.3 * cos(gradientRotation)
        )
    }

    private var secondaryStartPoint: UnitPoint {
        UnitPoint(
            x: 0.3 + 0.4 * cos(gradientRotation + .pi/4),
            y: 0.3 + 0.4 * sin(gradientRotation + .pi/4)
        )
    }

    private var secondaryEndPoint: UnitPoint {
        UnitPoint(
            x: 0.7 - 0.4 * cos(gradientRotation + .pi/4),
            y: 0.7 - 0.4 * sin(gradientRotation + .pi/4)
        )
    }

    private func updateGradientAnimation() {
        // Enhanced smooth flowing animation
        withAnimation(.linear(duration: 0.03)) {
            gradientRotation += 0.005 // Slower, more elegant rotation
            colorPhase += 0.008

            // Enhanced floating motion
            let time = Date().timeIntervalSince1970
            gradientOffset = CGSize(
                width: 25 * sin(time * 0.3),
                height: 20 * cos(time * 0.5)
            )

            // Add gentle pulsing effect
            pulseOpacity = 0.85 + 0.15 * sin(time * 0.2)

            // Add subtle floating offset
            floatingOffset = CGSize(
                width: 10 * sin(time * 0.15),
                height: 8 * cos(time * 0.25)
            )
        }
    }

    private func updateSecondaryGradientAnimation() {
        // Enhanced secondary layer with different animation parameters
        withAnimation(.linear(duration: 0.03)) {
            // Secondary layer moves at different rate for depth
            let time = Date().timeIntervalSince1970
            // Add subtle wave effect to secondary gradient
        }
    }
}

#Preview {
    FlowingGradientBackground()
        .ignoresSafeArea()
}