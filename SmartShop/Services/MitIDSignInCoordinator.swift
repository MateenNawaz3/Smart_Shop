//
//  MitIDSignInCoordinator.swift
//  SmartShop
//

import Foundation
import Observation

/// Drives a MitID sign-in across the browser round trip.
///
/// The flow leaves the app and comes back through a deep link, so the state has
/// to outlive the screen that started it:
///
///   1. `start()` asks the server for an authorization URL and keeps the
///      `state` it was issued with.
///   2. It opens that URL in an in-app `ASWebAuthenticationSession`.
///   3. MitID finishes — in the sheet, or in the MitID app if app-switch is
///      enabled — our server mints a one-time reference, and the browser is
///      redirected to `smartshop://mitid?…`.
///   4. `handle(_:)` checks the state, redeems the reference, and the customer
///      is signed in.
///
/// **Step 3 has two delivery routes and both must work.** The web session
/// intercepts its own callback; but when the MitID *app* has taken over, the
/// return can instead arrive as an ordinary deep link at `SmartShopApp`. Both
/// call `handle(_:)`, which is idempotent — redeeming clears `expectedState`,
/// so whichever lands second is ignored rather than failing.
///
/// This lives above the view because a deep link arrives at the app, not at a
/// screen — `SmartShopApp` routes it here regardless of what is on screen.
@MainActor
@Observable
final class MitIDSignInCoordinator {
    enum Phase: Equatable {
        case idle
        /// Asking for an authorization URL.
        case starting
        /// The browser is open and we are waiting for the deep link back.
        case awaitingCallback
        /// Redeeming the reference.
        case completing
        /// `didRegister` is true when MitID created the account rather than
        /// signing in to one that already existed — the app shows a different
        /// next step for each.
        case signedIn(didRegister: Bool)
        /// Translation *key*, resolved by the view.
        case failed(messageKey: String)
    }

    private(set) var phase: Phase = .idle

    private let auth: any AuthService
    /// Presents the browser leg in-app and intercepts its own callback.
    private let web: MitIDWebAuthenticator
    /// The state issued with the authorization URL, held for the return trip.
    private var expectedState: String?
    /// When the authorization URL stops being valid. The server says 600
    /// seconds; a return after that is a stale link, not a mystery failure.
    private var expiry: Date?

    /// What MitID told us about the customer, for the screen that follows.
    /// Often nearly empty — see `MitIDProfile`.
    private(set) var profile = MitIDProfile()

    init(auth: any AuthService, web: MitIDWebAuthenticator = MitIDWebAuthenticator()) {
        self.auth = auth
        self.web = web
    }

    /// Starts a sign-in and produces the URL to open.
    ///
    /// Terms are accepted here because a MitID sign-in can create an account,
    /// and by the time the subject is known to be new the customer has left
    /// MitID — there is nobody left to ask.
    func start(acceptsTerms: Bool = true) async {
        phase = .starting
        do {
            let session = try await auth.startMitIDSignIn(acceptsTerms: acceptsTerms)
            expectedState = session.state
            expiry = Date.now.addingTimeInterval(TimeInterval(session.expiresIn))
            phase = .awaitingCallback

            // The browser leg runs in-app and usually hands its own callback
            // back here. With app-switch on, the customer may instead leave for
            // the MitID app and return as a deep link through `SmartShopApp`,
            // so this result is one of two possible routes — not the only one.
            let result = await web.authenticate(
                url: session.authorizationURL,
                callbackScheme: Self.callbackScheme
            )

            switch result {
            case .success(let url):
                guard let callback = MitIDCallback(url: url) else {
                    fail("mitid.errorGeneric")
                    return
                }
                await handle(callback)

            case .failure(.cancelled):
                // Backing out of MitID is a choice, not a fault. Returning to
                // `.idle` lets the screen offer the button again rather than
                // showing an error for something the customer did on purpose.
                clearAttempt()
                phase = .idle

            case .failure:
                fail("mitid.errorGeneric")
            }
        } catch is UnsupportedAuthOperation {
            phase = .failed(messageKey: "mitid.errorEdgeFunction")
        } catch {
            phase = .failed(messageKey: "mitid.errorGeneric")
        }
    }

    /// The scheme `ASWebAuthenticationSession` watches for, and the one the
    /// server redirects to. Registered in `Info.plist`.
    private static let callbackScheme = "smartshop"

    /// Called when the app is opened by `smartshop://mitid?…`.
    ///
    /// Returns false for a link that is not ours to handle, so the caller can
    /// pass it on.
    @discardableResult
    func handle(_ callback: MitIDCallback) async -> Bool {
        guard let expectedState else {
            // A MitID link with no sign-in in progress. Most likely a stale one
            // from a previous attempt; possibly an injected one. Either way
            // there is nothing legitimate to redeem.
            return false
        }

        // The reference is single-use server-side, but that protects the
        // server. Without this check an injected link hands the app a reference
        // it never asked for, and it would sign the user in as whoever minted
        // it.
        guard callback.matches(state: expectedState) else {
            fail("mitid.errorGeneric")
            return true
        }

        switch callback.outcome {
        case .failure(let reason):
            fail(Self.messageKey(forReason: reason))
            return true

        case .success(let reference):
            if let expiry, Date.now > expiry {
                fail("mitid.errorExpired")
                return true
            }

            phase = .completing
            do {
                let outcome = try await auth.completeMitIDSignIn(reference: reference)
                clearAttempt()
                web.cancel()
                profile = outcome.profile
                phase = .signedIn(didRegister: outcome.didRegister)
            } catch {
                fail("mitid.errorGeneric")
            }
            return true
        }
    }

    func reset() {
        web.cancel()
        clearAttempt()
        phase = .idle
    }

    private func fail(_ key: String) {
        clearAttempt()
        phase = .failed(messageKey: key)
    }

    /// One attempt, one reference. Clearing the state means a second deep link
    /// for the same attempt cannot be replayed at us.
    private func clearAttempt() {
        expectedState = nil
        expiry = nil
    }

    /// The server's `reason` values, mapped to copy. Anything unrecognised gets
    /// the generic message rather than the raw code.
    private static func messageKey(forReason reason: String?) -> String {
        switch reason {
        case "session_expired": "mitid.errorExpired"
        case "access_denied", "user_cancelled": "mitid.errorCancelled"
        default: "mitid.errorGeneric"
        }
    }
}
