//
//  AuthService.swift
//  SmartShop
//

import Foundation
import Supabase

/// Everything the auth screens need from the backend.
///
/// Mirrors the calls the web app makes on `supabase.auth`, but as a protocol so
/// previews and tests can run the real screens against fakes.
protocol AuthService: Sendable {
    /// Current session, or `nil` when signed out.
    func currentSession() async -> Session?
    /// Emits on sign-in, sign-out, token refresh and password recovery.
    func sessionUpdates() -> AsyncStream<Session?>

    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, profile: SignUpProfile) async throws -> SignUpOutcome
    func sendPasswordReset(to email: String) async throws
    func updatePassword(_ newPassword: String) async throws
    /// Exchanges a one-time token hash for a session (used by the MitID flow
    /// and by password-recovery deep links).
    func verifyEmailToken(hash: String) async throws
    func signOut() async throws
}

/// Metadata written to `auth.users.raw_user_meta_data` at sign-up. The keys are
/// Danish because a database trigger copies them straight into `profiles`;
/// renaming them here would silently break that trigger.
struct SignUpProfile: Sendable {
    var fornavn: String
    var efternavn: String
    var adresse: String
    var postnr: String
    var by: String
    var telefon: String
    var markedsforing: Bool
}

/// Supabase can either sign the user straight in or require email confirmation,
/// depending on project settings. The caller has to show different UI for each.
enum SignUpOutcome: Sendable {
    case signedIn
    case needsEmailConfirmation
}

// MARK: - Live

struct SupabaseAuthService: AuthService {
    var client: SupabaseClient = .shared

    func currentSession() async -> Session? {
        try? await client.auth.session
    }

    func sessionUpdates() -> AsyncStream<Session?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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
}

// MARK: - Errors

/// Maps backend failures onto the Danish copy the screens display.
///
/// The web inspects `error.message` for the substring "invalid". That is
/// fragile but it is what the backend gives you, so the same check lives here —
/// kept in one place instead of repeated in every screen.
enum AuthErrorText {
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
