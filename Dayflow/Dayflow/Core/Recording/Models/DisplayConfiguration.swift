//
//  DisplayConfiguration.swift
//  Dayflow
//
//  Display configuration snapshot for recording metadata persistence.
//  Part of Epic 2 - Story 2.1: Multi-Display Screen Capture
//

import Foundation
import CoreGraphics

/// Complete display configuration snapshot for a recording session
struct DisplayConfiguration: Codable, Sendable, Equatable {
    /// Total number of connected displays
    let displayCount: Int

    /// ID of the primary display (contains menu bar)
    let primaryDisplayID: CGDirectDisplayID

    /// Resolution information for all active displays
    let displayResolutions: [DisplayResolution]

    /// Timestamp when this configuration was captured
    let capturedAt: Date

    /// Create configuration from current display state
    static func current(displays: [DisplayInfo]) -> DisplayConfiguration? {
        guard !displays.isEmpty else { return nil }

        // Find primary display
        guard let primary = displays.first(where: { $0.isPrimary }) ?? displays.first else {
            return nil
        }

        let resolutions = displays.map { display in
            DisplayResolution(
                displayID: display.id,
                width: display.width,
                height: display.height,
                scaleFactor: display.scaleFactor,
                isPrimary: display.isPrimary
            )
        }

        return DisplayConfiguration(
            displayCount: displays.count,
            primaryDisplayID: primary.id,
            displayResolutions: resolutions,
            capturedAt: Date()
        )
    }
}

/// Resolution information for a single display
struct DisplayResolution: Codable, Sendable, Equatable {
    /// Display identifier
    let displayID: CGDirectDisplayID

    /// Display width in pixels
    let width: Int

    /// Display height in pixels
    let height: Int

    /// Display scale factor (Retina)
    let scaleFactor: CGFloat

    /// Whether this is the primary display
    let isPrimary: Bool

    /// Resolution description string
    var description: String {
        "\(width)×\(height)@\(scaleFactor)x"
    }
}

extension DisplayConfiguration {
    /// Check if two configurations are equivalent (ignoring timestamps)
    func isEquivalent(to other: DisplayConfiguration) -> Bool {
        return self.displayCount == other.displayCount &&
               self.primaryDisplayID == other.primaryDisplayID &&
               self.displayResolutions == other.displayResolutions
    }

    /// Get display IDs in this configuration
    var displayIDs: [CGDirectDisplayID] {
        displayResolutions.map { $0.displayID }
    }
}
