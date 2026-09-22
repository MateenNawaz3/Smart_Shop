//
//  APITranslationService.swift
//  SmartShop
//

import Foundation

/// `TranslationService` over the Mobile API.
///
/// Covers string bundles and the language list. All three are
/// `auth: .forbidden`: the language bar works in guest mode and before sign-in.
nonisolated struct APITranslationService: TranslationService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    /// Languages the bar may offer.
    ///
    /// Codes the app has no `AppLanguage` for are dropped rather than guessed
    /// at — the app can only render a language it ships strings and a flag for.
    func languages() async throws -> [AppLanguage] {
        let dtos: [LanguageDTO] = try await client.send(
            .get("/mobile/translations/languages", auth: .forbidden)
        )
        return dtos.compactMap { AppLanguage(rawValue: $0.shortCode.lowercased()) }
    }

    func bundle() async throws -> TranslationBundle {
        try await bundle(from: .get("/mobile/translations", auth: .forbidden))
    }

    func bundle(for language: AppLanguage) async throws -> TranslationBundle {
        try await bundle(
            from: .get("/mobile/translations/\(language.rawValue)", auth: .forbidden)
        )
    }

    private func bundle(from request: APIRequest) async throws -> TranslationBundle {
        let dto: TranslationBundleDTO = try await client.send(request)
        let code = dto.language.shortCode.lowercased()
        return TranslationBundle(
            language: AppLanguage(rawValue: code),
            languageCode: code,
            strings: dto.translation
        )
    }
}
