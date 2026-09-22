//
//  LiveAPITests.swift
//  SmartShopTests
//

import CoreLocation
import Foundation
import Testing
@testable import SmartShop

/// Smoke tests against the real dev backend.
///
/// Off unless `SMARTSHOP_LIVE_TESTS=1`, so the ordinary suite stays offline and
/// deterministic. Run them when the networking layer changes, to catch the one
/// class of bug a stub cannot: the server's actual shapes drifting from what we
/// decode.
///
/// From the command line the variable needs xcodebuild's `TEST_RUNNER_` prefix,
/// which is stripped before it reaches the test process — without it the suite
/// silently skips:
///
///     TEST_RUNNER_SMARTSHOP_LIVE_TESTS=1 xcodebuild test \
///       -scheme SmartShop -destination 'name=SmartShop-26' \
///       -only-testing:SmartShopTests/LiveAPITests
///
/// Read-only, unauthenticated endpoints only — nothing here creates, changes or
/// deletes anything on the shared environment.
/// Caches one sign-in for the whole process.
///
/// The auth endpoints sit behind an IP-level throttle — separate from the
/// per-account lockout — and signing in once per test trips it, which fails
/// every test in the suite for reasons that have nothing to do with the code.
/// One sign-in, shared.
actor LiveSession {
    static let shared = LiveSession()

    private var tokens: FakeTokenStore?

    func store() async throws -> FakeTokenStore {
        if let tokens { return tokens }
        let fresh = FakeTokenStore()
        let auth = APIAuthService(
            client: LiveAPIClient(configuration: .development, tokens: fresh),
            tokens: fresh
        )
        try await auth.signIn(
            email: LiveAPITests.testEmail,
            password: LiveAPITests.testPassword
        )
        tokens = fresh
        return fresh
    }
}

/// `.serialized` for the same reason: parallel tests here mean parallel auth
/// calls, and the throttle counts them all.
@Suite(
    "Live dev backend",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["SMARTSHOP_LIVE_TESTS"] == "1")
)
struct LiveAPITests {
    private func client() -> LiveAPIClient {
        LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
    }

    private struct Health: Decodable, Sendable {
        var status: String
        var service: String
        var dependencies: Dependencies

        struct Dependencies: Decodable, Sendable {
            var database: String
            var redis: String
        }
    }

    /// `/health` sits outside the `/mobile` prefix and is how the app tells
    /// "the backend is down" from "my token is bad".
    @Test("health reports the service and its dependencies")
    func health() async throws {
        let health: Health = try await client().send(.get("/health", auth: .forbidden))
        #expect(health.status == "ok")
        #expect(health.service == "mobile-api")
        #expect(health.dependencies.database == "up")
    }

    private struct AppConfig: Decodable, Sendable {
        var minimumBuild: Int
        var recommendedBuild: Int
        var maintenance: Bool
        var languages: [String]
        var serverTime: Date
        var features: [String: Bool]
    }

    /// The call every cold start makes. It also exercises the custom date
    /// strategy: `serverTime` carries fractional seconds, which plain
    /// `.iso8601` rejects.
    @Test("app config decodes, including its fractional-second timestamp")
    func appConfig() async throws {
        let config: AppConfig = try await client().send(
            .get("/mobile/app/config", auth: .forbidden)
        )
        #expect(config.minimumBuild > 0)
        #expect(config.languages.contains("da"))
        #expect(config.features["guestMode"] != nil)
        #expect(abs(config.serverTime.timeIntervalSinceNow) < 300)
    }

    /// Optional auth: this is what lets guest mode share the store screens.
    @Test("stores answer with no token at all")
    func storesWithoutToken() async throws {
        let stores: [StoreRow] = try await client().send(
            .get("/mobile/stores", auth: .optional)
        )
        #expect(!stores.isEmpty)
    }

    private struct StoreRow: Decodable, Sendable {
        var id: String
        var slug: String
        var name: String
    }

