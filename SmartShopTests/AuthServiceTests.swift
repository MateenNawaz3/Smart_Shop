//
//  AuthServiceTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

/// `APIAuthService` against stubbed responses.
@Suite("API auth service")
struct APIAuthServiceTests {
    private func makeService(
        tokens: FakeTokenStore = FakeTokenStore()
    ) -> (APIAuthService, StubURLProtocol.Exchange, FakeTokenStore) {
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        return (APIAuthService(client: client, tokens: tokens), exchange, tokens)
    }

    private static let sessionBody = """
    {"success":true,"message":"Signed in","data":{
      "accessToken":"access-1","refreshToken":"refresh-1","expiresIn":900,
      "customer":{"id":"cust-1","customerCode":"47","email":"a@example.dk",
        "phone":"+4520304050","firstName":"Ann","status":"pending_verification",
        "emailVerified":false,"phoneVerified":false,"identityVerified":false,
        "preferredLanguage":"da-DK"}}}
    """

    @Test("a sign-in stores both tokens")
    func signInStoresTokens() async throws {
        let (service, exchange, tokens) = makeService()
        exchange.queue(.init(status: 200, body: Self.sessionBody))

        try await service.signIn(email: "a@example.dk", password: "TestPass123!")
        #expect(tokens.accessToken == "access-1")
        #expect(tokens.refreshToken == "refresh-1")
    }

    @Test("a sign-in sends no bearer token")
    func signInIsUnauthenticated() async throws {
        let (service, exchange, _) = makeService(tokens: FakeTokenStore(access: "old", refresh: "old"))
        exchange.queue(.init(status: 200, body: Self.sessionBody))

        try await service.signIn(email: "a@example.dk", password: "TestPass123!")
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("a sign-in announces the new session")
    func signInBroadcasts() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: Self.sessionBody))

        let updates = service.sessionUpdates()
        try await service.signIn(email: "a@example.dk", password: "TestPass123!")

        var iterator = updates.makeAsyncIterator()
        let session = await iterator.next()
        #expect(session??.email == "a@example.dk")
        #expect(session??.userID == "cust-1")
    }

    /// The account is usable straight away at `pending_verification`; there is
    /// no "confirm your email before signing in" gate the way Supabase had.
    @Test("registering signs you straight in")
    func registerSignsIn() async throws {
        let (service, exchange, tokens) = makeService()
        exchange.queue(.init(status: 201, body: Self.sessionBody))

        let outcome = try await service.signUp(
            email: "a@example.dk",
            password: "TestPass123!",
            profile: SignUpProfile(
                fornavn: "Ann", efternavn: "Berg", adresse: "", postnr: "", by: "",
                telefon: "+4520304050", markedsforing: false, acceptsTerms: true
            )
        )
        #expect(outcome == .signedIn)
        #expect(tokens.accessToken == "access-1")
    }

    /// `/auth/register` takes no address, so it arrives as a follow-up PATCH.
    @Test("an address registers as a profile edit afterwards")
    func registerPatchesAddress() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(
            .init(status: 201, body: Self.sessionBody),
            .init(status: 200, body: #"{"success":true,"data":{}}"#)
        )

        _ = try await service.signUp(
            email: "a@example.dk",
            password: "TestPass123!",
            profile: SignUpProfile(
                fornavn: "Ann", efternavn: "Berg", adresse: "Testvej 1",
                postnr: "6800", by: "Varde", telefon: "+4520304050",
                markedsforing: false, acceptsTerms: true
            )
        )

        let recorded = exchange.recorded
        #expect(recorded.count == 2)
        #expect(recorded[1].url?.path == "/mobile/me")
        #expect(recorded[1].httpMethod == "PATCH")
    }

    /// A failed address edit must not undo a successful registration — the
    /// account exists, and the profile screen can fix the address later.
    @Test("a failed address edit still leaves you registered")
    func addressFailureKeepsAccount() async throws {
        let (service, exchange, tokens) = makeService()
        exchange.queue(
            .init(status: 201, body: Self.sessionBody),
            .init(status: 400, body: #"{"success":false,"message":["bad"],"code":"VALIDATION_ERROR","data":null}"#)
        )

        let outcome = try await service.signUp(
            email: "a@example.dk",
            password: "TestPass123!",
            profile: SignUpProfile(
                fornavn: "Ann", efternavn: "Berg", adresse: "Testvej 1",
                postnr: "6800", by: "Varde", telefon: "+4520304050",
                markedsforing: false, acceptsTerms: true
            )
        )
        #expect(outcome == .signedIn)
        #expect(tokens.accessToken == "access-1")
    }

    @Test("signing out clears the device even when the server refuses")
    func signOutAlwaysClears() async throws {
        let (service, exchange, tokens) = makeService(
            tokens: FakeTokenStore(access: "access-1", refresh: "refresh-1")
        )
        exchange.queue(.init(status: 500, body: "nonsense"))

        _ = try? await service.signOut()
        #expect(tokens.accessToken == nil)
        #expect(tokens.refreshToken == nil)
    }

    @Test("a spent reset link reports itself as invalid rather than failing")
    func resetCheck() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"valid":false}}"#))

        #expect(try await service.isResetTokenValid("nope") == false)
    }

    @Test("a completed reset signs this device out too")
    func resetClearsSession() async throws {
        let (service, exchange, tokens) = makeService(
            tokens: FakeTokenStore(access: "access-1", refresh: "refresh-1")
        )
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{}}"#))

        try await service.resetPassword(token: "good", newPassword: "NewPass123!")
        #expect(tokens.accessToken == nil)
    }

    /// The load-bearing one. A wrong *current* password answers 401, exactly as
    /// a stale token would. Without the retry opt-out the client refreshes,
    /// retries, and reports "session expired" to someone who mistyped.
    @Test("a wrong current password does not trigger a refresh")
    func changePasswordDoesNotRefresh() async throws {
        let (service, exchange, tokens) = makeService(
            tokens: FakeTokenStore(access: "access-1", refresh: "refresh-1")
        )
        exchange.queue(.init(
            status: 401,
            body: #"{"success":false,"message":"Current password is incorrect","code":"UNAUTHORIZED","data":null}"#
        ))

        await #expect(throws: APIError.self) {
            try await service.changePassword(current: "wrong", new: "NewPass123!")
        }

        let paths = exchange.recorded.compactMap(\.url?.path)
        #expect(paths == ["/mobile/auth/password/change"])
        #expect(!paths.contains("/mobile/auth/refresh"))
        // The session survives a mistyped password.
        #expect(tokens.refreshToken == "refresh-1")
    }

    /// MitID sign-in is not built yet, and says so rather than failing oddly.
    @Test("MitID sign-in refuses cleanly")
    func mitIDUnsupported() async throws {
        let (service, _, _) = makeService()
        await #expect(throws: UnsupportedAuthOperation.self) {
            try await service.verifyEmailToken(hash: "anything")
        }
    }
}

