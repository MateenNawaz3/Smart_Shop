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
// The response shapes were confirmed by the backend on 2026-09-28, after our
// first guesses got history and revocation wrong:
//
//   unlock   {granted, reason, message, storeName, doorOpened}
//   history  {id, storeName, method, result, denialReason, doorUnlocked, occurredAt}
//
// The same fact is `doorOpened` on unlock and `doorUnlocked` on history. That
// is deliberate on their side (renaming would break working clients), so do
// not "fix" one to match the other.
//
// Anything missing still falls to the safe side: a decision we cannot read is
// a refusal, never a grant. doorOpened is false when the decision was a grant
// but no physical door responded — different facts, and the UI must not merge
// them.

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
    /// A revoked credential stays in the list with `status: "revoked"`: the
    /// server keeps the record of what was issued. There is no `revokedAt`.
    var status: String?

    var revoked: Bool { status?.lowercased() == "revoked" }
}

/// One entry of `/access/history`: a grant or a refusal at a door.
nonisolated struct AccessEventDTO: Decodable, Sendable {
    var id: String
    var occurredAt: Date
    var storeName: String?
    /// `nfc`, `qr` or `app_button`.
    var method: String?
    /// `granted` or `denied`. A string here, where unlock sends a boolean.
    var result: String?
    /// One of the seven refusal reasons, on a refusal.
    var denialReason: String?
    /// Whether a physical door moved. `doorOpened` on unlock.
    var doorUnlocked: Bool?

    var granted: Bool { result?.lowercased() == "granted" }
}

/// `POST /access/unlock`.
nonisolated struct UnlockResultDTO: Decodable, Sendable {
    var granted: Bool
    /// False on a grant when no physical door responded. A different fact from
    /// the decision, and the one that says whether to walk in.
    var doorOpened: Bool
    /// One of the seven refusal reasons, such as `not_verified`.
    var reason: String?
    /// A finished sentence for the customer, written per reason by the server.
    /// It also covers a grant where the door stayed shut. Show it as-is.
    var message: String?
    var storeName: String?

    private enum CodingKeys: String, CodingKey {
        case granted, doorOpened, reason, message, storeName
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        granted = (try? c.decodeIfPresent(Bool.self, forKey: .granted)) ?? false
        doorOpened = (try? c.decodeIfPresent(Bool.self, forKey: .doorOpened)) ?? false
        reason = try? c.decodeIfPresent(String.self, forKey: .reason)
        message = try? c.decodeIfPresent(String.self, forKey: .message)
        storeName = try? c.decodeIfPresent(String.self, forKey: .storeName)
    }
}

/// `POST /access/help` answers with the store's phone number.
nonisolated struct DoorHelpResultDTO: Decodable, Sendable {
    var storePhone: String?
}
