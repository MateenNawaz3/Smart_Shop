//
//  StoreCatalogTests.swift
//  SmartShopTests
//

import CoreLocation
import Foundation
import Testing
@testable import SmartShop

/// A `StoreService` that answers from memory.
private final class FakeStoreService: StoreService, @unchecked Sendable {
    private let lock = NSLock()
    private var stores: [Store]
    private var error: (any Error)?
    private(set) var added: [String] = []
    private(set) var removed: [String] = []
    var favouriteError: (any Error)?

    init(stores: [Store] = [], error: (any Error)? = nil) {
        self.stores = stores
        self.error = error
    }

    func stores(near: CLLocationCoordinate2D?, matching query: String?) async throws -> [Store] {
        if let error { throw error }
        return lock.withLock { stores }
    }

    func store(slug: String) async throws -> Store {
        guard let store = lock.withLock({ stores.first { $0.slug == slug } }) else {
            throw StoreNotFound(slug: slug)
        }
        return store
    }

    func addFavourite(storeID: String) async throws {
        if let favouriteError { throw favouriteError }
        lock.withLock { added.append(storeID) }
    }

    func removeFavourite(storeID: String) async throws {
        if let favouriteError { throw favouriteError }
        lock.withLock { removed.append(storeID) }
    }
}

private func remoteStore(
    slug: String,
    id: String,
    isFavourite: Bool? = false
) -> Store {
    Store(
        slug: slug, name: "Smart Shop 24-7 \(slug)", address: "A, 1 B, DK",
        displayAddress: ["A", "1 B"], phone: "", email: "", facebookUrl: "",
        hours: [], alwaysOpen: true, lat: 1, lng: 2,
        remoteID: id, distanceKm: nil, isFavourite: isFavourite, isMyStore: false
    )
}

/// A favourites store nobody else shares, so tests cannot invert each other's
/// toggles through `UserDefaults.standard`.
@MainActor
private func makeLocalFavourites() -> LocalFavourites {
    let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    return LocalFavourites(defaults: suite)
}

@MainActor
@Suite("Store catalog")
struct StoreCatalogTests {
    /// The bundled list is what the screens show until the server answers, so
    /// the finder is never empty and never shows a spinner.
    @Test("starts on the bundled list before anything loads")
    func startsBundled() {
        let catalog = StoreCatalog(service: FakeStoreService(), localFavourites: makeLocalFavourites())
        #expect(!catalog.stores.isEmpty)
    }

    @Test("a successful load replaces the list")
    func loadReplaces() async {
        let service = FakeStoreService(stores: [remoteStore(slug: "espe", id: "s-1")])
        let catalog = StoreCatalog(service: service)

        await catalog.load()
        #expect(catalog.stores.count == 1)
        #expect(catalog.stores.first?.remoteID == "s-1")
        #expect(catalog.lastLoadError == nil)
    }

    /// The shops do not change between releases, so a failed refresh is not
    /// worth an error state — it leaves what is already on screen.
    @Test("a failed load keeps the bundled list")
    func failedLoadFallsBack() async {
        let catalog = StoreCatalog(service: FakeStoreService(error: URLError(.notConnectedToInternet)), localFavourites: makeLocalFavourites())
        let before = catalog.stores.count

        await catalog.load()
        #expect(catalog.stores.count == before)
        #expect(catalog.lastLoadError != nil)
    }

    /// More likely a misconfigured environment than a chain with no shops.
    @Test("an empty list is ignored rather than blanking the finder")
    func emptyListIgnored() async {
        let catalog = StoreCatalog(service: FakeStoreService(stores: []), localFavourites: makeLocalFavourites())
        let before = catalog.stores.count

        await catalog.load()
        #expect(catalog.stores.count == before)
    }

    @Test("favourites come from the account when the rows say so")
    func favouritesFromAccount() async {
        let service = FakeStoreService(stores: [
            remoteStore(slug: "espe", id: "s-1", isFavourite: true),
            remoteStore(slug: "rarup", id: "s-2", isFavourite: false),
        ])
        let catalog = StoreCatalog(service: service, localFavourites: makeLocalFavourites())
        await catalog.load()

        #expect(catalog.favouriteSlugs == ["espe"])
        #expect(catalog.isFavourite("espe"))
        #expect(!catalog.isFavourite("rarup"))
    }

    /// Addressed by the API id, not the slug — the thing most likely to be got
    /// wrong, because every screen holds slugs.
    @Test("toggling sends the store id, not the slug")
    func togglesByID() async {
        let service = FakeStoreService(stores: [remoteStore(slug: "espe", id: "s-1")])
        let catalog = StoreCatalog(service: service, localFavourites: makeLocalFavourites())
        await catalog.load()

        await catalog.toggleFavourite("espe")
        #expect(service.added == ["s-1"])
        #expect(catalog.isFavourite("espe"))
    }

    @Test("toggling a favourite off removes it")
    func togglesOff() async {
        let service = FakeStoreService(stores: [
            remoteStore(slug: "espe", id: "s-1", isFavourite: true)
        ])
        let catalog = StoreCatalog(service: service, localFavourites: makeLocalFavourites())
        await catalog.load()

        await catalog.toggleFavourite("espe")
        #expect(service.removed == ["s-1"])
        #expect(!catalog.isFavourite("espe"))
    }

    /// The heart must not stay filled for something the account did not accept.
    @Test("a failed toggle puts the heart back")
    func failedToggleReverts() async {
        let service = FakeStoreService(stores: [remoteStore(slug: "espe", id: "s-1")])
        service.favouriteError = URLError(.timedOut)
        let catalog = StoreCatalog(service: service, localFavourites: makeLocalFavourites())
        await catalog.load()

        await catalog.toggleFavourite("espe")
        #expect(!catalog.isFavourite("espe"))
    }

    /// Guest mode has no account to put a favourite on, so it stays on the
    /// device — which is how these screens are shared with signed-out users.
    @Test("a guest's favourite falls back to the device")
    func guestFallsBackToDevice() async {
        let service = FakeStoreService(stores: [remoteStore(slug: "espe", id: "s-1")])
        service.favouriteError = APIError.unauthorized(message: "no token")
        let local = makeLocalFavourites()

        let catalog = StoreCatalog(service: service, localFavourites: local)
        await catalog.load()

        await catalog.toggleFavourite("espe")
        #expect(local.slugs == ["espe"])
        #expect(catalog.isFavourite("espe"))
    }

    /// A bundled store has no API id, so there is nothing to favourite against.
    @Test("a store with no API id is favourited on the device")
    func bundledStoreUsesDevice() async {
        let local = makeLocalFavourites()
        let catalog = StoreCatalog(service: FakeStoreService(), localFavourites: local)
        let slug = try! #require(catalog.stores.first?.slug)

        await catalog.toggleFavourite(slug)
        #expect(local.slugs == [slug])
        #expect(catalog.isFavourite(slug))
    }

    @Test("a store can be found by slug")
    func findBySlug() async {
        let service = FakeStoreService(stores: [remoteStore(slug: "espe", id: "s-1")])
        let catalog = StoreCatalog(service: service, localFavourites: makeLocalFavourites())
        await catalog.load()

        #expect(catalog.store(slug: "espe")?.remoteID == "s-1")
        #expect(catalog.store(slug: "no-such-store") == nil)
    }
}
