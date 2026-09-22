//
//  ContentAndWheelTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("Content service")
struct APIContentServiceTests {
    private func makeService() -> (APIContentService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        return (APIContentService(client: client), exchange)
    }

    @Test("every page comes back in one call")
    func pages() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[
          {"key":"about","title":"Om os","body":"Tekst","updatedAt":"2026-09-14T10:03:38.619Z"},
          {"key":"faq","title":"FAQ","body":"Mere","updatedAt":"2026-09-14T10:03:38.619Z"}]}
        """))

        let pages = try await service.pages()
        #expect(pages.map(\.key) == ["about", "faq"])
        #expect(pages.first?.title == "Om os")
        #expect(pages.first?.updatedAt != nil)
    }

    /// Readable in guest mode and before sign-in.
    @Test("pages are readable with no token")
    func noToken() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[]}"#))

        _ = try await service.pages()
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    /// A broken deep link should be loud, not an empty page.
    @Test("an unknown key is a missing page, not blank content")
    func unknownKey() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 404,
            body: #"{"success":false,"message":"No page 'nope'","code":"NOT_FOUND","data":null}"#
        ))

        await #expect(throws: PageNotFound.self) {
            _ = try await service.page(key: "nope")
        }
    }
}

@Suite("Contact service")
struct APIContactServiceTests {
    private func makeService() -> (APIContactService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        return (APIContactService(client: client), exchange)
    }

    @Test("a message returns its receipt")
    func send() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 201, body: #"{"success":true,"data":{"id":"m-1","delivered":true}}"#))

        let receipt = try await service.send(
            ContactMessage(name: "Ann", email: "a@example.dk", subject: "Hours", body: "Open Sunday?")
        )
        #expect(receipt.id == "m-1")
        #expect(receipt.delivered)
    }

    /// Stored first, emailed second. An undelivered message is safe, and the
    /// screen should still thank the customer — this must not surface as an
    /// error.
    @Test("an undelivered message is still a success")
    func storedButNotEmailed() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 201, body: #"{"success":true,"data":{"id":"m-1","delivered":false}}"#))

        let receipt = try await service.send(
            ContactMessage(name: "Ann", email: "a@example.dk", subject: "Hours", body: "Open Sunday?")
        )
        #expect(!receipt.delivered)
    }

    /// Someone who cannot get through the door is exactly the person who needs
    /// the contact form.
    @Test("the contact form works signed out")
    func worksSignedOut() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        exchange.queue(.init(status: 201, body: #"{"success":true,"data":{"id":"m-1","delivered":true}}"#))

        _ = try await APIContactService(client: client).send(
            ContactMessage(name: "Ann", email: "a@example.dk", subject: "S", body: "B")
        )
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("unsubscribe reads nothing back")
    func unsubscribe() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 202, body: #"{"success":true,"message":"If that address was subscribed, it is not any more","data":null}"#))

        try await service.unsubscribe(email: "nobody@example.dk")
        #expect(exchange.recorded.first?.url?.path == "/mobile/unsubscribe")
    }
}

@Suite("Prize wheel")
struct APIWheelServiceTests {
    private func makeService() -> (APIWheelService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(
            tokens: FakeTokenStore(access: "a", refresh: "r")
        )
        return (APIWheelService(client: client), exchange)
    }

    private static let status = """
    {"success":true,"data":{"canSpin":true,"spinDate":"2026-09-22","today":null,
      "segments":[
        {"id":"s1","label":"50 kr gavekort","outcome":"win","prizeMinor":5000,"currency":"DKK"},
        {"id":"s2","label":"Prøv igen","outcome":"retry","prizeMinor":0,"currency":"DKK"},
        {"id":"s3","label":"Ingen gevinst","outcome":"lose","prizeMinor":0,"currency":"DKK"}]}}
    """

    /// The one most likely to go wrong silently: the API sends **øre**, the
    /// screens print **kroner**. 5000 unconverted advertises a 5000 kr prize.
    @Test("minor units become kroner")
    func convertsMinorUnits() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: Self.status))

        let wheel = try await service.wheelStatus()
        let win = try #require(wheel.segments.first { $0.outcome == .win })
        #expect(win.prizeAmount == Kroner(50), "5000 øre is 50 kr")
    }

    @Test("status reports the segments and the server's today")
    func status() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: Self.status))

        let wheel = try await service.wheelStatus()
        #expect(wheel.canSpin)
        // The server's date, not the device's — a clock change buys nothing.
        #expect(wheel.spinDate == "2026-09-22")
        #expect(wheel.segments.count == 3)
        #expect(wheel.today == nil)
    }

    @Test("a spin already taken comes back as today's result")
    func alreadySpun() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"canSpin":false,"spinDate":"2026-09-22",
          "today":{"id":"sp-1","outcome":"lose","won":false,"prizeMinor":0,
            "currency":"DKK","code":null,"spinDate":"2026-09-22"},
          "segments":[]}}
        """))

        let wheel = try await service.wheelStatus()
        #expect(!wheel.canSpin)
        #expect(wheel.today?.alreadySpun == true)
        #expect(wheel.today?.outcome == .lose)
    }

    @Test("a winning spin carries the spendable code")
    func winningSpin() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"id":"sp-2","outcome":"win","won":true,"prizeMinor":5000,
          "currency":"DKK","code":"2912345678903","spinDate":"2026-09-22"}}
        """))

        let result = try await service.spin()
        #expect(result.won)
        #expect(result.prizeAmount == Kroner(50))
        // Minted server-side: a code the server does not know is not spendable.
        #expect(result.code == "2912345678903")
    }

    /// A second spin is a 409, and the screen has a state for that — so it is
    /// reported as today's result rather than thrown at the customer.
    @Test("a second spin the same day returns today's result")
    func secondSpin() async throws {
        let (service, exchange) = makeService()
        exchange.queue(
            .init(status: 409, body: #"{"success":false,"message":"You have already spun today","code":"CONFLICT","data":null}"#),
            .init(status: 200, body: """
            {"success":true,"data":{"canSpin":false,"spinDate":"2026-09-22",
              "today":{"id":"sp-1","outcome":"retry","won":false,"prizeMinor":0,
                "currency":"DKK","code":null,"spinDate":"2026-09-22"},"segments":[]}}
            """)
        )

        let result = try await service.spin()
        #expect(result.alreadySpun)
        #expect(result.outcome == .retry)
    }

    /// Wins only — anything without a code is not something the till can
    /// honour.
    @Test("the wins list skips anything with no code")
    func winsNeedCodes() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[
          {"id":"w1","outcome":"win","won":true,"prizeMinor":5000,"currency":"DKK",
           "code":"2912345678903","spinDate":"2026-09-20"},
          {"id":"w2","outcome":"lose","won":false,"prizeMinor":0,"currency":"DKK",
           "code":null,"spinDate":"2026-09-21"}]}
        """))

        let wins = try await service.wins()
        #expect(wins.count == 1)
        #expect(wins.first?.prizeAmount == Kroner(50))
        #expect(wins.first?.code == "2912345678903")
    }

    /// The wheel is off unless `CONTESTS_ENABLED=true`, and that is the normal
    /// case in most environments — not a misconfiguration.
    @Test("a disabled wheel surfaces as unavailable")
    func disabled() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 503,
            body: #"{"success":false,"message":"Contests are disabled","code":"SERVICE_UNAVAILABLE","data":null}"#
        ))

        do {
            _ = try await service.wheelStatus()
            Issue.record("expected a failure")
        } catch let error as APIError {
            guard case .unavailable = error else {
                Issue.record("expected .unavailable, got \(error)")
                return
            }
        }
    }
}
