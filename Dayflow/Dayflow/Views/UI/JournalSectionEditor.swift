//
//  JournalSectionEditor.swift
//  FocusLock
//
//  UI for customizing journal sections - add, edit, delete, and reorder sections
//

import SwiftUI

struct JournalSectionEditor: View {
    @Binding var sections: [JournalSection]
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddSection = false
    @State private var editingSection: JournalSection?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Section list
            if sections.isEmpty {
                emptyState
            } else {
                sectionList
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingAddSection) {
            SectionEditSheet(section: nil) { newSection in
                addSection(newSection)
            }
        }
        .sheet(item: $editingSection) { section in
            SectionEditSheet(section: section) { updatedSection in
                updateSection(updatedSection)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            Text("Customize Journal Sections")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            Button(action: {
                showingAddSection = true
            }) {
                Label("Add Section", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: {
                dismiss()
            }) {
                Text("Done")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No sections yet")
                .font(.system(size: 16, weight: .medium))
            
            Text("Add sections to customize your daily journal")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Button(action: {
                showingAddSection = true
            }) {
                Text("Add First Section")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sectionList: some View {
        List {
            ForEach(sections) { section in
                SectionRow(section: section) {
                    editingSection = section
                } onDelete: {
                    deleteSection(section)
                } onMoveUp: {
                    moveSection(section, direction: -1)
                } onMoveDown: {
                    moveSection(section, direction: 1)
                }
            }
            .onMove(perform: moveSections)
        }
    }
    
    // MARK: - Actions
    
    private func addSection(_ section: JournalSection) {
        var newSection = section
        newSection.order = sections.count
        sections.append(newSection)
    }
    
    private func updateSection(_ updatedSection: JournalSection) {
        guard let index = sections.firstIndex(where: { $0.id == updatedSection.id }) else { return }
        sections[index] = updatedSection
    }
    
    private func deleteSection(_ section: JournalSection) {
        sections.removeAll { $0.id == section.id }
        // Reorder remaining sections
        for (index, _) in sections.enumerated() {
            sections[index].order = index
        }
    }
    
    private func moveSection(_ section: JournalSection, direction: Int) {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < sections.count else { return }
        
        sections.swapAt(index, newIndex)
        sections[index].order = index
        sections[newIndex].order = newIndex
    }
    
    private func moveSections(from source: IndexSet, to destination: Int) {
        sections.move(fromOffsets: source, toOffset: destination)
        // Reorder all sections
        for (index, _) in sections.enumerated() {
            sections[index].order = index
        }
    }
}

// MARK: - Section Row

struct SectionRow: View {
    let section: JournalSection
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
            
            // Icon
            Image(systemName: section.type.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            // Section info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(section.title)
                        .font(.system(size: 14, weight: .medium))
                    
                    if section.isCustom {
                        Text("CUSTOM")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                }
                
                Text(section.type.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Section Edit Sheet

struct SectionEditSheet: View {
    let section: JournalSection?
    let onSave: (JournalSection) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sectionType: JournalSectionType
    @State private var title: String
    @State private var isCustom: Bool
    
    init(section: JournalSection?, onSave: @escaping (JournalSection) -> Void) {
        self.section = section
        self.onSave = onSave
        
        _sectionType = State(initialValue: section?.type ?? .daySummary)
        _title = State(initialValue: section?.title ?? "")
        _isCustom = State(initialValue: section?.isCustom ?? false)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(section == nil ? "Add Section" : "Edit Section")
                .font(.system(size: 18, weight: .semibold))
            
            // Section type picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Section Type")
                    .font(.system(size: 13, weight: .medium))
                
                Picker("Section Type", selection: $sectionType) {
                    ForEach(JournalSectionType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: sectionType) { _, newValue in
                    if title.isEmpty || title == section?.type.displayName {
                        title = newValue.displayName
                    }
                }
            }
            
            // Title field
            VStack(alignment: .leading, spacing: 8) {
                Text("Section Title")
                    .font(.system(size: 13, weight: .medium))
                
                TextField("Enter title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Custom section toggle
            Toggle("Custom Section", isOn: $isCustom)
                .font(.system(size: 13))
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(section == nil ? "Add" : "Save") {
                    saveSection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 350)
    }
    
    private func saveSection() {
        let newSection = JournalSection(
            id: section?.id ?? UUID(),
            type: sectionType,
            title: title,
            content: section?.content ?? "",
            order: section?.order ?? 0,
            isCustom: isCustom
        )
        
        onSave(newSection)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sections: [JournalSection] = [
        JournalSection(type: .daySummary, title: "Day Summary", content: "", order: 0),
        JournalSection(type: .unfinishedTasks, title: "Unfinished Tasks", content: "", order: 1),
        JournalSection(type: .summaryPoints, title: "Summary Points", content: "", order: 2)
    ]
    
    return JournalSectionEditor(sections: $sections)
}

