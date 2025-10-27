//
//  JournalExportView.swift
//  FocusLock
//
//  Export interface for sharing journals in various formats
//

import SwiftUI
import UniformTypeIdentifiers

struct JournalExportView: View {
    let journal: DailyJournal
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: JournalExportFormat = .markdown
    @State private var includeHighlights = true
    @State private var includeSentiment = true
    @State private var includeDate = true
    @State private var showingShareSheet = false
    @State private var exportedContent = ""
    @State private var isExporting = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Format Selection
                    formatSelectionSection

                    // Export Options
                    exportOptionsSection

                    // Preview
                    previewSection

                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Export Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [exportedContent])
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Share Your Journal")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Export your reflection in your preferred format for personal records or sharing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Format Selection Section

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Format")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(JournalExportFormat.allCases, id: \.self) { format in
                    formatCard(format)
                }
            }
        }
    }

    private func formatCard(_ format: JournalExportFormat) -> some View {
        Button(action: { selectedFormat = format }) {
            VStack(spacing: 8) {
                Image(systemName: format.systemImage)
                    .font(.title2)
                    .foregroundColor(selectedFormat == format ? .white : format.color)

                Text(format.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedFormat == format ? .white : .primary)

                Text(format.description)
                    .font(.caption)
                    .foregroundColor(selectedFormat == format ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedFormat == format ? format.color : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedFormat == format ? format.color : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Export Options Section

    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Options")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                toggleOption(
                    title: "Include Date",
                    description: "Add journal date to the export",
                    isOn: $includeDate
                )

                toggleOption(
                    title: "Include Highlights",
                    description: "Add key moments and insights",
                    isOn: $includeHighlights
                )

                toggleOption(
                    title: "Include Sentiment Analysis",
                    description: "Add emotional insights and patterns",
                    isOn: $includeSentiment
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func toggleOption(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(.blue)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text(selectedFormat.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedFormat.color.opacity(0.1))
                    .foregroundColor(selectedFormat.color)
                    .cornerRadius(6)
            }

            ScrollView {
                Text(exportedContent.isEmpty ? generatePreview() : exportedContent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.02))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await performExport()
                }
            }) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? "Exporting..." : "Export Journal")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isExporting)

            if !exportedContent.isEmpty {
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func generatePreview() -> String {
        var preview = ""

        if includeDate {
            preview += "# \(journal.date.formatted(date: .long, time: .omitted))\n\n"
        }

        preview += journal.content.prefix(200) + "...\n\n"

        if includeHighlights && !journal.highlights.isEmpty {
            preview += "## Key Highlights\n"
            for highlight in journal.highlights.prefix(2) {
                preview += "- \(highlight.title): \(highlight.description)\n"
            }
            preview += "\n"
        }

        if includeSentiment, let sentiment = journal.sentimentAnalysis {
            preview += "## Sentiment: \(sentiment.overallSentiment.displayName)\n"
        }

        return preview
    }

    private func performExport() async {
        isExporting = true

        // Simulate export process
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let content = generateExportContent()
        exportedContent = content

        isExporting = false
    }

    private func generateExportContent() -> String {
        var content = ""

        switch selectedFormat {
        case .markdown:
            content = generateMarkdownContent()
        case .plainText:
            content = generatePlainTextContent()
        case .html:
            content = generateHTMLContent()
        case .pdf:
            content = generateMarkdownContent() // PDF would require additional implementation
        }

        return content
    }

    private func generateMarkdownContent() -> String {
        var content = ""

        if includeDate {
            content += "# \(journal.date.formatted(date: .long, time: .omitted))\n\n"
        }

        content += journal.content + "\n\n"

        if includeHighlights && !journal.highlights.isEmpty {
            content += "## Key Highlights\n\n"
            for highlight in journal.highlights {
                content += "### \(highlight.title)\n"
                content += "\(highlight.description)\n\n"
            }
        }

        if includeSentiment, let sentiment = journal.sentimentAnalysis {
            content += "## Emotional Insights\n\n"
            content += "**Overall Sentiment:** \(sentiment.overallSentiment.displayName)\n\n"

            if !sentiment.emotionScores.isEmpty {
                content += "**Top Emotions:**\n"
                for emotion in sentiment.emotionScores.prefix(3) {
                    content += "- \(emotion.emotion.displayName): \(Int(emotion.intensity * 100))%\n"
                }
                content += "\n"
            }
        }

        content += "\n---\n*Generated by FocusLock on \(Date().formatted(date: .abbreviated, time: .shortened))*"

        return content
    }

    private func generatePlainTextContent() -> String {
        var content = ""

        if includeDate {
            content += "\(journal.date.formatted(date: .long, time: .omitted))\n"
            content += String(repeating: "=", count: journal.date.formatted(date: .long, time: .omitted).count) + "\n\n"
        }

        content += journal.content + "\n\n"

        if includeHighlights && !journal.highlights.isEmpty {
            content += "KEY HIGHLIGHTS\n"
            content += String(repeating: "-", count: 15) + "\n\n"
            for highlight in journal.highlights {
                content += "\(highlight.title): \(highlight.description)\n\n"
            }
        }

        if includeSentiment, let sentiment = journal.sentimentAnalysis {
            content += "EMOTIONAL INSIGHTS\n"
            content += String(repeating: "-", count: 19) + "\n\n"
            content += "Overall Sentiment: \(sentiment.overallSentiment.displayName)\n\n"

            if !sentiment.emotionScores.isEmpty {
                content += "Top Emotions:\n"
                for emotion in sentiment.emotionScores.prefix(3) {
                    content += "- \(emotion.emotion.displayName): \(Int(emotion.intensity * 100))%\n"
                }
                content += "\n"
            }
        }

        return content
    }

    private func generateHTMLContent() -> String {
        var content = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Journal - \(journal.date.formatted(date: .abbreviated, time: .omitted))</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
                h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
                h2 { color: #666; margin-top: 30px; }
                .highlight { background: #FFF3CD; padding: 15px; border-left: 4px solid #FFC107; margin: 10px 0; }
                .sentiment { background: #D1ECF1; padding: 15px; border-left: 4px solid #17A2B8; margin: 10px 0; }
                .date { color: #666; font-size: 14px; margin-bottom: 20px; }
            </style>
        </head>
        <body>
        """

        if includeDate {
            content += """
            <h1>\(journal.date.formatted(date: .long, time: .omitted))</h1>
            <p class="date">Generated on \(Date().formatted(date: .abbreviated, time: .shortened))</p>
            """
        }

        content += "<div class=\"content\">\(journal.content.replacingOccurrences(of: "\n", with: "<br>"))</div>\n"

        if includeHighlights && !journal.highlights.isEmpty {
            content += "<h2>Key Highlights</h2>\n"
            for highlight in journal.highlights {
                content += """
                <div class="highlight">
                    <strong>\(highlight.title)</strong><br>
                    \(highlight.description)
                </div>
                """
            }
        }

        if includeSentiment, let sentiment = journal.sentimentAnalysis {
            content += """
            <h2>Emotional Insights</h2>
            <div class="sentiment">
                <strong>Overall Sentiment:</strong> \(sentiment.overallSentiment.displayName)<br>
            """

            if !sentiment.emotionScores.isEmpty {
                content += "<strong>Top Emotions:</strong><br>"
                for emotion in sentiment.emotionScores.prefix(3) {
                    content += "\(emotion.emotion.displayName): \(Int(emotion.intensity * 100))%<br>"
                }
            }

            content += "</div>\n"
        }

        content += """
        </body>
        </html>
        """

        return content
    }
}

// MARK: - Export Format Extensions

extension JournalExportFormat {
    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        case .html: return "HTML"
        case .pdf: return "PDF"
        }
    }

    var systemImage: String {
        switch self {
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .html: return "globe"
        case .pdf: return "doc.richtext"
        }
    }

    var color: Color {
        switch self {
        case .markdown: return .blue
        case .plainText: return .gray
        case .html: return .orange
        case .pdf: return .red
        }
    }

    var description: String {
        switch self {
        case .markdown: return "Formatted text with structure"
        case .plainText: return "Simple text format"
        case .html: return "Web page format"
        case .pdf: return "Document format"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct JournalExportView_Previews: PreviewProvider {
    static var previews: some View {
        JournalExportView(journal: DailyJournal.sample)
    }
}

// MARK: - Sample Data Extension

extension DailyJournal {
    static let sample = DailyJournal(
        id: UUID(),
        date: Date(),
        content: "Today was a productive day filled with meaningful accomplishments and moments of reflection. I successfully completed my main project milestone and took time to appreciate the small victories along the way.",
        template: .comprehensive,
        highlights: [
            JournalHighlight(
                id: UUID(),
                category: .achievement,
                title: "Project Milestone",
                description: "Completed the main feature implementation",
                significance: 0.9,
                relatedActivities: [],
                timestamp: Date()
            )
        ],
        sentimentAnalysis: SentimentAnalysis(
            overallSentiment: .positive,
            sentimentScore: 0.8,
            emotionScores: [
                EmotionScore(emotion: .accomplished, intensity: 0.9, confidence: 0.8)
            ],
            confidence: 0.85,
            keywords: ["productive", "accomplished", "milestone"]
        ),
        userPreferences: JournalPreferences(),
        createdAt: Date(),
        updatedAt: Date()
    )
}