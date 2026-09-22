//
//  APIEnvelope.swift
//  SmartShop
//

import Foundation

/// The response shape every mobile endpoint returns, on success and on failure
/// alike:
///
///     { success, message, code, data }
///
/// Read `.data` when `success` is true and `.message` when it is false; tell
/// them apart by `success`. `code` is the stable identifier to translate
/// against — never the message text, which is prose and may change.
///
/// (admin-api is NOT enveloped. kiosk-api is. This type is for /mobile only.)
nonisolated struct APIEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
    var success: Bool
    var message: EnvelopeMessage?
    var code: String?
    var data: Payload?
}

/// `message` is usually a string, but a `VALIDATION_ERROR` answers with an
/// array of them — one per field that failed:
///
///     {"success":false,"message":["email must be an email", …],
///      "code":"VALIDATION_ERROR"}
///
/// Decoding it as a plain `String` therefore throws on every 400 and loses the
/// only useful part of the response. Accept both shapes.
nonisolated enum EnvelopeMessage: Decodable, Sendable {
    case one(String)
    case many([String])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .one(single)
        } else {
            self = .many(try container.decode([String].self))
        }
    }

    /// Flattened for display. The server returns the list in field order, which
    /// is the order the form shows them in, so joining keeps it readable.
    var text: String {
        switch self {
        case .one(let value): value
        case .many(let values): values.joined(separator: "\n")
        }
    }
}
