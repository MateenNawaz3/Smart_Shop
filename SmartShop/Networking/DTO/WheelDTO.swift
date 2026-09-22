//
//  WheelDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET  /mobile/contests/wheel/status
//   POST /mobile/contests/wheel/spin
//   GET  /mobile/contests/wheel/wins

/// Whether I may still spin, what I already got today, and the segments to
/// render.
nonisolated struct WheelStatusDTO: Decodable, Sendable {
    var canSpin: Bool
    /// The **server's** idea of today, `yyyy-MM-dd`. A device clock change
    /// cannot buy another go.
    var spinDate: String
    /// Today's spin, or null if there has not been one.
    var today: SpinDTO?
    var segments: [WheelSegmentDTO]
}

nonisolated struct WheelSegmentDTO: Decodable, Sendable {
    var id: String
    var label: String
    /// `win`, `retry` or `lose`.
    var outcome: String
    /// **Minor units** — 5000 is 50 kr. See `SpinResult.prizeAmount`, which is
    /// kroner.
    var prizeMinor: Int?
    var currency: String?
}

/// One spin. The outcome is decided server-side; the animation renders a
/// decision already committed.
nonisolated struct SpinDTO: Decodable, Sendable {
    var id: String?
    var outcome: String
    var won: Bool
    /// Minor units, as above.
    var prizeMinor: Int?
    var currency: String?
    /// The spendable gift-card code, minted in the same transaction as the win.
    /// Null for anything that is not a win.
    var code: String?
    var spinDate: String
    var createdAt: Date?
    /// Which segment was landed on.
    var prizeId: String?
}
