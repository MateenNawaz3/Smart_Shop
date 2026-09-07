//
//  FavoritesStore.swift
//  SmartShop
//

import Foundation
import Observation

/// Device-local favourite stores, as a list of store slugs.
/// Port of `src/lib/favorites.ts`, which keeps them in `localStorage`.
///
/// `@Observable` replaces the web's custom "favorites-changed" event: every
/// view that reads `slugs` re-renders when it changes.
@MainActor
@Observable
final class FavoritesStore {
    private static let key = "smartshop.favorites"

    private(set) var slugs: [String]

    init() {
        slugs = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func isFavorite(_ slug: String) -> Bool { slugs.contains(slug) }

    func toggle(_ slug: String) {
        if let index = slugs.firstIndex(of: slug) {
            slugs.remove(at: index)
        } else {
            slugs.append(slug)
        }
        UserDefaults.standard.set(slugs, forKey: Self.key)
    }

    /// Favourites in the order they were added, resolved to store records.
    var stores: [Store] {
        slugs.compactMap(Store.named)
    }
}
