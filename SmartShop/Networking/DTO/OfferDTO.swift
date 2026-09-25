//
//  OfferDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/offers
//
// Structured campaign offers — WHICH PRODUCTS ARE DISCOUNTED.
// Not the same thing as a banner; see `BannerDTO`. Validity windows are
// already applied server-side, so do not re-check dates in the app.
//
// Typed by the spec (`OfferDto`). Not seen live: the endpoint needs a token.

nonisolated struct OfferDTO: Decodable, Sendable {
    var id: String
    var headline: String
    var body: String?
    /// A key or a URL, or null when the offer has no artwork.
    var imageUrl: String?
    /// `percentage`, `fixed_amount`, or whatever else an operator creates —
    /// free text on the campaign row, not a closed set.
    var discountType: String
    /// Read with `discountType`: 20 is 20% or 20,00 kr. Null when the offer
    /// is not a simple discount.
    var discountValue: Double?
    /// Null — the common case — for an automatic offer.
    var code: String?
    var validTo: Date?

    enum CodingKeys: String, CodingKey {
        case id, headline, body, imageUrl, discountType, discountValue, code, validTo
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        headline = try c.decode(String.self, forKey: .headline)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        discountType = (try? c.decodeIfPresent(String.self, forKey: .discountType)) ?? ""
        // Typed `object` in the spec. Postgres numerics often travel as
        // strings ("20.00"), so accept either rather than lose the offer.
        if let number = try? c.decodeIfPresent(Double.self, forKey: .discountValue) {
            discountValue = number
        } else if let text = try? c.decodeIfPresent(String.self, forKey: .discountValue) {
            discountValue = Double(text)
        } else {
            discountValue = nil
        }
        code = try c.decodeIfPresent(String.self, forKey: .code)
        // An unreadable end date is dropped, not fatal: it is advisory only.
        validTo = try? c.decodeIfPresent(Date.self, forKey: .validTo)
    }
}
