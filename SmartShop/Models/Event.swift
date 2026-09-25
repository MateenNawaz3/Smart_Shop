//
//  Event.swift
//  SmartShop
//

import Foundation

/// A calendar event, free or ticketed. Port of `AppEvent` in `src/data/events.ts`.
nonisolated struct AppEvent: Identifiable, Codable, Hashable, Sendable {
    var id: String
    /// ISO date (YYYY-MM-DD).
    var date: String
    /// "16:00-18:00".
    var time: String
    var title: Post.Localized
    var body: Post.Localized
    var place: Post.Localized
    /// 0 means a free event.
    var priceKr: Int
    /// Nil when capacity is unlimited, and for bundled events.
    var seatsLeft: Int? = nil
    var soldOut = false
    /// The signed-in customer's own ticket, when they hold or held one.
    var myTicket: EventTicket? = nil

    /// The bundled `events.json` carries only the original seven fields; the
    /// rest come from the Mobile API.
    enum CodingKeys: String, CodingKey {
        case id, date, time, title, body, place, priceKr
    }

    var day: Date? {
        try? Date(date, strategy: .iso8601.year().month().day().dateSeparator(.dash))
    }
}

nonisolated extension AppEvent {
    /// Earliest first.
    static let all: [AppEvent] = {
        guard let url = Bundle.main.url(forResource: "events", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([AppEvent].self, from: data)
        else {
            assertionFailure("events.json missing or malformed")
            return []
        }
        return events.sorted { $0.date < $1.date }
    }()
}

/// A seat at an event.
///
/// **A paid ticket is never paid.** The server holds the seat as `reserved`
/// with `awaitingPayment` until `expiresAt`, and payment happens by card at the
/// till. Showing that as "bought" sends someone to an event believing they
/// have paid for a seat that may already have been released.
nonisolated struct EventTicket: Sendable, Hashable {
    enum Status: Sendable, Hashable {
        case confirmed, reserved, cancelled, expired
        /// A value this build does not know. Read as not held.
        case other(String)
    }

    var id: String
    var eventID: String? = nil
    var status: Status
    var awaitingPayment: Bool
    /// When a reserved seat is released. Nil on a confirmed ticket.
    var expiresAt: Date? = nil
    /// What the door scans.
    var code: String? = nil

    /// Whether the customer currently has this seat.
    var isHeld: Bool {
        switch status {
        case .confirmed: true
        case .reserved: expiresAt.map { $0 > .now } ?? true
        case .cancelled, .expired, .other: false
        }
    }

    /// Held, but still to be paid for in store.
    var isAwaitingPayment: Bool {
        isHeld && (awaitingPayment || status == .reserved)
    }
}
