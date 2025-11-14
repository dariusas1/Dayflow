//
//  DatabaseManagerTests.swift
//  DayflowTests
//
//  Created by Development Agent on 2025-11-13.
//  Story 1.1: Database Threading Crash Fix
//
//  Comprehensive test suite for DatabaseManager thread-safety and performance.
//

import XCTest
import GRDB
@testable import Dayflow

final class DatabaseManagerTests: XCTestCase {

    // MARK: - AC-1.1.1: DatabaseManager Initialization

    func testDatabaseManagerInitialization() async throws {
        // Test that DatabaseManager initializes successfully with correct configuration
        let manager = DatabaseManager.shared

        // Verify we can perform a simple read operation
        let result = try await manager.read { db in
            return try String.fetchOne(db, sql: "SELECT 'test'")
        }

        XCTAssertEqual(result, "test", "DatabaseManager should successfully execute read operations")
    }

    func testDatabaseManagerSingletonPattern() {
        // Verify singleton pattern - multiple accesses should return same instance
        let instance1 = DatabaseManager.shared
        let instance2 = DatabaseManager.shared

        XCTAssertTrue(instance1 === instance2, "DatabaseManager should be a singleton")
    }

    // MARK: - AC-1.1.2: Thread Safety - No Crashes from Multi-threaded Access

