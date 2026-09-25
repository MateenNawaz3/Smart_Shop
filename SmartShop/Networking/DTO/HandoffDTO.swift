//
//  HandoffDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   POST /mobile/handoff/token
//
// An opaque single-use token, valid 60 seconds, shown as a QR code or
// emitted over NFC so a till can attach the basket to this account.
// Deliberately carries no customer identity.
//
// The spec types no response, so the token is read tolerantly, like the
// access types. With no expiry in the answer, the documented 60 seconds is
// assumed — shorter is safe, longer would show a code the till refuses.

nonisolated struct HandoffTokenDTO: Decodable, Sendable {
    var token: String
    var expiresAt: Date?
    var expiresIn: Int?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        guard let token = c.first(String.self, "token", "handoffToken", "code") else {
            throw DecodingError.keyNotFound(
                AnyCodingKey("token"),
                .init(codingPath: c.codingPath, debugDescription: "handoff answer without a token")
            )
        }
        self.token = token
        expiresAt = c.first(Date.self, "expiresAt")
        expiresIn = c.first(Int.self, "expiresIn", "ttl", "ttlSeconds")
    }
}
