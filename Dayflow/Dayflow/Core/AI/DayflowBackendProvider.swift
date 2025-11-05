//
//  DayflowBackendProvider.swift
//  Dayflow
//

import Foundation
import os.log

final class DayflowBackendProvider: LLMProvider {
    private let token: String
    private let endpoint: String
    private let logger = Logger(subsystem: "FocusLock", category: "DayflowBackendProvider")
    
    init(token: String, endpoint: String = "https://api.dayflow.app") {
        self.token = token
        self.endpoint = endpoint
    }
    
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, batchStartTime: Date, videoDuration: TimeInterval, batchId: Int64?) async throws -> (observations: [Observation], log: LLMCall) {
        let callStart = Date()
        
        guard let url = URL(string: "\(endpoint)/v1/transcribe") else {
            throw DayflowBackendError.invalidEndpoint
        }
        
        // Encode video data as base64
        let videoBase64 = videoData.base64EncodedString()
        
        // Prepare request body
        struct TranscribeRequest: Codable {
            let video: String  // Base64 encoded video
            let mimeType: String
            let prompt: String
            let batchStartTime: String  // ISO8601
            let videoDuration: TimeInterval
            let batchId: Int64?
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let requestBody = TranscribeRequest(
            video: videoBase64,
            mimeType: mimeType,
            prompt: prompt,
            batchStartTime: dateFormatter.string(from: batchStartTime),
            videoDuration: videoDuration,
            batchId: batchId
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300.0  // 5-minute timeout for video processing
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        logger.info("Sending video transcription request to Dayflow backend")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DayflowBackendError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Backend API error: \(httpResponse.statusCode) - \(errorMessage)")
                throw DayflowBackendError.apiError(httpResponse.statusCode, errorMessage)
            }
            
            // Parse response
            struct TranscribeResponse: Codable {
                let observations: [ObservationResponse]
            }
            
            struct ObservationResponse: Codable {
                let startTs: Int
                let endTs: Int
                let observation: String
                let metadata: String?
            }
            
            let responseObj = try JSONDecoder().decode(TranscribeResponse.self, from: data)
            
            // Convert to Observation format
            let observations = responseObj.observations.map { obs in
                Observation(
                    id: nil,
                    batchId: batchId ?? 0,
                    startTs: obs.startTs,
                    endTs: obs.endTs,
                    observation: obs.observation,
                    metadata: obs.metadata,
                    llmModel: "dayflow-backend",
                    createdAt: Date()
                )
            }
            
            let totalTime = Date().timeIntervalSince(callStart)
            let log = LLMCall(
                timestamp: callStart,
                latency: totalTime,
                input: "Video transcription: \(videoDuration)s video",
                output: "Generated \(observations.count) observations in \(String(format: "%.2f", totalTime))s"
            )
            
            logger.info("Successfully transcribed video: \(observations.count) observations")
            
            return (observations, log)
        } catch {
            logger.error("Failed to transcribe video: \(error.localizedDescription)")
            throw error
        }
    }
    
    func generateActivityCards(observations: [Observation], context: ActivityGenerationContext, batchId: Int64?) async throws -> (cards: [ActivityCardData], log: LLMCall) {
        let callStart = Date()
        
        guard let url = URL(string: "\(endpoint)/v1/generate-cards") else {
            throw DayflowBackendError.invalidEndpoint
        }
        
        // Prepare request body
        struct GenerateCardsRequest: Codable {
            let observations: [ObservationRequest]
            let existingCards: [ActivityCardDataRequest]?
            let batchStartTime: String
            let categories: [CategoryDescriptorRequest]
        }
        
        struct ObservationRequest: Codable {
            let startTs: Int
            let endTs: Int
            let observation: String
        }
        
        struct ActivityCardDataRequest: Codable {
            let startTime: String
            let endTime: String
            let category: String
            let subcategory: String
            let title: String
            let summary: String
        }
        
        struct CategoryDescriptorRequest: Codable {
            let name: String
            let description: String?
        }
        
        let sortedObservations = context.batchObservations.sorted { $0.startTs < $1.startTs }
        
        let observationRequests = sortedObservations.map { obs in
            ObservationRequest(
                startTs: obs.startTs,
                endTs: obs.endTs,
                observation: obs.observation
            )
        }
        
        let existingCardRequests = context.existingCards.map { card in
            ActivityCardDataRequest(
                startTime: card.startTime,
                endTime: card.endTime,
                category: card.category,
                subcategory: card.subcategory,
                title: card.title,
                summary: card.summary
            )
        }
        
        let categoryDescriptors = context.categories.map { cat in
            CategoryDescriptorRequest(
                name: cat.name,
                description: cat.description
            )
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let requestBody = GenerateCardsRequest(
            observations: observationRequests,
            existingCards: existingCardRequests.isEmpty ? nil : existingCardRequests,
            batchStartTime: dateFormatter.string(from: context.currentTime),
            categories: categoryDescriptors
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120.0  // 2-minute timeout
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        logger.info("Sending activity card generation request to Dayflow backend")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DayflowBackendError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Backend API error: \(httpResponse.statusCode) - \(errorMessage)")
                throw DayflowBackendError.apiError(httpResponse.statusCode, errorMessage)
            }
            
            // Parse response
            struct GenerateCardsResponse: Codable {
                let cards: [ActivityCardResponse]
            }
            
            struct ActivityCardResponse: Codable {
                let startTime: String
                let endTime: String
                let category: String
                let subcategory: String
                let title: String
                let summary: String
                let detailedSummary: String
                let distractions: [DistractionResponse]?
                let appSites: AppSitesResponse?
            }
            
            struct DistractionResponse: Codable {
                let startTime: String
                let endTime: String
                let title: String
                let summary: String
            }
            
            struct AppSitesResponse: Codable {
                let primary: String?
                let secondary: String?
            }
            
            let responseObj = try JSONDecoder().decode(GenerateCardsResponse.self, from: data)
            
            // Convert to ActivityCardData format
            let cards = responseObj.cards.map { card in
                ActivityCardData(
                    startTime: card.startTime,
                    endTime: card.endTime,
                    category: card.category,
                    subcategory: card.subcategory,
                    title: card.title,
                    summary: card.summary,
                    detailedSummary: card.detailedSummary,
                    distractions: card.distractions?.map { d in
                        Distraction(
                            startTime: d.startTime,
                            endTime: d.endTime,
                            title: d.title,
                            summary: d.summary
                        )
                    },
                    appSites: card.appSites.map { sites in AppSites(primary: sites.primary, secondary: sites.secondary) }
                )
            }
            
            let totalTime = Date().timeIntervalSince(callStart)
            let log = LLMCall(
                timestamp: callStart,
                latency: totalTime,
                input: "Generate activity cards: \(observations.count) observations",
                output: "Generated \(cards.count) activity cards in \(String(format: "%.2f", totalTime))s"
            )
            
            logger.info("Successfully generated activity cards: \(cards.count) cards")
            
            return (cards, log)
        } catch {
            logger.error("Failed to generate activity cards: \(error.localizedDescription)")
            throw error
        }
    }
}

enum DayflowBackendError: Error, LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case apiError(Int, String)
    case encodingError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid Dayflow backend endpoint"
        case .invalidResponse:
            return "Invalid response from Dayflow backend"
        case .apiError(let code, let message):
            return "Dayflow backend API error (\(code)): \(message)"
        case .encodingError:
            return "Failed to encode request data"
        case .decodingError:
            return "Failed to decode response data"
        }
    }
}
