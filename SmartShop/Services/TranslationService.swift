//
//  TranslationService.swift
//  SmartShop
//

import Foundation

/// UI string bundles and the list of active languages.
///
/// These are **not** the app's own copy — that stays in the compiled string
/// catalog. These are strings the server owns because the server owns the
/// decision they describe: door outcomes and MitID results.
nonisolated protocol TranslationService: Sendable {
    /// Languages the language bar may offer.
    func languages() async throws -> [AppLanguage]
    /// The bundle for whatever the `x-localization` header says.
    func bundle() async throws -> TranslationBundle
    /// The bundle for one explicit language, for the in-app language switch.
    func bundle(for language: AppLanguage) async throws -> TranslationBundle
}

/// A bundle of server-owned strings.
nonisolated struct TranslationBundle: Sendable, Equatable {
    /// The language the server actually answered with.
    ///
    /// Worth checking against what was asked for. On the dev backend today
    /// `/translations/de` answers with Danish rather than failing, so a caller
    /// that trusts its own request would show Danish door messages to a German
    /// speaker and never know.
    var language: AppLanguage?
    /// The raw code, kept even when it is not one of the three the app knows.
    var languageCode: String
    var strings: [String: String]

    /// True when the server did not give us the language we asked for.
    func isFallback(from requested: AppLanguage) -> Bool {
        languageCode.lowercased() != requested.rawValue
    }

    subscript(key: String) -> String? { strings[key] }
}
