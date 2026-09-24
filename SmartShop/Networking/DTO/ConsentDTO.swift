//
//  ConsentDTO.swift
//  SmartShop
//

import Foundation

/// One row of `GET /mobile/me/consents`.
///
/// Consents are a **list of records, not a set of booleans**: each carries when
/// it was granted or withdrawn and under which version. Marketing is one entry
/// among several, which is why `PATCH /me` refuses `marketingOptIn` — a flag
/// cannot record consent, only a record can.
nonisolated struct ConsentDTO: Decodable, Sendable {
    /// `terms` · `privacy` · `marketing` · `age_data_processing` ·
    /// `face_biometric`. Decoded as a string rather than an enum so a consent
    /// type added later does not break the whole list.
    var type: String
    var active: Bool
    var grantedAt: Date?
    var withdrawnAt: Date?
    var version: String?
    var source: String?
    /// False for `terms` and `privacy` — those cannot be withdrawn while the
    /// account exists, so the UI must not offer a switch for them.
    var withdrawableByAdmin: Bool?
}

/// `PUT /mobile/me/consents`.
///
/// Only the three withdrawable types are accepted; `terms` and `privacy` are
/// not, and are recorded at registration instead.
nonisolated struct SetConsentRequestDTO: Encodable, Sendable {
    var type: String
    var granted: Bool

    static func marketing(_ granted: Bool) -> Self {
        Self(type: "marketing", granted: granted)
    }
}
