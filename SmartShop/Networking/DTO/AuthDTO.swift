//
//  AuthDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   POST /mobile/auth/register, /login, /logout, /refresh
//   POST /mobile/auth/password/{forgot,reset,change}
//   GET  /mobile/auth/password/reset/check
//
//   POST /mobile/auth/mitid/session, /mitid/complete
//
// MitID SIGN-IN (/auth/mitid/*) is not MitID VERIFICATION
// (/identity/mitid/*): a reference minted for one is refused by the other.

// MARK: - Requests

nonisolated struct RegisterRequestDTO: Encodable, Sendable {
    var email: String
    var password: String
    var firstName: String
    var lastName: String
    var phone: String
    var addressLine1: String?
    var postalCode: String?
    var city: String?
    /// Required, and refused when false: the server records the consent rather
    /// than trusting the client to have asked.
    var acceptsTerms: Bool
    /// Recorded as its own withdrawable consent.
    var marketingOptIn: Bool
}

nonisolated struct LoginRequestDTO: Encodable, Sendable {
    var email: String
    var password: String
}

/// Both logout and refresh identify the session by its refresh token rather
/// than by the bearer, because the bearer may already have expired.
nonisolated struct RefreshTokenRequestDTO: Encodable, Sendable {
    var refreshToken: String
}

nonisolated struct ForgotPasswordRequestDTO: Encodable, Sendable {
    var email: String
}

nonisolated struct ResetPasswordRequestDTO: Encodable, Sendable {
    var token: String
    var password: String
}

nonisolated struct ChangePasswordRequestDTO: Encodable, Sendable {
    var currentPassword: String
    var newPassword: String
}

/// Terms are accepted **up front** because a MitID sign-in can create an
/// account: by the time the server knows the subject is new, the customer has
/// left MitID and is looking at a redirect, and there is nobody left to ask.
nonisolated struct MitIDSignInSessionRequestDTO: Encodable, Sendable {
    var deviceType = "ios"
    var acceptsTerms: Bool
}

/// The OIDC `code` deliberately never leaves the server: a code sitting in
/// browser history is replayable, whereas this reference is single-use and
/// worthless once redeemed. At least 16 characters.
///
/// (The Postman collection's example body for `/auth/mitid/complete` still
/// shows `{code, state}`. The server rejects that outright — "property code
/// should not exist" — so the prose is right and the example is stale.)
nonisolated struct MitIDCompleteRequestDTO: Encodable, Sendable {
    var reference: String
}

// MARK: - Responses

/// What `/register` and `/login` hand back.
///
/// `/refresh` returns a *narrower* shape — `accessToken` and `expiresIn` only,
/// with no refresh token and no customer — so it decodes through
/// `RefreshedTokenDTO` instead of this.
nonisolated struct SessionDTO: Decodable, Sendable {
    var accessToken: String
    var refreshToken: String
    /// Access-token lifetime in seconds. 900 on the dev backend.
    var expiresIn: Int
    var customer: CustomerSummaryDTO
}

nonisolated struct RefreshedTokenDTO: Decodable, Sendable {
    var accessToken: String
    var expiresIn: Int
}

/// The abbreviated customer that rides along with a session.
///
/// Deliberately not the same as the full profile from `GET /mobile/me`: this
/// one has no `lastName`, address or marketing flag. Do not use it where a
/// profile is wanted.
nonisolated struct CustomerSummaryDTO: Decodable, Sendable {
    var id: String
    var customerCode: String
    /// **Nullable, and null is the normal case after a MitID sign-in** — MitID
    /// releases no email address, so an account it creates has none until the
    /// customer types one. This was `String` until 2026-09-23, which meant
    /// `/auth/mitid/complete` threw a decoding error for precisely the case it
    /// exists to serve: a brand new MitID account.
    var email: String?
    var phone: String?
    /// Null for an identity under Danish *navne- og adressebeskyttelse*: MitID
    /// releases the placeholder `NAVNE & ADRESSEBESKYTTET`, which the server
    /// stores as null rather than printing on a receipt as if it were a person.
    /// A real population, not an edge case — never treat a missing name as an
    /// error.
    var firstName: String?
    var middleName: String?
    var lastName: String?
    /// `yyyy-MM-dd`, from the CPR number behind MitID — **not** a free-text
    /// field the customer typed. Added by the backend on 2026-09-23 at our
    /// request. It is data, not an age *assertion*: `ageOver18` on
    /// `GET /identity/status` remains the only thing that proves age.
    var dateOfBirth: String?
    /// `male` / `female` as the registry records it, derived from the CPR
    /// number. Added by the backend 2026-09-23. Treated as an open set: an
    /// unrecognised value is shown as it arrives rather than dropped, because
    /// silently hiding a value we did not anticipate is worse than showing it.
    var gender: String?
    var addressLine1: String?
    var addressLine2: String?
    var postalCode: String?
    var city: String?
    /// ISO-3166-1 alpha-2. `DK` on a MitID account.
    var country: String?
    var registrationMethod: String?
    /// `pending_verification` immediately after registering.
    var status: String
    var emailVerified: Bool
    var phoneVerified: Bool
    var identityVerified: Bool
    /// A full locale such as `da-DK`, not the bare `da` the app's language
    /// store uses.
    var preferredLanguage: String?
}

/// `GET /auth/password/reset/check` answers 200 with this rather than failing,
/// so the screen can say "this link expired" before asking someone to type a
/// new password.
nonisolated struct ResetTokenCheckDTO: Decodable, Sendable {
    var valid: Bool
}

nonisolated struct SignedOutDTO: Decodable, Sendable {
    var signedOut: Bool
}

/// What `/auth/mitid/session` hands back.
///
/// `authorizationUrl` is opened in a browser. Note its `redirect_uri` points at
/// the **server** (`/mobile/identity/mitid/callback`), not at a `smartshop://`
/// deep link — see `APIAuthService.completeMitIDSignIn` for why that matters.
nonisolated struct MitIDSignInSessionDTO: Decodable, Sendable {
    var authorizationUrl: String
    /// Echoed back to `/mitid/complete`, and the app's protection against a
    /// response that belongs to a different attempt.
    var state: String
    /// Seconds the authorization URL stays good. 600 on dev.
    var expiresIn: Int
}

/// `/auth/mitid/complete` returns a session, plus whether this return created
/// the account rather than signing in to an existing one.
nonisolated struct MitIDSignInResultDTO: Decodable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Int
    var customer: CustomerSummaryDTO
    /// True when this MitID subject was unknown and an account was just made.
    var registered: Bool?
}
