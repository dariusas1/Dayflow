//
//  DashboardCustomizationView.swift
//  FocusLock
//
//  Customization interface for dashboard widgets and layouts
//

import SwiftUI

struct DashboardCustomizationView: View {
    @Binding var configuration: DashboardConfiguration
    @Binding var availableWidgets: [DashboardWidget]
    let onSave: () -> Void

    @State private var selectedCategory: WidgetCategory = .all
    @State private var editingWidget: DashboardWidget? = nil
    @State private var showingWidgetEditor: Bool = false
    @Environment(\.dismiss) private var dismiss

    enum WidgetCategory: String, CaseIterable {
        case all = "All"
        case focus = "Focus"
        case productivity = "Productivity"
        case tasks = "Tasks"
        case apps = "Apps"
        case wellness = "Wellness"
        case goals = "Goals"
        case insights = "Insights"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .focus: return "clock.fill"
            case .productivity: return "chart.line.uptrend.xyaxis"
            case .tasks: return "checkmark.circle.fill"
            case .apps: return "app.badge"
            case .wellness: return "heart.fill"
            case .goals: return "target"
            case .insights: return "lightbulb.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("Customize Dashboard")
                        .font(.custom("InstrumentSerif-Regular", size: 32))
                        .foregroundColor(.black)

                    Text("Add, remove, and arrange widgets to create your perfect productivity dashboard")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Category selector
                CategorySelector(
                    selectedCategory: $selectedCategory,
                    categories: WidgetCategory.allCases
                )
                .padding(.horizontal)
                .padding(.vertical, 16)

                // Content
                HStack(spacing: 0) {
                    // Available widgets
                    AvailableWidgetsPanel(
                        widgets: filteredAvailableWidgets,
                        onAddWidget: addWidget,
                        selectedCategory: selectedCategory
                    )

                    Divider()
                        .frame(width: 1)
                        .background(Color.gray.opacity(0.2))

                    // Current widgets
                    CurrentWidgetsPanel(
                        widgets: $configuration.widgets,
                        onRemoveWidget: removeWidget,
                        onReorderWidgets: reorderWidgets,
                        onEditWidget: editWidget
                    )
                }
                .padding(.horizontal)

                // Footer
                HStack {
                    Button("Reset to Default") {
                        resetToDefault()
                    }
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.red)

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("Nunito", size: 16))
                    .foregroundColor(.gray)

                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingWidgetEditor) {
            if let widget = editingWidget {
                WidgetEditorView(
                    widget: widget,
                    onSave: updateWidget,
                    onCancel: {
                        editingWidget = nil
                        showingWidgetEditor = false
                    }
                )
            }
        }
    }

    private var filteredAvailableWidgets: [DashboardWidget] {
        if selectedCategory == .all {
            return availableWidgets.filter { widget in
                !configuration.widgets.contains { $0.id == widget.id }
            }
        }

        return availableWidgets.filter { widget in
            !configuration.widgets.contains { $0.id == widget.id } &&
            categoryForWidget(widget) == selectedCategory
        }
    }

    private func categoryForWidget(_ widget: DashboardWidget) -> WidgetCategory {
        switch widget.type {
        case .focusTime: return .focus
        case .productivity: return .productivity
        case .tasks: return .tasks
        case .apps: return .apps
        case .wellness: return .wellness
        case .goals: return .goals
        case .insights, .trends: return .insights
        }
    }

    private func addWidget(_ widget: DashboardWidget) {
        var newWidget = widget
        newWidget.position.order = configuration.widgets.count
        configuration.widgets.append(newWidget)
    }

    private func removeWidget(_ widget: DashboardWidget) {
        configuration.widgets.removeAll { $0.id == widget.id }
        // Update positions
        for index in configuration.widgets.indices {
            configuration.widgets[index].position.order = index
        }
    }

    private func reorderWidgets(from source: IndexSet, to destination: Int) {
        configuration.widgets.move(fromOffsets: source, toOffset: destination)
        // Update positions
        for index in configuration.widgets.indices {
            configuration.widgets[index].position.order = index
        }
    }

    private func editWidget(_ widget: DashboardWidget) {
        editingWidget = widget
        showingWidgetEditor = true
    }

    private func updateWidget(_ updatedWidget: DashboardWidget) {
        if let index = configuration.widgets.firstIndex(where: { $0.id == updatedWidget.id }) {
            configuration.widgets[index] = updatedWidget
        }
        editingWidget = nil
        showingWidgetEditor = false
    }

    private func resetToDefault() {
        configuration = DashboardConfiguration(
            widgets: [
                DashboardWidget(
                    id: "focus-time",
                    type: .focusTime,
                    title: "Focus Time",
                    position: .init(row: 0),
                    size: .large
                ),
                DashboardWidget(
                    id: "productivity-score",
                    type: .productivity,
                    title: "Productivity Score",
                    position: .init(row: 1),
                    size: .medium
                ),
                DashboardWidget(
                    id: "app-usage",
                    type: .apps,
                    title: "App Usage",
                    position: .init(row: 2),
                    size: .large
                ),
                DashboardWidget(
                    id: "insights",
                    type: .insights,
                    title: "Insights",
                    position: .init(row: 3),
                    size: .large
                )
            ]
        )
    }
}

// MARK: - Category Selector

