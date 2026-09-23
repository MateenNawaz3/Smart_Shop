//
//  MitIDWebAuthenticator.swift
//  SmartShop
//

import AuthenticationServices
import UIKit

/// Runs the MitID browser leg *inside* the app.
///
/// This replaced `openURL`, which handed the customer to Safari and left them
/// looking at a browser window with our login in it. `ASWebAuthenticationSession`
/// presents the same page over the app, and — the part that matters — it
/// **intercepts its own callback**: iOS hands the `smartshop://` URL straight
/// back to the completion handler rather than cold-starting the app through
/// `onOpenURL`.
///
/// `SFSafariViewController` cannot do that, which is why the backend's
/// integration guide asks for this one specifically.
///
/// **Both delivery routes stay live.** With app-switch enabled the customer
/// leaves for the MitID app entirely, and the return may arrive as an ordinary
/// deep link instead of through this session. `MitIDSignInCoordinator.handle`
/// is therefore idempotent — whichever arrives first wins and the second is a
/// no-op, because redeeming clears the attempt.
@MainActor
final class MitIDWebAuthenticator: NSObject {
    private var session: ASWebAuthenticationSession?

    /// Presents `url` and resolves with the callback, or `nil` if the customer
    /// dismissed it.
    ///
    /// A dismissal is a real outcome, not a failure: tapping "Cancel" is how
    /// someone backs out of MitID, and it must not be reported as an error.
    func authenticate(
        url: URL,
        callbackScheme: String
    ) async -> Result<URL, MitIDWebAuthenticationError> {
        session?.cancel()

        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: .success(callbackURL))
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(returning: .failure(.cancelled))
                } else {
                    continuation.resume(returning: .failure(.failed))
                }
            }
            session.presentationContextProvider = self
            // Deliberately NOT ephemeral. An ephemeral session gets a private
            // cookie jar, so a customer who has just authenticated with MitID
            // in Safari would be made to do it again.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            if !session.start() {
                continuation.resume(returning: .failure(.couldNotPresent))
            }
        }
    }

    func cancel() {
        session?.cancel()
        session = nil
    }
}

nonisolated enum MitIDWebAuthenticationError: Error, Sendable {
    /// The customer dismissed the sheet. Not an error to report.
    case cancelled
    /// No window to present over — should not happen in a running app.
    case couldNotPresent
    case failed
}

extension MitIDWebAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // The key window of the active foreground scene. A fresh `UIWindow()`
        // would be returned with no scene attached and nothing would appear.
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        return scene?.keyWindow
            ?? scene?.windows.first
            ?? ASPresentationAnchor()
    }
}
