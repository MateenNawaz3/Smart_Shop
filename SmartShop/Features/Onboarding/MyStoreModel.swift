//
//  MyStoreModel.swift
//  SmartShop
//

import Foundation
import Observation

/// The user's chosen store plus every store sorted by distance from home.
/// Port of `hooks/useMyStore.ts`.
///
/// The home address is geocoded once through DAWA and the coordinates cached
/// on the profile, so later pages can sort without another lookup.
@MainActor
@Observable
final class MyStoreModel {
    private(set) var profile: StoreProfile?
    private(set) var loaded = false
    private(set) var saving = false
    private var geoFailed = false

    private let profiles: any ProfileService
    private let addresses = DanishAddressService()

    init(profiles: any ProfileService) {
        self.profiles = profiles
    }

    var slug: String? { profile?.favoriteStore }
    var store: Store? { slug.flatMap(Store.named) }
    var hasAddress: Bool { !(profile?.adresse.trimmingCharacters(in: .whitespaces).isEmpty ?? true) }
    var locating: Bool { hasAddress && profile?.home == nil && !geoFailed }
    var sorted: [(store: Store, km: Double?)] { Store.byDistance(from: profile?.home) }
    var nearest: (store: Store, km: Double?)? { profile?.home == nil ? nil : sorted.first }

    func load() async {
        profile = try? await profiles.storeProfile()
        loaded = true
        guard let p = profile, p.home == nil, hasAddress else { return }
        // Missing coordinates: look the address up and cache them.
        guard let point = await addresses.geocode(address: p.adresse, postalCode: p.postnr, city: p.by) else {
            geoFailed = true
            return
        }
        try? await profiles.setHome(point)
        profile?.home = point
    }

    func setStore(_ slug: String) async {
        saving = true
        defer { saving = false }
        guard (try? await profiles.setFavoriteStore(slug, home: nil)) != nil else { return }
        profile?.favoriteStore = slug
    }
}
