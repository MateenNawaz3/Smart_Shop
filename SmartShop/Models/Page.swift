//
//  Page.swift
//  SmartShop
//

import Foundation

/// A static content page served from the database rather than the binary.
///
/// That is the whole point of the module: fixing a typo becomes an edit, not an
/// App Store release.
///
/// Note the split — page *content* comes from `/mobile/pages`, while UI
/// *labels* come from `/mobile/translations`. They are different things from
/// different endpoints.
nonisolated struct Page: Identifiable, Sendable, Equatable {
    /// `about`, `faq`, `how_to_shop`, `good_to_know`.
    var key: String
    var title: String
    /// Body copy. Light markdown: `**bold**` and blank-line paragraphs.
    var body: String
    var updatedAt: Date?

    var id: String { key }
}

nonisolated enum PageKey {
    static let about = "about"
    static let faq = "faq"
    static let howToShop = "how_to_shop"
    static let goodToKnow = "good_to_know"
}
