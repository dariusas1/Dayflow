//
//  KillSwitchManager.swift
//  FocusLock
//
//  Global hotkey manager for Nuclear Bedtime mode
//  Hotkey: ⌘⌥⇧Z + passphrase to disable enforcement
//

import Foundation
import AppKit
import Carbon
import os.log

@MainActor
class KillSwitchManager: ObservableObject {
    static let shared = KillSwitchManager()

    private let logger = Logger(subsystem: "FocusLock", category: "KillSwitch")

    // Published state
    @Published var isPassphraseSet: Bool = false
    @Published var showPassphraseEntry: Bool = false

    // Hotkey state
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // Keychain keys
    private let keychainService = "com.dayflow.focuslock.killswitch"
    private let keychainAccount = "passphrase"

    // Hotkey definition: ⌘⌥⇧Z
    private let hotKeyID = EventHotKeyID(signature: OSType("KSWI".fourCharCodeValue!), id: 1)
    private let hotKeyCode: UInt32 = 6 // Z key
    private let hotKeyModifiers: UInt32 = UInt32(cmdKey | optionKey | shiftKey)

    private init() {
        loadPassphraseStatus()
    }

    // MARK: - Passphrase Management

    /// Set new passphrase for Kill Switch
    func setPassphrase(_ passphrase: String) {
        guard !passphrase.isEmpty else {
            logger.error("Attempted to set empty passphrase")
            return
        }

        // Store in Keychain
        let data = passphrase.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]

        // Delete existing if present
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            isPassphraseSet = true
            logger.info("Kill Switch passphrase set successfully")

            // Register global hotkey
            registerGlobalHotkey()
        } else {
            logger.error("Failed to save passphrase to Keychain: \(status)")
        }
    }

    /// Verify entered passphrase against stored one
    func validatePassphrase(_ input: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let storedPassphrase = String(data: data, encoding: .utf8) else {
            logger.error("Failed to retrieve passphrase from Keychain: \(status)")
            return false
        }

        let isValid = input == storedPassphrase

        if isValid {
            logger.info("Kill Switch passphrase validated successfully")
            AnalyticsService.shared.capture("killswitch_activated", [:])
        } else {
            logger.warning("Invalid Kill Switch passphrase entered")
            AnalyticsService.shared.capture("killswitch_invalid_attempt", [:])
        }

        return isValid
    }

    /// Remove passphrase from Keychain
    func removePassphrase() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            isPassphraseSet = false
            logger.info("Kill Switch passphrase removed")

            // Unregister global hotkey
            unregisterGlobalHotkey()
        } else {
            logger.error("Failed to remove passphrase: \(status)")
        }
    }

    private func loadPassphraseStatus() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        isPassphraseSet = (status == errSecSuccess)

        if isPassphraseSet {
            // Register hotkey if passphrase exists
            registerGlobalHotkey()
        }
    }

    // MARK: - Global Hotkey

    func registerGlobalHotkey() {
        // Unregister existing if present
        unregisterGlobalHotkey()

        // Create event handler
        var eventHandlerUPP: EventHandlerUPP? = nil
        eventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            Task { @MainActor in
                KillSwitchManager.shared.handleHotkeyPress()
            }
            return noErr
        }

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetEventDispatcherTarget(), eventHandlerUPP, 1, &eventType, nil, &eventHandler)

        guard status == noErr else {
            logger.error("Failed to install hotkey event handler: \(status)")
            return
        }

        // Register hot key
        var hotKeyID = self.hotKeyID
        let registerStatus = RegisterEventHotKey(hotKeyCode, hotKeyModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)

        if registerStatus == noErr {
            logger.info("Kill Switch global hotkey registered: ⌘⌥⇧Z")
        } else {
            logger.error("Failed to register global hotkey: \(registerStatus)")
        }
    }

    func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            logger.info("Kill Switch global hotkey unregistered")
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handleHotkeyPress() {
        logger.info("Kill Switch hotkey pressed (⌘⌥⇧Z)")

        // Show passphrase entry modal
        showPassphraseEntry = true
    }

    // MARK: - Cleanup

    deinit {
        unregisterGlobalHotkey()
    }
}

// MARK: - String Extension for FourCharCode

extension String {
    var fourCharCodeValue: FourCharCode? {
        guard self.count == 4 else { return nil }
        var result: FourCharCode = 0
        for char in self.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
