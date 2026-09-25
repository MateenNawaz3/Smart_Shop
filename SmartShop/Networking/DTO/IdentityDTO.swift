//
//  IdentityDTO.swift
//  SmartShop
//

// Wire types for:
//
//   GET /mobile/identity/status
//   POST /mobile/identity/document
//
// Still to come: GET/POST/DELETE /mobile/identity/face and
// POST /mobile/identity/mitid/{session,result}.
//
// `enrolled` means a face is actually indexed and usable at a till, not
// that a photo was uploaded. `available: false` means no Rekognition in
// this environment — expect it, eu-north-1 does not offer it.

import Foundation

/// `IdentityStatusDto`. Both endpoints return it: the upload answers `202`
/// with the status it just queued, which is `pending`, never `verified`.
nonisolated struct IdentityStatusDTO: Decodable, Sendable {
    /// `unverified`, `pending`, `verified`, `expired` or `rejected`.
    var state: String
    var isVerified: Bool
    /// Set only when the newest decision was a refusal.
    var rejectionReason: String?

    enum CodingKeys: String, CodingKey {
        case state, isVerified, rejectionReason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = try c.decode(String.self, forKey: .state)
        isVerified = try c.decode(Bool.self, forKey: .isVerified)
        // The spec types this as `object` with a string example. Read it as a
        // string when it is one, rather than failing the whole status over it.
        rejectionReason = try? c.decodeIfPresent(String.self, forKey: .rejectionReason)
    }
}
