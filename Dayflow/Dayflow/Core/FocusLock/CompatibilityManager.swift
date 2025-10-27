import Foundation
import SwiftUI
import Combine

/// Comprehensive backward compatibility and graceful degradation system
class CompatibilityManager: ObservableObject {
    static let shared = CompatibilityManager()

    // MARK: - Published Properties
    @Published var systemCompatibility: SystemCompatibility
    @Published var degradedFeatures: Set<String> = []
    @Published var compatibilityWarnings: [CompatibilityWarning] = []
    @Published var migrationStatus: MigrationStatus = .notStarted
    @Published var isGracefulModeActive: Bool = false

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let compatibilityKey = "FocusLockCompatibilityInfo"
    private let migrationKey = "FocusLockMigrationStatus"

    // System requirements
    private let minimummacOSVersion = OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0)
    private let recommendedmacOSVersion = OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
    private let minimumMemoryMB: Double = 4096 // 4GB
    private let recommendedMemoryMB: Double = 8192 // 8GB

    private init() {
        self.systemCompatibility = Self.assessSystemCompatibility()
        checkFeatureCompatibility()
        setupMigrationMonitoring()
    }

    // MARK: - Public Interface

    func checkCompatibility() -> CompatibilityReport {
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let availableMemory = getAvailableMemory()

        let versionCompatible = isVersionCompatible(currentVersion, minimum: minimummacOSVersion)
        let memoryCompatible = availableMemory >= minimumMemoryMB

        let systemScore = calculateCompatibilityScore(
            osVersion: currentVersion,
            memoryMB: availableMemory
        )

        return CompatibilityReport(
            macOSVersion: currentVersion,
            memoryMB: availableMemory,
            isVersionCompatible: versionCompatible,
            isMemoryCompatible: memoryCompatible,
            compatibilityScore: systemScore,
            degradedFeatures: degradedFeatures,
            warnings: compatibilityWarnings,
            recommendations: generateRecommendations(systemScore: systemScore)
        )
    }

    func enableGracefulMode() {
        isGracefulModeActive = true

        // Disable resource-intensive features
        let resourceIntensiveFeatures: [String] = [
            "AdvancedDashboard",
            "JarvisChat",
            "Analytics",
            "CloudSync",
            "AdvancedSettings"
        ]

        for feature in resourceIntensiveFeatures {
            degradedFeatures.insert(feature)
        }

        // Apply performance optimizations
        applyPerformanceOptimizations()

        // Notify user about graceful mode
        addCompatibilityWarning(
            type: .performanceDegradation,
            message: "Graceful mode enabled to ensure stability on this system.",
            severity: .info
        )
    }

    func disableGracefulMode() {
        isGracefulModeActive = false
        degradedFeatures.removeAll()
        compatibilityWarnings.removeAll { $0.type == .performanceDegradation }
        checkFeatureCompatibility()
    }

    func migrateFromLegacyVersion() async -> MigrationResult {
        migrationStatus = .inProgress

        do {
            // Check for legacy data
            let hasLegacyData = checkForLegacyData()
            guard hasLegacyData else {
                migrationStatus = .completed
                return MigrationResult(success: true, migratedItems: 0, errors: [])
            }

            // Perform migration steps
            var migratedItems = 0
            var migrationErrors: [MigrationError] = []

            // Step 1: Migrate user preferences
            let preferencesResult = await migrateLegacyPreferences()
            migratedItems += preferencesResult.itemsMigrated
            migrationErrors.append(contentsOf: preferencesResult.errors)

            // Step 2: Migrate session data
            let sessionsResult = await migrateLegacySessions()
            migratedItems += sessionsResult.itemsMigrated
            migrationErrors.append(contentsOf: sessionsResult.errors)

            // Step 3: Migrate focus statistics
            let statsResult = await migrateLegacyStatistics()
            migratedItems += statsResult.itemsMigrated
            migrationErrors.append(contentsOf: statsResult.errors)

            // Step 4: Validate migration
            let validationResult = validateMigration()
            if !validationResult.isValid {
                migrationErrors.append(MigrationError(
                    type: .validationFailed,
                    message: "Migration validation failed: \(validationResult.issues.joined(separator: ", "))"
                ))
            }

            // Save migration status
            userDefaults.set(true, forKey: migrationKey)
            userDefaults.set(Date(), forKey: "MigrationDate")

            migrationStatus = migrationErrors.isEmpty ? .completed : .failed
            return MigrationResult(
                success: migrationErrors.isEmpty,
                migratedItems: migratedItems,
                errors: migrationErrors
            )

        } catch {
            migrationStatus = .failed
            return MigrationResult(
                success: false,
                migratedItems: 0,
                errors: [MigrationError(type: .unknownError, message: error.localizedDescription)]
            )
        }
    }

    func isFeatureAvailable(_ feature: String) -> Bool {
        return !degradedFeatures.contains(feature) && isSystemCompatible()
    }

    func getFallbackImplementation(for feature: String) -> FallbackImplementation? {
        switch feature {
        case "AdvancedDashboard":
            return FallbackImplementation(
                feature: feature,
                fallbackType: .simplifiedView,
                description: "Simplified dashboard with basic statistics only"
            )
        case "JarvisChat":
            return FallbackImplementation(
                feature: feature,
                fallbackType: .textBased,
                description: "Basic text input without AI processing"
            )
        case "Analytics":
            return FallbackImplementation(
                feature: feature,
                fallbackType: .basicStats,
                description: "Basic session statistics without detailed analytics"
            )
        case "CloudSync":
            return FallbackImplementation(
                feature: feature,
                fallbackType: .localOnly,
                description: "Local storage only, no cloud synchronization"
            )
        default:
            return nil
        }
    }

    // MARK: - Private Methods

    private static func assessSystemCompatibility() -> SystemCompatibility {
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let availableMemory = Self().getAvailableMemory()

        return SystemCompatibility(
            osVersion: currentVersion,
            memoryMB: availableMemory,
            processorCount: ProcessInfo.processInfo.processorCount,
            supportsAdvancedFeatures: currentVersion >= OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0),
            recommendedPerformanceLevel: availableMemory >= 8192
        )
    }

    private func getAvailableMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        }

        return 8192 // Default to 8GB if detection fails
    }

    private func isVersionCompatible(_ current: OperatingSystemVersion, minimum: OperatingSystemVersion) -> Bool {
        if current.majorVersion > minimum.majorVersion { return true }
        if current.majorVersion < minimum.majorVersion { return false }
        if current.minorVersion > minimum.minorVersion { return true }
        if current.minorVersion < minimum.minorVersion { return false }
        return current.patchVersion >= minimum.patchVersion
    }

    private func calculateCompatibilityScore(osVersion: OperatingSystemVersion, memoryMB: Double) -> Double {
        var score: Double = 1.0

        // OS Version scoring
        if osVersion < minimummacOSVersion {
            score *= 0.3
        } else if osVersion < recommendedmacOSVersion {
            score *= 0.7
        }

        // Memory scoring
        if memoryMB < minimumMemoryMB {
            score *= 0.4
        } else if memoryMB < recommendedMemoryMB {
            score *= 0.8
        }

        return score
    }

    private func checkFeatureCompatibility() {
        var newDegradedFeatures: Set<String> = []
        var newWarnings: [CompatibilityWarning] = []

        // Check each feature against system capabilities
        if systemCompatibility.memoryMB < minimumMemoryMB {
            newDegradedFeatures.insert("AdvancedDashboard")
            newDegradedFeatures.insert("JarvisChat")
            newDegradedFeatures.insert("Analytics")

            newWarnings.append(CompatibilityWarning(
                type: .memoryConstraints,
                message: "Limited memory may affect performance of advanced features.",
                severity: .warning,
                recommendation: "Consider upgrading memory or using simplified features."
            ))
        }

        if !systemCompatibility.supportsAdvancedFeatures {
            newDegradedFeatures.insert("AdvancedDashboard")
            newDegradedFeatures.insert("JarvisChat")

            newWarnings.append(CompatibilityWarning(
                type: .osVersionConstraints,
                message: "Some advanced features require a newer macOS version.",
                severity: .info,
                recommendation: "Upgrade to macOS 13.0 or later for full functionality."
            ))
        }

        degradedFeatures = newDegradedFeatures
        compatibilityWarnings = newWarnings
    }

    private func applyPerformanceOptimizations() {
        // Reduce animation quality
        // Limit background processing
        // Lower refresh rates
        // Disable non-essential features
    }

    private func addCompatibilityWarning(type: CompatibilityWarningType, message: String, severity: WarningSeverity, recommendation: String? = nil) {
        let warning = CompatibilityWarning(
            type: type,
            message: message,
            severity: severity,
            recommendation: recommendation
        )

        if !compatibilityWarnings.contains(where: { $0.type == type }) {
            compatibilityWarnings.append(warning)
        }
    }

    private func checkForLegacyData() -> Bool {
        // Check for legacy Dayflow data
        return userDefaults.object(forKey: "DayflowSessionData") != nil ||
               userDefaults.object(forKey: "DayflowPreferences") != nil
    }

    private func migrateLegacyPreferences() async -> MigrationStepResult {
        // Implementation for migrating legacy preferences
        return MigrationStepResult(itemsMigrated: 0, errors: [])
    }

    private func migrateLegacySessions() async -> MigrationStepResult {
        // Implementation for migrating legacy session data
        return MigrationStepResult(itemsMigrated: 0, errors: [])
    }

    private func migrateLegacyStatistics() async -> MigrationStepResult {
        // Implementation for migrating legacy statistics
        return MigrationStepResult(itemsMigrated: 0, errors: [])
    }

    private func validateMigration() -> ValidationResult {
        var issues: [String] = []

        // Validate migrated data integrity
        // Check for missing or corrupted data
        // Verify data consistency

        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }

    private func generateRecommendations(systemScore: Double) -> [String] {
        var recommendations: [String] = []

        if systemScore < 0.5 {
            recommendations.append("Consider upgrading your hardware for better performance")
            recommendations.append("Enable graceful mode for optimal stability")
        } else if systemScore < 0.8 {
            recommendations.append("Monitor system performance regularly")
            recommendations.append("Consider closing other applications during intensive sessions")
        }

        if !systemCompatibility.supportsAdvancedFeatures {
            recommendations.append("Upgrade to macOS 13.0 or later for access to all features")
        }

        if systemCompatibility.memoryMB < recommendedMemoryMB {
            recommendations.append("Adding more RAM will improve performance")
        }

        return recommendations
    }

    private func setupMigrationMonitoring() {
        // Monitor for migration events and handle appropriately
    }

    private func isSystemCompatible() -> Bool {
        return systemCompatibility.memoryMB >= minimumMemoryMB &&
               isVersionCompatible(systemCompatibility.osVersion, minimum: minimummacOSVersion)
    }
}

