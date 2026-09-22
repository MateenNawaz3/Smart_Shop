//
//  APIStoreService.swift
//  SmartShop
//

import Foundation
import CoreLocation

/// `StoreService` over the Mobile API.
///
/// Covers stores and favourites. The two reads use **optional** auth — they
/// must work with no token so guest mode can share these screens, and a bad
/// token on them still answers 200 rather than 401.
nonisolated struct APIStoreService: StoreService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    /// The query parameters are `lat`, `lng` and `q`.
    ///
    /// Worth noting because they are in neither the implementation plan nor the
    /// Postman collection — `latitude`/`longitude` are rejected outright with a
    /// validation error.
    func stores(
        near: CLLocationCoordinate2D? = nil,
        matching query: String? = nil
    ) async throws -> [Store] {
        var items: [URLQueryItem] = []
        if let near {
            items.append(URLQueryItem(name: "lat", value: String(near.latitude)))
            items.append(URLQueryItem(name: "lng", value: String(near.longitude)))
        }
        if let query, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }

        let dtos: [StoreDTO] = try await client.send(
            .get("/mobile/stores", query: items, auth: .optional)
        )
        return dtos.map(Store.init)
    }

    func store(slug: String) async throws -> Store {
        do {
            let dto: StoreDTO = try await client.send(
                .get("/mobile/stores/\(slug)", auth: .optional)
            )
            return Store(dto)
        } catch APIError.failure(let code, _, _) where code == "NOT_FOUND" {
            // A shared link to a shop that is not public in this environment.
            throw StoreNotFound(slug: slug)
        }
    }

    func addFavourite(storeID: String) async throws {
        let _: FavouriteChangeDTO = try await client.send(
            APIRequest(method: .put, path: "/mobile/me/favourite-stores/\(storeID)")
        )
    }

    func removeFavourite(storeID: String) async throws {
        let _: FavouriteChangeDTO = try await client.send(
            .delete("/mobile/me/favourite-stores/\(storeID)")
        )
    }
}
