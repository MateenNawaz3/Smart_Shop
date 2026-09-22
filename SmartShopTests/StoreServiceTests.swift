//
//  StoreServiceTests.swift
//  SmartShopTests
//

import CoreLocation
import Foundation
import Testing
@testable import SmartShop

@Suite("API store service")
struct APIStoreServiceTests {
    private func makeService(
        tokens: FakeTokenStore = FakeTokenStore()
    ) -> (APIStoreService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        return (APIStoreService(client: client), exchange)
    }

    private static let espe = """
    {"id":"88c18d0d","slug":"espe","name":"Smart Shop 24-7 Espe","shortName":"Espe",
     "addressLine1":"Skovvej 21","postalCode":"5750","city":"Ringe","country":"DK",
     "latitude":55.2109,"longitude":10.2813,"phone":"+45 7022 0360",
     "email":"espe@smartshop24-7.dk","facebookUrl":"https://facebook.com/x",
     "openingHours":{"open247":true},"alwaysOpen":true,"status":"online",
     "distanceKm":null,"isFavourite":false,"isPreferred":false}
    """

    @Test("a store decodes into the app's shape")
    func decodes() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[\#(Self.espe)]}"#))

        let stores = try await service.stores()
        let store = try #require(stores.first)
        #expect(store.slug == "espe")
        #expect(store.remoteID == "88c18d0d")
        #expect(store.isAlwaysOpen)
        // Composed from the parts the API sends separately.
        #expect(store.displayAddress == ["Skovvej 21", "5750 Ringe"])
        #expect(store.address == "Skovvej 21, 5750 Ringe, DK")
    }

    /// The app keys a store by slug and deep links depend on that, but
    /// favourites and my-store are addressed by the API's id. Both must survive.
    @Test("a store keeps its slug identity and its API id")
    func keepsBothIdentities() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[\#(Self.espe)]}"#))

        let store = try #require(try await service.stores().first)
        #expect(store.id == "espe")
        #expect(store.remoteID == "88c18d0d")
    }

    /// Two shapes, neither documented: `{open247: true}` and per-weekday hours.
    @Test("per-weekday opening hours decode Monday first")
    func weekdayHours() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[{"id":"1","slug":"rarup","name":"Rarup",
          "addressLine1":"A","postalCode":"1","city":"B","country":"DK",
          "latitude":1,"longitude":2,
          "openingHours":{"sun":"08:00-20:00","mon":"06:00-22:00","tue":"06:00-22:00",
            "wed":"06:00-22:00","thu":"06:00-22:00","fri":"06:00-22:00","sat":"07:00-21:00"},
          "alwaysOpen":false,"status":"online"}]}
        """))

        let store = try #require(try await service.stores().first)
        #expect(!store.isAlwaysOpen)
        #expect(store.hours.count == 7)
        #expect(store.hours.first == "06:00-22:00")   // Monday
        #expect(store.hours.last == "08:00-20:00")    // Sunday
        #expect(store.hours[5] == "07:00-21:00")      // Saturday
    }

    @Test("a round-the-clock store has no per-day hours to show")
    func alwaysOpenHasNoHours() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[\#(Self.espe)]}"#))

        let store = try #require(try await service.stores().first)
        #expect(store.hours.isEmpty)
        #expect(store.isAlwaysOpen)
    }

    /// `latitude`/`longitude` are rejected by the server with a validation
    /// error; the accepted names are `lat` and `lng`.
    @Test("a point is sent as lat and lng")
    func pointParameters() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[]}"#))

        _ = try await service.stores(
            near: CLLocationCoordinate2D(latitude: 55.4, longitude: 9.5),
            matching: nil
        )
        let query = try #require(exchange.recorded.first?.url?.query())
        #expect(query.contains("lat=55.4"))
        #expect(query.contains("lng=9.5"))
        #expect(!query.contains("latitude"))
    }

    @Test("a search term is sent as q")
    func searchParameter() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[]}"#))

        _ = try await service.stores(near: nil, matching: "espe")
        #expect(exchange.recorded.first?.url?.query()?.contains("q=espe") == true)
    }

    @Test("a blank search term is left off entirely")
    func blankSearchOmitted() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[]}"#))

        _ = try await service.stores(near: nil, matching: "   ")
        #expect(exchange.recorded.first?.url?.query() == nil)
    }

    /// Optional auth is what lets guest mode share these screens.
    @Test("the finder works with no token")
    func worksSignedOut() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":[\#(Self.espe)]}"#))

        _ = try await service.stores()
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("the finder sends a token when there is one, and says more for it")
    func saysMoreSignedIn() async throws {
        let (service, exchange) = makeService(tokens: FakeTokenStore(access: "a", refresh: "r"))
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[{"id":"1","slug":"espe","name":"Espe","addressLine1":"A",
          "postalCode":"1","city":"B","country":"DK","latitude":1,"longitude":2,
          "alwaysOpen":true,"status":"online","distanceKm":18.2,
          "isFavourite":true,"isPreferred":true}]}
        """))

        let store = try #require(try await service.stores().first)
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == "Bearer a")
        #expect(store.isFavourite == true)
        #expect(store.isMyStore == true)
        #expect(store.distanceKm == 18.2)
    }

    @Test("an unknown slug reports itself as a missing store")
    func unknownSlug() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 404,
            body: #"{"success":false,"message":"Store not found","code":"NOT_FOUND","data":null}"#
        ))

        await #expect(throws: StoreNotFound.self) {
            _ = try await service.store(slug: "no-such-store")
        }
    }

    /// Favourites are addressed by the API id, not the slug.
    @Test("favouriting uses the store id")
    func favouriteUsesID() async throws {
        let (service, exchange) = makeService(tokens: FakeTokenStore(access: "a", refresh: "r"))
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"added":true}}"#))

        try await service.addFavourite(storeID: "88c18d0d")
        let request = try #require(exchange.recorded.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/mobile/me/favourite-stores/88c18d0d")
    }

    @Test("unfavouriting deletes by store id")
    func unfavourite() async throws {
        let (service, exchange) = makeService(tokens: FakeTokenStore(access: "a", refresh: "r"))
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"removed":true}}"#))

        try await service.removeFavourite(storeID: "88c18d0d")
        #expect(exchange.recorded.first?.httpMethod == "DELETE")
    }
}

