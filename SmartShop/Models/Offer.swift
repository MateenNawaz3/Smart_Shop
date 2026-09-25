//
//  Offer.swift
//  SmartShop
//

import SwiftUI

/// An image the app shows: bundled, remote, or not there at all.
///
/// Offers, banners and posts used to be asset-catalog images. On the Mobile API
/// they are remote — and on dev every one of them is *missing*, because the
/// seeded keys have no files behind them. So the missing case is modelled
/// rather than treated as an error, and every screen that draws one has a
/// placeholder for it.
nonisolated enum Artwork: Hashable, Sendable {
    case bundled(ImageResource)
    case remote(URL)
    case missing

    /// From an API image field, which may be a URL or a bare storage key.
    init(apiValue: String?) {
        self = AssetURL.resolve(apiValue).map(Artwork.remote) ?? .missing
    }
}

/// One promotional poster on the home screen — a **banner**, in the API's terms.
///
/// The web hard-codes these as imports and swaps the files each week. That is
/// fine for a site you redeploy; an app cannot ship a new binary every Friday.
/// So they are data behind `OfferService`.
///
/// Not to be confused with `CampaignOffer`: a banner answers "which poster do
/// I show", a campaign offer "which products are discounted". The API keeps
/// them apart on purpose.
nonisolated struct Offer: Identifiable, Hashable, Sendable {
    let id: String
    var artwork: Artwork
    /// Catalog key for the description of a bundled banner.
    var altKey: String?
    /// The server's own description. Used as-is; never invented.
    var altText: String?
    /// Where tapping should go, or nil for a poster that only enlarges.
    var link: URL?

    init(id: String, image: ImageResource, altKey: String) {
        self.id = id
        artwork = .bundled(image)
        self.altKey = altKey
    }

    init(id: String, artwork: Artwork, altText: String?, link: URL?) {
        self.id = id
        self.artwork = artwork
        self.altText = altText
        self.link = link
    }

    @MainActor
    func alt(_ t: Translator) -> String {
        altText ?? t(altKey ?? "home.offerImageAlt")
    }
}

/// A structured campaign offer from `GET /offers`: which products are
/// discounted, and by how much. The discount is the point, so an offer with
/// no artwork is still shown.
nonisolated struct CampaignOffer: Identifiable, Hashable, Sendable {
    enum Discount: Hashable, Sendable {
        case percentage(Double)
        /// Kroner — the field has no `Minor` suffix, and the spec reads
        /// `20` as "20,00 kr".
        case amount(Double)
        /// A type this build does not know, or no simple headline number.
        case other
    }

    var id: String
    var headline: String
    var body: String?
    var artwork: Artwork
    var discount: Discount
    /// The code to type at the till. Nil — the common case — means automatic.
    var code: String?
    var validTo: Date?
}

/// Supplies the offer rails on the home screen and the offers page.
nonisolated protocol OfferService: Sendable {
    /// The fixed Friday–Sunday strip: banners placed `weekend`.
    func weekendOffers() async -> [Offer]
    /// This week's carousel: banners placed `weekly`.
    func weeklyOffers() async -> [Offer]
    /// The offers page. Needs a session on the Mobile API.
    func campaignOffers() async throws -> [CampaignOffer]
}

/// Reads from the asset catalog. Used by the UI tests and previews.
nonisolated struct BundledOfferService: OfferService {
    // The generated asset symbols are main-actor.
    func weekendOffers() async -> [Offer] {
        await MainActor.run { [
            Offer(id: "weekend-egg", image: .weekendEggBanner, altKey: "home.weekendEggAlt"),
            Offer(id: "weekend-candy", image: .favoriteCandyBanner, altKey: "home.weekendCandyAlt")
        ] }
    }

    func weeklyOffers() async -> [Offer] {
        await MainActor.run { [
            Offer(id: "tuborg", image: .offerTuborg, altKey: "home.offerImageAlt"),
            Offer(id: "isvafler", image: .offerIsvafler, altKey: "home.offerImageAlt"),
            Offer(id: "kakaomaelk", image: .offerKakaomaelk, altKey: "home.offerImageAlt"),
            Offer(id: "vin", image: .offerVin, altKey: "home.offerImageAlt")
        ] }
    }

    /// The bundled posters, as image-only offers — what the page showed before.
    func campaignOffers() async throws -> [CampaignOffer] {
        await weeklyOffers().map {
            CampaignOffer(id: $0.id, headline: "", artwork: $0.artwork, discount: .other)
        }
    }
}
