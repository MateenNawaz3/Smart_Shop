//
//  TranslationDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/translations
//   GET /mobile/translations/{lang}
//   GET /mobile/translations/languages
//
// UI string bundles. Distinct from page CONTENT, which comes from
// /mobile/pages — see ContentDTO.

nonisolated struct LanguageDTO: Decodable, Sendable {
    var id: Int
    var name: String
    /// The two-letter code the app uses: `da`, `en`, `de`.
    var shortCode: String
    var countryIso2: String?
}

/// A bundle reports which language it *actually* is, which is not always the
/// one that was asked for — see `TranslationService.bundle(for:)`.
nonisolated struct TranslationBundleDTO: Decodable, Sendable {
    var language: LanguageDTO
    /// `mobile` for everything this app asks for.
    var platform: String?
    var isActive: Bool?
    /// Flat key/value pairs. On dev these are door decisions and MitID
    /// outcomes — messages the server owns because the server makes the
    /// decision they describe.
    var translation: [String: String]
}