struct CategorySelector: View {
    @Binding var selectedCategory: DashboardCustomizationView.WidgetCategory
    let categories: [DashboardCustomizationView.WidgetCategory]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12, weight: .medium))

                            Text(category.rawValue)
                                .font(.custom("Nunito", size: 14))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category ? Color.black : Color.white
                        )
                        .foregroundColor(
                            selectedCategory == category ? Color.white : Color.black
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - Available Widgets Panel

struct AvailableWidgetsPanel: View {
    let widgets: [DashboardWidget]
    let onAddWidget: (DashboardWidget) -> Void
    let selectedCategory: DashboardCustomizationView.WidgetCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Widgets")
                .font(.custom("InstrumentSerif-Regular", size: 20))
                .foregroundColor(.black)
                .padding(.leading, 4)

            if widgets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("No widgets available")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.gray)

                    Text("Try selecting a different category")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(widgets, id: \.id) { widget in
                            AvailableWidgetCard(
                                widget: widget,
                                onAdd: { onAddWidget(widget) }
                            )
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AvailableWidgetCard: View {
    let widget: DashboardWidget
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Widget preview
            VStack(spacing: 4) {
                Image(systemName: iconForWidget(widget))
                    .font(.system(size: 24))
                    .foregroundColor(colorForWidget(widget))

                Text(widget.title)
                    .font(.custom("Nunito", size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 60)

            // Size indicator
            HStack {
                Spacer()
                Text(sizeLabel(widget.size))
                    .font(.custom("Nunito", size: 10))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            onAdd()
        }
    }

    private func iconForWidget(_ widget: DashboardWidget) -> String {
        return widget.type.icon
    }

    private func colorForWidget(_ widget: DashboardWidget) -> Color {
        switch widget.type {
        case .focusTime: return .blue
        case .productivity: return .green
        case .tasks: return .orange
        case .apps: return .purple
        case .wellness: return .pink
        case .goals: return .teal
        case .insights: return .purple
        case .trends: return .orange
        }
    }

    private func sizeLabel(_ size: DashboardWidget.WidgetSize) -> String {
        switch size {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
}

// MARK: - Current Widgets Panel

struct CurrentWidgetsPanel: View {
    @Binding var widgets: [DashboardWidget]
    let onRemoveWidget: (DashboardWidget) -> Void
    let onReorderWidgets: (IndexSet, Int) -> Void
    let onEditWidget: (DashboardWidget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Widgets")
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.black)

                Spacer()

                Text("\(widgets.count) widgets")
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.leading, 4)

            if widgets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("No widgets added")
                        .font(.custom("Nunito", size: 16))
                        .foregroundColor(.gray)

                    Text("Add widgets from the available panel")
                        .font(.custom("Nunito", size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                List {
                    ForEach(widgets, id: \.id) { widget in
                        CurrentWidgetRow(
                            widget: widget,
                            onRemove: { onRemoveWidget(widget) },
                            onEdit: { onEditWidget(widget) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: onReorderWidgets)
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CurrentWidgetRow: View {
    let widget: DashboardWidget
    let onRemove: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.5))

            // Widget info
            VStack(alignment: .leading, spacing: 4) {
                Text(widget.title)
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.black)

                HStack(spacing: 12) {
                    Text(widget.type.displayName)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)

                    Text("•")
                        .foregroundColor(.gray.opacity(0.5))

                    Text(sizeLabel(widget.size))
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Edit Widget")

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Remove Widget")
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func sizeLabel(_ size: DashboardWidget.WidgetSize) -> String {
        switch size {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

// MARK: - Widget Editor

struct WidgetEditorView: View {
    let widget: DashboardWidget
    let onSave: (DashboardWidget) -> Void
    let onCancel: () -> Void

    @State private var editedWidget: DashboardWidget
    @Environment(\.dismiss) private var dismiss

    init(widget: DashboardWidget, onSave: @escaping (DashboardWidget) -> Void, onCancel: @escaping () -> Void) {
        self.widget = widget
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedWidget = State(initialValue: widget)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Widget Title")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.black)

                    TextField("Enter widget title", text: $editedWidget.title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.custom("Nunito", size: 14))
                }

                // Size selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Widget Size")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.black)

                    HStack(spacing: 12) {
                        ForEach(DashboardWidget.WidgetSize.allCases, id: \.self) { size in
                            Button(action: { editedWidget.size = size }) {
                                Text(sizeDisplayName(size))
                                    .font(.custom("Nunito", size: 14))
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        editedWidget.size == size ? Color.black : Color.white
                                    )
                                    .foregroundColor(
                                        editedWidget.size == size ? Color.white : Color.black
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.black)

                    WidgetPreview(widget: editedWidget)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Edit Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.custom("Nunito", size: 16))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedWidget)
                    }
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                }
            }
        }
        .frame(width: 400, height: 350)
    }

    private func sizeDisplayName(_ size: DashboardWidget.WidgetSize) -> String {
        switch size {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
}

struct WidgetPreview: View {
    let widget: DashboardWidget

    var body: some View {
        VStack(spacing: 8) {
            // Simplified preview based on size
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: widget.systemImage)
                            .font(.system(size: iconSize))
                            .foregroundColor(.blue)

                        Text(widget.title)
                            .font(.custom("Nunito", size: titleSize))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                )
                .frame(height: previewHeight)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var previewHeight: CGFloat {
        switch widget.size {
        case .small: return 80
        case .medium: return 120
        case .large: return 160
        }
    }

    private var iconSize: CGFloat {
        switch widget.size {
        case .small: return 16
        case .medium: return 24
        case .large: return 32
        }
    }

    private var titleSize: CGFloat {
        switch widget.size {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        }
    }
}

#Preview {
    DashboardCustomizationView(
        configuration: .constant(DashboardConfiguration(
            widgets: []
        )),
        availableWidgets: .constant([]),
        onSave: { }
    )
}
