//
//  DayflowPillButton.swift
//  Dayflow
//
//  Pill-shaped button component with text content
//

import SwiftUI

struct DayflowPillButton: View {
    let text: String
    var fixedWidth: CGFloat? = nil
    
    var background: Color = .white
    var foreground: Color = .black
    var borderColor: Color = .black.opacity(0.15)
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 12
    var showShadow: Bool = true

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hoverAnim = Animation.spring(response: 0.22, dampingFraction: 0.85)
    private let pressAnim = Animation.spring(response: 0.26, dampingFraction: 0.75)

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .foregroundColor(foreground.opacity(0.85))
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(width: fixedWidth)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 0.75)
                .stroke(isHovered ? borderColor.opacity(1.0) : borderColor, lineWidth: 1)
        )
        .cornerRadius(20)
        .if(showShadow) { view in
            view
                .shadow(color: .black.opacity(isHovered ? 0.10 : 0.06), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
                .shadow(color: .black.opacity(isHovered ? 0.06 : 0.04), radius: isHovered ? 2 : 1, x: 0, y: 1)
        }
        .brightness(isPressed ? -0.04 : (isHovered ? 0.02 : 0))
        .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.985 : (isHovered ? 1.02 : 1.0)))
    }
}

