//
//  ContentDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/pages
//   GET /mobile/pages/{key}
//   GET /mobile/posts
//   GET /mobile/posts/{id}
//   GET /mobile/banners
//
// Posts and banners are typed by the spec and were checked against dev on
// 2026-09-25. Their image fields are keys or URLs — see `AssetURL`.
//
// Page CONTENT comes from here; UI LABELS come from /mobile/translations. The
// two are deliberately separate.

nonisolated struct PageDTO: Decodable, Sendable {
    var key: String
    var title: String
    var body: String
    var updatedAt: Date?
}

/// `PostDto`. Text is single-language (Danish) on the server.
nonisolated struct PostDTO: Decodable, Sendable {
    var id: String
    /// `YYYY-MM-DD`, newest first.
    var date: String
    /// `news`, `opening_soon`, `from_opening` on dev — an open set, so a
    /// string rather than an enum.
    var category: String?
    var title: String
    var body: String?
    /// An image key or URL.
    var media: String?
}

/// `BannerDto`: promotional artwork, not a discount.
nonisolated struct BannerDTO: Decodable, Sendable {
    var id: String
    /// `weekly` or `weekend` today, but not a constrained column: filter to
    /// the placements the app renders and ignore the rest.
    var placement: String
    var imageUrl: String?
    var alt: String?
    var linkUrl: String?
}
