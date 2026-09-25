//
//  AccessDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET/POST /mobile/access/credentials
//   DELETE /mobile/access/credentials/{id}
//   GET /mobile/access/history
//   POST /mobile/access/unlock
//   POST /mobile/access/help
//
// The spec (`/mobile/docs-json`) types every request here but **none of the
// responses**, and neither the Postman collection nor the integration guide
// carries an example. The response types below are therefore read
// tolerantly: each field accepts the handful of names the server's
// conventions make likely, and anything unreadable falls to the safe side —
// a decision we cannot read is a refusal, never a grant. Replace the
// alternatives with the one real name once a live payload has been seen.
//
// The unlock response carries a decision and one of seven refusal reasons.
// doorOpened is false when the decision was a grant but no physical door
// responded — those are different facts and the UI must not merge them.

/// `AddCredentialDto`.
nonisolated struct AddCredentialRequestDTO: Encodable, Sendable {
    /// `phone_nfc`, `key_fob` or `qr`. A phone or QR secret is minted by the
    /// server and returned ONCE; it cannot be read back.
    var type: String
    /// Required for a key fob: the number printed on it. The field is
    /// `identifier`, not `value`.
    var identifier: String?
    var label: String?
    /// Ties a phone credential to a device, so forgetting the device removes
    /// it. The server's device id, not `installationIdentifier`.
    var deviceId: String?
}

/// `UnlockDto`.
nonisolated struct UnlockRequestDTO: Encodable, Sendable {
    /// `nfc`, `qr` or `app_button`. The server defaults to `app_button`.
    var method: String
    /// A specific door, not a store. There is deliberately no endpoint listing
    /// doors: the id comes off the reader the customer taps.
    var accessPointId: String?
    var nfcTagId: String?
    var qrCode: String?
    /// Omit for an in-app unlock, which needs no credential.
    var credentialSecret: String?
}

/// `DoorHelpDto`. Every field is optional, but send the door when it is known:
/// it tells staff which entrance someone is standing at.
nonisolated struct DoorHelpRequestDTO: Encodable, Sendable {
    var accessPointId: String?
    var storeId: String?
    /// Shown to staff as-is. At most 500 characters.
    var note: String?
}

// MARK: - Responses

/// A coding key built from any string, so a response can be read by trying
/// several candidate names for one field.
nonisolated struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

nonisolated extension KeyedDecodingContainer where Key == AnyCodingKey {
    /// The first of `names` that is present and decodes as `T`.
    func first<T: Decodable>(_ type: T.Type, _ names: String...) -> T? {
        for name in names {
            if let value = try? decodeIfPresent(T.self, forKey: AnyCodingKey(name)) {
                return value
            }
        }
        return nil
    }
}

/// A list that arrives either bare or wrapped as `{items: [...]}`, the
/// paginated shape `/notifications` and `/purchases` use.
nonisolated struct AccessListDTO<Element: Decodable & Sendable>: Decodable, Sendable {
    var items: [Element]

    init(from decoder: any Decoder) throws {
        if let bare = try? [Element](from: decoder) {
            items = bare
            return
        }
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        items = c.first([Element].self, "items", "credentials", "events", "history", "tickets") ?? []
    }
}

/// One door credential: a phone, a key fob or a QR code.
nonisolated struct AccessCredentialDTO: Decodable, Sendable {
    var id: String
    /// `phone_nfc`, `key_fob` or `qr`.
    var type: String
    var label: String?
    /// A fob number is hashed on the way in; only the last four stay readable.
    var lastFour: String?
    /// Minted by the server for a phone or QR credential and returned ONCE,
    /// on creation. Never present in a listing.
    var secret: String?
    var revoked: Bool

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        guard let id = c.first(String.self, "id", "credentialId") else {
            throw DecodingError.keyNotFound(AnyCodingKey("id"), .init(codingPath: c.codingPath, debugDescription: "credential without an id"))
        }
        self.id = id
        type = c.first(String.self, "type") ?? ""
        label = c.first(String.self, "label")
        lastFour = c.first(String.self, "last4", "lastFour", "identifierLast4", "identifierHint", "hint", "maskedIdentifier")
        secret = c.first(String.self, "secret", "credentialSecret")
        revoked = c.first(Bool.self, "revoked", "isRevoked")
            ?? (c.first(String.self, "revokedAt") != nil)
    }
}

/// One entry of `/access/history`: a grant or a refusal at a door.
nonisolated struct AccessEventDTO: Decodable, Sendable {
    var id: String
    var at: Date
    var granted: Bool
    /// One of the seven refusal reasons, on a refusal.
    var reason: String?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        at = c.first(Date.self, "occurredAt", "createdAt", "at", "timestamp") ?? .now
        id = c.first(String.self, "id") ?? UUID().uuidString
        granted = AccessDecision.isGrant(c)
        reason = c.first(String.self, "reason", "denialReason", "refusalReason")
    }
}

/// `POST /access/unlock`.
nonisolated struct UnlockResultDTO: Decodable, Sendable {
    var granted: Bool
    /// False on a grant when no physical door responded. A different fact from
    /// the decision, and the one that says whether to walk in.
    var doorOpened: Bool
    var reason: String?
    /// Something the customer can act on, written by the server.
    var message: String?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        granted = AccessDecision.isGrant(c)
        doorOpened = c.first(Bool.self, "doorOpened") ?? false
        reason = c.first(String.self, "reason", "denialReason", "refusalReason")
        message = c.first(String.self, "message", "customerMessage")
    }
}

/// `POST /access/help` answers with the store's phone number.
nonisolated struct DoorHelpResultDTO: Decodable, Sendable {
    var phone: String?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        phone = c.first(String.self, "storePhone", "phone", "phoneNumber", "contactPhone")
    }
}

/// Reads a door decision from whichever form it arrives in. Anything that is
/// not recognisably a grant is a refusal.
nonisolated enum AccessDecision {
    static func isGrant(_ c: KeyedDecodingContainer<AnyCodingKey>) -> Bool {
        if let flag = c.first(Bool.self, "granted", "allowed", "approved", "ok") { return flag }
        let word = c.first(String.self, "decision", "outcome", "result")?.lowercased()
        return word == "granted" || word == "grant" || word == "allow" || word == "allowed"
    }
}
