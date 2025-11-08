//
//  DesignTokens.swift
//  FocusLock
//
//  Unified design system with flowing orange-to-white gradient theme
//

import SwiftUI
import Foundation

// MARK: - Color System
struct DesignColors {

    // MARK: - Primary Colors (Orange Theme)
    static let primaryOrange = Color(red: 1, green: 0.54, blue: 0.17)
    static let secondaryOrange = Color(red: 0.62, green: 0.44, blue: 0.36)
    static let lightOrange = Color(red: 1, green: 0.77, blue: 0.34)
    static let vibrantOrange = Color(red: 1, green: 0.42, blue: 0.02)

    // MARK: - Gradient Colors
    static let gradientStart = Color(red: 1, green: 0.77, blue: 0.34)
    static let gradientEnd = Color(red: 1, green: 0.98, blue: 0.95)
    static let gradientMid = Color(red: 1, green: 0.88, blue: 0.65)

    // MARK: - Background Colors
    static let warmBackground = Color(hex: "FFF8F1")
    static let cardBackground = Color.white
    static let glassBackground = Color.white.opacity(0.7)
    static let sidebarBackground = Color.black.opacity(0.02)

    // MARK: - Text Colors
    static let primaryText = Color.black
    static let secondaryText = Color.black.opacity(0.7)
    static let tertiaryText = Color.black.opacity(0.5)
    static let primaryTextOnOrange = Color.white
    static let secondaryTextOnOrange = Color.white.opacity(0.8)

    // MARK: - Status Colors
    static let successGreen = Color(red: 0.34, green: 1, blue: 0.45)
    static let errorRed = Color(hex: "E91515")
    static let warningYellow = Color(red: 1, green: 0.82, blue: 0.0)

    // MARK: - Interactive Colors
    static let hoverBackground = Color.gray.opacity(0.1)
    static let selectedBackground = Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.1)
    static let pressedBackground = Color(red: 0.62, green: 0.44, blue: 0.36).opacity(0.2)
}

// MARK: - Gradients
struct DesignGradients {
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            DesignColors.gradientStart,
            DesignColors.gradientMid,
            DesignColors.gradientEnd
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let flowingGradient = LinearGradient(
        gradient: Gradient(colors: [
            DesignColors.gradientStart,
            DesignColors.gradientMid,
            DesignColors.gradientEnd
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        gradient: Gradient(colors: [
            DesignColors.cardBackground,
            DesignColors.glassBackground
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let buttonGradient = LinearGradient(
        gradient: Gradient(colors: [
            DesignColors.vibrantOrange,
            DesignColors.primaryOrange
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Typography
struct DesignTypography {
    // MARK: - Font Families
    static let headingFont = "InstrumentSerif-Regular"
    static let bodyFont = "Nunito"
    static let systemFont = "San Francisco"
    static let displayFont = "InstrumentSerif-Regular"

    // MARK: - Font Sizes
    static let display: CGFloat = 48
    static let largeTitle: CGFloat = 36
    static let title1: CGFloat = 28
    static let title2: CGFloat = 24
    static let title3: CGFloat = 20
    static let headline: CGFloat = 18
    static let subheadline: CGFloat = 17
    static let body: CGFloat = 16
    static let callout: CGFloat = 15
    static let caption: CGFloat = 14
    static let caption2: CGFloat = 13
    static let footnote: CGFloat = 12

    // MARK: - Font Weights
    static let bold = Font.Weight.bold
    static let semibold = Font.Weight.semibold
    static let medium = Font.Weight.medium
    static let regular = Font.Weight.regular
    static let light = Font.Weight.light
}

// MARK: - Spacing
struct DesignSpacing {
    // MARK: - Base Spacing
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: - Component Spacing
    static let cardPadding: CGFloat = 24
    static let cardSpacing: CGFloat = 16
    static let buttonSpacing: CGFloat = 12
    static let inputSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 32

    // MARK: - Layout Spacing
    static let sidebarWidth: CGFloat = 100
    static let contentPadding: CGFloat = 32
    static let containerWidth: CGFloat = 800
    static let maxWidth: CGFloat = 1200
}

// MARK: - Border Radius
struct DesignRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xl: CGFloat = 20
    static let round: CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - Shadows (use with .shadow() modifier)
struct DesignShadows {
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    static let cardShadow = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let hoverShadow = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    static let elevatedShadow = ShadowStyle(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
}

// MARK: - Animation Durations
struct DesignAnimation {
    static let quick: Double = 0.2
    static let standard: Double = 0.3
    static let slow: Double = 0.5
    static let verySlow: Double = 0.8

    static let spring = Animation.spring(response: 0.22, dampingFraction: 0.8)
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.65)
    static let hover = Animation.spring(response: 0.22, dampingFraction: 0.8)
    static let reveal = Animation.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)
    static let stagger = Animation.spring(response: 0.5, dampingFraction: 0.75)
}

// MARK: - Z-Index Levels
struct DesignZIndex {
    static let background: CGFloat = 0
    static let cards: CGFloat = 10
    static let buttons: CGFloat = 20
    static let modals: CGFloat = 100
    static let sidebars: CGFloat = 30
    static let headers: CGFloat = 40
    static let overlays: CGFloat = 50
}

// MARK: - Accessibility
struct DesignAccessibility {
    static let minimumTouchTarget: CGFloat = 44
    static let preferredButtonHeight: CGFloat = 56
    static let standardButtonHeight: CGFloat = 48
    static let compactButtonHeight: CGFloat = 40
}