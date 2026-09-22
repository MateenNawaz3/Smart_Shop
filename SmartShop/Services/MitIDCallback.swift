//
//  MitIDCallback.swift
//  SmartShop
//

import Foundation

/// The MitID deep link, parsed.
///
/// The server's `/mobile/identity/mitid/callback` finishes a MitID round trip by
/// redirecting the browser to one of:
///
///     smartshop://mitid?status=success&reference=<one-time ref>&state=<state>
///     smartshop://mitid?status=error&reason=<reason>&state=<state>
///
/// The OIDC `code` never appears here by design: a code in browser history is
/// replayable, whereas the reference is single-use and worthless once redeemed.
nonisolated struct MitIDCallback: Sendable, Equatable {
    enum Outcome: Sendable, Equatable {
        /// Redeem this at `/auth/mitid/complete`.
        case success(reference: String)
        /// `session_expired`, `access_denied`, and so on.
        case failure(reason: String?)
    }

    var outcome: Outcome
    /// Echoed from the session that started this. Absent when the callback was
    /// reached without one.
    var state: String?

    /// Parses a `smartshop://mitid` URL, and returns nil for anything else.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "smartshop" else { return nil }

        // The host carries the route for `smartshop://mitid?…`, but a URL
        // written `smartshop:///mitid` puts it in the path instead.
        let route = (url.host() ?? url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            .lowercased()
        guard route == "mitid" else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?.nilIfEmpty
        }

        state = value("state")

        if let reference = value("reference"), value("status") != "error" {
            outcome = .success(reference: reference)
        } else {
            outcome = .failure(reason: value("reason"))
        }
    }

    /// Whether this callback belongs to the sign-in attempt that was started.
    ///
    /// The reference is single-use server-side, but that protects the server,
    /// not the app: without this check a deep link injected from anywhere hands
    /// the app a reference it never asked for, and it would sign the user in as
    /// whoever minted it.
    ///
    /// A callback with no state is **not** a match. Treating a missing state as
    /// acceptable would defeat the whole check.
    func matches(state expected: String) -> Bool {
        state == expected
    }
}

nonisolated private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
