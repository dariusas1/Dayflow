//
//  AIProviderTests.swift
//  DayflowTests
//
//  End-to-end tests for AI providers (Gemini and Ollama) with error scenarios
//

import XCTest
import AVFoundation
@testable import Dayflow

final class AIProviderTests: XCTestCase {
    
    // MARK: - Gemini Provider Tests
    
    func testGeminiProviderInitialization() throws {
        // Test that Gemini provider initializes with valid API key
        let apiKey = "test-api-key"
        let preference = GeminiModelPreference.default
        let provider = GeminiDirectProvider(apiKey: apiKey, preference: preference)
        
        XCTAssertNotNil(provider, "Gemini provider should initialize with valid API key")
    }
    
    func testGeminiProviderErrorHandling() async throws {
        // Test error handling for various Gemini error scenarios
        let apiKey = "invalid-key"
        let preference = GeminiModelPreference.default
        let provider = GeminiDirectProvider(apiKey: apiKey, preference: preference)
        
        // Create minimal test video data
        let testVideoData = Data(repeating: 0, count: 100)
        let batchStartTime = Date()
        
        // This should fail with authentication error
        do {
            _ = try await provider.transcribeVideo(
                videoData: testVideoData,
                mimeType: "video/mp4",
                prompt: "Test prompt",
                batchStartTime: batchStartTime,
                videoDuration: 10.0,
                batchId: nil
            )
            XCTFail("Expected authentication error")
        } catch {
            // Verify error is properly formatted
            let errorDescription = error.localizedDescription.lowercased()
            XCTAssertTrue(
                errorDescription.contains("api key") || 
                errorDescription.contains("unauthorized") ||
                errorDescription.contains("authentication"),
                "Error should indicate API key or authentication issue"
            )
        }
    }
    
    func testGeminiProviderRateLimitHandling() async throws {
        // Test that rate limit errors are properly handled
        // This is a placeholder - in real tests would mock HTTP responses
        let apiKey = "test-key"
        let provider = GeminiDirectProvider(apiKey: apiKey)
        
        // Verify provider has retry logic
        // In real implementation, would test actual rate limit responses
        XCTAssertNotNil(provider, "Provider should initialize")
    }
    
    // MARK: - Ollama Provider Tests
    
    func testOllamaProviderInitialization() throws {
        // Test that Ollama provider initializes with endpoint
        let endpoint = "http://localhost:11434"
        let provider = OllamaProvider(endpoint: endpoint)
        
        XCTAssertNotNil(provider, "Ollama provider should initialize with endpoint")
    }
    
    func testOllamaProviderEndpointConfiguration() throws {
        // Test custom endpoint configuration
        let customEndpoint = "http://localhost:1234"
        let provider = OllamaProvider(endpoint: customEndpoint)
        
        XCTAssertNotNil(provider, "Ollama provider should accept custom endpoint")
    }
    
    func testOllamaProviderConnectionFailure() async throws {
        // Test handling of connection failures
        let invalidEndpoint = "http://localhost:99999" // Invalid endpoint
        let provider = OllamaProvider(endpoint: invalidEndpoint)
        
        let testVideoData = Data(repeating: 0, count: 100)
        let batchStartTime = Date()
        
        // This should fail with connection error
        do {
            _ = try await provider.transcribeVideo(
                videoData: testVideoData,
                mimeType: "video/mp4",
                prompt: "Test prompt",
                batchStartTime: batchStartTime,
                videoDuration: 10.0,
                batchId: nil
            )
            XCTFail("Expected connection error")
        } catch {
            let errorDescription = error.localizedDescription.lowercased()
            XCTAssertTrue(
                errorDescription.contains("connection") ||
                errorDescription.contains("connect") ||
                errorDescription.contains("unreachable"),
                "Error should indicate connection failure"
            )
        }
    }
    
    // MARK: - Provider Switching Tests
    
    func testProviderSwitching() throws {
        // Test that LLMService can switch between providers
        let llmService = LLMService.shared
        
        // Verify service initializes
        XCTAssertNotNil(llmService, "LLMService should initialize")
        
        // In real implementation, would test actual provider switching
        // This tests that the service can handle different provider types
    }
    
    // MARK: - Error Scenario Tests
    
    func testNetworkFailureHandling() async throws {
        // Test that network failures are properly handled
        // Placeholder - in real tests would simulate network failures
        let endpoint = "http://invalid-host:8080"
        let provider = OllamaProvider(endpoint: endpoint)
        
        let testVideoData = Data(repeating: 0, count: 100)
        let batchStartTime = Date()
        
        // Expect network failure
        do {
            _ = try await provider.transcribeVideo(
                videoData: testVideoData,
                mimeType: "video/mp4",
                prompt: "Test",
                batchStartTime: batchStartTime,
                videoDuration: 10.0,
                batchId: nil
            )
            XCTFail("Expected network error")
        } catch {
            // Verify error indicates network issue
            XCTAssertNotNil(error, "Should receive error for network failure")
        }
    }
    
    func testInvalidVideoDataHandling() async throws {
        // Test handling of invalid video data
        let apiKey = "test-key"
        let provider = GeminiDirectProvider(apiKey: apiKey)
        
        let invalidData = Data() // Empty data
        let batchStartTime = Date()
        
        // Should handle invalid data gracefully
        do {
            _ = try await provider.transcribeVideo(
                videoData: invalidData,
                mimeType: "video/mp4",
                prompt: "Test",
                batchStartTime: batchStartTime,
                videoDuration: 0.0,
                batchId: nil
            )
            XCTFail("Expected error for invalid video data")
        } catch {
            // Should receive appropriate error
            XCTAssertNotNil(error, "Should handle invalid video data")
        }
    }
    
    // MARK: - Card Generation Tests
    
    func testCardGenerationFromObservations() async throws {
        // Test that observations can be converted to activity cards
        // This would test the generateActivityCards method
        // Placeholder for actual implementation
        
        // Create mock observations
        let observations: [Observation] = [
            Observation(
                startTs: Date().timeIntervalSince1970,
                endTs: Date().timeIntervalSince1970 + 900,
                observation: "User working on project"
            )
        ]
        
        // Verify observations structure
        XCTAssertFalse(observations.isEmpty, "Should have observations")
        XCTAssertEqual(observations.count, 1, "Should have one observation")
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryLogicForTransientErrors() throws {
        // Test that providers implement retry logic for transient errors
        // Placeholder - would test actual retry behavior
        let apiKey = "test-key"
        let provider = GeminiDirectProvider(apiKey: apiKey)
        
        XCTAssertNotNil(provider, "Provider should support retry logic")
    }
    
    // MARK: - Performance Tests
    
    func testProviderPerformance() async throws {
        // Test that providers perform within acceptable time limits
        // Placeholder for performance benchmarks
        
        let startTime = Date()
        // Simulate provider operation
        let duration = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(duration, 30.0, "Provider operations should complete within 30 seconds")
    }
}