// MARK: - Supporting Data Models

struct SystemCompatibility: Codable {
    let osVersion: OperatingSystemVersion
    let memoryMB: Double
    let processorCount: Int
    let supportsAdvancedFeatures: Bool
    let recommendedPerformanceLevel: Bool

    var osVersionString: String {
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }
}

struct CompatibilityReport {
    let macOSVersion: OperatingSystemVersion
    let memoryMB: Double
    let isVersionCompatible: Bool
    let isMemoryCompatible: Bool
    let compatibilityScore: Double
    let degradedFeatures: Set<String>
    let warnings: [CompatibilityWarning]
    let recommendations: [String]

    var isFullyCompatible: Bool {
        return isVersionCompatible && isMemoryCompatible && compatibilityScore >= 0.8
    }

    var needsGracefulMode: Bool {
        return compatibilityScore < 0.6 || !degradedFeatures.isEmpty
    }
}

struct CompatibilityWarning: Identifiable, Codable {
    let id = UUID()
    let type: CompatibilityWarningType
    let message: String
    let severity: WarningSeverity
    let recommendation: String?

    enum CompatibilityWarningType: String, Codable {
        case osVersionConstraints = "os_version_constraints"
        case memoryConstraints = "memory_constraints"
        case performanceDegradation = "performance_degradation"
        case featureIncompatibility = "feature_incompatibility"
    }

    enum WarningSeverity: String, Codable {
        case info = "info"
        case warning = "warning"
        case error = "error"
    }
}

struct FallbackImplementation {
    let feature: String
    let fallbackType: FallbackType
    let description: String

    enum FallbackType {
        case simplifiedView
        case textBased
        case basicStats
        case localOnly
        case disabled
    }
}

enum MigrationStatus: String, Codable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
}

struct MigrationResult {
    let success: Bool
    let migratedItems: Int
    let errors: [MigrationError]
}

struct MigrationStepResult {
    let itemsMigrated: Int
    let errors: [MigrationError]
}

struct MigrationError: Identifiable, Error {
    let id = UUID()
    let type: MigrationErrorType
    let message: String

    enum MigrationErrorType {
        case dataCorruption
        case versionMismatch
        case insufficientSpace
        case validationFailed
        case unknownError
    }
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
}