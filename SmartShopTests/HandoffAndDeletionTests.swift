//
//  HandoffAndDeletionTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("Deletion request")
struct DeletionRequestTests {
    private func makeService() -> (APIProfileService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        let service = APIProfileService(
            client: client,
            onboarding: APIOnboardingService(client: client),
            stores: APIStoreService(client: client)
        )
        return (service, exchange)
    }

    /// A reason cannot be a condition of the right, so none is sent unasked.
    @Test("a request with no reason sends an empty body and accepts 202")
    func noReason() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 202, body: #"{"success":true,"message":"Accepted","data":null}"#))

        try await service.requestDeletion(reason: nil)
        let request = try #require(exchange.recorded.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/mobile/me/deletion-request")
        #expect(request.bodyText == "{}")
    }

    @Test("a failed request throws, so the sheet can offer the email instead")
    func failure() async {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 500, body: #"{"success":false,"message":"boom","code":null,"data":null}"#))

        await #expect(throws: (any Error).self) { try await service.requestDeletion(reason: nil) }
    }
}

@Suite("Handoff token")
struct HandoffTokenTests {
    private func makeService() -> (APIHandoffService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APIHandoffService(client: client), exchange)
    }

    @Test("the server's expiry is used when it sends one")
    func serverExpiry() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"token":"opaque","expiresAt":"2099-01-01T00:00:00.000Z"}}"#))

        let token = try await service.token()
        #expect(token.value == "opaque")
        #expect(!token.isExpired)
        #expect(exchange.recorded.first?.url?.path == "/mobile/handoff/token")
    }

    @Test("with no expiry, the documented 60 seconds is assumed")
    func defaultLifetime() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"token":"opaque"}}"#))

        let before = Date.now
        let token = try await service.token()
        #expect(token.expiresAt.timeIntervalSince(before) <= 60)
        #expect(token.expiresAt.timeIntervalSince(before) > 55)
    }

    @Test("an answer without a token is an error, not an empty code")
    func missingToken() async {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"expiresIn":60}}"#))

        await #expect(throws: (any Error).self) { _ = try await service.token() }
    }
}
