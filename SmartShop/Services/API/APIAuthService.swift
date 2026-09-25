//
//  APIAuthService.swift
//  SmartShop
//

import Foundation

/// `AuthService` over the Mobile API.
///
/// Covers register, login, logout, refresh and the four password endpoints.
///
/// MitID sign-in (`/auth/mitid/*`) is implemented, but see
/// `completeMitIDSignIn` for the piece that is still missing outside this app.
///
/// Not to be confused with MitID VERIFICATION (`/identity/mitid/*`): a
/// reference minted for one is refused by the other.
nonisolated final class APIAuthService: AuthService {
    private let client: any APIClient
    private let tokens: any TokenStoring
    /// Listeners on `sessionUpdates()`. Supabase pushed these for us; on the
    /// Mobile API nothing tells the app its session changed, so this service
    /// announces its own sign-ins and sign-outs.
    private let listeners = Listeners()

    init(client: any APIClient, tokens: any TokenStoring = KeychainTokenStore()) {
        self.client = client
        self.tokens = tokens
    }

    convenience init(configuration: APIConfiguration = .current) {
        let tokens = KeychainTokenStore()
        self.init(client: LiveAPIClient(configuration: configuration, tokens: tokens), tokens: tokens)
    }

    // MARK: - Session

    /// Asks the server who the bearer token belongs to.
    ///
    /// Deliberately a round-trip rather than a look at the stored token: the
    /// token may have been revoked by a logout elsewhere, a password change or
    /// a reset, and only the server knows. A 401 here is answered by the
    /// client's refresh-and-retry, so a merely *expired* access token still
    /// produces a session.
    func currentSession() async -> AuthSession? {
        guard tokens.accessToken != nil else { return nil }
        do {
            let me: CurrentCustomerDTO = try await client.send(.get("/mobile/me"))
            // Empty, not absent: a MitID account has no email until the
            // customer supplies one, and `AuthSession.email` is display-only.
            return AuthSession(userID: me.id, email: me.email ?? "")
        } catch {
            return nil
        }
    }

    func sessionUpdates() -> AsyncStream<AuthSession?> {
        listeners.stream()
    }

    // MARK: - Sign in and out

    func signIn(email: String, password: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/login",
            body: LoginRequestDTO(email: email, password: password),
            auth: .forbidden
        )
        let session: SessionDTO = try await client.send(request)
        adopt(session)
    }

    func signUp(
        email: String,
        password: String,
        profile: SignUpProfile
    ) async throws -> SignUpOutcome {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/register",
            body: RegisterRequestDTO(
                email: email,
                password: password,
                firstName: profile.fornavn,
                lastName: profile.efternavn,
                phone: profile.telefon,
                addressLine1: profile.adresse.nilWhenEmpty,
                postalCode: profile.postnr.nilWhenEmpty,
                city: profile.by.nilWhenEmpty,
                acceptsTerms: profile.acceptsTerms,
                marketingOptIn: profile.markedsforing
            ),
            auth: .forbidden
        )
        let session: SessionDTO = try await client.send(request)
        adopt(session)

        // The account exists and is usable immediately, at
        // `status: pending_verification`. There is no "check your email before
        // you may sign in" gate to report.
        return .signedIn
    }

    func signOut() async throws {
        defer {
            // Local state is cleared whatever the server says. A logout that
            // cannot reach the backend still has to sign the user out of this
            // device, or they are stuck signed in to a session they asked to
            // leave.
            tokens.clear()
            listeners.broadcast(nil)
        }

        guard let refreshToken = tokens.refreshToken else { return }
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/logout",
            body: RefreshTokenRequestDTO(refreshToken: refreshToken)
        )
        // The access token stays valid until it expires; the refresh token is
        // what this revokes.
        let _: SignedOutDTO = try await client.send(request)
    }

    // MARK: - Passwords

    func sendPasswordReset(to email: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/password/forgot",
            body: ForgotPasswordRequestDTO(email: email),
            auth: .forbidden
        )
        // Always 202, whether or not the address has an account — otherwise
        // this becomes a way to discover who is registered.
        let _: EmptyResponse = try await client.send(request)
    }

    func isResetTokenValid(_ token: String) async throws -> Bool {
        let check: ResetTokenCheckDTO = try await client.send(
            .get(
                "/mobile/auth/password/reset/check",
                query: [URLQueryItem(name: "token", value: token)],
                auth: .forbidden
            )
        )
        return check.valid
    }

    func resetPassword(token: String, newPassword: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/password/reset",
            body: ResetPasswordRequestDTO(token: token, password: newPassword),
            auth: .forbidden
        )
        let _: EmptyResponse = try await client.send(request)

        // Success ends every existing session, including any this device holds.
        tokens.clear()
        listeners.broadcast(nil)
    }

    func changePassword(current: String, new: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/password/change",
            body: ChangePasswordRequestDTO(currentPassword: current, newPassword: new)
        )
        // A wrong *current* password answers 401, same as a stale token would.
        // Without this the client would spend a refresh and then tell someone
        // who mistyped their password that their session had expired.
        let _: EmptyResponse = try await client.send(request.withoutUnauthorizedRetry())
    }

    /// The Mobile API has no set-password-without-the-current-one endpoint, so
    /// the sign-up password is supplied where the API does accept one: the
    /// `password` field of `POST /auth/register`, which creates the account.
    func setSignUpPassword(
        _ password: String,
        email: String,
        profile: SignUpProfile
    ) async throws {
        _ = try await signUp(email: email, password: password, profile: profile)
    }

    // MARK: - MitID sign-in

    func startMitIDSignIn(acceptsTerms: Bool) async throws -> MitIDSignInSession {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/mitid/session",
            body: MitIDSignInSessionRequestDTO(acceptsTerms: acceptsTerms),
            auth: .forbidden
        )
        let started: MitIDSignInSessionDTO = try await client.send(request)

        guard let url = URL(string: started.authorizationUrl) else {
            throw APIError.decoding(
                URLError(.badURL, userInfo: [
                    NSURLErrorFailingURLStringErrorKey: started.authorizationUrl
                ])
            )
        }
        return MitIDSignInSession(
            authorizationURL: url,
            state: started.state,
            expiresIn: started.expiresIn
        )
    }

    /// Exchanges the deep link's one-time reference for a session.
    ///
    /// The reference arrives on `smartshop://mitid?status=success&reference=…`,
    /// which the server's callback redirects to — see `MitIDCallback`. Compare
    /// the callback's `state` against the one from `startMitIDSignIn` before
    /// calling this: the reference is single-use server-side, but that protects
    /// the server, not the app. Without the state check, a deep link injected
    /// from anywhere hands the app a reference it never asked for, and it would
    /// sign the user in as whoever minted it.
    func completeMitIDSignIn(reference: String) async throws -> MitIDSignInOutcome {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/mitid/complete",
            body: MitIDCompleteRequestDTO(reference: reference),
            auth: .forbidden
        )
        let result: MitIDSignInResultDTO = try await client.send(request)

        tokens.save(accessToken: result.accessToken, refreshToken: result.refreshToken)
        // A MitID account has no email until the customer gives us one, so the
        // session's is empty rather than absent — `AuthSession.email` is only
        // ever read for display.
        let session = AuthSession(
            userID: result.customer.id,
            email: result.customer.email ?? ""
        )
        listeners.broadcast(session)

        return MitIDSignInOutcome(
            session: session,
            didRegister: result.registered ?? false,
            profile: MitIDProfile(
                // A Danish *mellemnavn* is part of the given name, not the
                // surname, so it rides with the first name. Dropping it would
                // quietly shorten someone's name on their own receipt.
                firstName: [result.customer.firstName, result.customer.middleName]
                    .compactMap { $0?.isEmpty == false ? $0 : nil }
                    .joined(separator: " ")
                    .nilWhenEmpty,
                lastName: result.customer.lastName,
                email: result.customer.email,
                phone: result.customer.phone,
                dateOfBirth: result.customer.dateOfBirth,
                gender: result.customer.gender,
                addressLine1: result.customer.addressLine1,
                postalCode: result.customer.postalCode,
                city: result.customer.city
            )
        )
    }

    /// Supabase updates a password on the live recovery session. The Mobile API
    /// has no equivalent — a change needs the current password, and a reset
    /// needs the emailed token.
    func updatePassword(_ newPassword: String) async throws {
        throw UnsupportedAuthOperation(
            operation: "updating a password without the current one or a reset token"
        )
    }

    /// No token hashes here, so the two enrolment flows built on them cannot
    /// run against this backend. The screens check this rather than calling
    /// `verifyEmailToken` and reporting the refusal as a generic error.
    var supportsTokenHashSignIn: Bool { false }

    /// Supabase's one-time-token exchange. The Mobile API signs MitID in
    /// through `completeMitIDSignIn` instead, and has no token-hash concept.
    func verifyEmailToken(hash: String) async throws {
        throw UnsupportedAuthOperation(operation: "exchanging a token hash for a session")
    }

    // MARK: - Plumbing

    private func adopt(_ session: SessionDTO) {
        tokens.save(accessToken: session.accessToken, refreshToken: session.refreshToken)
        listeners.broadcast(
            AuthSession(userID: session.customer.id, email: session.customer.email ?? "")
        )
    }

    /// Fan-out for `sessionUpdates()`.
    private final class Listeners: @unchecked Sendable {
        private let lock = NSLock()
        private var continuations: [UUID: AsyncStream<AuthSession?>.Continuation] = [:]

        func stream() -> AsyncStream<AuthSession?> {
            AsyncStream { continuation in
                let id = UUID()
                lock.withLock { continuations[id] = continuation }
                continuation.onTermination = { [weak self] _ in
                    self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
                }
            }
        }

        func broadcast(_ session: AuthSession?) {
            // `yield` runs consumer code, so the lock only copies the list.
            let targets = lock.withLock { Array(continuations.values) }
            for continuation in targets { continuation.yield(session) }
        }
    }
}
