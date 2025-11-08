//
//  AccessibilityExtensions.swift
//  Dayflow
//
//  Accessibility enhancements for all UI components
//

import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    // Accessibility identifier for testing
    func accessibilityIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }

    // Accessibility label for screen readers
    func accessibilityLabel(_ label: String) -> some View {
        self.accessibilityLabel(label)
    }

    // Accessibility hint for additional context
    func accessibilityHint(_ hint: String) -> some View {
        self.accessibilityHint(hint)
    }

    // Accessibility value for dynamic content
    func accessibilityValue(_ value: String) -> some View {
        self.accessibilityValue(value)
    }

    // Make element accessible but hidden from screen readers
    func accessibilityHidden(_ hidden: Bool = true) -> some View {
        self.accessibility(hidden: hidden)
    }

    // Set accessibility traits
    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        self.accessibilityAddTraits(traits)
    }

    // Remove accessibility traits
    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        self.accessibilityRemoveTraits(traits)
    }

    // Accessibility for buttons
    func accessibleButton(
        label: String,
        hint: String? = nil,
        role: AccessibilityRole = .button
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityRole(role)
            .accessibilityHint(hint ?? "")
    }

    // Accessibility for images
    func accessibleImage(
        label: String,
        decorative: Bool = false
    ) -> some View {
        self
            .accessibilityLabel(decorative ? "" : label)
            .accessibilityAddTraits(decorative ? .isImage : [.isImage, .isButton])
            .accessibilityHidden(decorative)
    }

    // Accessibility for status indicators
    func accessibleStatus(
        label: String,
        value: String,
        isImportant: Bool = true
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAddTraits(isImportant ? .updatesFrequently : [])
    }

    // Accessibility for progress indicators
    func accessibleProgress(
        label: String,
        value: Double,
        total: Double = 100.0
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value)) of \(Int(total))")
            .accessibilityAddTraits(.updatesFrequently)
    }

    // Accessibility for lists
    func accessibleList(
        label: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label ?? "List")
            .accessibilityAddTraits(.isSummaryElement)
    }

    // Accessibility for navigation
    func accessibleNavigation(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Navigate to \(label.lowercased())")
            .accessibilityAddTraits(.isButton)
    }

    // Accessibility for form fields
    func accessibleField(
        label: String,
        value: String? = nil,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
    }

    // Accessibility for interactive cards
    func accessibleCard(
        title: String,
        subtitle: String? = nil,
        hint: String? = nil,
        isButton: Bool = false
    ) -> some View {
        let fullLabel = subtitle != nil ? "\(title). \(subtitle!)" : title
        return self
            .accessibilityLabel(fullLabel)
            .accessibilityHint(hint ?? (isButton ? "Double tap to interact" : ""))
            .accessibilityAddTraits(isButton ? .isButton : .isStaticText)
    }
}

// MARK: - Focus Management

extension View {
    // Make element focusable
    func focusable() -> some View {
        self.focusable()
    }

    // Set focus style
    func focusStyle(_ style: some FocusEffectStyle) -> some View {
        self.focusSection()
    }

    // Custom focus ring with orange accent
    func orangeFocusRing() -> some View {
        self.focusable()
            .focused(\.isFocused) { isFocused in
                // Custom focus handling can be added here
            }
    }
}

// MARK: - Voice Over Support

extension View {
    // Announce changes to VoiceOver users
    func announceChange(_ message: String) -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    // Screen changed notification
    func screenChanged() -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    // Layout changed notification
    func layoutChanged() -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }
}

// MARK: - High Contrast Support

extension View {
    // Adapt for high contrast mode
    func adaptForHighContrast() -> some View {
        self.environment(\.colorSchemeContrast, .increased)
    }

    // Check if high contrast is enabled
    func isHighContrastMode() -> Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

// MARK: - Reduced Motion Support

extension View {
    // Respect reduced motion preferences
    func reducedMotionAnimation() -> some View {
        self.animation(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .none : .default,
            value: UUID()
        )
    }

