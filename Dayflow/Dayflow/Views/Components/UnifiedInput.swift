//
//  UnifiedInput.swift
//  Dayflow
//
//  Unified input components with consistent styling
//

import SwiftUI

struct UnifiedTextField: View {
    @Binding var text: String
    let placeholder: String
    let style: InputStyle
    let isSecure: Bool
    let disabled: Bool
    let errorMessage: String?
    let onSubmit: () -> Void

    init(
        _ placeholder: String,
        text: Binding<String>,
        style: InputStyle = .standard,
        isSecure: Bool = false,
        disabled: Bool = false,
        errorMessage: String? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
        self.isSecure = isSecure
        self.disabled = disabled
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
    }

    @State private var isEditing = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Input field
            HStack(spacing: 12) {
                if let icon = style.icon {
                    inputIcon(icon)
                }

                inputField

                if style == .search {
                    searchIcon
                }

                if isSecure && !text.isEmpty {
                    clearButton
                }
            }
            .inputFieldBackground
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                    .inset(by: 1.5)
                    .stroke(borderColor, lineWidth: isEditing ? 2 : 1)
            )
            .if(style == .error || errorMessage != nil) { view in
                view.animation(.easeInOut(duration: 0.2)) {
                    view.overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                            .inset(by: 1.5)
                            .stroke(DesignColors.errorRed, lineWidth: 1.5)
                    )
                }
            }

            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(DesignColors.errorRed)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(DesignColors.errorRed)
                }
                .animation(.easeInOut(duration: 0.2))
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        Group {
            if isSecure {
                SecureField("", text: $text)
                    .placeholder(placeholder)
                    .textContentType(.password)
                    .disabled(disabled)
                    .onSubmit(onSubmit)
            } else {
                TextField("", text: $text)
                    .placeholder(placeholder)
                    .textContentType(style.contentType)
                    .disabled(disabled)
                    .onSubmit(onSubmit)
            }
        }
        .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
        .foregroundColor(DesignColors.primaryText)
        .onTapGesture {
            isEditing = true
        }
        .onChange(of: isEditing) { oldValue, newValue in
            if !newValue && text.isEmpty {
                onSubmit()
            }
        }
    }

    @ViewBuilder
    private var inputIcon: some View {
        Image(systemName: iconSystemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(iconColor)
            .frame(width: 20, height: 20)
    }

    @ViewBuilder
    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(DesignColors.secondaryText)
            .frame(width: 20, height: 20)
    }

    @ViewBuilder
    private var clearButton: some View {
        Button(action: {
            text = ""
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(DesignColors.secondaryText)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var inputFieldBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                .fill(DesignColors.cardBackground)
                .background(.regularMaterial)

            RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.3)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var borderStrokeColor: Color {
        switch style {
        case .standard:
            return DesignColors.secondaryText.opacity(isEditing ? 0.5 : 0.3)
        case .search:
            return DesignColors.primaryOrange.opacity(isEditing ? 0.7 : 0.4)
        case .error:
            return DesignColors.errorRed
        }
    }

    private var iconSystemName: String {
        switch style {
        case .standard:
            return "envelope"
        case .search:
            return "magnifyingglass"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch style {
        case .standard:
            return DesignColors.primaryOrange
        case .search:
            return DesignColors.primaryOrange
        case .error:
            return DesignColors.errorRed
        }
    }
}

// MARK: - Input Styles

struct InputStyle {
    let contentType: UITextContentType
    let icon: String?
    let color: Color?

    init(
        contentType: UITextContentType = .name,
        icon: String? = nil,
        color: Color? = nil
    ) {
        self.contentType = contentType
        self.icon = icon
        self.color = color
    }

    static var standard: InputStyle {
        InputStyle()
    }

    static var search: InputStyle {
        InputStyle(
            contentType: .name,
            icon: "magnifyingglass"
        )
    }

    static var email: InputStyle {
        InputStyle(
            contentType: .emailAddress,
            icon: "envelope"
        )
    }

    static var password: InputStyle {
        InputStyle(
            contentType: .password,
            icon: "lock"
        )
    }

    static var error: InputStyle {
        InputStyle(
            contentType: .name,
            icon: "exclamationmark.triangle.fill",
            color: DesignColors.errorRed
        )
    }
}

// MARK: - Text Area

struct UnifiedTextArea: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat
    let style: InputStyle
    let errorMessage: String?

    init(
        _ placeholder: String,
        text: Binding<String>,
        height: CGFloat = 120,
        style: InputStyle = .standard,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.height = height
        self.style = style
        self.errorMessage = errorMessage
    }

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Text area
            ZStack {
                RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                    .fill(DesignColors.cardBackground)
                    .background(.regularMaterial)

                TextEditor(text: $text)
                    .font(.custom(DesignTypography.bodyFont, size: DesignTypography.body))
                    .foregroundColor(DesignColors.primaryText)
                    .padding(12)
                    .frame(height: height)
                    .overlay(
                        Group {
                            if text.isEmpty {
                                Text(placeholder)
                                    .foregroundColor(DesignColors.tertiaryText)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                            .inset(by: 1.5)
                            .stroke(borderColor, lineWidth: isEditing ? 2 : 1)
                    )
                    .onTapGesture {
                        isEditing = true
                    }
            }

            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(DesignColors.errorRed)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(DesignColors.errorRed)
                }
                .animation(.easeInOut(duration: 0.2))
            }
        }
    }

    private var borderStrokeColor: Color {
        DesignColors.secondaryText.opacity(isEditing ? 0.5 : 0.3)
    }
}

