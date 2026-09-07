//
//  DeviceState.swift
//  SmartShop
//

import Foundation
import Security

/// Device-local auth flags: does this device have a PIN, is it unlocked, and is
/// the user browsing as a guest.
///
/// Ports `src/lib/pin.ts` and `src/lib/guest.ts`. The web keeps these in
/// `localStorage` / `sessionStorage`; on iOS the "has a PIN" flag goes in the
/// **Keychain** instead, because `UserDefaults` is plain plist inside the app
/// container and survives in unencrypted device backups.
///
/// `isUnlocked` deliberately stays in memory only. That is the direct analogue
/// of `sessionStorage`: relaunching the app re-locks it, which is the point.
@MainActor
@Observable
final class DeviceState {
    private enum Key {
        static let pinFlag = "ss247_pin_device"
        static let guest = "smartshop_guest"
    }

    /// Not persisted — resets to `false` on every cold launch.
    private(set) var isUnlocked = false
    private(set) var hasPinOnDevice: Bool
    private(set) var isGuest: Bool

    init() {
        hasPinOnDevice = Keychain.exists(Key.pinFlag)
        isGuest = UserDefaults.standard.bool(forKey: Key.guest)
    }

    func markPinOnDevice() {
        Keychain.set("1", for: Key.pinFlag)
        hasPinOnDevice = true
    }

    func clearPinOnDevice() {
        Keychain.remove(Key.pinFlag)
        hasPinOnDevice = false
        isUnlocked = false
    }

    func markUnlocked() { isUnlocked = true }
    func lock() { isUnlocked = false }

    func startGuest() {
        UserDefaults.standard.set(true, forKey: Key.guest)
        isGuest = true
    }

    func stopGuest() {
        UserDefaults.standard.set(false, forKey: Key.guest)
        isGuest = false
    }
}

/// Minimal Keychain wrapper for small flags.
enum Keychain {
    private static let service = "dk.smartshop.app"

    private static func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    static func set(_ value: String, for key: String) {
        remove(key)
        var attributes = query(key)
        attributes[kSecValueData as String] = Data(value.utf8)
        // Available after first unlock, never synced to iCloud or other devices.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func exists(_ key: String) -> Bool {
        SecItemCopyMatching(query(key) as CFDictionary, nil) == errSecSuccess
    }

    static func remove(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