    // Check if reduced motion is preferred
    func prefersReducedMotion() -> Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

// MARK: - Keyboard Navigation

extension View {
    // Enable keyboard navigation
    func keyboardNavigable() -> some View {
        self.focusable()
            .focusSection()
    }

    // Set tab order
    func tabOrder(_ order: Int) -> some View {
        self.accessibilityAddTraits(.isSummaryElement)
    }
}

// MARK: - Color Blindness Support

extension DesignColors {
    // High contrast variants for better accessibility
    static var accessibleOrange: Color {
        // Use higher contrast orange for better visibility
        Color(red: 0.9, green: 0.4, blue: 0.1)
    }

    static var accessibleBackground: Color {
        // Ensure sufficient contrast ratio
        Color(red: 1.0, green: 0.98, blue: 0.95)
    }

    static var accessibleText: Color {
        // High contrast text
        Color.black
    }
}

// MARK: - Typography Accessibility

extension View {
    // Ensure text meets accessibility standards
    func accessibleText(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self
            .font(.system(size: size, weight: weight))
            .foregroundColor(DesignColors.accessibleText)
            .minimumScaleFactor(0.8) // Prevent text from becoming too small
    }

    // Accessible heading
    func accessibleHeading(level: Int = 1) -> some View {
        let size: CGFloat = {
            switch level {
            case 1: return 24
            case 2: return 20
            case 3: return 18
            default: return 16
            }
        }()

        return self
            .font(.system(size: size, weight: .bold))
            .foregroundColor(DesignColors.accessibleText)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Component Accessibility Helpers

struct AccessibleButton: View {
    let title: String
    let action: () -> Void
    let variant: ButtonVariant

    enum ButtonVariant {
        case primary
        case secondary
        case destructive
    }

    var body: some View {
        UnifiedButton.primary(title, action: action)
            .accessibleButton(
                label: title,
                hint: accessibilityHint,
                role: .button
            )
    }

    private var accessibilityHint: String {
        switch variant {
        case .primary:
            return "Primary action"
        case .secondary:
            return "Secondary action"
        case .destructive:
            return "Deletes or removes content"
        }
    }
}

struct AccessibleCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let content: Content

    @State private var isHovered: Bool = false

    init(
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.content = content()
    }

    var body: some View {
        UnifiedCard(style: .interactive) {
            content
        }
        .onTapGesture {
            action?()
        }
        .accessibleCard(
            title: title,
            subtitle: subtitle,
            hint: action != nil ? "Double tap to activate" : nil,
            isButton: action != nil
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AccessibleProgress: View {
    let progress: Double
    let total: Double
    let label: String

    var body: some View {
        ProgressView(value: progress, total: total)
            .accessibleProgress(
                label: label,
                value: progress,
                total: total
            )
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Settings Accessibility

extension View {
    // Accessible settings toggle
    func accessibleToggle(
        label: String,
        value: Bool,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value ? "On" : "Off")
            .accessibilityHint(hint ?? "Double tap to toggle")
            .accessibilityAddTraits(.isButton)
    }

    // Accessible settings slider
    func accessibleSlider(
        label: String,
        value: Double,
        range: ClosedRange<Double>,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value))")
            .accessibilityHint(hint ?? "Adjust value")
            .accessibilityAddTraits(.adjustable)
    }
}

// MARK: - Preview with Accessibility

#Preview("Accessibility Components") {
    VStack(spacing: 20) {
        AccessibleButton(title: "Accessible Button") {
            // Action
        }

        AccessibleCard(
            title: "Card Title",
            subtitle: "Card subtitle",
            action: {
                // Action
            }
        ) {
            Text("Card content")
                .foregroundColor(DesignColors.primaryText)
        }

        AccessibleProgress(
            progress: 75,
            total: 100,
            label: "Download Progress"
        )
    }
    .padding()
    .background(DesignColors.accessibleBackground)
}