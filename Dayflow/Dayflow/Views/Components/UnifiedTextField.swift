//
//  UnifiedTextField.swift
//  Dayflow
//
//  Simple text field wrapper
//

import SwiftUI

struct UnifiedTextField: View {
    let placeholder: String
    @Binding var text: String
    let style: Style
    
    init(_ placeholder: String, text: Binding<String>, style: Style = .default) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
    }
    
    var body: some View {
        HStack {
            if style == .search {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.custom("Nunito", size: 16))
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(style == .search ? 16 : 8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    enum Style {
        case `default`
        case standard
        case search
    }
}

