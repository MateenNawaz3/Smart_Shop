//
//  APIOfferService.swift
//  SmartShop
//

import Foundation

/// `OfferService` over the Mobile API.
///
/// The home rails are **banners** (`/banners`, public artwork); the offers page
/// is **campaign offers** (`/offers`, needs a token). The API keeps the two
/// apart deliberately, and so does this.
nonisolated struct APIOfferService: OfferService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func weekendOffers() async -> [Offer] {
        await banners(placement: "weekend")
    }

    func weeklyOffers() async -> [Offer] {
        await banners(placement: "weekly")
    }

    /// Scoped by the server to the customer's own store, plus everything
    /// chain-wide — so it is never empty merely for want of a preferred store.
    func campaignOffers() async throws -> [CampaignOffer] {
        let offers: [OfferDTO] = try await client.send(.get("/mobile/offers"))
        return offers.map(Self.map)
    }

    /// A rail that fails to load is an empty rail, as the bundled one could
    /// never fail — the home screen is not the place for an error.
    private func banners(placement: String) async -> [Offer] {
        let request = APIRequest.get(
            "/mobile/banners",
            query: [URLQueryItem(name: "placement", value: placement)],
            auth: .optional
        )
        guard let banners: [BannerDTO] = try? await client.send(request) else { return [] }
        // Filtered here too: `placement` is an open set server-side.
        return banners.filter { $0.placement == placement }.map {
            Offer(
                id: $0.id,
                artwork: Artwork(apiValue: $0.imageUrl),
                altText: $0.alt,
                link: Self.webLink($0.linkUrl)
            )
        }
    }

    /// Only an absolute web link is followed. Tapping a poster must not be a
    /// way to hand the app an arbitrary scheme.
    private static func webLink(_ value: String?) -> URL? {
        guard let url = value.flatMap(URL.init(string:)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    private static func map(_ dto: OfferDTO) -> CampaignOffer {
        let discount: CampaignOffer.Discount = switch (dto.discountType, dto.discountValue) {
        case ("percentage", let value?): .percentage(value)
        case ("fixed_amount", let value?): .amount(value)
        default: .other
        }
        return CampaignOffer(
            id: dto.id,
            headline: dto.headline,
            body: dto.body,
            artwork: Artwork(apiValue: dto.imageUrl),
            discount: discount,
            code: dto.code,
            validTo: dto.validTo
        )
    }
}
