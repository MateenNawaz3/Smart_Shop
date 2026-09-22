//
//  StoreCatalog.swift
//  SmartShop
//

import Foundation
import Observation

/// The app's view of the store list and which of them are favourites.
///
/// Replaces reading `Store.all` directly and the `UserDefaults`-backed
/// `FavoritesStore`. One type owns both because the API answers both in one
/// call: each row from `/mobile/stores` already says whether it is a favourite.
///
/// ## Why it falls back rather than failing
///
/// The bundled `stores.json` stays in the app and is what this starts with. A
/// store list that cannot load is not an error state worth showing — the shops
/// are the same ten shops, and their addresses and phone numbers do not change
/// between releases. So a failed load leaves the bundled list in place and the
/// screens carry on working offline, in guest mode, and in UI tests.
@MainActor
@Observable
final class StoreCatalog {
    /// Bundled until the first successful load, then whatever the server said.
    private(set) var stores: [Store] = Store.all
    private(set) var isLoading = false
    /// Set when the last load failed. The screens ignore it — it is here for
    /// debugging and for a future "couldn't refresh" hint.
    private(set) var lastLoadError: (any Error)?

    private let service: any StoreService
    /// Favourites for someone who is not signed in.
    ///
    /// Guest mode has no account to put them on, so they stay on the device,
    /// exactly as they did before. Signing in does not migrate them: the
    /// account's own list wins, because that is the one that survives a new
    /// phone.
    private let localFavourites: LocalFavourites

    init(service: any StoreService, localFavourites: LocalFavourites = LocalFavourites()) {
        self.service = service
        self.localFavourites = localFavourites
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await service.stores()
            // An empty list is more likely a misconfigured environment than a
            // chain with no shops, so the bundled list stands.
            if !loaded.isEmpty {
                stores = loaded
            }
            lastLoadError = nil
        } catch {
            lastLoadError = error
        }
    }

    func store(slug: String) -> Store? {
        stores.first { $0.slug == slug } ?? Store.named(slug)
    }

    // MARK: - Favourites

    /// Slugs, because that is what every screen already holds.
    var favouriteSlugs: [String] {
        let fromAccount = stores.filter { $0.isFavourite == true }.map(\.slug)
        return fromAccount.isEmpty ? localFavourites.slugs : fromAccount
    }

    var favourites: [Store] {
        favouriteSlugs.compactMap { store(slug: $0) }
    }

    func isFavourite(_ slug: String) -> Bool {
        favouriteSlugs.contains(slug)
    }

    /// Adds or removes a favourite.
    ///
    /// Tries the account first and falls back to the device when nobody is
    /// signed in — which is how guest mode keeps working without the screens
    /// needing to know which case they are in.
    func toggleFavourite(_ slug: String) async {
        let wasFavourite = isFavourite(slug)

        guard let remoteID = store(slug: slug)?.remoteID else {
            localFavourites.toggle(slug)
            return
        }

        // Optimistic: the heart should fill on the tap, not on the round trip.
        setFavouriteLocally(slug, to: !wasFavourite)

        do {
            if wasFavourite {
                try await service.removeFavourite(storeID: remoteID)
            } else {
                try await service.addFavourite(storeID: remoteID)
            }
        } catch APIError.unauthorized {
            // Guest mode. Keep it on the device instead.
            localFavourites.toggle(slug)
        } catch {
            // Put the heart back rather than leaving the screen claiming
            // something the account does not agree with.
            setFavouriteLocally(slug, to: wasFavourite)
        }
    }

    private func setFavouriteLocally(_ slug: String, to isFavourite: Bool) {
        guard let index = stores.firstIndex(where: { $0.slug == slug }) else { return }
        stores[index].isFavourite = isFavourite
    }
}

/// Device-local favourite stores, as a list of store slugs.
///
/// Port of `src/lib/favorites.ts`, which keeps them in `localStorage`. Only
/// used when nobody is signed in — an account's favourites live on the account,
/// which is what makes them survive a reinstall.
@MainActor
@Observable
final class LocalFavourites {
    private static let key = "smartshop.favorites"

    private(set) var slugs: [String]
    /// Injectable so tests get a store of their own — sharing
    /// `UserDefaults.standard` let one test's favourite invert the next one's
    /// toggle.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        slugs = defaults.stringArray(forKey: Self.key) ?? []
    }

    func toggle(_ slug: String) {
        if let index = slugs.firstIndex(of: slug) {
            slugs.remove(at: index)
        } else {
            slugs.append(slug)
        }
        defaults.set(slugs, forKey: Self.key)
    }
}
