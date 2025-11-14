//
//  DatabaseManager.swift
//  Dayflow
//
//  Created by Development Agent on 2025-11-13.
//  Story 1.1: Database Threading Crash Fix
//
//  This actor provides a thread-safe wrapper around GRDB database operations.
//  All database access must go through this serial queue to prevent crashes from
//  concurrent access, specifically the "freed pointer was not last allocation" error.
//

import Foundation
import GRDB
import os.log

/// Thread-safe database manager using actor isolation and a serial dispatch queue.
/// All GRDB operations are serialized through a single queue to prevent concurrent access crashes.
actor DatabaseManager: DatabaseManagerProtocol {

    /// Shared singleton instance. All database operations should use this instance.
    static let shared = DatabaseManager()

    /// Serial queue for all database operations. QoS .userInitiated prevents priority inversion.
    private let serialQueue = DispatchQueue(
        label: "com.focusLock.database",
        qos: .userInitiated
    )

    /// GRDB database pool for connection management
    /// Optional to allow graceful handling when database initialization fails
    private let pool: DatabasePool?

    /// Logger for database operations
    private let logger = Logger(subsystem: "Dayflow", category: "DatabaseManager")

    /// Private initializer to enforce singleton pattern
    private init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let baseDir = appSupport.appendingPathComponent("Dayflow", isDirectory: true)

        // Ensure base directory exists
        try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)

        let dbURL = baseDir.appendingPathComponent("chunks.sqlite")

        // Configure database with same settings as StorageManager for compatibility
        var config = Configuration()
        config.maximumReaderCount = 5
        config.qos = .userInitiated

        config.prepareDatabase { db in
            if !db.configuration.readonly {
                try? db.execute(sql: "PRAGMA journal_mode = WAL")
                try? db.execute(sql: "PRAGMA synchronous = NORMAL")
            }
            try? db.execute(sql: "PRAGMA busy_timeout = 5000")
        }

        // Initialize database pool with retry logic and fallback
        self.pool = Self.initializeDatabasePoolWithRetry(
            dbURL: dbURL,
            config: config,
            logger: logger
        )
    }

    /// Initialize database pool with retry logic and fallback to in-memory database
    /// Returns nil if all initialization attempts fail (extremely rare)
    private static func initializeDatabasePoolWithRetry(
        dbURL: URL,
        config: Configuration,
        logger: Logger
    ) -> DatabasePool? {
        let maxRetries = 3
        var lastError: Error?

        // Attempt to initialize disk database with exponential backoff
        for attempt in 1...maxRetries {
            do {
                let pool = try DatabasePool(path: dbURL.path, configuration: config)
                logger.info("DatabaseManager initialized successfully at \(dbURL.path)")
                return pool
            } catch {
                lastError = error
                logger.error("Database initialization attempt \(attempt)/\(maxRetries) failed: \(error.localizedDescription, privacy: .public)")

                if attempt < maxRetries {
                    // Exponential backoff: 100ms, 200ms, 400ms
                    let backoffMs = 100 * (1 << (attempt - 1))
                    Thread.sleep(forTimeInterval: Double(backoffMs) / 1000.0)
                }
            }
        }

        // All retries failed, attempt fallback to in-memory database
        logger.error("Failed to initialize disk database after \(maxRetries) attempts. Falling back to in-memory database.")

        do {
            // Create in-memory database as fallback
            let inMemoryPool = try DatabasePool()
            logger.warning("⚠️ FALLBACK: Using in-memory database. All data will be lost when app closes!")

            // Notify user asynchronously (non-blocking)
            DispatchQueue.main.async {
                Self.notifyUserOfDatabaseFailure(diskPath: dbURL.path, error: lastError)
            }

            return inMemoryPool
        } catch {
            // In-memory database also failed - this should be extremely rare
            logger.critical("Critical error: Both disk and in-memory database initialization failed!")
            logger.critical("Disk error: \(lastError?.localizedDescription ?? "unknown", privacy: .public)")
            logger.critical("Memory error: \(error.localizedDescription, privacy: .public)")

            // Try one last time with minimal config
            do {
                var minimalConfig = Configuration()
                minimalConfig.readonly = false
                let minimalPool = try DatabasePool(configuration: minimalConfig)
                logger.warning("Successfully created minimal in-memory database as last resort")

                // Notify user asynchronously (non-blocking)
                DispatchQueue.main.async {
                    Self.notifyUserOfDatabaseFailure(diskPath: dbURL.path, error: lastError)
                }

                return minimalPool
            } catch let finalError {
                // All attempts failed - notify user and return nil
                logger.critical("FATAL: Cannot initialize any database (disk, in-memory, or minimal)")
                logger.critical("Final error: \(finalError.localizedDescription, privacy: .public)")

                // Notify user synchronously before returning nil
                DispatchQueue.main.sync {
                    Self.notifyUserOfCriticalFailure(diskError: lastError, memoryError: error)
                }

                // Return nil instead of crashing - let the app handle gracefully
                return nil
            }
        }
    }

    /// Notify user that disk database failed but app is running with in-memory fallback
    private static func notifyUserOfDatabaseFailure(diskPath: String, error: Error?) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Database Warning"
        alert.informativeText = """
        Could not access the database file at:
        \(diskPath)

        The app is running with temporary in-memory storage. Your data will not be saved when you close the app.

        Error: \(error?.localizedDescription ?? "Unknown error")

        Please check disk space and file permissions, then restart the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
        #endif
    }

    /// Notify user of critical failure when both disk and memory databases fail
    private static func notifyUserOfCriticalFailure(diskError: Error?, memoryError: Error) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Critical Database Error"
        alert.informativeText = """
        The app cannot initialize its database system.

        Disk database error: \(diskError?.localizedDescription ?? "Unknown error")
        In-memory database error: \(memoryError.localizedDescription)

        The app will run in limited mode with database operations disabled. Please check disk space and file permissions, then restart the app.

        Some features may not work correctly.
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Continue")
        alert.runModal()
        #endif
    }

    /// Execute a read operation on the serial database queue.
    /// - Parameter operation: A closure that receives a GRDB.Database and returns a Sendable result.
    /// - Returns: The result of the operation.
    /// - Throws: Any error that occurs during the database operation.
    func read<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T {
        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            serialQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: DatabaseError.managerDeallocated)
                    return
                }

                guard let pool = self.pool else {
                    self.logger.error("Database pool is unavailable - initialization failed")
                    continuation.resume(throwing: DatabaseError.databaseUnavailable)
                    return
                }

                do {
                    let result = try pool.read(operation)
                    let duration = Date().timeIntervalSince(startTime) * 1000

                    if duration > 100 {
                        self.logger.warning("Slow database read: \(duration, privacy: .public)ms")
                    }

                    continuation.resume(returning: result)
                } catch {
                    self.logger.error("Database read error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Execute a write operation on the serial database queue.
    /// - Parameter operation: A closure that receives a GRDB.Database and returns a Sendable result.
    /// - Returns: The result of the operation.
    /// - Throws: Any error that occurs during the database operation.
    func write<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T {
        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            serialQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: DatabaseError.managerDeallocated)
                    return
                }

                guard let pool = self.pool else {
                    self.logger.error("Database pool is unavailable - initialization failed")
                    continuation.resume(throwing: DatabaseError.databaseUnavailable)
                    return
                }

                do {
                    let result = try pool.write(operation)
                    let duration = Date().timeIntervalSince(startTime) * 1000

                    if duration > 100 {
                        self.logger.warning("Slow database write: \(duration, privacy: .public)ms")
                    }

                    continuation.resume(returning: result)
                } catch {
                    self.logger.error("Database write error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Execute a transaction on the serial database queue.
    /// Transactions provide atomicity for batch operations.
    /// - Parameter operation: A closure that receives a GRDB.Database and returns a Sendable result.
    /// - Returns: The result of the operation.
    /// - Throws: Any error that occurs during the database operation, triggering a rollback.
    func transaction<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T {
        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            serialQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: DatabaseError.managerDeallocated)
                    return
                }

                guard let pool = self.pool else {
                    self.logger.error("Database pool is unavailable - initialization failed")
                    continuation.resume(throwing: DatabaseError.databaseUnavailable)
                    return
                }

                do {
                    let result = try pool.write { db in
                        // Use explicit transaction for better control
                        try db.inTransaction {
                            let result = try operation(db)
                            return .commit(result)
                        }
                    }

                    let duration = Date().timeIntervalSince(startTime) * 1000

                    if duration > 100 {
                        self.logger.warning("Slow database transaction: \(duration, privacy: .public)ms")
                    }

                    continuation.resume(returning: result)
                } catch {
                    self.logger.error("Database transaction error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// Custom errors for DatabaseManager
enum DatabaseError: Error, LocalizedError {
    case managerDeallocated
    case operationTimeout
    case invalidConfiguration
    case databaseUnavailable

    var errorDescription: String? {
        switch self {
        case .managerDeallocated:
            return "DatabaseManager was deallocated during operation"
        case .operationTimeout:
            return "Database operation timed out"
        case .invalidConfiguration:
            return "Database configuration is invalid"
        case .databaseUnavailable:
            return "Database is unavailable - initialization failed. The app is running in limited mode."
        }
    }
}
