//
//  VideoCodec.swift
//  Dayflow
//
//  Video codec selection for compression engine.
//  Part of Epic 2 - Story 2.2: Video Compression Optimization
//

import Foundation
import AVFoundation

/// Video codec options for compression
enum VideoCodec: String, Codable, Sendable {
    /// H.264 codec - widely compatible, good for Intel Macs
    case h264 = "H.264"

    /// H.265/HEVC codec - better compression, preferred for Apple Silicon
    case hevc = "H.265"

    /// Get the corresponding AVVideoCodecType for AVFoundation
    var avCodecType: AVVideoCodecType {
        switch self {
        case .h264:
            return .h264
        case .hevc:
            return .hevc
        }
    }

    /// Detect the best codec for the current system architecture
    static var recommended: VideoCodec {
        #if arch(arm64)
        // Apple Silicon - H.265 has excellent hardware acceleration
        return .hevc
        #else
        // Intel Macs - H.264 is more reliable
        return .h264
        #endif
    }

    /// Check if hardware encoding is available for this codec
    func isHardwareEncodingAvailable() -> Bool {
        // Both H.264 and H.265 support hardware encoding on modern Macs
        // H.265 is particularly efficient on Apple Silicon
        switch self {
        case .h264:
            return true
        case .hevc:
            #if arch(arm64)
            return true
            #else
            // H.265 hardware encoding may be limited on Intel Macs
            return false
            #endif
        }
    }
}
