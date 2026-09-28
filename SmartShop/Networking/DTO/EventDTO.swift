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
// `EventDTO` is read from a live payload (dev, 2026-09-25). The ticket shape
// was confirmed by the backend on 2026-09-28: `status` is a closed set of
// `confirmed`, `reserved`, `cancelled` and `expired`, and there is no
// `awaitingPayment` field. A status this build does not know counts as not
// held.
//
// A PAID ticket is never "paid": it comes back `reserved` with an expiresAt,
// and is released then. See `EventTicket`.

/// One event. The text fields are single strings, already translated into
/// the language sent as `x-localization` — not `Accept-Language`, which the
/// server ignores.
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
    /// `confirmed`, `reserved`, `cancelled` or `expired`.
    var status: String
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
        status = c.first(String.self, "status")?.lowercased() ?? ""
        expiresAt = c.first(Date.self, "expiresAt")
        code = c.first(String.self, "code", "ticketCode", "barcode")
    }
}
