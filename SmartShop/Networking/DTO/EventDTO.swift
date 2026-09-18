//
//  EventDTO.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Wire types for:
//
//   GET /mobile/events
//   GET /mobile/events/{id}
//   POST /mobile/events/{id}/tickets
//   GET /mobile/me/tickets
//   DELETE /mobile/me/tickets/{id}
//
// A PAID ticket is never "paid": it comes back status `reserved` with
// awaitingPayment true and an expiresAt. Model the state explicitly —
// the existing AppEvent.priceKr has no room for it.
