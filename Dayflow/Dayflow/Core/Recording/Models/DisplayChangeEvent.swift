//
//  DisplayChangeEvent.swift
//  Dayflow
//
//  Display configuration change event types for AsyncStream monitoring.
//  Part of Epic 2 - Story 2.1: Multi-Display Screen Capture
//

import Foundation
import CoreGraphics

/// Events emitted when display configuration changes
enum DisplayChangeEvent: Sendable, Equatable {
    /// A new display was connected
    case added(DisplayInfo)

    /// A display was disconnected
    case removed(CGDirectDisplayID)

    /// Display configuration changed (resolution, arrangement, etc.)
    case reconfigured([DisplayInfo])

    /// Display configuration is being actively reconfigured (transition state)
    case reconfiguring

    var description: String {
        switch self {
        case .added(let display):
            return "Display added: \(display.id) (\(display.resolutionDescription))"
        case .removed(let id):
            return "Display removed: \(id)"
        case .reconfigured(let displays):
            return "Configuration changed: \(displays.count) display(s)"
        case .reconfiguring:
            return "Display configuration in progress..."
        }
    }
}
