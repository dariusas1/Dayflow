//
//  AnalysisModels.swift
//  Dayflow
//
//  Created on 5/1/2025.
//

import Foundation

/// Represents a recording chunk from the database
/// Sendable conformance allows safe cross-actor boundary passing (Story 1.1)
struct RecordingChunk: Codable, Sendable {
    let id: Int64
    let startTs: Int
    let endTs: Int
    let fileUrl: String
    let status: String

    var duration: TimeInterval {
        TimeInterval(endTs - startTs)
    }
}
