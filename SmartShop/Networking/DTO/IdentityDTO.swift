//
//  IdentityDTO.swift
//  SmartShop
//

// Wire types for:
//
//   GET /mobile/identity/status
//   POST /mobile/identity/document
//
// Request bodies only, for now: POST /mobile/identity/mitid/{session,result}.
// The spec (`/mobile/docs-json`) does not type the responses of those two or
// of GET/POST/DELETE /mobile/identity/face, so their DTOs wait on a real
// payload rather than a guess.
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
    /// `mitid`, `passport_eid`, `third_party_kyc` or `manual`. Null when
    /// nothing was submitted.
    var method: String?
    /// `passport`, `driving_licence` or `national_id`.
    var documentType: String?
    /// Set only when the newest decision was a refusal.
    var rejectionReason: String?
    /// Whether age has been *proven*, which only a broker can do. Null for a
    /// staff-reviewed document. Never infer age from `isVerified`.
    var ageOver18: Bool?
    /// Whether to offer the MitID button at all, including as the way out of
    /// a rejection. Mirrors `features.mitid` in `/app/config`.
    var mitIdAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case state, isVerified, method, documentType, rejectionReason, ageOver18, mitIdAvailable
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = try c.decode(String.self, forKey: .state)
        isVerified = try c.decode(Bool.self, forKey: .isVerified)
        // The spec types this as `object` with a string example. Read it as a
        // string when it is one, rather than failing the whole status over it.
        rejectionReason = try? c.decodeIfPresent(String.self, forKey: .rejectionReason)
        method = try c.decodeIfPresent(String.self, forKey: .method)
        documentType = try c.decodeIfPresent(String.self, forKey: .documentType)
        // Typed `object` in the spec, like `rejectionReason`.
        ageOver18 = try? c.decodeIfPresent(Bool.self, forKey: .ageOver18)
        // Absent is read as unavailable, so an older server never offers a
        // MitID button that leads nowhere.
        mitIdAvailable = try c.decodeIfPresent(Bool.self, forKey: .mitIdAvailable) ?? false
    }
}

/// `StartMitIdDto`. `ios` decides how the callback hands control back.
nonisolated struct StartIdentityMitIDRequestDTO: Encodable, Sendable {
    var deviceType = "ios"
}

/// `MitIdResultDto`. Takes the one-time `reference` from the deep link. The
/// Postman example shows `{code, state}`, which is stale, exactly as it was
/// for `/auth/mitid/complete`.
nonisolated struct IdentityMitIDResultRequestDTO: Encodable, Sendable {
    var reference: String
}

/// `GET /identity/face`, and the answer to enrolling or withdrawing.
///
/// `enrolled` means indexed and usable at a till, not merely uploaded.
/// `available: false` means no face collection in this environment, which is
/// the normal case on dev (eu-north-1 has no Rekognition).
nonisolated struct FaceStatusDTO: Decodable, Sendable {
    var available: Bool
    var enrolled: Bool

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        available = c.first(Bool.self, "available") ?? false
        enrolled = c.first(Bool.self, "enrolled") ?? false
    }
}