    func testConcurrentReadsNoCrash() async throws {
        // Test that multiple concurrent reads don't cause crashes
        let iterations = 10
        let manager = DatabaseManager.shared

        // Create a test table
        try await manager.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS test_chunks (
                    id INTEGER PRIMARY KEY,
                    data TEXT
                )
                """)
            // Insert test data
            for i in 1...10 {
                try db.execute(sql: "INSERT INTO test_chunks (id, data) VALUES (?, ?)",
                              arguments: [i, "data_\(i)"])
            }
        }

        // Perform concurrent reads
        try await withThrowingTaskGroup(of: [String].self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    return try await manager.read { db in
                        try String.fetchAll(db, sql: "SELECT data FROM test_chunks")
                    }
                }
            }

            var allResults: [[String]] = []
            for try await result in group {
                allResults.append(result)
            }

            // Verify all reads succeeded
            XCTAssertEqual(allResults.count, iterations, "All concurrent reads should succeed")
            for result in allResults {
                XCTAssertEqual(result.count, 10, "Each read should return all records")
            }
        }

        // Cleanup
        try await manager.write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS test_chunks")
        }
    }

    // MARK: - AC-1.1.3: Stress Test with Concurrent Operations

    func testStressConcurrentDatabaseOperations() async throws {
        // Stress test with 10 concurrent operations (reads + writes)
        let manager = DatabaseManager.shared
        let operationCount = 10

        // Create test table
        try await manager.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS stress_test (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    value INTEGER,
                    timestamp REAL
                )
                """)
        }

        // Perform mixed concurrent operations
        try await withThrowingTaskGroup(of: Void.self) { group in
            // 5 concurrent writes
            for i in 0..<5 {
                group.addTask {
                    try await manager.write { db in
                        try db.execute(sql: """
                            INSERT INTO stress_test (value, timestamp)
                            VALUES (?, ?)
                            """, arguments: [i, Date().timeIntervalSince1970])
                    }
                }
            }

            // 5 concurrent reads
            for _ in 0..<5 {
                group.addTask {
                    _ = try await manager.read { db in
                        try Int.fetchAll(db, sql: "SELECT value FROM stress_test")
                    }
                }
            }

            try await group.waitForAll()
        }

        // Verify data integrity - all writes should have succeeded
        let count = try await manager.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM stress_test")
        }

        XCTAssertEqual(count, 5, "All concurrent writes should succeed without data corruption")

        // Cleanup
        try await manager.write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS stress_test")
        }
    }

    func testDataConsistencyUnderConcurrentLoad() async throws {
        // Test that data remains consistent under concurrent mixed operations
        let manager = DatabaseManager.shared

        // Create test table with a counter
        try await manager.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS counter_test (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    count INTEGER NOT NULL DEFAULT 0
                )
                """)
            try db.execute(sql: "INSERT INTO counter_test (id, count) VALUES (1, 0)")
        }

        // Perform 20 concurrent increment operations
        let incrementCount = 20
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<incrementCount {
                group.addTask {
                    try await manager.write { db in
                        // Read current value, increment, and write back
                        if let current = try Int.fetchOne(db, sql: "SELECT count FROM counter_test WHERE id = 1") {
                            try db.execute(sql: "UPDATE counter_test SET count = ? WHERE id = 1",
                                          arguments: [current + 1])
                        }
                    }
                }
            }

            try await group.waitForAll()
        }

        // Verify final count is correct (serial queue ensures atomicity)
        let finalCount = try await manager.read { db in
            try Int.fetchOne(db, sql: "SELECT count FROM counter_test WHERE id = 1")
        }

        XCTAssertEqual(finalCount, incrementCount,
                      "Serial queue should ensure all increments are applied correctly")

        // Cleanup
        try await manager.write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS counter_test")
        }
    }

    // MARK: - AC-1.1.5: Error Handling and Propagation

    func testErrorPropagation() async {
        let manager = DatabaseManager.shared

        do {
            _ = try await manager.read { db in
                // Intentionally cause a SQL error
                try String.fetchOne(db, sql: "SELECT * FROM nonexistent_table")
            }
            XCTFail("Should throw an error for invalid SQL")
        } catch {
            // Error should be properly propagated
            XCTAssertNotNil(error, "Error should be propagated from database operation")
        }
    }

    func testTransactionRollbackOnError() async throws {
        let manager = DatabaseManager.shared

        // Create test table
        try await manager.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS transaction_test (
                    id INTEGER PRIMARY KEY,
                    value TEXT
                )
                """)
        }

        // Attempt a transaction that will fail
        do {
            _ = try await manager.transaction { db in
                // First insert should succeed
                try db.execute(sql: "INSERT INTO transaction_test (id, value) VALUES (1, 'test')")

                // This will fail due to duplicate primary key
                try db.execute(sql: "INSERT INTO transaction_test (id, value) VALUES (1, 'duplicate')")

                return "success"
            }
            XCTFail("Transaction should fail due to duplicate key")
        } catch {
            // Transaction should have rolled back
            let count = try await manager.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transaction_test")
            }
            XCTAssertEqual(count, 0, "Transaction rollback should prevent any inserts")
        }

        // Cleanup
        try await manager.write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS transaction_test")
        }
    }

    // MARK: - AC-1.1.6: Performance Tests

    func testDatabaseOperationLatency() async throws {
        // Test that database operations complete within acceptable latency
        let manager = DatabaseManager.shared
        let iterations = 100
        var latencies: [TimeInterval] = []

        // Create test table
        try await manager.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS latency_test (
                    id INTEGER PRIMARY KEY,
                    data TEXT
                )
                """)
            // Insert test data
            for i in 1...100 {
                try db.execute(sql: "INSERT INTO latency_test (id, data) VALUES (?, ?)",
                              arguments: [i, "data_\(i)"])
            }
        }

        // Measure read latencies
        for _ in 0..<iterations {
            let start = Date()
            _ = try await manager.read { db in
                try Int.fetchAll(db, sql: "SELECT id FROM latency_test WHERE id < 50")
            }
            let latency = Date().timeIntervalSince(start) * 1000 // Convert to ms
            latencies.append(latency)
        }

        // Calculate P95 latency
        let sortedLatencies = latencies.sorted()
        let p95Index = Int(Double(sortedLatencies.count) * 0.95)
        let p95Latency = sortedLatencies[p95Index]

        print("📊 P95 Latency: \(p95Latency)ms")
        XCTAssertLessThan(p95Latency, 100.0,
                         "P95 latency should be less than 100ms (AC-1.1.6)")

        // Cleanup
        try await manager.write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS latency_test")
        }
    }

    // MARK: - Integration Tests

    func testActorIsolation() async {
        // Test that DatabaseManager actor properly isolates access
        let manager = DatabaseManager.shared

        // This should compile and work thanks to actor isolation
        let result = try? await manager.read { db in
            return "isolated"
        }

        XCTAssertEqual(result, "isolated", "Actor isolation should work correctly")
    }

    func testSendableConformance() {
        // Test that protocol conformance is correct
        let manager: any DatabaseManagerProtocol = DatabaseManager.shared

        // This should compile thanks to Sendable conformance
        Task {
            _ = try? await manager.read { db in
                return "sendable"
            }
        }
    }
}
