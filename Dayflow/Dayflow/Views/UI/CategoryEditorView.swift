//
//  CategoryEditorView.swift
//  FocusLock
//
//  Category management interface wrapper
//

import SwiftUI

struct CategoryEditorView: View {
    @ObservedObject var categoryStore: CategoryStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ColorOrganizerRoot(
            presentationStyle: .sheet,
            onDismiss: { dismiss() },
            completionButtonTitle: "Done",
            showsTitles: true
        )
        .environmentObject(categoryStore)
    }
}

#Preview {
    CategoryEditorView(categoryStore: CategoryStore())
}

