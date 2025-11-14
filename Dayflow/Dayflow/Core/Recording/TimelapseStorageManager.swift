import Foundation

final class TimelapseStorageManager {
    static let shared = TimelapseStorageManager()

    private let fileMgr = FileManager.default
    private let root: URL
    private let queue = DispatchQueue(label: "com.dayflow.timelapse.purge", qos: .utility)

    private init() {
        let appSupport = fileMgr.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let path = appSupport.appendingPathComponent("Dayflow/timelapses", isDirectory: true)
        root = path
        try? fileMgr.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var rootURL: URL { root }

    func currentUsageBytes() -> Int64 {
        (try? fileMgr.allocatedSizeOfDirectory(at: root)) ?? 0
    }

    func updateLimit(bytes: Int64) {
        let previous = StoragePreferences.timelapsesLimitBytes
        StoragePreferences.timelapsesLimitBytes = bytes
        if bytes < previous {
            purgeIfNeeded(limit: bytes)
        }
    }

    func purgeIfNeeded(limit: Int64? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            let limitBytes = limit ?? StoragePreferences.timelapsesLimitBytes
            guard limitBytes < Int64.max else { return }

            do {
                var usage = (try? self.fileMgr.allocatedSizeOfDirectory(at: self.root)) ?? 0
                if usage <= limitBytes { return }

                let entries = try self.fileMgr.contentsOfDirectory(
                    at: self.root,
                    includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                .sorted { lhs, rhs in
                    let lValues = try? lhs.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let rValues = try? rhs.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let lDate = lValues?.creationDate ?? lValues?.contentModificationDate ?? Date.distantPast
                    let rDate = rValues?.creationDate ?? rValues?.contentModificationDate ?? Date.distantPast
                    return lDate < rDate
                }

                for entry in entries {
                    if usage <= limitBytes { break }
                    let size = (try? self.entrySize(entry)) ?? 0
                    do {
                        try self.fileMgr.removeItem(at: entry)
                        usage -= size
                    } catch {
                        print("⚠️ Failed to delete timelapse entry at \(entry.path): \(error)")
                    }
                }
            } catch {
                print("❌ Timelapse purge error: \(error)")
            }
        }
    }

    private func entrySize(_ url: URL) throws -> Int64 {
        var isDir: ObjCBool = false
        if fileMgr.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return (try? fileMgr.allocatedSizeOfDirectory(at: url)) ?? 0
        }
        let attrs = try fileMgr.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    // MARK: - Storage Metrics (Story 2.2)

    /// Calculate comprehensive storage metrics for recordings
    /// - Returns: Storage metrics including usage, averages, and retention info
    func calculateStorageMetrics() -> StorageMetrics {
        var totalSize: Int64 = 0
        var recordingCount = 0
        var oldestDate: Date? = nil
        var newestDate: Date? = nil
        var totalCompressionRatio: Double = 0.0
        var compressionRatioCount = 0

        // Get all recording files
        do {
            let entries = try fileMgr.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            for entry in entries {
                // Get file attributes
                let values = try? entry.resourceValues(forKeys: [.creationDateKey, .fileSizeKey, .contentModificationDateKey])

                // Accumulate size
                if let size = values?.fileSize {
                    totalSize += Int64(size)
                    recordingCount += 1
                }

                // Track date range
                if let creationDate = values?.creationDate {
                    if oldestDate == nil || creationDate < oldestDate! {
                        oldestDate = creationDate
                    }
                    if newestDate == nil || creationDate > newestDate! {
                        newestDate = creationDate
                    }
                }

                // Try to extract compression metadata from filename or associated metadata
                // For now, estimate compression ratio based on file size and resolution
                // (Will be more accurate when Epic 1 DatabaseManager is available)
                if let size = values?.fileSize {
                    // Estimate: assume 1920x1080 RGBA frames at 1 FPS
                    // Each frame uncompressed: 1920 * 1080 * 4 bytes = ~8MB
                    // 15-minute chunk at 1 FPS: 900 frames = ~7.2GB uncompressed
                    // Actual compressed size gives compression ratio
                    let estimatedFrames = 900 // 15 minutes at 1 FPS
                    let uncompressedSize = Int64(1920 * 1080 * 4 * estimatedFrames)
                    let ratio = Double(uncompressedSize) / max(Double(size), 1.0)
                    totalCompressionRatio += ratio
                    compressionRatioCount += 1
                }
            }
        } catch {
            print("⚠️ Failed to calculate storage metrics: \(error)")
        }

        // Calculate averages
        let averageCompressionRatio = compressionRatioCount > 0 ? totalCompressionRatio / Double(compressionRatioCount) : 1.0

        // Calculate daily average
        var dailyAverage: Int64 = 0
        if let oldest = oldestDate, let newest = newestDate {
            let daysDifference = Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
            if daysDifference > 0 {
                dailyAverage = totalSize / Int64(daysDifference)
            } else {
                // Less than a day of data, extrapolate
                let hoursDifference = Calendar.current.dateComponents([.hour], from: oldest, to: newest).hour ?? 1
                let hoursPerDay = 8  // Assume 8-hour recording days
                dailyAverage = (totalSize / Int64(max(hoursDifference, 1))) * Int64(hoursPerDay)
            }
        }

        // Get retention days from preferences (default 30)
        let retentionDays = 30  // TODO: Make configurable via StoragePreferences

        // Get storage limit
        let storageLimit = StoragePreferences.timelapsesLimitBytes

        return StorageMetrics(
            totalStorageUsed: totalSize,
            recordingCount: recordingCount,
            oldestRecordingDate: oldestDate,
            newestRecordingDate: newestDate,
            compressionRatio: averageCompressionRatio,
            dailyAverageSize: dailyAverage,
            retentionDays: retentionDays,
            storageLimit: storageLimit,
            calculatedAt: Date()
        )
    }

    /// Check if storage is approaching limit
    /// - Parameter threshold: Warning threshold (0.0 to 1.0)
    /// - Returns: True if usage exceeds threshold
    func isApproachingStorageLimit(threshold: Double = 0.8) -> Bool {
        let metrics = calculateStorageMetrics()
        return metrics.isApproachingLimit(threshold: threshold)
    }

    /// Get daily storage usage trend
    /// - Parameter days: Number of days to analyze
    /// - Returns: Array of (date, bytes) tuples
    func getDailyUsageTrend(days: Int = 7) -> [(date: Date, bytes: Int64)] {
        var trend: [(date: Date, bytes: Int64)] = []

        // Get all recording files grouped by day
        do {
            let entries = try fileMgr.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            // Group by day
            var dailyUsage: [Date: Int64] = [:]
            let calendar = Calendar.current

            for entry in entries {
                let values = try? entry.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])

                if let creationDate = values?.creationDate,
                   let size = values?.fileSize {
                    let dayStart = calendar.startOfDay(for: creationDate)

                    dailyUsage[dayStart, default: 0] += Int64(size)
                }
            }

            // Convert to sorted array
            trend = dailyUsage.map { (date: $0.key, bytes: $0.value) }
                .sorted { $0.date < $1.date }

            // Keep only last N days
            if trend.count > days {
                trend = Array(trend.suffix(days))
            }
        } catch {
            print("⚠️ Failed to calculate daily usage trend: \(error)")
        }

        return trend
    }

    /// Log storage metrics for monitoring
    func logStorageMetrics() {
        let metrics = calculateStorageMetrics()

        print("📊 Storage Metrics:")
        print("   Total used: \(metrics.formattedTotalStorage)")
        print("   Recording count: \(metrics.recordingCount)")
        print("   Daily average: \(metrics.formattedDailyAverage)")
        print("   Compression ratio: \(String(format: "%.1f", metrics.compressionRatio)):1")
        print("   Usage: \(String(format: "%.1f%%", metrics.usagePercentage * 100)) of limit (\(metrics.formattedStorageLimit))")

        if let daysUntilFull = metrics.estimatedDaysUntilFull {
            print("   Estimated days until full: \(daysUntilFull)")
        }

        if metrics.isApproachingLimit() {
            print("   ⚠️ WARNING: Approaching storage limit!")
        }
    }
}
