//
//  UnifiedButton.swift
//  Dayflow
//
//  Wrapper for DayflowButton with unified interface
//

import SwiftUI

struct UnifiedButton {
    // Static factory methods for different button styles
    
    static func primary(
        _ title: String,
        size: Size = .medium,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        DayflowButton(title: title, action: action)
            .opacity(disabled ? 0.5 : 1.0)
            .disabled(disabled)
    }
    
    static func secondary(
        _ title: String,
        size: Size = .medium,
        action: @escaping () -> Void
    ) -> some View {
        DayflowButton(title: title, action: action)
    }
    
    static func ghost(
        _ title: String,
        size: Size = .medium,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Nunito", size: 16))
                .foregroundColor(Color(hex: "FF6B35"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    enum Size {
        case small
        case medium
        case large
        case xlarge
    }
}

