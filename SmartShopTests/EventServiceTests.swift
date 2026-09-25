//
//  EventServiceTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("Event service")
struct APIEventServiceTests {
    private func makeService() -> (APIEventService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APIEventService(client: client), exchange)
    }

    /// Copied from dev on 2026-09-25, `GET /mobile/events?includePast=true`.
    private static let liveEvents = """
    {"success":true,"message":"Success","data":[
      {"id":"b5342d38-d61e-4ae7-825f-a85ed9bd184e","date":"2026-09-21","time":"15:00-18:00",
       "title":"Smagsprøver i butikken","body":"Kig forbi.","place":"Smart Shop Espe",
       "priceMinor":0,"currency":"DKK","free":true,"capacity":null,"seatsLeft":null,
       "soldOut":false,"storeId":null,"myTicket":null},
      {"id":"036729a5-82c9-4607-be8e-f0806ca9f231","date":"2026-10-05","time":"19:00-21:30",
       "title":"Vinsmagning med vinekspert","body":"Seks vine.","place":"Smart Shop Ballum",
       "priceMinor":14900,"currency":"DKK","free":false,"capacity":20,"seatsLeft":13,
       "soldOut":false,"storeId":null,"myTicket":null}]}
    """

    @Test("the live payload decodes, with the price converted from øre")
    func liveShape() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: Self.liveEvents))

        let events = try await service.events()
        #expect(events.map(\.id) == ["b5342d38-d61e-4ae7-825f-a85ed9bd184e", "036729a5-82c9-4607-be8e-f0806ca9f231"])
        #expect(events[0].priceKr == 0)
        // 14900 øre. Assigning `priceMinor` unconverted would advertise 14900 kr.
        #expect(events[1].priceKr == 149)
        #expect(events[1].seatsLeft == 13)
        #expect(events[1].myTicket == nil)
        // Danish only on the server, so every language shows it.
        #expect(events[1].title(.en) == "Vinsmagning med vinekspert")
    }

    @Test("the calendar is readable signed out, and sends the token when there is one")
    func optionalAuth() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[]}"#))

        _ = try await service.events()
        #expect(exchange.recorded.first?.url?.path == "/mobile/events")
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == "Bearer a")
    }

    /// The one to get right: a customer who sees "bought" turns up believing
    /// they have paid for a seat that may already have been released.
    @Test("a paid seat comes back reserved, and is never shown as bought")
    func paidSeatIsReserved() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 201, body: """
        {"success":true,"data":{"id":"t1","eventId":"e1","status":"reserved",
          "awaitingPayment":true,"expiresAt":"2099-10-05T17:00:00.000Z","code":"EVT-123"}}
        """))

        let event = AppEvent(id: "e1", date: "2026-10-05", time: "19:00-21:30",
                             title: .init(da: "", en: "", de: ""), body: .init(da: "", en: "", de: ""),
                             place: .init(da: "", en: "", de: ""), priceKr: 149)
        let ticket = try await service.takeSeat(at: event)

        #expect(exchange.recorded.first?.httpMethod == "POST")
        #expect(exchange.recorded.first?.url?.path == "/mobile/events/e1/tickets")
        #expect(ticket.isHeld)
        #expect(ticket.isAwaitingPayment)
        #expect(ticket.code == "EVT-123")
    }

    @Test("a reservation past its expiry is no longer held")
    func expiredReservation() {
        let ticket = EventTicket(id: "t1", status: .reserved, awaitingPayment: true,
                                 expiresAt: .now.addingTimeInterval(-60))
        #expect(!ticket.isHeld)
        #expect(!ticket.isAwaitingPayment)
    }

    @Test("a free seat is confirmed at once")
    func freeSeatConfirmed() {
        let ticket = EventTicket(id: "t1", status: .confirmed, awaitingPayment: false)
        #expect(ticket.isHeld)
        #expect(!ticket.isAwaitingPayment)
    }

    @Test("an unknown status is read as not held")
    func unknownStatus() {
        #expect(!EventTicket(id: "t1", status: .other("refunded"), awaitingPayment: false).isHeld)
    }

    @Test("my tickets read bare or paginated")
    func myTicketsShapes() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"items":[{"id":"t1","status":"confirmed","awaitingPayment":false}],"total":1}}
        """))
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[{"id":"t2","status":"cancelled","awaitingPayment":false}]}
        """))

        #expect(try await service.myTickets().map(\.id) == ["t1"])
        let bare = try await service.myTickets()
        #expect(bare.map(\.id) == ["t2"])
        #expect(bare.first?.isHeld == false)
    }

    @Test("giving a seat back deletes the ticket")
    func cancel() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":null}"#))

        try await service.cancel(ticketID: "t1")
        #expect(exchange.recorded.first?.httpMethod == "DELETE")
        #expect(exchange.recorded.first?.url?.path == "/mobile/me/tickets/t1")
    }
}

@Suite("Access service")
struct APIAccessServiceTests {
    private func makeService() -> (APIAccessService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APIAccessService(client: client), exchange)
    }

    /// The response shape is undocumented. Whatever it turns out to be, a
    /// decision this build cannot read must never open the door.
    @Test("an unreadable decision is a refusal")
    func unreadableDecisionRefuses() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"verdict":"yes"}}"#))

        let outcome = try await service.unlock(accessPointID: nil)
        #expect(!outcome.granted)
        #expect(!outcome.doorOpened)
    }

    @Test("a grant with no door moved keeps the two facts apart")
    func grantWithoutDoor() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"decision":"granted","doorOpened":false}}"#))

        let outcome = try await service.unlock(accessPointID: "door-1")
        #expect(outcome.granted)
        #expect(!outcome.doorOpened)
    }

    @Test("a refusal carries its reason")
    func refusalReason() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"decision":"denied","reason":"not_verified","doorOpened":false,"message":"Verify first"}}
        """))

        let outcome = try await service.unlock(accessPointID: nil)
        #expect(!outcome.granted)
        #expect(outcome.reason == "not_verified")
        #expect(outcome.message == "Verify first")
    }

    @Test("a key fob is sent as identifier, not value")
    func keyFobBody() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 201, body: #"{"success":true,"data":{"id":"c1","type":"key_fob"}}"#))

        let fob = try await service.addKeyFob("FOB-12345")
        let body = try #require(exchange.recorded.first?.bodyText)
        let json = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
        #expect(json?["type"] as? String == "key_fob")
        #expect(json?["identifier"] as? String == "FOB-12345")
        // Not echoed by the server here, so kept from what was sent.
        #expect(fob.lastFour == "2345")
    }

    @Test("revoked credentials are left out of the list")
    func revokedHidden() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[{"id":"c1","type":"key_fob","last4":"2345"},
                                {"id":"c2","type":"key_fob","revokedAt":"2026-09-20T10:00:00.000Z"}]}
        """))

        let credentials = try await service.credentials()
        #expect(credentials.map(\.id) == ["c1"])
        #expect(credentials.first?.kind == .keyFob)
    }
}
