//
//  Offer.swift
//  SmartShop
//

import SwiftUI

/// One promotional image shown on the home screen.
///
/// The web hard-codes these as imports and swaps the files each week. That is
/// fine for a site you redeploy; an app cannot ship a new binary every Friday.
/// So offers are modelled as *data* behind `OfferService`, with the bundled
/// implementation standing in until they come from Supabase.
struct Offer: Identifiable, Hashable, Sendable {
    let id: String
    /// Asset-catalog image for bundled offers.
    var image: ImageResource
    /// Key for the accessibility description.
    var altKey: String
}

/// Supplies the two offer rails on the home screen.
protocol OfferService: Sendable {
    /// The fixed Friday–Sunday banners.
    func weekendOffers() async -> [Offer]
    /// This week's favourites.
    func weeklyOffers() async -> [Offer]
}

/// Reads from the asset catalog. Replace with a Supabase-backed type once
/// offers are managed in the database; nothing in the views changes.
struct BundledOfferService: OfferService {
    func weekendOffers() async -> [Offer] {
        [
            Offer(id: "weekend-egg", image: .weekendEggBanner, altKey: "home.weekendEggAlt"),
            Offer(id: "weekend-candy", image: .favoriteCandyBanner, altKey: "home.weekendCandyAlt")
        ]
    }

    func weeklyOffers() async -> [Offer] {
        [
            Offer(id: "tuborg", image: .offerTuborg, altKey: "home.offerImageAlt"),
            Offer(id: "isvafler", image: .offerIsvafler, altKey: "home.offerImageAlt"),
            Offer(id: "kakaomaelk", image: .offerKakaomaelk, altKey: "home.offerImageAlt"),
            Offer(id: "vin", image: .offerVin, altKey: "home.offerImageAlt")
        ]
    }
}
