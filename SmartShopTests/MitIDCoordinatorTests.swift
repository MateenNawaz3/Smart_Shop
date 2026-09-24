//
//  MitIDCoordinatorTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

/// An `AuthService` that only answers the MitID calls.
private final class FakeMitIDAuth: AuthService, @unchecked Sendable {
    var session: MitIDSignInSession?
    var startError: (any Error)?
    var outcome: MitIDSignInOutcome?
    var completeError: (any Error)?
    private(set) var redeemed: [String] = []

    func startMitIDSignIn(acceptsTerms: Bool) async throws -> MitIDSignInSession {
        if let startError { throw startError }
        return session ?? MitIDSignInSession(
            authorizationURL: URL(string: "https://broker.test/authorize")!,
            state: "state-1",
            expiresIn: 600
        )
    }

    func completeMitIDSignIn(reference: String) async throws -> MitIDSignInOutcome {
        redeemed.append(reference)
        if let completeError { throw completeError }
        return outcome ?? MitIDSignInOutcome(
            session: AuthSession(userID: "c-1", email: "m@example.dk"),
            didRegister: false
        )
    }

    // Unused by these tests.
    func currentSession() async -> AuthSession? { nil }
    func sessionUpdates() -> AsyncStream<AuthSession?> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String, profile: SignUpProfile) async throws -> SignUpOutcome { .signedIn }
    func sendPasswordReset(to email: String) async throws {}
    func updatePassword(_ newPassword: String) async throws {}
    func verifyEmailToken(hash: String) async throws {}
    func signOut() async throws {}
}

/// A browser leg that never answers.
///
/// These tests exercise the **deep-link** delivery route, where the MitID app
/// took over and the return arrives at `SmartShopApp` rather than through the
/// web session. Suspending forever models exactly that: the sheet is still open
/// when the answer comes from somewhere else. It also keeps the real
/// `ASWebAuthenticationSession` out of a unit test, where there is no window to
/// present over.
@MainActor
private final class SilentWeb: MitIDWebAuthenticating {
    /// What the coordinator asked us to open, so a test can assert the
    /// authorization URL actually reached the browser leg.
    private(set) var presentedURL: URL?

    func authenticate(
        url: URL,
        callbackScheme: String
    ) async -> Result<URL, MitIDWebAuthenticationError> {
        presentedURL = url
        return await withCheckedContinuation { _ in }
    }

    func cancel() {}

    /// The browser leg is launched in a detached task, so it has not
    /// necessarily run by the time `start()` returns. Yields until it has.
    func waitForPresentation() async -> URL? {
        for _ in 0..<10 {
            if let presentedURL { return presentedURL }
            await Task.yield()
        }
        return presentedURL
    }
}

@MainActor
private func makeCoordinator(_ auth: FakeMitIDAuth) -> MitIDSignInCoordinator {
    MitIDSignInCoordinator(auth: auth, web: SilentWeb())
}

@MainActor
private func makeCoordinator(
    _ auth: FakeMitIDAuth,
    web: SilentWeb
) -> MitIDSignInCoordinator {
    MitIDSignInCoordinator(auth: auth, web: web)
}

private func callback(_ string: String) -> MitIDCallback {
    MitIDCallback(url: URL(string: string)!)!
}

@MainActor
@Suite("MitID sign-in coordinator")
struct MitIDCoordinatorTests {
    @Test("starting opens the authorization URL and waits for the callback")
    func start() async {
        let auth = FakeMitIDAuth()
        let web = SilentWeb()
        let coordinator = makeCoordinator(auth, web: web)

        await coordinator.start()
        #expect(coordinator.phase == .awaitingCallback)

        // The browser leg is launched, not awaited — `start()` returning while
        // the sheet is still open is the whole point, because the answer may
        // instead arrive as a deep link after the MitID app takes over.
        #expect(await web.waitForPresentation()?.host() == "broker.test")
    }

    @Test("a backend with no MitID says so rather than failing generically")
    func unsupported() async {
        let auth = FakeMitIDAuth()
        auth.startError = UnsupportedAuthOperation(operation: "MitID sign-in")
        let coordinator = makeCoordinator(auth)

        await coordinator.start()
        #expect(coordinator.phase == .failed(messageKey: "mitid.errorEdgeFunction"))
    }

