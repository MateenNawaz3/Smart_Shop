//
//  DeviceService.swift
//  SmartShop
//

import Foundation
import UIKit

/// Handset registration for push, and the per-device PIN.
///
/// Follows the existing convention in this folder: the protocol and its
/// supporting types live together, with the API conformance in `Services/API`.
///
/// Supersedes the locally-derived hash in `PinService.swift`. The important
/// difference is whose PIN it is: the old one belonged to the *account*, so
/// clearing it anywhere cleared it everywhere. This one belongs to **this
/// device** — five wrong entries lock this handset for 15 minutes, and a thief
/// cannot lock the owner out of their other phone.
nonisolated protocol DeviceService: Sendable {
    /// Registers this handset and returns its server-side id.
    ///
    /// Upserts on the device identifier, so calling it at every launch is
    /// correct and cheap.
    @discardableResult
    func registerCurrentDevice(pushToken: String?) async throws -> String

    func devices() async throws -> [RegisteredDevice]

    /// The answer to a lost phone: removes its push token and its PIN.
    func forgetDevice(id: String) async throws

    func setPin(_ pin: String, deviceID: String) async throws
    func verifyPin(_ pin: String, deviceID: String) async throws -> PinCheck
    func removePin(deviceID: String) async throws
}

nonisolated struct RegisteredDevice: Sendable, Identifiable, Equatable {
    var id: String
    var platform: String
    var appVersion: String?
    var isTrusted: Bool
    var hasPin: Bool
    var lastSeenAt: Date?
    var registeredAt: Date?

    /// True for the handset this code is running on.
    func isCurrent(_ identity: DeviceIdentity) -> Bool {
        id == identity.serverDeviceID
    }
}

/// Who this handset is, across launches.
///
/// Two different identifiers, and they are easy to confuse:
///
///   - `installationIdentifier` is ours, sent as `deviceIdentifier`, and is what
///     the server upserts on.
///   - `serverDeviceID` is the id the server hands back, and is what every PIN
///     endpoint is addressed by.
///
/// Both live in the Keychain rather than `UserDefaults`, so a reinstall does not
/// silently orphan the registration — and so the PIN's device cannot be
/// impersonated by editing a plist.
nonisolated struct DeviceIdentity: Sendable {
    private enum Key {
        static let installation = "ss247_device_identifier"
        static let serverID = "ss247_device_id"
    }

    /// Where the two ids are kept. The Keychain in the app; tests substitute an
    /// in-memory store so parallel suites cannot hand each other a handset.
    var storage: any DeviceIdentityStorage

    init(storage: any DeviceIdentityStorage = KeychainDeviceIdentityStorage()) {
        self.storage = storage
    }

    /// Stable for the life of the installation.
    ///
    /// `identifierForVendor` is the natural choice but it is nil before first
    /// unlock and changes when the last app from a vendor is removed, so it is
    /// only a seed: whatever we first resolve is written to the Keychain and
    /// that value is what we keep using.
    var installationIdentifier: String {
        if let existing = storage.get(Key.installation) { return existing }
        let fresh = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        storage.set(fresh, for: Key.installation)
        return fresh
    }

    /// The id returned by `POST /me/devices`. Nil until the first registration
    /// of this install succeeds — every PIN call needs it, so `PinSetupView` and
    /// `UnlockView` cannot work before then.
    var serverDeviceID: String? {
        get { storage.get(Key.serverID) }
        nonmutating set {
            if let newValue {
                storage.set(newValue, for: Key.serverID)
            } else {
                storage.remove(Key.serverID)
            }
        }
    }

    func clear() {
        storage.remove(Key.serverID)
    }
}

nonisolated protocol DeviceIdentityStorage: Sendable {
    func get(_ key: String) -> String?
    func set(_ value: String, for key: String)
    func remove(_ key: String)
}

nonisolated struct KeychainDeviceIdentityStorage: DeviceIdentityStorage {
    func get(_ key: String) -> String? { Keychain.get(key) }
    func set(_ value: String, for key: String) { Keychain.set(value, for: key) }
    func remove(_ key: String) { Keychain.remove(key) }
}

/// Raised when a PIN call is made before this handset has been registered.
nonisolated struct DeviceNotRegistered: LocalizedError {
    var errorDescription: String? {
        "This device has not been registered yet."
    }
}
