//
//  ContentService.swift
//  SmartShop
//

import Foundation

/// Static pages.
///
/// Serving copy from the database rather than the string catalog is the point:
/// fixing a typo becomes an edit, not an App Store release.
///
/// Bulletin-board posts are `PostService`; promotional banners and campaign
/// offers are `OfferService`.
nonisolated protocol ContentService: Sendable {
    /// Every page in one call, so the app can cache them at launch.
    func pages() async throws -> [Page]
    /// One page. An unknown key is an error rather than an empty page — a
    /// broken deep link should be loud.
    func page(key: String) async throws -> Page
}

nonisolated struct PageNotFound: LocalizedError {
    var key: String
    var errorDescription: String? { "No page '\(key)'." }
}

/// Answers nothing, for the build that still reads its copy from the string
/// catalog. The info screens keep their compiled text until they are moved over.
nonisolated struct UnavailableContentService: ContentService {
    func pages() async throws -> [Page] { [] }
    func page(key: String) async throws -> Page { throw PageNotFound(key: key) }
}
