//
//  PermissionsManager.swift
//  FocusLock
//
//  Manages permissions for AX, Screen Recording, and Screen Time
//

import Foundation
import SwiftUI
import Combine
import AppKit
import ScreenCaptureKit
import Accessibility
import os.log

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    // MARK: - Published Properties
    @Published var hasAccessibilityPermission: Bool = false
    @Published var hasScreenRecordingPermission: Bool = false
    @Published var hasScreenTimePermission: Bool = false

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init() {
        checkAllPermissions()
        setupPermissionObservers()
    }

    // MARK: - Permission Checking
    func checkAllPermissions() {
        hasAccessibilityPermission = checkAccessibilityPermission()
        hasScreenRecordingPermission = checkScreenRecordingPermission()
        hasScreenTimePermission = checkScreenTimePermission()
    }

    private func checkAccessibilityPermission() -> Bool {
        // Check if app has accessibility permissions
        let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): kCFBooleanTrue] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func checkScreenRecordingPermission() -> Bool {
        // Check if app has screen recording permissions
        return CGPreflightScreenCaptureAccess()
    }

    private func checkScreenTimePermission() -> Bool {
        // Check if app has Screen Time permissions
        // This is a simplified check - in practice, you'd need Family Controls authorization
        // For now, assume no Screen Time permissions needed
        return true
    }

    // MARK: - Permission Requesting
    func requestAccessibilityPermission() {
        print("[PermissionsManager] Requesting accessibility permission")
        // Show system dialog to enable accessibility
        showAccessibilitySettings()
    }

    func requestScreenRecordingPermission() {
        print("[PermissionsManager] Requesting screen recording permission")
        // Show system dialog to enable screen recording
        showScreenRecordingSettings()
    }

    func requestScreenTimePermission() {
        print("[PermissionsManager] Requesting screen time permission")
        // Request Screen Time authorization
        requestScreenTimeAuthorization()
    }

    // MARK: - Private Methods
    private func setupPermissionObservers() {
        // Set up observers to detect when permissions change
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)
    }

    private func showAccessibilitySettings() {
        // Open System Preferences -> Accessibility
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func showScreenRecordingSettings() {
        // Open System Preferences -> Security & Privacy -> Screen Recording
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    private func requestScreenTimeAuthorization() {
        // Request Family Controls authorization
        // This is not implemented for now
        DispatchQueue.main.async {
            self.hasScreenTimePermission = true
        }
    }

    // MARK: - Permission Status
    var allPermissionsGranted: Bool {
        return hasAccessibilityPermission && hasScreenRecordingPermission && hasScreenTimePermission
    }

    var missingPermissions: [String] {
        var missing: [String] = []

        if !hasAccessibilityPermission {
            missing.append("Accessibility")
        }
        if !hasScreenRecordingPermission {
            missing.append("Screen Recording")
        }
        if !hasScreenTimePermission {
            missing.append("Screen Time")
        }

        return missing
    }
}

// MARK: - Permission Wizard View
struct PermissionsWizard: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("FocusLock Permissions")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color.black)

            Text("FocusLock requires several permissions to work properly. Please grant all of the following permissions:")
                .font(.custom("Nunito", size: 14))
                .foregroundColor(Color.gray)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Read text from application windows for task detection",
                    isGranted: permissionsManager.hasAccessibilityPermission,
                    onRequest: {
                        permissionsManager.requestAccessibilityPermission()
                    }
                )

                PermissionRow(
                    title: "Screen Recording",
                    description: "Capture screenshots for OCR task detection",
                    isGranted: permissionsManager.hasScreenRecordingPermission,
                    onRequest: {
                        permissionsManager.requestScreenRecordingPermission()
                    }
                )

                PermissionRow(
                    title: "Screen Time",
                    description: "Block distracting applications during focus sessions",
                    isGranted: permissionsManager.hasScreenTimePermission,
                    onRequest: {
                        permissionsManager.requestScreenTimePermission()
                    }
                )
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.custom("Nunito", size: 16))
                .foregroundColor(Color.gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Spacer()

                Button(permissionsManager.allPermissionsGranted ? "Continue" : "Grant Missing") {
                    if !permissionsManager.allPermissionsGranted {
                        // Request missing permissions
                        for permission in permissionsManager.missingPermissions {
                            switch permission {
                            case "Accessibility":
                                permissionsManager.requestAccessibilityPermission()
                            case "Screen Recording":
                                permissionsManager.requestScreenRecordingPermission()
                            case "Screen Time":
                                permissionsManager.requestScreenTimePermission()
                            default:
                                break
                            }
                        }
                    }

                    if permissionsManager.allPermissionsGranted {
                        dismiss()
                    }
                }
                .font(.custom("Nunito", size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(permissionsManager.allPermissionsGranted ? Color.blue : Color.gray)
                .cornerRadius(8)
                .disabled(permissionsManager.allPermissionsGranted)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Nunito", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(Color.black)

                Text(description)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(Color.gray)
            }

            Spacer()

            Button(isGranted ? "✓ Granted" : "Grant") {
                onRequest()
            }
            .font(.custom("Nunito", size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isGranted ? Color.green : Color.blue)
            .cornerRadius(6)
            .disabled(isGranted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}