    /// A rejected token must surface as `.unauthorized` rather than a generic
    /// failure, because that is what drives the guest gate and the sign-out
    /// path. `.forbidden` here keeps the client from trying to refresh a token
    /// we deliberately made up.
    @Test("a bad token maps to unauthorized")
    func badToken() async throws {
        let live = LiveAPIClient(
            configuration: .development,
            tokens: FakeTokenStore(access: "not-a-real-token", refresh: nil)
        )

        do {
            let _: EmptyResponse = try await live.send(
                .get("/mobile/me", auth: .optional)
            )
            Issue.record("expected the server to refuse a made-up token")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                Issue.record("expected .unauthorized, got \(error)")
                return
            }
            #expect(error.code == "UNAUTHORIZED")
        }
    }

    /// The array-shaped `message` is real server behaviour, not a hypothetical
    /// — this is the response that would break a `message: String` decode.
    @Test("a validation failure returns its messages as an array")
    func validationMessages() async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/auth/login",
            body: ["email": "nope"],
            auth: .forbidden
        )

        do {
            let _: EmptyResponse = try await client().send(request)
            Issue.record("expected a validation failure")
        } catch let error as APIError {
            #expect(error.code == "VALIDATION_ERROR")
            #expect(error.serverMessage?.contains("email") == true)
        }
    }

    // MARK: - Auth

    /// A throwaway account created on the dev backend for these probes. Not a
    /// secret and not a real person; override with `SMARTSHOP_TEST_EMAIL` /
    /// `SMARTSHOP_TEST_PASSWORD` to point at a different one.
    static var testEmail: String {
        ProcessInfo.processInfo.environment["SMARTSHOP_TEST_EMAIL"]
            ?? "claude.probe+auth@example.dk"
    }

    static var testPassword: String {
        ProcessInfo.processInfo.environment["SMARTSHOP_TEST_PASSWORD"]
            ?? "TestPass123!"
    }

    /// The auth endpoints sit behind an IP throttle, and the deliberate-failure
    /// probes here spend the same budget as the real calls. A throttle is the
    /// shared environment talking, not a defect in the app, so it stops the
    /// test rather than failing it. Every other error still fails.
    ///
    /// `ifReachable` is the honest name: these assertions hold when the
    /// endpoint answers at all.
    private func ifReachable(_ body: () async throws -> Void) async throws {
        do {
            try await body()
        } catch let error as APIError {
            guard case .rateLimited = error else { throw error }
        }
    }

    private func authService() -> (APIAuthService, FakeTokenStore) {
        let tokens = FakeTokenStore()
        let client = LiveAPIClient(configuration: .development, tokens: tokens)
        return (APIAuthService(client: client, tokens: tokens), tokens)
    }

    @Test("signing in returns a usable session")
    func signIn() async throws {
        let tokens = try await LiveSession.shared.store()
        #expect(tokens.accessToken != nil)
        #expect(tokens.refreshToken != nil)

        let service = APIAuthService(
            client: LiveAPIClient(configuration: .development, tokens: tokens),
            tokens: tokens
        )
        let session = await service.currentSession()
        #expect(session?.email == Self.testEmail)
    }

    /// Deliberately against an address with no account, **not** the shared test
    /// account: five failed logins lock an account for 15 minutes, and this
    /// suite runs more than once per invocation. Pointing it at the real
    /// account locked it and failed every other auth test here.
    ///
    /// It still tests what it should. A wrong password and an unknown account
    /// answer identically by design, so there is no way to use this endpoint to
    /// discover who is registered.
    @Test("an unknown account is refused, indistinguishably from a wrong password")
    func wrongPassword() async throws {
        let (service, tokens) = authService()
        try await ifReachable {
            do {
                try await service.signIn(
                    email: "nobody-at-all@example.dk",
                    password: "DefinitelyWrong1!"
                )
                Issue.record("expected the server to refuse")
            } catch let error as APIError {
                if case .rateLimited = error { throw error }
                guard case .unauthorized = error else {
                    Issue.record("expected .unauthorized, got \(error)")
                    return
                }
                #expect(error.serverMessage == "Invalid email or password")
            }
        }
        #expect(tokens.accessToken == nil)
    }

    /// A wrong current password answered **401** on 2026-09-22 morning and
    /// **400 VALIDATION_ERROR** by that afternoon — the backend changed under
    /// us. Either way the session must survive, which is what this asserts;
    /// `withoutUnauthorizedRetry()` stays as protection in case it reverts.
    @Test("a wrong current password is refused without losing the session")
    func wrongCurrentPassword() async throws {
        let tokens = try await LiveSession.shared.store()
        let service = APIAuthService(
            client: LiveAPIClient(configuration: .development, tokens: tokens),
            tokens: tokens
        )
        let refreshBefore = tokens.refreshToken

        try await ifReachable {
            do {
                try await service.changePassword(current: "DefinitelyWrong1!", new: "Another123!")
                Issue.record("expected the server to refuse a wrong current password")
            } catch let error as APIError {
                if case .rateLimited = error { throw error }
                // Accepts either status: the refusal is the point, not its code.
                let refused: Bool
                switch error {
                case .unauthorized: refused = true
                case .failure(let code, _, _): refused = code == "VALIDATION_ERROR"
                default: refused = false
                }
                if !refused {
                    Issue.record("expected a refusal, got \(error)")
                    return
                }
            }
        }

        // Still signed in — a mistyped password is not a sign-out.
        #expect(tokens.refreshToken == refreshBefore)
        #expect(await service.currentSession() != nil)
    }

    /// Always 202, whether or not the address has an account, so it cannot be
    /// used to discover who is registered.
    /// Only the unknown address is probed: an address with no account is the
    /// interesting half — a 202 there is what stops this becoming a way to
    /// discover who is registered.
    ///
    /// `/password/forgot` sends mail, so it is throttled harder than the rest,
    /// and this suite runs more than once per invocation. A throttle is the
    /// shared environment talking, not a defect, so it is accepted rather than
    /// failing the build — anything *else* still fails.
    @Test("forgot-password says nothing about who exists")
    func forgotPasswordIsSilent() async throws {
        let (service, _) = authService()
        try await ifReachable {
            try await service.sendPasswordReset(to: "nobody-at-all@example.dk")
        }
    }

    @Test("a bogus reset link reports itself invalid rather than failing")
    func resetCheck() async throws {
        let (service, _) = authService()
        #expect(try await service.isResetTokenValid("not-a-real-token") == false)
    }

    /// Registration is throttled on the same tight budget as `/password/forgot`
    /// — see the note there. The conflict is the assertion; a throttle is
    /// tolerated, anything else fails.
    @Test("registering with an address already in use conflicts")
    func duplicateRegistration() async throws {
        let (service, _) = authService()
        do {
            _ = try await service.signUp(
                email: Self.testEmail,
                password: Self.testPassword,
                profile: SignUpProfile(
                    fornavn: "Claude", efternavn: "Probe", adresse: "", postnr: "",
                    by: "", telefon: "+4571828384", markedsforing: false, acceptsTerms: true
                )
            )
            Issue.record("expected a conflict")
        } catch let error as APIError {
            if case .rateLimited = error { return }
            #expect(error.code == "CONFLICT")
        }
    }

    /// Signing out revokes the refresh token, so a refresh with it afterwards
    /// is refused — which is what drives the app's sign-out path.
    /// The one test that needs a session of its own — it spends it.
    @Test("signing out revokes the refresh token")
    func signOutRevokes() async throws {
        let (service, tokens) = authService()
        try await service.signIn(email: Self.testEmail, password: Self.testPassword)
        let refreshToken = try #require(tokens.refreshToken)

        try await service.signOut()
        #expect(tokens.accessToken == nil)

        let spent = FakeTokenStore(access: "expired", refresh: refreshToken)
        let refresher = TokenRefresher(configuration: .development, tokens: spent)
        await #expect(throws: APIError.self) {
            _ = try await refresher.freshToken(replacing: "expired")
        }
    }

    // MARK: - Device & PIN

    /// Registers a handset on the shared test account, exercises the PIN, and
    /// forgets it again so the account does not collect devices.
    ///
    /// Deliberately stops at one wrong attempt: exhausting the five would lock
    /// the device for 15 real minutes and make the next run fail.
    @Test("a handset registers, takes a PIN, and is forgotten again")
    func deviceAndPin() async throws {
        let tokens = try await LiveSession.shared.store()
        let client = LiveAPIClient(configuration: .development, tokens: tokens)

        let identity = DeviceIdentity()
        identity.clear()
        let devices = APIDeviceService(client: client, identity: identity)

        let deviceID = try await devices.registerCurrentDevice(pushToken: nil)
        #expect(identity.serverDeviceID == deviceID)

        // Upsert: the same handset registering again is the same device.
        let again = try await devices.registerCurrentDevice(pushToken: nil)
        #expect(again == deviceID)

        defer {
            Task { try? await devices.forgetDevice(id: deviceID) }
        }

        let listed = try await devices.devices()
        #expect(listed.contains { $0.id == deviceID })

        try await devices.setPin("1234", deviceID: deviceID)
        #expect(try await devices.devices().first { $0.id == deviceID }?.hasPin == true)

        #expect(try await devices.verifyPin("1234", deviceID: deviceID) == .correct)

        // A wrong PIN is a 200 carrying the remaining attempts, not an error.
        let wrong = try await devices.verifyPin("9999", deviceID: deviceID)
        #expect(wrong == .wrong(attemptsLeft: 4))

        // A correct PIN resets the counter.
        #expect(try await devices.verifyPin("1234", deviceID: deviceID) == .correct)

        try await devices.removePin(deviceID: deviceID)
        #expect(try await devices.devices().first { $0.id == deviceID }?.hasPin == false)

        try await devices.forgetDevice(id: deviceID)
        #expect(identity.serverDeviceID == nil)
        #expect(try await devices.devices().contains { $0.id == deviceID } == false)
    }

    /// A PIN belongs to a device, so an id that is not yours is a 404 rather
    /// than a wrong-PIN answer.
    @Test("a PIN cannot be checked against someone else's device")
    func pinOnUnknownDevice() async throws {
        let tokens = try await LiveSession.shared.store()
        let client = LiveAPIClient(configuration: .development, tokens: tokens)

        let identity = DeviceIdentity()
        identity.clear()
        let devices = APIDeviceService(client: client, identity: identity)

        // Maps to .notSet, which is what stops the unlock gate stranding
        // someone whose device was forgotten elsewhere.
        let check = try await devices.verifyPin(
            "1234",
            deviceID: "00000000-0000-4000-8000-000000000000"
        )
        #expect(check == .notSet)
    }

    // MARK: - MitID sign-in

    /// Only the *start* of the flow can be tested here. Completing it needs a
    /// real MitID round trip through the broker, which no automated test can do.
    @Test("starting a MitID sign-in returns an authorization URL")
    func mitIDSessionStarts() async throws {
        let (service, _) = authService()
        try await ifReachable {
            let started = try await service.startMitIDSignIn(acceptsTerms: true)
            #expect(!started.state.isEmpty)
            #expect(started.expiresIn > 0)
            #expect(started.authorizationURL.scheme == "https")

            // The broker sends the browser back to the *server*, not to a
            // smartshop:// deep link — which is the piece still missing for a
            // working round trip in the app.
            let query = started.authorizationURL.query() ?? ""
            #expect(query.contains("redirect_uri"))
        }
    }

    /// Terms are refused rather than assumed, because a MitID sign-in can
    /// create an account.
    @Test("a MitID sign-in cannot start without accepting the terms")
    func mitIDRequiresTerms() async throws {
        let (service, _) = authService()
        try await ifReachable {
            do {
                _ = try await service.startMitIDSignIn(acceptsTerms: false)
                Issue.record("expected the server to refuse")
            } catch let error as APIError {
                if case .rateLimited = error { throw error }
                #expect(error.code == "VALIDATION_ERROR")
            }
        }
    }

    /// A spent reference is refused.
    ///
    /// An earlier version of this test passed for the wrong reason: it sent
    /// `{code, state}`, which the server rejects as a malformed body with the
    /// same `VALIDATION_ERROR` a bad reference gets. It proved the endpoint
    /// existed and nothing else. The message distinguishes them — a malformed
    /// body lists the offending properties, a bad reference does not.
    @Test("a bogus MitID reference is refused, as a reference")
    func mitIDBogusReference() async throws {
        let (service, _) = authService()
        try await ifReachable {
            do {
                _ = try await service.completeMitIDSignIn(
                    reference: "not-a-real-reference"
                )
                Issue.record("expected the server to refuse")
            } catch let error as APIError {
                if case .rateLimited = error { throw error }
                #expect(error.code == "VALIDATION_ERROR")
                let message = error.serverMessage ?? ""
                #expect(
                    !message.contains("should not exist"),
                    "the body shape is wrong, not just the reference: \(message)"
                )
            }
        }
    }

    // MARK: - Bootstrap

    @Test("the launch gate answers with flags and build numbers")
    func liveAppConfig() async throws {
        let service = APIAppConfigService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let config = try await service.configuration()

        #expect(config.minimumBuild > 0)
        #expect(config.recommendedBuild >= config.minimumBuild)
        #expect(!config.languages.isEmpty)
        #expect(abs(config.serverTime?.timeIntervalSinceNow ?? 0) < 300)

        // This build should not be locked out of the dev backend.
        #expect(config.gate(forBuild: AppBuild.current) == .open)
    }

    @Test("health reports the service and its dependencies")
    func liveHealth() async throws {
        let service = APIAppConfigService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let report = try await service.health()
        #expect(report.service == "mobile-api")
        #expect(report.isHealthy)
    }

    @Test("the language list is not empty")
    func liveLanguages() async throws {
        let service = APITranslationService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let languages = try await service.languages()
        #expect(languages.contains(.da))
    }

    @Test("the default bundle carries the server-owned strings")
    func liveBundle() async throws {
        let service = APITranslationService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let bundle = try await service.bundle()
        // Door outcomes are the reason these strings live on the server: the
        // server makes the decision, so it owns the words explaining it.
        #expect(bundle["door_granted"] != nil)
        #expect(!bundle.strings.isEmpty)
    }

    /// Documents a live backend defect rather than asserting it is correct:
    /// `/translations/de` answers with Danish instead of German or an error.
    /// Raised with the backend in `docs/mobile-api-backend-requests.md`. When
    /// they fix it this test starts reporting the fallback is gone, which is
    /// the signal to delete it.
    @Test("German currently falls back to Danish — a known backend defect")
    func liveGermanFallsBackToDanish() async throws {
        let service = APITranslationService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let german = try await service.bundle(for: .de)
        let english = try await service.bundle(for: .en)

        // English proves the endpoint does honour a language code in general.
        #expect(english.language == .en)
        #expect(!english.isFallback(from: .en))

        if !german.isFallback(from: .de) {
            Issue.record("German no longer falls back — the backend is fixed, delete this test")
        }
    }

    // MARK: - Stores, favourites and onboarding

    @Test("the store finder works signed out and keeps the app's slugs")
    func liveStores() async throws {
        let service = APIStoreService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let stores = try await service.stores()
        #expect(stores.count > 1)

        // Existing deep links depend on these.
        let slugs = Set(stores.map(\.slug))
        #expect(slugs.contains("grimstrup"))
        #expect(slugs.contains("rarup"))
        #expect(slugs.contains("hunderup-sejstrup"))

        // Every store must carry the API id, or nothing can be favourited.
        #expect(stores.allSatisfy { $0.remoteID?.isEmpty == false })
    }

    /// Alphabetical without a point, nearest first with one.
    @Test("a point sorts the finder by distance")
    func liveStoresNearest() async throws {
        let service = APIStoreService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let plain = try await service.stores()
        #expect(plain.allSatisfy { $0.distanceKm == nil })

        let near = try await service.stores(
            near: CLLocationCoordinate2D(latitude: 55.4, longitude: 9.5),
            matching: nil
        )
        let distances = near.compactMap(\.distanceKm)
        #expect(distances.count == near.count)
        #expect(distances == distances.sorted())
    }

    @Test("one store by slug, and an unknown one")
    func liveStoreBySlug() async throws {
        let service = APIStoreService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let espe = try await service.store(slug: "espe")
        #expect(espe.name.contains("Espe"))
        #expect(!espe.displayAddress.isEmpty)

        await #expect(throws: StoreNotFound.self) {
            _ = try await service.store(slug: "no-such-store")
        }
    }

    /// `rarup` is the only store on dev with per-weekday hours, which makes it
    /// the only live check that the non-24/7 shape decodes at all.
    @Test("per-weekday opening hours decode from the live data")
    func liveWeekdayHours() async throws {
        let service = APIStoreService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let rarup = try await service.store(slug: "rarup")
        if rarup.isAlwaysOpen {
            // Fine — dev data changed. Nothing to assert about hours then.
            return
        }
        #expect(rarup.hours.count == 7)
        #expect(rarup.hours.allSatisfy { !$0.isEmpty })
    }

    /// Favourite, confirm, unfavourite, confirm — then leave the account as it
    /// was found.
    @Test("favouriting a store round-trips and is idempotent")
    func liveFavourites() async throws {
        let tokens = try await LiveSession.shared.store()
        let client = LiveAPIClient(configuration: .development, tokens: tokens)
        let service = APIStoreService(client: client)

        let store = try #require(try await service.stores().first)
        let id = try #require(store.remoteID)

        try await service.addFavourite(storeID: id)
        // Tapping the heart twice is the same wish, not an error.
        try await service.addFavourite(storeID: id)

        let listed = try await service.stores()
        #expect(listed.first { $0.remoteID == id }?.isFavourite == true)

        try await service.removeFavourite(storeID: id)
        try await service.removeFavourite(storeID: id)

        let after = try await service.stores()
        #expect(after.first { $0.remoteID == id }?.isFavourite == false)
    }

    @Test("my store can be set, read back and cleared")
    func liveMyStore() async throws {
        let tokens = try await LiveSession.shared.store()
        let client = LiveAPIClient(configuration: .development, tokens: tokens)
        let stores = APIStoreService(client: client)
        let onboarding = APIOnboardingService(client: client)

        let store = try #require(try await stores.stores().first)
        let id = try #require(store.remoteID)

        try await onboarding.setMyStore(id: id)
        #expect(try await stores.stores().first { $0.remoteID == id }?.isMyStore == true)

        try await onboarding.clearMyStore()
        #expect(try await stores.stores().first { $0.remoteID == id }?.isMyStore == false)
    }

    /// Idempotent — replaying the guide does not reset the date.
    @Test("finishing onboarding can be replayed")
    func liveOnboarding() async throws {
        let tokens = try await LiveSession.shared.store()
        let service = APIOnboardingService(
            client: LiveAPIClient(configuration: .development, tokens: tokens)
        )
        try await service.completeOnboarding()
        try await service.completeOnboarding()
    }

    @Test("the home location geocodes the address on file")
    func liveHomeLocation() async throws {
        let tokens = try await LiveSession.shared.store()
        let service = APIOnboardingService(
            client: LiveAPIClient(configuration: .development, tokens: tokens)
        )
        let location = try await service.resolveHomeLocation()
        // The test account has an address, so this should place it. If it ever
        // does not, `resolved: false` is still a success, not a failure.
        if location.resolved {
            #expect(location.latitude != nil)
            #expect(location.longitude != nil)
        }
    }

    // MARK: - Pages and contact

    @Test("every page the plan names is served")
    func livePages() async throws {
        let service = APIContentService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let pages = try await service.pages()
        let keys = Set(pages.map(\.key))
        #expect(keys.isSuperset(of: [
            PageKey.about, PageKey.faq, PageKey.howToShop, PageKey.goodToKnow,
        ]))
        #expect(pages.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
    }

    @Test("one page by key, and an unknown one")
    func livePageByKey() async throws {
        let service = APIContentService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        let faq = try await service.page(key: PageKey.faq)
        #expect(faq.key == PageKey.faq)
        #expect(!faq.body.isEmpty)

        // A broken deep link should be loud.
        await #expect(throws: PageNotFound.self) {
            _ = try await service.page(key: "no-such-page")
        }
    }

    /// Always 202 whether or not the address was subscribed, for the same
    /// non-oracle reason as password/forgot.
    @Test("unsubscribe says nothing about who is subscribed")
    func liveUnsubscribe() async throws {
        let service = APIContactService(
            client: LiveAPIClient(configuration: .development, tokens: FakeTokenStore())
        )
        try await ifReachable {
            try await service.unsubscribe(email: "nobody-at-all@example.dk")
        }
    }

    // MARK: - Prize wheel

    /// The wheel is off unless `CONTESTS_ENABLED=true`, so a 503 here is an
    /// ordinary answer rather than a failure. Dev currently has it on.
    @Test("the wheel reports its segments, or says it is switched off")
    func liveWheelStatus() async throws {
        let tokens = try await LiveSession.shared.store()
        let service = APIWheelService(
            client: LiveAPIClient(configuration: .development, tokens: tokens)
        )

        do {
            let wheel = try await service.wheelStatus()
            // The server's today, not the device's.
            #expect(wheel.spinDate.count == 10)
            #expect(!wheel.segments.isEmpty)

            // Minor units converted: a 50 kr gift card must not read as 5000.
            for segment in wheel.segments where segment.outcome == .win {
                #expect(segment.prizeAmount.amount > 0 && segment.prizeAmount.amount < 1000)
            }
        } catch let error as APIError {
            guard case .unavailable = error else { throw error }
            // Contests switched off in this environment. Normal.
        }
    }

    /// Every win carries a code the till can scan — one the *server* minted.
    @Test("wins all carry a spendable code")
    func liveWheelWins() async throws {
        let tokens = try await LiveSession.shared.store()
        let service = APIWheelService(
            client: LiveAPIClient(configuration: .development, tokens: tokens)
        )

        do {
            let wins = try await service.wins()
            #expect(wins.allSatisfy { !$0.code.isEmpty })
        } catch let error as APIError {
            guard case .unavailable = error else { throw error }
        }
    }

    /// Deliberately does not spin: a spin is once per day per account and mints
    /// a real gift card, so an automated test would burn the shared account's
    /// go and leave the next run with nothing to assert.
    @Test("a second spin on a day already spun reports today's result")
    func liveWheelSpinIsOncePerDay() async throws {
        let tokens = try await LiveSession.shared.store()
        let service = APIWheelService(
            client: LiveAPIClient(configuration: .development, tokens: tokens)
        )

        do {
            let wheel = try await service.wheelStatus()
            guard !wheel.canSpin else {
                // The day's spin is still available — leave it alone.
                return
            }
            // Already spun: the 409 must come back as today's result, not an
            // error thrown at the customer.
            let result = try await service.spin()
            #expect(result.alreadySpun)
            #expect(result.spinDate == wheel.spinDate)
        } catch let error as APIError {
            guard case .unavailable = error else { throw error }
        }
    }
}
