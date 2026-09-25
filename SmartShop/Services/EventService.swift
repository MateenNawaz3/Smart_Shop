//
//  EventService.swift
//  SmartShop
//

import Foundation

/// The events calendar and ticket holding.
///
/// Takes over `boughtTicketEventIds()` and `buyTicket()` from
/// `VerificationService`, where they did not belong. Each event carries the
/// customer's own ticket, so the calendar needs no second call to know what
/// is held.
nonisolated protocol EventService: Sendable {
    /// Upcoming events, soonest first.
    func events() async throws -> [AppEvent]
    func event(id: String) async throws -> AppEvent
    /// Free events are confirmed at once; paid ones come back `reserved`.
    /// Throws a 409 when sold out or already held — the message says which.
    func takeSeat(at event: AppEvent) async throws -> EventTicket
    /// Every ticket held or previously held, newest first.
    func myTickets() async throws -> [EventTicket]
    /// Gives the seat back. Cancelling twice is not an error.
    func cancel(ticketID: String) async throws
}

/// The bundled `events.json`, with tickets kept by the demo backend.
///
/// Demo tickets stay "confirmed", as the web demo's did: its note already
/// tells the customer that no real payment happens.
struct DemoEventService: EventService {
    var backend: DemoBackend = .shared

    func events() async throws -> [AppEvent] {
        let held = Set(backend.read { $0.tickets })
        return AppEvent.all.map { event in
            var event = event
            if held.contains(event.id) { event.myTicket = Self.ticket(for: event.id) }
            return event
        }
    }

    func event(id: String) async throws -> AppEvent {
        guard let event = try await events().first(where: { $0.id == id }) else {
            throw APIError.failure(code: "NOT_FOUND", message: "Event not found", status: 404)
        }
        return event
    }

    func takeSeat(at event: AppEvent) async throws -> EventTicket {
        await DemoMode.pause(0.8)
        backend.write { $0.tickets.append(event.id) }
        return Self.ticket(for: event.id)
    }

    func myTickets() async throws -> [EventTicket] {
        backend.read { $0.tickets }.reversed().map(Self.ticket(for:))
    }

    func cancel(ticketID: String) async throws {
        backend.write { $0.tickets.removeAll { $0 == ticketID } }
    }

    /// A demo ticket's id is its event's id: the demo backend stores only that.
    private static func ticket(for eventID: String) -> EventTicket {
        EventTicket(id: eventID, eventID: eventID, status: .confirmed, awaitingPayment: false)
    }
}
