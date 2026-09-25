//
//  HandoffService.swift
//  SmartShop
//

import Foundation

/// A single-use, 60-second token identifying this customer at a terminal.
///
/// Identification only: it does not authorise payment (still a card tap) and
/// does not clear an age gate. The design has no screen for it yet — see
/// `Features/Handoff/` — so nothing calls this today.
nonisolated protocol HandoffService: Sendable {
    func token() async throws -> HandoffToken
}

nonisolated struct HandoffToken: Sendable, Equatable {
    /// Opaque. Render as a QR code or emit over NFC; never parse it.
    var value: String
    var expiresAt: Date

    var isExpired: Bool { expiresAt <= .now }
}

/// A random token that no till will redeem, for previews and UI tests.
nonisolated struct DemoHandoffService: HandoffService {
    func token() async throws -> HandoffToken {
        HandoffToken(value: UUID().uuidString, expiresAt: .now.addingTimeInterval(60))
    }
}
