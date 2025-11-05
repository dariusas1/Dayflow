//
//  DayflowCircleButton.swift
//  Dayflow
//
//  Circular button component with unified Emil-style hover/press interactions
//

import SwiftUI

struct DayflowCircleButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var background: Color = .white
    var foreground: Color = .black
    var borderColor: Color = .black.opacity(0.15)
    var size: CGFloat = 40
    var showShadow: Bool = true

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hoverAnim = Animation.spring(response: 0.22, dampingFraction: 0.85)
    private let pressAnim = Animation.spring(response: 0.26, dampingFraction: 0.75)

    var body: some View {
        Button(action: {
            withAnimation(pressAnim) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(pressAnim) { isPressed = false }
                action()
            }
        }) {
            ZStack {
                content()
                    .foregroundColor(foreground.opacity(0.85))
            }
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .inset(by: 0.75)
                    .stroke(isHovered ? borderColor.opacity(1.0) : borderColor, lineWidth: 1)
            )
            .if(showShadow) { view in
                view
                    .shadow(color: .black.opacity(isHovered ? 0.10 : 0.06), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
                    .shadow(color: .black.opacity(isHovered ? 0.06 : 0.04), radius: isHovered ? 2 : 1, x: 0, y: 1)
            }
            .brightness(isPressed ? -0.04 : (isHovered ? 0.02 : 0))
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.985 : (isHovered ? 1.02 : 1.0)))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(hoverAnim) { isHovered = hovering }
        }
        .pointingHandCursor()
    }
}

