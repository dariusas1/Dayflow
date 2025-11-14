//
//  ActiveDisplayTracker.swift
//  Dayflow
//
//  Tracks the CGDirectDisplayID under the mouse with debounce to avoid
//  flapping when the cursor grazes multi-monitor borders.
//  Enhanced for Epic 2 - Story 2.1: Multi-Display Screen Capture
//

import Foundation
import AppKit
import Combine
import CoreGraphics

@MainActor
final class ActiveDisplayTracker: ObservableObject {
    @Published private(set) var activeDisplayID: CGDirectDisplayID?

    private var timer: Timer?
    private var candidateID: CGDirectDisplayID?
    private var candidateSince: Date?
    private var screensObserver: Any?

    // Multi-display tracking
    private var lastKnownDisplays: [DisplayInfo] = []
    private var configurationChangesContinuation: AsyncStream<DisplayChangeEvent>.Continuation?

    // Tunables
    private let pollHz: Double
    private let debounceSeconds: TimeInterval
    private let hysteresisInset: CGFloat

    init(pollHz: Double = 6.0, debounceMs: Double = 400, hysteresisInset: CGFloat = 10) {
        self.pollHz = max(1.0, pollHz)
        self.debounceSeconds = max(0.0, debounceMs / 1000.0)
        self.hysteresisInset = hysteresisInset

        // Observe screen parameter changes to refresh immediately
        screensObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDisplayConfigurationChange()
            }
        }

        start()

        // Initialize display list
        lastKnownDisplays = getActiveDisplays()
    }

    deinit {
        // Avoid calling main-actor methods from deinit
        timer?.invalidate()
        timer = nil
        if let obs = screensObserver { NotificationCenter.default.removeObserver(obs) }
        configurationChangesContinuation?.finish()
    }

    private func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / pollHz, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stop() { timer?.invalidate(); timer = nil }

    private func resetCandidateDueToDisplayChange() {
        candidateID = nil
        candidateSince = nil
    }

    private func tick() {
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: hysteresisInset, dy: hysteresisInset).contains(loc) })
                ?? NSScreen.screens.first(where: { $0.frame.contains(loc) })
        else { return }

        let newID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let id = newID else { return }

        let now = Date()
        if candidateID != id {
            candidateID = id
            candidateSince = now
            return
        }

        // Candidate is stable long enough
        if activeDisplayID != id, let since = candidateSince, now.timeIntervalSince(since) >= debounceSeconds {
            activeDisplayID = id
        }
    }

    // MARK: - Multi-Display Support (Epic 2 - Story 2.1)

    /// Get all currently active displays
    /// - Returns: Array of DisplayInfo for all connected displays
    func getActiveDisplays() -> [DisplayInfo] {
        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16) // Max 16 displays

        let result = CGGetActiveDisplayList(16, &displayIDs, &displayCount)
        guard result == .success, displayCount > 0 else {
            return []
        }

        let currentActiveID = activeDisplayID

        return displayIDs.prefix(Int(displayCount)).compactMap { displayID in
            DisplayInfo.from(
                displayID: displayID,
                isActive: displayID == currentActiveID
            )
        }
    }

    /// Get the primary display (currently active or main display)
    /// - Returns: DisplayInfo for the primary display, or nil if none found
    func getPrimaryDisplay() -> DisplayInfo? {
        // First, try to get the currently active display (where mouse is)
        if let activeID = activeDisplayID {
            return DisplayInfo.from(displayID: activeID, isActive: true)
        }

        // Fall back to main display (contains menu bar)
        let mainDisplayID = CGMainDisplayID()
        return DisplayInfo.from(displayID: mainDisplayID, isActive: false)
    }

    /// AsyncStream that emits display configuration change events
    var configurationChanges: AsyncStream<DisplayChangeEvent> {
        AsyncStream { continuation in
            self.configurationChangesContinuation = continuation

            // Emit initial configuration
            let initialDisplays = self.getActiveDisplays()
            if !initialDisplays.isEmpty {
                continuation.yield(.reconfigured(initialDisplays))
            }

            continuation.onTermination = { @Sendable _ in
                // Clean up if needed
            }
        }
    }

    /// Handle display configuration changes (called from notification observer)
    private func handleDisplayConfigurationChange() {
        // Reset candidate to avoid stale display IDs
        resetCandidateDueToDisplayChange()

        // Emit reconfiguring event first
        configurationChangesContinuation?.yield(.reconfiguring)

        // Get new display configuration
        let currentDisplays = getActiveDisplays()
        let previousDisplays = lastKnownDisplays

        // Detect what changed
        let currentIDs = Set(currentDisplays.map { $0.id })
        let previousIDs = Set(previousDisplays.map { $0.id })

        // Displays added
        let addedIDs = currentIDs.subtracting(previousIDs)
        for id in addedIDs {
            if let display = currentDisplays.first(where: { $0.id == id }) {
                configurationChangesContinuation?.yield(.added(display))
            }
        }

        // Displays removed
        let removedIDs = previousIDs.subtracting(currentIDs)
        for id in removedIDs {
            configurationChangesContinuation?.yield(.removed(id))
        }

        // Emit reconfigured event with new configuration
        if !addedIDs.isEmpty || !removedIDs.isEmpty || currentDisplays.count != previousDisplays.count {
            configurationChangesContinuation?.yield(.reconfigured(currentDisplays))
        }

        // Update known displays
        lastKnownDisplays = currentDisplays

        // Refresh active display immediately
        tick()
    }
}
