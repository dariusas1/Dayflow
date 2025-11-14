//
//  RetentionManager.swift
//  Dayflow
//
//  Created for Story 4.2: Recording Chunk Management
//  Purpose: Automatic cleanup manager for recording chunks with configurable retention policies
//

import Foundation

/// Retention policy configuration for automatic chunk cleanup
struct RetentionPolicy: Codable, Sendable {
    /// Whether automatic cleanup is enabled
    var enabled: Bool = true

    /// Number of days to retain chunks before deletion (1-365)
    var retentionDays: Int = 3

    /// Maximum storage limit in GB (1-1000)
    var maxStorageGB: Int = 10

    /// How often to run cleanup in hours (1-24)
    var cleanupIntervalHours: Int = 1

    /// Default retention policy
    static let `default` = RetentionPolicy()

    /// Validate policy settings
    /// - Returns: Array of validation errors, empty if valid
    func validate() -> [String] {
        var errors: [String] = []

        if retentionDays < 1 || retentionDays > 365 {
            errors.append("Retention days must be between 1 and 365 (got \(retentionDays))")
        }

        if maxStorageGB < 1 || maxStorageGB > 1000 {
            errors.append("Maximum storage must be between 1 and 1000 GB (got \(maxStorageGB))")
        }

        if cleanupIntervalHours < 1 || cleanupIntervalHours > 24 {
            errors.append("Cleanup interval must be between 1 and 24 hours (got \(cleanupIntervalHours))")
        }

        return errors
    }

    /// Check if policy is valid
    var isValid: Bool {
        validate().isEmpty
    }
}

/// Manager for automatic cleanup of old recording chunks
@MainActor
final class RetentionManager {
    static let shared = RetentionManager()

    private var policy: RetentionPolicy
    private var cleanupTimer: Timer?
    private let storageManager: StorageManaging

    /// Initialize with default storage manager
    private init() {
        self.storageManager = StorageManager.shared
        self.policy = Self.loadPolicy()

        // Validate policy on initialization
        let errors = policy.validate()
        if !errors.isEmpty {
            print("⚠️ RetentionPolicy validation errors:")
            errors.forEach { print("  - \($0)") }
            print("  Using default policy instead")
            self.policy = .default
        }
    }

    /// Initialize with custom storage manager (for testing)
    init(storageManager: StorageManaging, policy: RetentionPolicy? = nil) {
        self.storageManager = storageManager
        self.policy = policy ?? Self.loadPolicy()
    }

    // MARK: - Policy Management

    /// Load retention policy from UserDefaults
    private static func loadPolicy() -> RetentionPolicy {
        guard let data = UserDefaults.standard.data(forKey: "retentionPolicy"),
              let policy = try? JSONDecoder().decode(RetentionPolicy.self, from: data) else {
            return .default
        }
        return policy
    }

    /// Save retention policy to UserDefaults
    private func savePolicy() {
        guard let data = try? JSONEncoder().encode(policy) else {
            print("❌ Failed to encode retention policy")
            return
        }
        UserDefaults.standard.set(data, forKey: "retentionPolicy")
    }

    /// Update retention policy and restart timer if needed
    /// - Parameter newPolicy: New retention policy to apply
    /// - Throws: Error if policy validation fails
    func updatePolicy(_ newPolicy: RetentionPolicy) throws {
        let errors = newPolicy.validate()
        guard errors.isEmpty else {
            throw NSError(
                domain: "RetentionManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Policy validation failed: \(errors.joined(separator: ", "))"]
            )
        }

        let intervalChanged = policy.cleanupIntervalHours != newPolicy.cleanupIntervalHours

        policy = newPolicy
        savePolicy()

        // Restart timer if interval changed
        if intervalChanged && policy.enabled {
            stopAutomaticCleanup()
            startAutomaticCleanup()
        }
    }

    /// Get current retention policy
    func getPolicy() -> RetentionPolicy {
        policy
    }

    // MARK: - Automatic Cleanup

    /// Start automatic cleanup timer
    func startAutomaticCleanup() {
        guard policy.enabled else {
            print("ℹ️ Automatic cleanup is disabled")
            return
        }

        // Stop existing timer if running
        stopAutomaticCleanup()

        let interval = TimeInterval(policy.cleanupIntervalHours * 3600)

        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanup()
            }
        }

        // Ensure timer runs on common run loop modes (so it fires during UI interactions)
        if let timer = cleanupTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("✅ Automatic cleanup started (interval: \(policy.cleanupIntervalHours)h, retention: \(policy.retentionDays) days)")
    }

    /// Stop automatic cleanup timer
    func stopAutomaticCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        print("ℹ️ Automatic cleanup stopped")
    }

    /// Perform cleanup operation
    /// - Returns: Statistics about the cleanup operation
    @discardableResult
    func performCleanup() async -> CleanupStats? {
        guard policy.enabled else {
            print("ℹ️ Cleanup skipped (policy disabled)")
            return nil
        }

        let start = Date()

        do {
            let stats = try await storageManager.cleanupOldChunks(retentionDays: policy.retentionDays)
            let duration = Date().timeIntervalSince(start)

            // Log cleanup results
            logCleanupResults(stats: stats, duration: duration)

            return stats
        } catch {
            print("❌ Cleanup failed: \(error)")
            return nil
        }
    }

    /// Perform cleanup immediately (manual trigger)
    /// - Returns: Statistics about the cleanup operation
    @discardableResult
    func performManualCleanup() async -> CleanupStats? {
        print("🔄 Manual cleanup triggered")
        return await performCleanup()
    }

    // MARK: - Storage Management

    /// Check current storage usage
    /// - Returns: Current storage usage information
    func checkStorageUsage() async -> StorageUsage? {
        do {
            let usage = try await storageManager.calculateStorageUsage()
            return usage
        } catch {
            print("❌ Failed to calculate storage usage: \(error)")
            return nil
        }
    }

    /// Check if storage is approaching quota (> 90%)
    /// - Returns: True if storage usage exceeds 90% of configured limit
    func isApproachingQuota() async -> Bool {
        guard let usage = await checkStorageUsage() else {
            return false
        }

        let quotaBytes = Int64(policy.maxStorageGB) * 1024 * 1024 * 1024
        let usagePercentage = Double(usage.totalBytes) / Double(quotaBytes)

        return usagePercentage > 0.9
    }

    /// Get storage usage percentage
    /// - Returns: Percentage of quota used (0.0 to 1.0+)
    func getStorageUsagePercentage() async -> Double? {
        guard let usage = await checkStorageUsage() else {
            return nil
        }

        let quotaBytes = Int64(policy.maxStorageGB) * 1024 * 1024 * 1024
        return Double(usage.totalBytes) / Double(quotaBytes)
    }

    // MARK: - Logging

    /// Log cleanup results in a formatted manner
    private func logCleanupResults(stats: CleanupStats, duration: TimeInterval) {
        if stats.chunksFound == 0 {
            print("✅ Cleanup completed: No old chunks found (duration: \(String(format: "%.2f", duration))s)")
            return
        }

        let bytesFreedMB = Double(stats.bytesFreed) / (1024 * 1024)

        print("""
        ✅ Cleanup Summary:
           - Chunks found: \(stats.chunksFound)
           - Files deleted: \(stats.filesDeleted)
           - Records deleted: \(stats.recordsDeleted)
           - Space freed: \(String(format: "%.2f", bytesFreedMB)) MB
           - Duration: \(String(format: "%.2f", duration))s
        """)
    }
}
