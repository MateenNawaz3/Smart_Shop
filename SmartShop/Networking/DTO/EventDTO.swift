//
//  EventDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/events
//   GET /mobile/events/{id}
//   POST /mobile/events/{id}/tickets
//   GET /mobile/me/tickets
//   DELETE /mobile/me/tickets/{id}
//
// `EventDTO` is read from a live payload (dev, 2026-09-25). The ticket shape is
// not: the spec types no response here, the public endpoints never show a
// ticket, and the documented facts are only `status`, `awaitingPayment`,
// `expiresAt` and `code`. So the ticket is read tolerantly, like the access
// types, and a status it cannot read counts as not held.
//
// A PAID ticket is never "paid": it comes back status `reserved` with
// awaitingPayment true and an expiresAt. See `EventTicket`.

/// One event. The text fields are single strings, in Danish, whatever the
/// `Accept-Language` — the server has no translations for events.
nonisolated struct EventDTO: Decodable, Sendable {
    var id: String
    /// `YYYY-MM-DD`.
    var date: String
    /// `19:00-21:30`.
    var time: String
    var title: String
    var body: String
    var place: String
    /// **Øre.** `14900` is 149 kr.
    var priceMinor: Int
    var free: Bool
    /// Null for unlimited capacity.
    var seatsLeft: Int?
    var soldOut: Bool
    /// Null when signed out, or when this customer has no ticket.
    var myTicket: EventTicketDTO?
}

nonisolated struct EventTicketDTO: Decodable, Sendable {
    var id: String
    var eventId: String?
    /// `confirmed`, `reserved`, `cancelled`, … — documented only by example.
    var status: String
    var awaitingPayment: Bool
    var expiresAt: Date?
    var code: String?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        guard let id = c.first(String.self, "id", "ticketId") else {
            throw DecodingError.keyNotFound(
                AnyCodingKey("id"),
                .init(codingPath: c.codingPath, debugDescription: "ticket without an id")
            )
        }
        self.id = id
        eventId = c.first(String.self, "eventId")
            ?? (try? c.nestedContainer(keyedBy: AnyCodingKey.self, forKey: AnyCodingKey("event")))?
                .first(String.self, "id")
        status = c.first(String.self, "status", "state")?.lowercased() ?? ""
        awaitingPayment = c.first(Bool.self, "awaitingPayment") ?? false
        expiresAt = c.first(Date.self, "expiresAt", "holdExpiresAt")
        code = c.first(String.self, "code", "ticketCode", "barcode")
    }
}
