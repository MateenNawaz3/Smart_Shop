//
//  APIError.swift
//  SmartShop
//

import Foundation

/// Typed failures from the Mobile API.
///
/// Two cases deserve their own treatment rather than being lumped in with the
/// rest, because the UI must handle them as ordinary states:
///
///   - `.unauthorized` — drives the guest gate sheet and the sign-out path
///   - `.unavailable` (503) — the prize wheel when `CONTESTS_ENABLED` is false,
///     and face enrolment when `FACE_COLLECTION_ID` is unset. Both are the
///     normal case in most environments, not a misconfiguration.
nonisolated enum APIError: Error, Sendable {
    /// The request never reached the server, or the reply never came back.
    case transport(any Error)
    /// The envelope said `success: false`.
    case failure(code: String?, message: String, status: Int)
    /// Rejected credentials, after a refresh has already been tried.
    case unauthorized(message: String)
    /// The feature is switched off in this environment.
    case unavailable(message: String)
    /// Too many attempts. Five failed logins lock an account for 15 minutes,
    /// and during the lockout the *correct* password is refused too — so this
    /// cannot be reported as "wrong password" without misleading the user.
    case rateLimited(message: String)
    /// A status we could not turn into an envelope at all.
    case unexpectedStatus(Int)
    /// The envelope arrived but its `data` did not match what we expected.
    case decoding(any Error)

    /// The stable identifier to translate against, when there is one.
    var code: String? {
        switch self {
        case .failure(let code, _, _): code
        case .unauthorized: "UNAUTHORIZED"
        case .unavailable: "SERVICE_UNAVAILABLE"
        case .rateLimited: "RATE_LIMITED"
        case .transport, .unexpectedStatus, .decoding: nil
        }
    }

    /// Server prose. Useful for logs and as a last-resort fallback; it is not
    /// what the UI should key off, and it is not localized.
    var serverMessage: String? {
        switch self {
        case .failure(_, let message, _), .unauthorized(let message),
             .unavailable(let message), .rateLimited(let message):
            message
        case .transport, .unexpectedStatus, .decoding:
            nil
        }
    }
}