    @Test("a successful return redeems the reference and signs in")
    func success() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        )
        #expect(coordinator.phase == .signedIn(didRegister: false))
        #expect(auth.redeemed == ["abc123def456ghi7"])
    }

    /// `registered` is what tells "welcome back" from "your account has been
    /// created".
    @Test("a new MitID subject reports that it registered")
    func registered() async {
        let auth = FakeMitIDAuth()
        auth.outcome = MitIDSignInOutcome(
            session: AuthSession(userID: "c-1", email: "m@example.dk"),
            didRegister: true
        )
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        )
        #expect(coordinator.phase == .signedIn(didRegister: true))
    }

    /// The load-bearing one. The reference is single-use server-side, but that
    /// protects the server: without the state check an injected deep link hands
    /// the app a reference it never asked for, and it signs the user in as
    /// whoever minted it.
    @Test("a callback from another attempt is refused and never redeemed")
    func rejectsForeignState() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=attacker")
        )
        #expect(auth.redeemed.isEmpty, "a foreign reference must never reach the server")
        if case .signedIn = coordinator.phase {
            Issue.record("signed in from a foreign callback")
        }
    }

    /// A deep link with no sign-in in progress is not ours to act on.
    @Test("a callback with no attempt in progress is ignored")
    func ignoresUnsolicited() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)

        let handled = await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=whatever")
        )
        #expect(!handled)
        #expect(auth.redeemed.isEmpty)
        #expect(coordinator.phase == .idle)
    }

    /// One attempt, one reference — a second delivery of the same link must not
    /// be redeemed again.
    @Test("the same callback cannot be replayed")
    func noReplay() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        let link = callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        await coordinator.handle(link)
        await coordinator.handle(link)

        #expect(auth.redeemed.count == 1)
    }

    @Test("a cancelled sign-in reports that, not a generic error")
    func cancelled() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=error&reason=access_denied&state=state-1")
        )
        #expect(coordinator.phase == .failed(messageKey: "mitid.errorCancelled"))
        #expect(auth.redeemed.isEmpty)
    }

    /// Verified live: the server's callback answers a stale attempt with
    /// `reason=session_expired`.
    @Test("an expired session reports an expired link")
    func expiredReason() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=error&reason=session_expired&state=state-1")
        )
        #expect(coordinator.phase == .failed(messageKey: "mitid.errorExpired"))
    }

    /// An unrecognised reason gets the generic message rather than a raw code
    /// shown to the customer.
    @Test("an unknown reason falls back to the generic message")
    func unknownReason() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=error&reason=teapot&state=state-1")
        )
        #expect(coordinator.phase == .failed(messageKey: "mitid.errorGeneric"))
    }

    /// The authorization URL is good for 600 seconds; a return after that is a
    /// stale link, not a mystery failure.
    @Test("a return after the URL expired reports an expired link")
    func expiredByClock() async {
        let auth = FakeMitIDAuth()
        auth.session = MitIDSignInSession(
            authorizationURL: URL(string: "https://broker.test/authorize")!,
            state: "state-1",
            expiresIn: 0
        )
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        )
        #expect(coordinator.phase == .failed(messageKey: "mitid.errorExpired"))
        #expect(auth.redeemed.isEmpty, "an expired reference must not be sent")
    }

    @Test("a refused redemption reports a failure and keeps no attempt")
    func completionFails() async {
        let auth = FakeMitIDAuth()
        auth.completeError = APIError.failure(
            code: "VALIDATION_ERROR", message: "expired or already used", status: 400
        )
        let coordinator = makeCoordinator(auth)
        await coordinator.start()

        await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        )
        #expect(coordinator.phase == .failed(messageKey: "mitid.errorGeneric"))

        // The attempt is over, so a second link cannot resurrect it.
        let handled = await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        )
        #expect(!handled)
    }

    @Test("resetting abandons the attempt")
    func reset() async {
        let auth = FakeMitIDAuth()
        let coordinator = makeCoordinator(auth)
        await coordinator.start()
        coordinator.reset()

        #expect(coordinator.phase == .idle)
        let handled = await coordinator.handle(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=state-1")
        )
        #expect(!handled)
    }
}
