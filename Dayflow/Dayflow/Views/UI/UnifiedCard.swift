//
//  UnifiedCard.swift
//  FocusLock
//
//  Unified card component system matching MainView design language
//

import SwiftUI

struct UnifiedCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    var shadowOpacity: Double = 0.05
    var shadowRadius: CGFloat = 2
    var shadowOffset: CGSize = CGSize(width: 0, height: 1)
    var hoverEnabled: Bool = false
    
    @State private var isHovered: Bool = false
    
    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        shadowOpacity: Double = 0.05,
        shadowRadius: CGFloat = 2,
        shadowOffset: CGSize = CGSize(width: 0, height: 1),
        hoverEnabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.hoverEnabled = hoverEnabled
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(Color.white)
            .cornerRadius(cornerRadius)
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: isHovered && hoverEnabled ? shadowRadius * 1.5 : shadowRadius,
                x: shadowOffset.width,
                y: isHovered && hoverEnabled ? shadowOffset.height * 1.5 : shadowOffset.height
            )
            .scaleEffect(isHovered && hoverEnabled ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                if hoverEnabled {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Section Header Component

struct UnifiedSectionHeader: View {
    let title: String
    var fontSize: CGFloat = 24
    
    var body: some View {
        Text(title)
            .font(.custom("InstrumentSerif-Regular", size: fontSize))
            .foregroundColor(.black)
    }
}

// MARK: - Card with Entrance Animation

struct AnimatedCard<Content: View>: View {
    let index: Int
    let content: Content
    var animationDelay: Double = 0.1
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = -20
    
    init(index: Int = 0, animationDelay: Double = 0.1, @ViewBuilder content: () -> Content) {
        self.index = index
        self.animationDelay = animationDelay
        self.content = content()
    }
    
    var body: some View {
        UnifiedCard {
            content
        }
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(Double(index) * animationDelay)) {
                opacity = 1
                offset = 0
            }
        }
    }
}

// MARK: - Preview

// MARK: - View Modifier for Unified Cards

struct UnifiedCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 12
    var shadowOpacity: Double = 0.05
    var shadowRadius: CGFloat = 2
    var shadowOffset: CGSize = CGSize(width: 0, height: 1)
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.white)
            .cornerRadius(cornerRadius)
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
    }
}

extension View {
    func unifiedCardStyle(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        shadowOpacity: Double = 0.05,
        shadowRadius: CGFloat = 2,
        shadowOffset: CGSize = CGSize(width: 0, height: 1)
    ) -> some View {
        modifier(UnifiedCardModifier(
            padding: padding,
            cornerRadius: cornerRadius,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset
        ))
    }
}

struct UnifiedCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            UnifiedCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Title")
                        .font(.custom("Nunito", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text("Card content goes here")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            
            UnifiedCard(hoverEnabled: true) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.blue)
                    Text("Hoverable Card")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.black)
                }
            }
            
            AnimatedCard(index: 0) {
                Text("Animated Card")
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.black)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

