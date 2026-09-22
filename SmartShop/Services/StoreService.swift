//
//  StoreService.swift
//  SmartShop
//

import Foundation
import CoreLocation

/// Store finder, store detail, and favourites.
///
/// Replaces the bundled `stores.json` as the source of the store list. Moving
/// favourites onto the account fixes a real defect: on the device they did not
/// survive a reinstall or a new phone.
nonisolated protocol StoreService: Sendable {
    /// Public, active stores.
    ///
    /// Nearest first when `near` is given or a home location is on file,
    /// alphabetical otherwise. Works signed out, and says more signed in — each
    /// row then carries whether it is a favourite and whether it is my store.
    func stores(near: CLLocationCoordinate2D?, matching query: String?) async throws -> [Store]

    /// One store. Slugs match the ones already in use (`grimstrup`, `rarup`,
    /// `hunderup-sejstrup`), so existing deep links keep working.
    func store(slug: String) async throws -> Store

    /// Idempotent — tapping the heart twice is the same wish, not an error.
    ///
    /// Addressed by the API's store id, **not** the slug.
    func addFavourite(storeID: String) async throws
    func removeFavourite(storeID: String) async throws
}

extension StoreService {
    func stores() async throws -> [Store] {
        try await stores(near: nil, matching: nil)
    }
}

/// Serves the bundled `stores.json`, which is what the app uses today.
///
/// Favourites are not its business — `StoreCatalog` keeps those on the device
/// when there is no account — so the two calls do nothing rather than
/// pretending to succeed against a backend that is not there.
nonisolated struct BundledStoreService: StoreService {
    func stores(near: CLLocationCoordinate2D?, matching query: String?) async throws -> [Store] {
        var stores = Store.all
        if let query, !query.isEmpty {
            stores = stores.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.displayAddress.joined(separator: " ").localizedCaseInsensitiveContains(query)
            }
        }
        guard let near else { return stores }

        let origin = CLLocation(latitude: near.latitude, longitude: near.longitude)
        return stores.sorted {
            origin.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lng))
                < origin.distance(from: CLLocation(latitude: $1.lat, longitude: $1.lng))
        }
    }

    func store(slug: String) async throws -> Store {
        guard let store = Store.named(slug) else { throw StoreNotFound(slug: slug) }
        return store
    }

    func addFavourite(storeID: String) async throws {}
    func removeFavourite(storeID: String) async throws {}
}

nonisolated struct StoreNotFound: LocalizedError {
    var slug: String
    var errorDescription: String? { "No store '\(slug)'." }
}
