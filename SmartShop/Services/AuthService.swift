//
//  AuthService.swift
//  SmartShop
//

import Foundation
import Supabase

/// Who is signed in, independent of which backend answered.
///
/// The protocol used to hand back Supabase's own `Session`, which made every
/// conformance require a Supabase type — impossible for a Mobile API one to
/// produce. Nothing in the app ever read that session's contents; it was only
/// checked for nil. This carries the little that is genuinely useful instead.
nonisolated struct AuthSession: Sendable, Equatable {
    var userID: String
    var email: String
}

/// Everything the auth screens need from the backend.
///
/// Mirrors the calls the web app makes on `supabase.auth`, but as a protocol so
/// previews and tests can run the real screens against fakes.
nonisolated protocol AuthService: Sendable {
    /// Current session, or `nil` when signed out.
    func currentSession() async -> AuthSession?
    /// Emits on sign-in, sign-out, token refresh and password recovery.
    func sessionUpdates() -> AsyncStream<AuthSession?>

    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, profile: SignUpProfile) async throws -> SignUpOutcome
    func sendPasswordReset(to email: String) async throws
    func updatePassword(_ newPassword: String) async throws
    /// Exchanges a one-time token hash for a session (used by the MitID flow
    /// and by password-recovery deep links).
    func verifyEmailToken(hash: String) async throws
    func signOut() async throws

    // MARK: Mobile API password flow
    //
    // Supabase does password recovery in two steps — swap the emailed token for
    // a session, then update the password on that session. The Mobile API does
    // it in one call that carries the token and the new password together, and
    // it can also tell you in advance whether a link is still good.
    //
    // Both shapes have to coexist while the migration is in flight, so these
    // come with default implementations that refuse. A backend that cannot do
    // them says so rather than every conformance growing dead methods.

    /// Whether a reset link is still usable, so the screen can say "this link
    /// expired" before asking someone to type a new password.
    func isResetTokenValid(_ token: String) async throws -> Bool
    /// Sets a new password from an emailed reset token. The token works once,
    /// and success ends every existing session.
    func resetPassword(token: String, newPassword: String) async throws
    /// Changes the password from inside the app. Requires the current one, and
    /// ends every *other* session.
    func changePassword(current: String, new: String) async throws

    /// Sets the password chosen in the sign-up wizard's password step.
    ///
    /// Each backend does this where it can: Supabase updates the password on
    /// the session the wizard already created, while the Mobile API has no
    /// set-without-current endpoint and so registers the account here instead —
    /// which is the only place its `password` field can be supplied.
    func setSignUpPassword(
        _ password: String,
        email: String,
        profile: SignUpProfile
    ) async throws

    // MARK: MitID sign-in
    //
    // Not to be confused with MitID *verification* (`/identity/mitid/*`), which
    // proves who an existing customer is. This one signs in, and creates the
    // account when the MitID subject is unknown.

    /// Starts a MitID sign-in and returns the URL to open in a browser.
    ///
    /// Terms are accepted up front because this can create an account, and by
    /// the time the subject is known to be new the customer has left MitID.
    func startMitIDSignIn(acceptsTerms: Bool) async throws -> MitIDSignInSession

    /// Exchanges the deep link's one-time reference for a session.
    func completeMitIDSignIn(reference: String) async throws -> MitIDSignInOutcome
}

nonisolated struct MitIDSignInSession: Sendable, Equatable {
    var authorizationURL: URL
    /// Hold on to this: it is sent back to `complete`, and it is what tells a
    /// response for this attempt from a response for another one.
    var state: String
    /// Seconds the authorization URL stays valid.
    var expiresIn: Int
}

nonisolated struct MitIDSignInOutcome: Sendable, Equatable {
    var session: AuthSession
    /// True when this MitID return created the account rather than signing in
    /// to one that already existed — the app shows a different next step.
    var didRegister: Bool
}

/// Raised by a backend asked for something it cannot do.
nonisolated struct UnsupportedAuthOperation: LocalizedError {
    var operation: String
    var errorDescription: String? {
        "This backend does not support \(operation)."
    }
}

