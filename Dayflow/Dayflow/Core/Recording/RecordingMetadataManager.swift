//
//  RecordingMetadataManager.swift
//  Dayflow
//
//  Simple persistence manager for recording metadata including display configuration.
//  Part of Epic 2 - Story 2.1: Multi-Display Screen Capture
//
//  NOTE: This is a transitional implementation using JSON file storage.
//  Will be migrated to DatabaseManager with proper serial queue pattern when Epic 1 is completed.
//

import Foundation

/// Manager for persisting recording metadata including display configuration
@MainActor
final class RecordingMetadataManager {
    static let shared = RecordingMetadataManager()

    private let fileManager = FileManager.default
    private let metadataDirectoryName = "RecordingMetadata"

    private init() {
        ensureMetadataDirectoryExists()
    }

    /// Get the metadata directory URL
    private var metadataDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dayflowDir = appSupport.appendingPathComponent("Dayflow", isDirectory: true)
        return dayflowDir.appendingPathComponent(metadataDirectoryName, isDirectory: true)
    }

    /// Ensure the metadata directory exists
    private func ensureMetadataDirectoryExists() {
        let directory = metadataDirectory
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Save display configuration for a recording session
    /// - Parameters:
    ///   - configuration: Display configuration to save
    ///   - sessionID: Unique identifier for the recording session (uses timestamp if not provided)
    func saveDisplayConfiguration(_ configuration: DisplayConfiguration, sessionID: String? = nil) {
        let id = sessionID ?? ISO8601DateFormatter().string(from: Date())
        let filename = "display_config_\(id).json"
        let fileURL = metadataDirectory.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(configuration)
            try data.write(to: fileURL, options: .atomic)

            print("[RecordingMetadata] Saved display configuration: \(filename)")
            print("  - Display count: \(configuration.displayCount)")
            print("  - Primary display: \(configuration.primaryDisplayID)")
            print("  - Captured at: \(configuration.capturedAt)")
        } catch {
            print("[RecordingMetadata] Failed to save display configuration: \(error)")
        }
    }

    /// Load display configuration for a recording session
    /// - Parameter sessionID: Session identifier
    /// - Returns: Display configuration if found
    func loadDisplayConfiguration(sessionID: String) -> DisplayConfiguration? {
        let filename = "display_config_\(sessionID).json"
        let fileURL = metadataDirectory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("[RecordingMetadata] No configuration found for session: \(sessionID)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let configuration = try decoder.decode(DisplayConfiguration.self, from: data)
            print("[RecordingMetadata] Loaded display configuration: \(filename)")
            return configuration
        } catch {
            print("[RecordingMetadata] Failed to load display configuration: \(error)")
            return nil
        }
    }

    /// Get all saved display configurations
    /// - Returns: Array of all saved configurations with their session IDs
    func getAllDisplayConfigurations() -> [(sessionID: String, configuration: DisplayConfiguration)] {
        guard let files = try? fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        let configFiles = files.filter { $0.lastPathComponent.hasPrefix("display_config_") }

        return configFiles.compactMap { fileURL in
            let filename = fileURL.lastPathComponent
            guard let sessionID = extractSessionID(from: filename) else { return nil }
            guard let config = loadDisplayConfiguration(sessionID: sessionID) else { return nil }
            return (sessionID, config)
        }
    }

    /// Extract session ID from filename
    private func extractSessionID(from filename: String) -> String? {
        let prefix = "display_config_"
        let suffix = ".json"

        guard filename.hasPrefix(prefix), filename.hasSuffix(suffix) else {
            return nil
        }

        let start = filename.index(filename.startIndex, offsetBy: prefix.count)
        let end = filename.index(filename.endIndex, offsetBy: -suffix.count)

        return String(filename[start..<end])
    }

    /// Clear old metadata files (older than specified days)
    /// - Parameter days: Number of days to retain
    func cleanupOldMetadata(olderThanDays days: Int = 30) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))

        let configs = getAllDisplayConfigurations()
        for (sessionID, configuration) in configs {
            if configuration.capturedAt < cutoffDate {
                deleteDisplayConfiguration(sessionID: sessionID)
            }
        }
    }

    /// Delete display configuration for a session
    /// - Parameter sessionID: Session identifier
    func deleteDisplayConfiguration(sessionID: String) {
        let filename = "display_config_\(sessionID).json"
        let fileURL = metadataDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
            print("[RecordingMetadata] Deleted configuration: \(filename)")
        }
    }
}