// MARK: - MitID sign-in

@Suite("MitID sign-in")
struct MitIDSignInTests {
    private func makeService(
        tokens: FakeTokenStore = FakeTokenStore()
    ) -> (APIAuthService, StubURLProtocol.Exchange, FakeTokenStore) {
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        return (APIAuthService(client: client, tokens: tokens), exchange, tokens)
    }

    private static let sessionStart = """
    {"success":true,"message":"MitID sign-in started","data":{
      "authorizationUrl":"https://smartshop.test.idura.broker/oauth2/authorize?client_id=x&state=abc",
      "state":"abc","expiresIn":600}}
    """

    @Test("starting a sign-in returns a URL to open and a state to keep")
    func startsSession() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: Self.sessionStart))

        let started = try await service.startMitIDSignIn(acceptsTerms: true)
        #expect(started.state == "abc")
        #expect(started.expiresIn == 600)
        #expect(started.authorizationURL.host() == "smartshop.test.idura.broker")
    }

    /// Terms are accepted up front because a MitID sign-in can create an
    /// account, and the server refuses the call without it.
    @Test("the request carries the terms acceptance and the platform")
    func sendsTerms() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: Self.sessionStart))

        _ = try await service.startMitIDSignIn(acceptsTerms: true)
        let body = try #require(exchange.recorded.first?.bodyText)
        #expect(body.contains("\"acceptsTerms\":true"))
        #expect(body.contains("\"deviceType\":\"ios\""))
    }

    /// Starting a sign-in must work signed out — that is the whole point.
    @Test("starting a sign-in sends no bearer token")
    func startIsUnauthenticated() async throws {
        let (service, exchange, _) = makeService(tokens: FakeTokenStore(access: "old", refresh: "old"))
        exchange.queue(.init(status: 200, body: Self.sessionStart))

        _ = try await service.startMitIDSignIn(acceptsTerms: true)
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    /// `{code, state}` is refused outright — "property code should not exist".
    /// The reference is what the deep link carries and what this must send.
    @Test("completing a sign-in sends the reference, not a code")
    func completeSendsReference() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"accessToken":"a-1","refreshToken":"r-1","expiresIn":900,
          "registered":false,
          "customer":{"id":"c-9","customerCode":"48","email":"m@example.dk",
            "status":"active","emailVerified":true,"phoneVerified":true,
            "identityVerified":true,"preferredLanguage":"da-DK"}}}
        """))

        _ = try await service.completeMitIDSignIn(reference: "a-sixteen-char-reference")
        let body = try #require(exchange.recorded.first?.bodyText)
        #expect(body.contains("\"reference\":\"a-sixteen-char-reference\""))
        #expect(!body.contains("\"code\""))
        #expect(!body.contains("\"state\""))
    }

    @Test("completing a sign-in stores the session")
    func completeStoresSession() async throws {
        let (service, exchange, tokens) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"accessToken":"a-1","refreshToken":"r-1","expiresIn":900,
          "registered":false,
          "customer":{"id":"cust-9","customerCode":"48","email":"m@example.dk",
            "status":"active","emailVerified":true,"phoneVerified":true,
            "identityVerified":true,"preferredLanguage":"da-DK"}}}
        """))

        let outcome = try await service.completeMitIDSignIn(reference: "a-sixteen-char-reference")
        #expect(outcome.session.email == "m@example.dk")
        #expect(outcome.didRegister == false)
        #expect(tokens.accessToken == "a-1")
    }

    /// `registered` is what tells "welcome back" from "let's finish setting you
    /// up" — an unknown MitID subject gets an account made for them.
    @Test("a new MitID subject reports that it registered")
    func completeReportsRegistration() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"accessToken":"a-1","refreshToken":"r-1","expiresIn":900,
          "registered":true,
          "customer":{"id":"cust-9","customerCode":"48","email":"m@example.dk",
            "status":"pending_verification","emailVerified":false,"phoneVerified":false,
            "identityVerified":true,"preferredLanguage":"da-DK"}}}
        """))

        let outcome = try await service.completeMitIDSignIn(reference: "a-sixteen-char-reference")
        #expect(outcome.didRegister)
    }

    /// A reference minted for identity *verification* is refused here.
    @Test("a spent or foreign reference is refused")
    func completeRejectsBadReference() async throws {
        let (service, exchange, tokens) = makeService()
        exchange.queue(.init(status: 400, body: """
        {"success":false,"message":"This MitID verification has expired or was already used. Please start again.","code":"VALIDATION_ERROR","data":null}
        """))

        await #expect(throws: APIError.self) {
            _ = try await service.completeMitIDSignIn(reference: "a-sixteen-char-reference")
        }
        #expect(tokens.accessToken == nil)
    }

    /// Supabase's token-hash exchange has no Mobile API equivalent, and says so
    /// rather than failing obscurely.
    @Test("the old token-hash exchange refuses cleanly")
    func tokenHashUnsupported() async throws {
        let (service, _, _) = makeService()
        await #expect(throws: UnsupportedAuthOperation.self) {
            try await service.verifyEmailToken(hash: "anything")
        }
    }
}

// MARK: - Sign-up password step

@Suite("Sign-up password step")
struct SignUpPasswordTests {
    /// The Mobile API has no set-password-without-the-current-one endpoint, so
    /// the wizard's password step is where `POST /auth/register` gets its
    /// `password` field.
    @Test("the chosen password registers the account")
    func passwordRegisters() async throws {
        let tokens = FakeTokenStore()
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        let service = APIAuthService(client: client, tokens: tokens)

        exchange.queue(.init(status: 201, body: """
        {"success":true,"data":{"accessToken":"a-1","refreshToken":"r-1","expiresIn":900,
          "customer":{"id":"cust-1","customerCode":"47","email":"a@example.dk",
            "status":"pending_verification","emailVerified":false,"phoneVerified":false,
            "identityVerified":false,"preferredLanguage":"da-DK"}}}
        """))

        try await service.setSignUpPassword(
            "TestPass123!",
            email: "a@example.dk",
            profile: SignUpProfile(
                fornavn: "Ann", efternavn: "Berg", adresse: "", postnr: "", by: "",
                telefon: "", markedsforing: false, acceptsTerms: true
            )
        )

        let request = try #require(exchange.recorded.first)
        #expect(request.url?.path == "/mobile/auth/register")
        let body = try #require(request.bodyText)
        #expect(body.contains("\"password\":\"TestPass123!\""))
        #expect(body.contains("\"email\":\"a@example.dk\""))
        #expect(tokens.accessToken == "a-1")
    }
}
