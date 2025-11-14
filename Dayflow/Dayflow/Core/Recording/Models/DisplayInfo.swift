//
//  DisplayInfo.swift
//  Dayflow
//
//  Individual display information model for multi-display tracking.
//  Part of Epic 2 - Story 2.1: Multi-Display Screen Capture
//

import Foundation
import CoreGraphics

/// Information about a single display in a multi-display configuration
struct DisplayInfo: Codable, Sendable, Equatable {
    /// Unique CoreGraphics display ID
    let id: CGDirectDisplayID

    /// Display bounds in screen coordinates
    let bounds: CGRect

    /// Display scale factor (1.0 for non-Retina, 2.0 for Retina, etc.)
    let scaleFactor: CGFloat

    /// Whether this display is currently active (has mouse focus or active windows)
    let isActive: Bool

    /// Whether this is the primary display (contains menu bar)
    let isPrimary: Bool

    /// Display width in pixels
    var width: Int {
        Int(bounds.width)
    }

    /// Display height in pixels
    var height: Int {
        Int(bounds.height)
    }

    /// Display resolution description
    var resolutionDescription: String {
        "\(width)×\(height)"
    }
}

extension DisplayInfo {
    /// Create DisplayInfo from a CoreGraphics display ID
    static func from(displayID: CGDirectDisplayID, isActive: Bool = false) -> DisplayInfo? {
        let bounds = CGDisplayBounds(displayID)

        // Check if display is valid (bounds are non-zero)
        guard bounds.width > 0 && bounds.height > 0 else {
            return nil
        }

        // Get scale factor from display mode
        var scaleFactor: CGFloat = 1.0
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            let pixelWidth = mode.pixelWidth
            let logicalWidth = Int(bounds.width)
            if logicalWidth > 0 {
                scaleFactor = CGFloat(pixelWidth) / CGFloat(logicalWidth)
            }
        }

        // Check if this is the primary display (contains menu bar at origin)
        let isPrimary = CGDisplayIsMain(displayID) != 0

        return DisplayInfo(
            id: displayID,
            bounds: bounds,
            scaleFactor: scaleFactor,
            isActive: isActive,
            isPrimary: isPrimary
        )
    }
}
