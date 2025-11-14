//
//  TimelineCache.swift
//  Dayflow
//
//  Created for Story 4.1: Timeline Data Persistence
//  Purpose: In-memory caching layer for timeline cards to optimize performance
//

import Foundation

/// Thread-safe caching layer for timeline cards
/// Provides in-memory caching with automatic expiration
final class TimelineCache: @unchecked Sendable {
    // MARK: - Cache Entry

    private struct CacheEntry {
        let cards: [TimelineCard]
        let timestamp: Date
        let expiresAt: Date

        var isExpired: Bool {
            Date() > expiresAt
        }
    }

    // MARK: - Properties

    /// Cache storage: day string -> cache entry
    private var cache: [String: CacheEntry] = [:]

    /// Cache expiration duration (default: 60 seconds)
    private let cacheDuration: TimeInterval

    /// Maximum cache size (number of days to cache)
    private let maxCacheSize: Int

    /// Cache statistics for monitoring
    private var hits: Int = 0
    private var misses: Int = 0

    /// Serial queue for thread-safe cache access
    private let queue = DispatchQueue(label: "com.dayflow.timelineCache", qos: .userInitiated)

    // MARK: - Initialization

    init(cacheDuration: TimeInterval = 60.0, maxCacheSize: Int = 30) {
        self.cacheDuration = cacheDuration
        self.maxCacheSize = maxCacheSize
    }

    // MARK: - Public Methods

    /// Retrieves cached timeline cards for a specific day
    /// - Parameter day: Day string in YYYY-MM-DD format
    /// - Returns: Cached cards if available and not expired, nil otherwise
    func getCachedCards(forDay day: String) -> [TimelineCard]? {
        return queue.sync {
            // Clean up expired entries periodically
            cleanupExpiredEntries()

            guard let entry = cache[day] else {
                misses += 1
                return nil
            }

            if entry.isExpired {
                cache.removeValue(forKey: day)
                misses += 1
                return nil
            }

            hits += 1
            return entry.cards
        }
    }

    /// Caches timeline cards for a specific day
    /// - Parameters:
    ///   - cards: Timeline cards to cache
    ///   - day: Day string in YYYY-MM-DD format
    func cacheCards(_ cards: [TimelineCard], forDay day: String) {
        queue.sync {
            let now = Date()
            let entry = CacheEntry(
                cards: cards,
                timestamp: now,
                expiresAt: now.addingTimeInterval(cacheDuration)
            )

            cache[day] = entry

            // Enforce cache size limit
            if cache.count > maxCacheSize {
                evictOldestEntry()
            }
        }
    }

    /// Invalidates cache for a specific day
    /// - Parameter day: Day string in YYYY-MM-DD format
    func invalidate(forDay day: String) {
        queue.sync {
            cache.removeValue(forKey: day)
        }
    }

    /// Invalidates all cached entries
    func invalidateAll() {
        queue.sync {
            cache.removeAll()
        }
    }

    /// Returns cache statistics for monitoring
    func getStatistics() -> CacheStatistics {
        return queue.sync {
            let totalRequests = hits + misses
            let hitRate = totalRequests > 0 ? Double(hits) / Double(totalRequests) : 0.0

            return CacheStatistics(
                totalEntries: cache.count,
                hits: hits,
                misses: misses,
                hitRate: hitRate,
                oldestEntry: getOldestEntryDate(),
                newestEntry: getNewestEntryDate()
            )
        }
    }

    /// Resets cache statistics
    func resetStatistics() {
        queue.sync {
            hits = 0
            misses = 0
        }
    }

    // MARK: - Private Methods

    /// Removes expired cache entries (must be called within queue.sync)
    private func cleanupExpiredEntries() {
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
    }

    /// Evicts the oldest cache entry to maintain size limit (must be called within queue.sync)
    private func evictOldestEntry() {
        guard let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key else {
            return
        }
        cache.removeValue(forKey: oldestKey)
    }

    /// Returns the date of the oldest cache entry (must be called within queue.sync)
    private func getOldestEntryDate() -> Date? {
        cache.values.min(by: { $0.timestamp < $1.timestamp })?.timestamp
    }

    /// Returns the date of the newest cache entry (must be called within queue.sync)
    private func getNewestEntryDate() -> Date? {
        cache.values.max(by: { $0.timestamp < $1.timestamp })?.timestamp
    }
}

// MARK: - Cache Statistics

/// Statistics about cache performance
struct CacheStatistics: Sendable {
    let totalEntries: Int
    let hits: Int
    let misses: Int
    let hitRate: Double
    let oldestEntry: Date?
    let newestEntry: Date?

    var formattedHitRate: String {
        String(format: "%.1f%%", hitRate * 100)
    }
}
