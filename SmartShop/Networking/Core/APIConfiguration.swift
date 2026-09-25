//
//  APIConfiguration.swift
//  SmartShop
//

import Foundation

/// Base URL and per-build environment selection.
///
/// Replaces `SupabaseConfig` as the single place the backend address is chosen.
/// Nothing else in the app should ever spell out a host.
nonisolated struct APIConfiguration: Sendable {
    var baseURL: URL
    /// Where relative image keys (`banners/weekly-tuborg.png`) live.
    ///
    /// The server joins its own `ASSET_BASE_URL` onto image fields and sends a
    /// bare key when that is unset — which it is on dev, where the seeded keys
    /// have no files behind them anyway. Nil means "a relative key is not an
    /// image yet": the screens draw their placeholder rather than a URL that
    /// cannot load. See `AssetURL`.
    var assetBaseURL: URL? = nil

    /// The shared dev backend. Reachable over the public internet, so it works
    /// from a device as well as the simulator.
    static let development = APIConfiguration(
        baseURL: URL(string: "https://mobile.dev.smartshop24-7.dk")!
    )

    // Staging and production come later; they are deliberately absent rather
    // than guessed, so a wrong host cannot ship silently.

    /// The environment this build talks to.
    static var current: APIConfiguration { .development }
}

/// The language every request advertises through `x-localization`.
///
/// `LanguageStore` is `@MainActor`, and requests are built off the main actor,
/// so the client cannot read it directly. This holder is the bridge: the store
/// writes the chosen language in, the client reads it out, and neither has to
/// know about the other's isolation.
///
/// Danish is the fallback because that is what the server itself falls back to
/// — an unset header and a `da` header mean the same thing.
nonisolated final class APILocalization: @unchecked Sendable {
    static let shared = APILocalization()

    private let lock = NSLock()
    private var code = "da"

    var current: String {
        get { lock.withLock { code } }
        set { lock.withLock { code = newValue } }
    }
}

/// Turns the API's image fields into something `AsyncImage` can load.
///
/// The fields are named `imageUrl` and `media` but are **not always URLs**:
/// the rule the backend gave us is to treat one as absolute only when it
/// begins `http://`, `https://`, `//` or `data:`, and to join anything else to
/// the asset base. With no base configured, a relative key resolves to nil.
nonisolated enum AssetURL {
    static func resolve(_ value: String?, base: URL? = APIConfiguration.current.assetBaseURL) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let lower = value.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("data:") {
            return URL(string: value)
        }
        if lower.hasPrefix("//") {
            return URL(string: "https:" + value)
        }
        guard let base else { return nil }
        let key = value.hasPrefix("/") ? String(value.dropFirst()) : value
        return base.appending(path: key)
    }
}