nonisolated extension AuthService {
    func isResetTokenValid(_ token: String) async throws -> Bool {
        throw UnsupportedAuthOperation(operation: "checking a reset link")
    }

    func resetPassword(token: String, newPassword: String) async throws {
        throw UnsupportedAuthOperation(operation: "resetting a password by token")
    }

    func changePassword(current: String, new: String) async throws {
        throw UnsupportedAuthOperation(operation: "changing a password")
    }

    func setSignUpPassword(
        _ password: String,
        email: String,
        profile: SignUpProfile
    ) async throws {
        throw UnsupportedAuthOperation(operation: "setting a sign-up password")
    }

    func startMitIDSignIn(acceptsTerms: Bool) async throws -> MitIDSignInSession {
        throw UnsupportedAuthOperation(operation: "MitID sign-in")
    }

    func completeMitIDSignIn(reference: String) async throws -> MitIDSignInOutcome {
        throw UnsupportedAuthOperation(operation: "MitID sign-in")
    }
}

/// Metadata written to `auth.users.raw_user_meta_data` at sign-up. The keys are
/// Danish because a database trigger copies them straight into `profiles`;
/// renaming them here would silently break that trigger.
nonisolated struct SignUpProfile: Sendable {
    var fornavn: String
    var efternavn: String
    var adresse: String
    var postnr: String
    var by: String
    var telefon: String
    var markedsforing: Bool
    /// Whether the terms and privacy policy were accepted.
    ///
    /// Supabase never asked for this — the sign-up screen validated the toggle
    /// and then dropped it. `POST /mobile/auth/register` refuses a registration
    /// without it and records the consent server-side, so it has to travel.
    var acceptsTerms: Bool = false
}

/// Supabase can either sign the user straight in or require email confirmation,
/// depending on project settings. The caller has to show different UI for each.
nonisolated enum SignUpOutcome: Sendable {
    case signedIn
    case needsEmailConfirmation
}

// MARK: - Live

nonisolated struct SupabaseAuthService: AuthService {
    var client: SupabaseClient = .shared

    func currentSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return Self.map(session)
    }

    func sessionUpdates() -> AsyncStream<AuthSession?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session.map(Self.map))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func map(_ session: Session) -> AuthSession {
        AuthSession(
            userID: session.user.id.uuidString,
            email: session.user.email ?? ""
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(
        email: String,
        password: String,
        profile: SignUpProfile
    ) async throws -> SignUpOutcome {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "fornavn": .string(profile.fornavn),
                "efternavn": .string(profile.efternavn),
                "adresse": .string(profile.adresse),
                "postnr": .string(profile.postnr),
                "by": .string(profile.by),
                "telefon": .string(profile.telefon),
                "markedsforing": .bool(profile.markedsforing)
            ],
            redirectTo: SupabaseConfig.redirectURL
        )
        return response.session == nil ? .needsEmailConfirmation : .signedIn
    }

    func sendPasswordReset(to email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: SupabaseConfig.redirectURL)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func verifyEmailToken(hash: String) async throws {
        try await client.auth.verifyOTP(tokenHash: hash, type: .email)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Supabase has no "check this current password" call — updating on the
    /// live session is the whole of it, so the current password is unused here.
    func changePassword(current: String, new: String) async throws {
        try await updatePassword(new)
    }

    /// The wizard already created the account in step 1, so this is an update,
    /// and `email`/`profile` are already on file.
    func setSignUpPassword(
        _ password: String,
        email: String,
        profile: SignUpProfile
    ) async throws {
        try await updatePassword(password)
    }
}

// MARK: - Errors

/// Maps backend failures onto the Danish copy the screens display.
///
/// The web inspects `error.message` for the substring "invalid". That is
/// fragile but it is what the backend gives you, so the same check lives here —
/// kept in one place instead of repeated in every screen.
nonisolated enum AuthErrorText {
    /// Returns a translation *key*, leaving the language to the caller.
    static func signIn(_ error: any Error) -> String {
        message(error).contains("invalid")
            ? "login.errWrong"
            : "login.errGeneric"
    }

    static func signUp(_ error: any Error) -> String {
        let text = message(error)
        if text.contains("already registered") || text.contains("already been registered") {
            return "signup.errors.emailTaken"
        }
        if text.contains("weak") || text.contains("password") && text.contains("short") {
            return "signup.errors.weakPassword"
        }
        return "signup.errors.generic"
    }

    private static func message(_ error: any Error) -> String {
        if let authError = error as? AuthError { return authError.message.lowercased() }
        return error.localizedDescription.lowercased()
    }
}