// MARK: - Convenience Modifiers

extension View {
    func inputField(
        _ placeholder: String,
        text: Binding<String>,
        style: InputStyle = .standard,
        isSecure: Bool = false,
        disabled: Bool = false,
        errorMessage: String? = nil
    ) -> some View {
        UnifiedTextField(
            placeholder: placeholder,
            text: text,
            style: style,
            isSecure: isSecure,
            disabled: disabled,
            errorMessage: errorMessage
        )
    }

    func standardInput(
        _ placeholder: String,
        text: Binding<String>
    ) -> some View {
        UnifiedTextField(
            placeholder: placeholder,
            text: text,
            style: .standard
        )
    }

    func searchInput(
        _ placeholder: String,
        text: Binding<String>
    ) -> some View {
        UnifiedTextField(
            placeholder: placeholder,
            text: text,
            style: .search
        )
    }

    func emailInput(
        _ placeholder: String,
        text: Binding<String>
    ) -> some View {
        UnifiedTextField(
            placeholder: placeholder,
            text: text,
            style: .email
        )
    }

    func passwordInput(
        _ placeholder: String,
        text: Binding<String>
    ) -> some View {
        UnifiedTextField(
            placeholder: placeholder,
            text: text,
            style: .password,
            isSecure: true
        )
    }

    func textArea(
        _ placeholder: String,
        text: Binding<String>,
        height: CGFloat = 120,
        errorMessage: String? = nil
    ) -> some View {
        UnifiedTextArea(
            placeholder: placeholder,
            text: text,
            height: height,
            errorMessage: errorMessage
        )
    }
}

// MARK: - Preview

#Preview("Input Components") {
    VStack(spacing: 20) {
        VStack(spacing: 12) {
            UnifiedTextField(
                "Enter your name",
                text: .constant(""),
                style: .standard
            )

            UnifiedTextField(
                "Search...",
                text: .constant(""),
                style: .search
            )

            UnifiedTextField(
                "Email",
                text: .constant(""),
                style: .email
            )

            UnifiedTextField(
                "Password",
                text: .constant(""),
                style: .password,
                isSecure: true
            )

            UnifiedTextField(
                "Error input",
                text: .constant(""),
                style: .error,
                errorMessage: "This field is required"
            )
        }

        UnifiedTextArea(
            "Enter your message...",
            text: .constant(""),
            height: 120
        )
    }
    .padding()
    .background(DesignColors.warmBackground)
}