@Suite("API onboarding service")
struct APIOnboardingServiceTests {
    private func makeService() -> (APIOnboardingService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(
            tokens: FakeTokenStore(access: "a", refresh: "r")
        )
        return (APIOnboardingService(client: client), exchange)
    }

    @Test("setting my store sends the store id")
    func setMyStore() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"preferredStoreId":"s-1"}}"#))

        try await service.setMyStore(id: "s-1")
        let request = try #require(exchange.recorded.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/mobile/me/store")
        #expect(request.bodyText?.contains("\"storeId\":\"s-1\"") == true)
    }

    @Test("clearing my store deletes it")
    func clearMyStore() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"cleared":true}}"#))

        try await service.clearMyStore()
        #expect(exchange.recorded.first?.httpMethod == "DELETE")
    }

    /// The reply is the whole updated profile, which this call does not want —
    /// it must not fail just because the payload is bigger than expected.
    @Test("finishing onboarding ignores the profile it gets back")
    func completeOnboarding() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"id":"c-1","customerCode":"47","email":"a@example.dk",
          "onboardingCompleted":true,"status":"active","emailVerified":true,
          "phoneVerified":true,"identityVerified":false,"marketingOptIn":false,
          "registeredAt":"2026-09-22T06:36:26.061Z"}}
        """))

        try await service.completeOnboarding()
        #expect(exchange.recorded.first?.url?.path == "/mobile/me/onboarding/complete")
    }

    @Test("a resolved home location comes back with its point")
    func homeLocationResolved() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 200,
            body: #"{"success":true,"data":{"resolved":true,"latitude":55.63,"longitude":8.53}}"#
        ))

        let location = try await service.resolveHomeLocation()
        #expect(location.resolved)
        #expect(location.latitude == 55.63)
    }

    /// An address that cannot be placed answers `resolved: false` rather than
    /// failing — the finder still works, just without distances.
    @Test("an unplaceable address is not an error")
    func homeLocationUnresolved() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"resolved":false}}"#))

        let location = try await service.resolveHomeLocation()
        #expect(!location.resolved)
        #expect(location.latitude == nil)
    }
}
