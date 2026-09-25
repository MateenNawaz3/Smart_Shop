//
//  APIEventService.swift
//  SmartShop
//

import Foundation

/// `EventService` over the Mobile API.
///
/// `/events` works signed out and says more signed in: with a token, each
/// event carries the customer's own ticket as `myTicket`.
nonisolated struct APIEventService: EventService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    /// Soonest first, past events excluded by the server — the app does not
    /// have to know the server's idea of today.
    func events() async throws -> [AppEvent] {
        let request = APIRequest.get(
            "/mobile/events",
            query: [URLQueryItem(name: "limit", value: "100")],
            auth: .optional
        )
        let events: [EventDTO] = try await client.send(request)
        return events.map(Self.map)
    }

    func event(id: String) async throws -> AppEvent {
        let event: EventDTO = try await client.send(.get("/mobile/events/\(id)", auth: .optional))
        return Self.map(event)
    }

    func takeSeat(at event: AppEvent) async throws -> EventTicket {
        let ticket: EventTicketDTO = try await client.send(.post("/mobile/events/\(event.id)/tickets"))
        var mapped = Self.map(ticket)
        if mapped.eventID == nil { mapped.eventID = event.id }
        return mapped
    }

    func myTickets() async throws -> [EventTicket] {
        let list: AccessListDTO<EventTicketDTO> = try await client.send(.get("/mobile/me/tickets"))
        return list.items.map(Self.map)
    }

    func cancel(ticketID: String) async throws {
        let _: EmptyResponse = try await client.send(.delete("/mobile/me/tickets/\(ticketID)"))
    }

    // MARK: - Mapping

    /// The server's text is Danish only, so every language shows the same.
    private static func map(_ dto: EventDTO) -> AppEvent {
        func same(_ text: String) -> Post.Localized { Post.Localized(da: text, en: text, de: text) }
        return AppEvent(
            id: dto.id,
            date: dto.date,
            time: dto.time,
            title: same(dto.title),
            body: same(dto.body),
            place: same(dto.place),
            // Øre on the wire. `free` is the server's word on it, so a price
            // that rounds to 0 kr is not mistaken for a free event.
            priceKr: dto.free ? 0 : max(1, Kroner(minorUnits: dto.priceMinor).amount),
            seatsLeft: dto.seatsLeft,
            soldOut: dto.soldOut,
            myTicket: dto.myTicket.map(map)
        )
    }

    private static func map(_ dto: EventTicketDTO) -> EventTicket {
        let status: EventTicket.Status = switch dto.status {
        case "confirmed", "paid", "active", "issued": .confirmed
        case "reserved", "held", "pending": .reserved
        case "cancelled", "canceled", "released": .cancelled
        case "expired": .expired
        default: .other(dto.status)
        }
        return EventTicket(
            id: dto.id,
            eventID: dto.eventId,
            status: status,
            awaitingPayment: dto.awaitingPayment,
            expiresAt: dto.expiresAt,
            code: dto.code
        )
    }
}
