//
//  AppLinks.swift
//  SmartShop
//

import Foundation

/// Which incoming URLs belong to this app.
///
/// There are two shapes of the same links, and both must keep working:
///
///   - **`smartshop://…`** — the custom scheme. Registered in `Info.plist`,
///     used by the MitID callback and by password-reset mail on dev.
///   - **`https://<our host>/app/…`** — the Universal Link. What production
///     wants, because a custom scheme does nothing in a desktop mail client,
///     several clients will not linkify it at all, and even on a phone iOS
///     shows an "Open in SmartShop?" prompt that a Universal Link does not.
///
/// A Universal Link only opens the app when the domain serves a matching
/// `apple-app-site-association` file **and** the app carries the domain in its
/// `Associated Domains` entitlement. When either is missing the link silently
/// opens Safari instead — so the fallbacks below are not theoretical.
nonisolated enum AppLinks {
    /// Hosts whose `https://` links this app claims. Must stay in step with
    /// `SmartShop.entitlements`; a host here but not there simply never
    /// arrives, and a host there but not here is ignored on arrival.
    static let universalLinkHosts: Set<String> = [
        "mobile.dev.smartshop24-7.dk",
        "mobile.smartshop24-7.dk"
    ]

    static var customScheme: String { SupabaseConfig.redirectURL.scheme ?? "smartshop" }

    static func isOurs(_ url: URL) -> Bool {
        if url.scheme == customScheme { return true }
        guard url.scheme == "https", let host = url.host() else { return false }
        return universalLinkHosts.contains(host)
    }

    /// What the link is asking for, independent of which shape it arrived in.
    ///
    /// `smartshop://mitid` puts "mitid" in the *host*, while
    /// `https://…/app/mitid/callback` puts it in the path — so neither alone is
    /// a reliable discriminator. The MitID return is recognised by its
    /// parameters instead, and a reset by its `token`.
    static func route(for url: URL) -> Route? {
        let items = queryItems(of: url)
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }

        // A reset carries a one-time token and nothing else does.
        if let token = value("token") { return .passwordReset(token: token) }

        // A MitID return always carries `status`; `state` is what proves it
        // belongs to the attempt this app started.
        if value("status") != nil || value("reference") != nil { return .mitID }

        if value("type") == "recovery" { return .supabaseRecovery }
        return nil
    }

    /// Supabase puts its parameters in the URL *fragment*; ours are ordinary
    /// query items. Reading both means one parser serves every link.
    static func queryItems(of url: URL) -> [URLQueryItem] {
        let fragment = URLComponents(string: "?" + (url.fragment() ?? ""))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return (fragment?.queryItems ?? []) + (query?.queryItems ?? [])
    }

    nonisolated enum Route: Equatable {
        case mitID
        case passwordReset(token: String)
        case supabaseRecovery
    }
}
