//
//  WheelDTO.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Wire types for:
//
//   GET /mobile/contests/wheel/status
//   POST /mobile/contests/wheel/spin
//   GET /mobile/contests/wheel/wins
//
// The outcome and the gift-card code are both decided server-side.
// spinDate is the server's idea of today, so a device clock change cannot
// buy another go. Expect 503 unless CONTESTS_ENABLED=true.
