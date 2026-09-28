//
//  NotificationServiceTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("Notification inbox")
struct NotificationServiceTests {
    private func makeService() -> (APINotificationService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APINotificationService(client: client), exchange)
    }

    /// The live shape, as seeded on dev 2026-09-28.
    private let page = """
    {"success":true,"data":{"items":[
      {"id":"n1","type":"receipt_ready","title":"Din kvittering er klar","body":"Tak for dit køb.",
       "entityType":"purchase","entityId":"p-123","read":false,"createdAt":"2026-09-28T09:00:00.000Z"},
      {"id":"n2","type":"general","title":"Velkommen","body":null,
       "entityType":null,"entityId":null,"read":true,"createdAt":"2026-09-27T09:00:00.000Z"},
      {"id":"n3","type":"birthday","title":"Tillykke","body":"Linje 1\\nLinje 2",
       "entityType":"voucher","entityId":"v-1","read":false,"createdAt":"2026-09-26T09:00:00.000Z"}
    ],"total":7,"unread":4,"limit":3,"offset":0}}
    """

    @Test("the inbox reads its page and asks with limit and offset")
    func inbox() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: page))

        let inbox = try await service.inbox(limit: 3, offset: 0)
        let request = try #require(exchange.recorded.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/mobile/notifications")
        #expect(request.url?.query?.contains("limit=3") == true)
        #expect(request.url?.query?.contains("offset=0") == true)
        #expect(inbox.items.map(\.id) == ["n1", "n2", "n3"])
        #expect(inbox.items.map(\.read) == [false, true, false])
        #expect(inbox.items[2].body == "Linje 1\nLinje 2")
    }

    /// `unread` covers the whole inbox. Counting this page would say 2.
    @Test("the badge is the server's unread, not a count of the page")
    func badge() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: page))

        let inbox = try await service.inbox(limit: 3, offset: 0)
        #expect(inbox.unread == 4)
        #expect(inbox.total == 7)
    }

    @Test("a purchase opens its receipt, and nothing else pretends to")
    func targets() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: page))

        let items = try await service.inbox(limit: 3, offset: 0).items
        #expect(items[0].target == .receipt(id: "p-123"))
        #expect(items[1].target == nil)
        #expect(items[2].target == .other(type: "voucher", id: "v-1"))
    }

    /// A phone already installed cannot be redeployed with a migration.
    @Test("an unknown type is kept, not dropped")
    func unknownType() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: page))

        let items = try await service.inbox(limit: 3, offset: 0).items
        #expect(items[0].kind == .receiptReady)
        #expect(items[1].kind == .general)
        #expect(items[2].kind == .other("birthday"))
    }

    @Test("marking one read posts to its own path")
    func markRead() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"ok":true}}"#))

        #expect(try await service.markRead(id: "n1"))
        let request = try #require(exchange.recorded.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/mobile/notifications/n1/read")
    }

    /// `marked` is rows changed. 0 is a no-op, not a failure.
    @Test("read-all returns rows changed, and 0 is not an error")
    func markAllRead() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"marked":2}}"#))
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"marked":0}}"#))

        #expect(try await service.markAllRead() == 2)
        #expect(try await service.markAllRead() == 0)
        #expect(exchange.recorded.map { $0.url?.path } == ["/mobile/notifications/read-all", "/mobile/notifications/read-all"])
    }

    @Test("the demo inbox counts unread across every page")
    func demo() async throws {
        let service = DemoNotificationService()
        let first = try await service.inbox(limit: 1, offset: 0)
        #expect(first.items.count == 1)
        #expect(first.unread == 1)

        #expect(try await service.markAllRead() == 1)
        #expect(try await service.inbox().unread == 0)
    }
}
