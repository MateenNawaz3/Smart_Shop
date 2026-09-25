//
//  MitIDVerifier.swift
//  SmartShop
//

import Foundation

/// Links MitID to the signed-in account: `/identity/mitid/session`, the
/// browser leg, then `/identity/mitid/result` with the callback's reference.
///
/// Smaller than `MitIDSignInCoordinator` because it can be: nobody is signed
/// out while it runs, so there is no session to adopt and no screen to route
/// to afterwards — the caller just re-reads the status. The callback is the
/// same `smartshop://mitid` link, checked against the state the same way, so
/// an injected link cannot attach someone else's identity.
///
/// It relies on the web session intercepting its own callback. With MitID
/// app-switch off (`MITID_APPSWITCH_ENABLED=false`) that is the only route.
@MainActor
final class MitIDVerifier {
    enum Outcome: Equatable {
        case verified
        /// The customer backed out. Not an error.
        case cancelled
        /// Translation key.
        case failed(messageKey: String)
    }

    private let identity: any IdentityService
    private let web: any MitIDWebAuthenticating

    init(identity: any IdentityService, web: any MitIDWebAuthenticating = MitIDWebAuthenticator()) {
        self.identity = identity
        self.web = web
    }

    func verify() async -> Outcome {
        let session: MitIDSignInSession
        do {
            session = try await identity.startMitIDVerification()
        } catch {
            return .failed(messageKey: "mitid.errorGeneric")
        }
        let expiry = Date.now.addingTimeInterval(TimeInterval(session.expiresIn))

        switch await web.authenticate(url: session.authorizationURL, callbackScheme: "smartshop") {
        case .failure(.cancelled):
            return .cancelled
        case .failure:
            return .failed(messageKey: "mitid.errorGeneric")
        case .success(let url):
            guard let callback = MitIDCallback(url: url), callback.matches(state: session.state) else {
                return .failed(messageKey: "mitid.errorGeneric")
            }
            switch callback.outcome {
            case .failure(let reason):
                return reason == "access_denied" || reason == "user_cancelled"
                    ? .cancelled
                    : .failed(messageKey: reason == "session_expired" ? "mitid.errorExpired" : "mitid.errorGeneric")
            case .success(let reference):
                guard Date.now <= expiry else { return .failed(messageKey: "mitid.errorExpired") }
                do {
                    try await identity.completeMitIDVerification(reference: reference)
                    return .verified
                } catch {
                    return .failed(messageKey: "mitid.errorGeneric")
                }
            }
        }
    }

    func cancel() {
        web.cancel()
    }
}
