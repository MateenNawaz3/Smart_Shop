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
///
/// `nonisolated` because the networking layer reads tokens off the main actor.
/// The Security framework calls underneath are thread-safe, and the type holds
/// no state of its own.
nonisolated enum Keychain {
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

    /// Reads a stored value back. `exists` alone was enough while the only
    /// entries were flags; the Mobile API's tokens have to be read, not just
    /// counted.
    static func get(_ key: String) -> String? {
        var attributes = query(key)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(attributes as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func remove(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
