//
//  DatabaseManagerProtocol.swift
//  Dayflow
//
//  Created by Development Agent on 2025-11-13.
//  Story 1.1: Database Threading Crash Fix
//

import Foundation
import GRDB

/// Protocol defining thread-safe database operations.
/// All implementations must conform to Sendable to guarantee safe cross-actor usage.
protocol DatabaseManagerProtocol: Sendable {

    /// Execute a read operation on the serial database queue.
    /// - Parameter operation: A closure that receives a GRDB.Database and returns a Sendable result.
    /// - Returns: The result of the operation.
    /// - Throws: Any error that occurs during the database operation.
    func read<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T

    /// Execute a write operation on the serial database queue.
    /// - Parameter operation: A closure that receives a GRDB.Database and returns a Sendable result.
    /// - Returns: The result of the operation.
    /// - Throws: Any error that occurs during the database operation.
    func write<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T

    /// Execute a transaction on the serial database queue.
    /// - Parameter operation: A closure that receives a GRDB.Database and returns a Sendable result.
    /// - Returns: The result of the operation.
    /// - Throws: Any error that occurs during the database operation.
    func transaction<T: Sendable>(_ operation: @escaping (GRDB.Database) throws -> T) async throws -> T
}
