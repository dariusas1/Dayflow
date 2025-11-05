//
//  JournalSupportingViews.swift
//  Dayflow
//
//  Supporting views for Daily Journal generation and display
//

import SwiftUI

// MARK: - Journal Generation Supporting Views

struct GenerationProgressCard: View {
    @ObservedObject var generator: DailyJournalGenerator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Generating journal...")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
            }
            
            Text(generator.progressMessage)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))
            
            ProgressView(value: generator.currentProgress)
                .tint(Color(red: 0.25, green: 0.17, blue: 0))
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ErrorCard: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                
                Text("Generation Failed")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
            }
            
            Text(error.localizedDescription)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.6))
            
            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("Retry")
                        .font(.custom("Nunito", size: 13))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GeneratedJournalContent: View {
    let journal: DailyJournal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Journal content
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Day")
                    .font(.custom("InstrumentSerif-Regular", size: 22))
                    .foregroundColor(.black.opacity(0.9))
                
                Text(journal.content)
                    .font(.custom("Nunito", size: 14))
                    .foregroundColor(.black.opacity(0.7))
                    .lineSpacing(4)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            
            // Highlights
            if !journal.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Moments")
                        .font(.custom("Nunito", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.8))
                    
                    ForEach(journal.highlights.prefix(5), id: \.id) { highlight in
                        HighlightRow(highlight: highlight)
                    }
                }
            }
            
            // Sentiment
            SentimentCard(sentiment: journal.sentiment)
        }
    }
}

struct HighlightRow: View {
    let highlight: JournalHighlight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(significanceColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.title)
                    .font(.custom("Nunito", size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.8))
                
                Text(highlight.content)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private var significanceColor: Color {
        if highlight.significance > 0.75 {
            return .green
        } else if highlight.significance > 0.5 {
            return .orange
        } else {
            return .gray
        }
    }
}

struct SentimentCard: View {
    let sentiment: SentimentAnalysis
    
    var body: some View {
        HStack(spacing: 16) {
            Text(sentimentEmoji)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Mood")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.6))
                
                Text(sentimentText)
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(sentimentColor)
            }
            
            Spacer()
        }
        .padding(12)
        .background(sentimentColor.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(sentimentColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var sentimentEmoji: String {
        switch sentiment.overallSentiment.sentimentType {
        case .positive: return "😊"
        case .neutral: return "😐"
        case .negative: return "😔"
        }
    }
    
    private var sentimentText: String {
        sentiment.overallSentiment.emotion.capitalized
    }
    
    private var sentimentColor: Color {
        switch sentiment.overallSentiment.sentimentType {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}

struct EmptyJournalState: View {
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Enhanced icon with background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Color(red: 0.25, green: 0.17, blue: 0).opacity(0.1), location: 0.00),
                                Gradient.Stop(color: Color.white.opacity(0), location: 1.00),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0).opacity(0.5))
            }
            
            VStack(spacing: 12) {
                Text("No Journal for This Date")
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(.black.opacity(0.9))
                
                Text("Journals are automatically generated at midnight each day.\n\nYour daily reflections will appear here once the system processes your activities.")
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
            }
            
            // Info indicator
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(red: 0.25, green: 0.17, blue: 0))
                
                Text("Check back tomorrow or select a past date")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.5))
            }
            .padding(.horizontal, 16)
                .padding(.vertical, 10)
            .background(Color(red: 0.25, green: 0.17, blue: 0).opacity(0.05))
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct TemplateSelector: View {
    @Binding var selectedTemplate: JournalTemplate
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Template")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(.black)
            
            ForEach([JournalTemplate.concise, .balanced, .detailed, .reflective, .gratitude], id: \.self) { template in
                Button(action: {
                    selectedTemplate = template
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(templateName(template))
                                .font(.custom("Nunito", size: 16))
                                .fontWeight(.medium)
                                .foregroundColor(.black.opacity(0.9))
                            
                            Text(templateDescription(template))
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if selectedTemplate == template {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(16)
                    .background(selectedTemplate == template ? Color.green.opacity(0.05) : Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedTemplate == template ? Color.green.opacity(0.3) : Color.black.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 500)
    }
    
    private func templateName(_ template: JournalTemplate) -> String {
        return template.displayName
    }
    
    private func templateDescription(_ template: JournalTemplate) -> String {
        switch template {
        case .concise: return "Quick summary of the day"
        case .balanced: return "Balanced overview with key moments"
        case .detailed: return "Comprehensive day analysis"
        case .reflective: return "Thoughtful reflection and insights"
        case .gratitude: return "Focus on positive moments"
        case .achievement: return "Highlight achievements"
        case .growth: return "Focus on growth and learning"
        case .comprehensive: return "Complete daily review"
        case .custom: return "Custom template"
        }
    }
}

