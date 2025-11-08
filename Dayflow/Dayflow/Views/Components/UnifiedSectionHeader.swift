//
//  UnifiedSectionHeader.swift
//  Dayflow
//
//  Section header component
//

import SwiftUI

struct UnifiedSectionHeader: View {
    let title: String
    var fontSize: CGFloat = 24
    
    var body: some View {
        Text(title)
            .font(.custom("InstrumentSerif-Regular", size: fontSize))
            .foregroundColor(.black)
    }
}

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
        content
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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

