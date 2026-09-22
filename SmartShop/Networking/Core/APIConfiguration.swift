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
