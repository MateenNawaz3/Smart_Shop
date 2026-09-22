//
//  DeviceDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   POST   /mobile/me/devices
//   GET    /mobile/me/devices
//   DELETE /mobile/me/devices/{id}
//   POST   /mobile/me/devices/{id}/pin
//   POST   /mobile/me/devices/{id}/pin/verify
//   DELETE /mobile/me/devices/{id}/pin

nonisolated struct RegisterDeviceRequestDTO: Encodable, Sendable {
    var platform: String
    var appVersion: String
    /// Stable per-installation identifier. The server upserts on this, so
    /// sending the same value at every launch re-registers rather than
    /// accumulating duplicate handsets.
    var deviceIdentifier: String
    var pushToken: String?
    /// `apns` on iOS. Absent when there is no push token to go with it.
    var pushProvider: String?
}

/// Registration answers with the id alone — and calls it `deviceId`, where the
/// listing calls the same value `id`. Not a typo; two different shapes.
nonisolated struct RegisteredDeviceIdDTO: Decodable, Sendable {
    var deviceId: String
}

nonisolated struct DeviceDTO: Decodable, Sendable {
    var id: String
    var platform: String
    var appVersion: String?
    var isTrusted: Bool
    var hasPin: Bool
    var lastSeenAt: Date?
    var registeredAt: Date?
}

nonisolated struct SetPinRequestDTO: Encodable, Sendable {
    /// Exactly four digits; anything else is a 400. Note the server does *not*
    /// reject a weak PIN such as 1111 — that check, if wanted, is the app's.
    var pin: String
}

/// The reply to `POST .../pin/verify`.
///
/// A wrong PIN is **not** an error: the call answers 200 with `success: true`
/// and `ok: false`. Treating a failed unlock as a failed request would miss the
/// attempt counter entirely.
///
///   - `attemptsLeft` counts down 4, 3, 2, 1, 0 and resets to 5 on a correct PIN
///   - `lockedForSeconds` appears only once locked, and counts down from 900
///   - while locked, even the correct PIN answers `ok: false`
nonisolated struct PinVerificationDTO: Decodable, Sendable {
    var ok: Bool
    var attemptsLeft: Int?
    var lockedForSeconds: Int?
}

/// `POST .../pin` answers `{ "ok": true }`.
nonisolated struct PinMutationDTO: Decodable, Sendable {
    var ok: Bool
}
