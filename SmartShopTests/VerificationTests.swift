//
//  VerificationTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

// MARK: - Fakes

/// An `IdentityService` that answers from fields and records what it was asked.
private final class FakeIdentity: IdentityService, @unchecked Sendable {
    var current = IdentityStatus(state: .unverified)
    var session = MitIDSignInSession(
        authorizationURL: URL(string: "https://broker.test/authorize")!,
        state: "state-1",
        expiresIn: 600
    )
    var startError: (any Error)?
    private(set) var redeemed: [String] = []
    private(set) var submitted: [VerificationMethod] = []

    func submitDocument(_ method: VerificationMethod, front: Data, back: Data?) async throws -> IdentityStatus {
        submitted.append(method)
        return IdentityStatus(state: .pending)
    }

    func status() async throws -> IdentityStatus { current }

    var supportsMitIDVerification: Bool { true }

    func startMitIDVerification() async throws -> MitIDSignInSession {
        if let startError { throw startError }
        return session
    }

    func completeMitIDVerification(reference: String) async throws {
        redeemed.append(reference)
    }
}

/// An `AccessService` that keeps a list of credentials and logs every call in
/// order, so a test can assert *sequence* — the fob replacement depends on it.
private final class FakeAccess: AccessService, @unchecked Sendable {
    var stored: [AccessCredential] = []
    var listError: (any Error)?
    var addError: (any Error)?
    var outcome = UnlockOutcome(granted: true, doorOpened: false)
    var events: [AccessEvent] = []
    private(set) var log: [String] = []

    func credentials() async throws -> [AccessCredential] {
        if let listError { throw listError }
        return stored
    }

    func addKeyFob(_ number: String) async throws -> AccessCredential {
        log.append("add:\(number)")
        if let addError { throw addError }
        let fob = AccessCredential(id: "new", kind: .keyFob, lastFour: String(number.suffix(4)))
        stored.append(fob)
        return fob
    }

    func revoke(credentialID: String) async throws {
        log.append("revoke:\(credentialID)")
        stored.removeAll { $0.id == credentialID }
    }

    func unlock(accessPointID: String?) async throws -> UnlockOutcome {
        log.append("unlock:\(accessPointID ?? "none")")
        return outcome
    }

    func history(limit: Int) async throws -> [AccessEvent] { Array(events.prefix(limit)) }

    func help(accessPointID: String?, storeID: String?, note: String?) async throws -> String? { nil }
}

/// A browser leg that answers at once with a scripted result.
@MainActor
private final class ScriptedWeb: MitIDWebAuthenticating {
    var result: Result<URL, MitIDWebAuthenticationError>
    private(set) var opened: URL?

    init(_ result: Result<URL, MitIDWebAuthenticationError>) {
        self.result = result
    }

    func authenticate(url: URL, callbackScheme: String) async -> Result<URL, MitIDWebAuthenticationError> {
        opened = url
        return result
    }

    func cancel() {}
}

private let meJSON = """
{"success":true,"data":{"id":"c-1","customerCode":"SS-1","firstName":"Mia","email":"mia@example.dk",
 "emailVerified":true,"phone":"+4512345678","phoneVerified":false,"status":"active",
 "identityVerified":false,"marketingOptIn":false,"onboardingCompleted":true}}
"""

// MARK: - The verification facade

@Suite("Verification facade")
@MainActor
struct APIVerificationServiceTests {
    private func make(
        identity: FakeIdentity = FakeIdentity(),
        access: FakeAccess = FakeAccess()
    ) -> (APIVerificationService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        let service = APIVerificationService(
            client: client,
            identity: identity,
            access: access,
            tickets: StubVerificationService()
        )
        return (service, exchange)
    }

    @Test("status, method, fob and contact details come from three sources")
    func info() async throws {
        let identity = FakeIdentity()
        identity.current = IdentityStatus(state: .pending, documentType: "driving_licence")
        let access = FakeAccess()
        access.stored = [
            AccessCredential(id: "p1", kind: .phone),
            AccessCredential(id: "c1", kind: .keyFob, lastFour: "2345"),
        ]
        let (service, exchange) = make(identity: identity, access: access)
        exchange.queue(.init(status: 200, body: meJSON))

        let info = try await service.info()
        #expect(info.status == .pending)
        #expect(info.method == .license)
        // Only the last four stay readable server-side.
        #expect(info.keyFob == "••••2345")
        #expect(info.phone == "+4512345678")
        #expect(!info.phoneVerified)
        #expect(info.email == "mia@example.dk")
        #expect(info.emailVerified)
    }

    @Test("expired reads as not verified, and MitID is its own method")
    func expiredAndMitID() async throws {
        let identity = FakeIdentity()
        identity.current = IdentityStatus(state: .expired, method: .mitid)
        let (service, exchange) = make(identity: identity)
        exchange.queue(.init(status: 200, body: meJSON))

        let info = try await service.info()
        #expect(info.status == .none)
        #expect(info.method == .mitid)
    }

    @Test("a failed credential list does not hide the verification status")
    func credentialsFailure() async throws {
        let identity = FakeIdentity()
        identity.current = IdentityStatus(state: .verified)
        let access = FakeAccess()
        access.listError = APIError.unexpectedStatus(500)
        let (service, exchange) = make(identity: identity, access: access)
        exchange.queue(.init(status: 200, body: meJSON))

        let info = try await service.info()
        #expect(info.status == .verified)
        #expect(info.keyFob == "")
    }

    @Test("a document is queued for review, never approved on submit")
    func submitIsPending() async throws {
        let identity = FakeIdentity()
        let (service, _) = make(identity: identity)

        let status = try await service.submit(method: .passport, front: Data([1]), back: nil)
        #expect(status == .pending)
        #expect(identity.submitted == [.passport])
    }

    // MARK: Key fob

    /// Adding first means a failure part-way leaves a working fob, not none.
    @Test("replacing a fob adds the new one before revoking the old")
    func replaceOrder() async throws {
        let access = FakeAccess()
        access.stored = [AccessCredential(id: "c1", kind: .keyFob, lastFour: "2345")]
        let (service, _) = make(access: access)

        try await service.saveKeyFob("FOB-9999")
        #expect(access.log == ["add:FOB-9999", "revoke:c1"])
    }

    @Test("a failed add keeps the old fob")
    func failedAddKeepsOld() async {
        let access = FakeAccess()
        access.stored = [AccessCredential(id: "c1", kind: .keyFob, lastFour: "2345")]
        access.addError = APIError.unexpectedStatus(500)
        let (service, _) = make(access: access)

        await #expect(throws: (any Error).self) { try await service.saveKeyFob("FOB-9999") }
        #expect(access.log == ["add:FOB-9999"])
        #expect(access.stored.map(\.id) == ["c1"])
    }

    @Test("saving the masked value it was loaded with changes nothing")
    func unchangedIsNoOp() async throws {
        let access = FakeAccess()
        access.stored = [AccessCredential(id: "c1", kind: .keyFob, lastFour: "2345")]
        let (service, _) = make(access: access)

        try await service.saveKeyFob("••••2345")
        #expect(access.log.isEmpty)
    }

    @Test("removing revokes every fob and leaves other credentials alone")
    func remove() async throws {
        let access = FakeAccess()
        access.stored = [
            AccessCredential(id: "p1", kind: .phone),
            AccessCredential(id: "c1", kind: .keyFob, lastFour: "2345"),
            AccessCredential(id: "c2", kind: .keyFob, lastFour: "1111"),
        ]
        let (service, _) = make(access: access)

        try await service.saveKeyFob(nil)
        #expect(access.log == ["revoke:c1", "revoke:c2"])
        #expect(access.stored.map(\.id) == ["p1"])
    }

    // MARK: Door and checkout

    @Test("the door asks the server, with no reader id from a simulated tap")
    func doorAsksServer() async throws {
        let access = FakeAccess()
        access.outcome = UnlockOutcome(granted: false, doorOpened: false, reason: "not_verified")
        let (service, _) = make(access: access)

        let granted = try await service.logNfcAccess(point: "doer", storeSlug: "espe")
        #expect(!granted)
        #expect(access.log == ["unlock:none"])
    }

    /// No endpoint exists for the checkout, so it must not reach the door.
    @Test("the checkout reads verification and never unlocks anything")
    func checkoutReadsStatus() async throws {
        let identity = FakeIdentity()
        identity.current = IdentityStatus(state: .verified)
        let access = FakeAccess()
        let (service, _) = make(identity: identity, access: access)

        #expect(try await service.logNfcAccess(point: "kasse", storeSlug: nil))
        #expect(access.log.isEmpty)
    }

    @Test("history becomes door entries, newest five")
    func history() async throws {
        let access = FakeAccess()
        access.events = (1...7).map { AccessEvent(id: "e\($0)", at: .now, granted: $0.isMultiple(of: 2)) }
        let (service, _) = make(access: access)

        let entries = try await service.recentNfcAccess()
        #expect(entries.count == 5)
        #expect(entries.allSatisfy { $0.point == "doer" })
        #expect(entries.map(\.approved) == [false, true, false, true, false])
    }
}

// MARK: - MitID verification

@Suite("MitID verification")
@MainActor
struct MitIDVerifierTests {
    private let success = URL(string: "smartshop://mitid?status=success&reference=ref-1234567890abcdef&state=state-1")!

    @Test("a matching callback redeems its reference")
    func verified() async {
        let identity = FakeIdentity()
        let web = ScriptedWeb(.success(success))

        let outcome = await MitIDVerifier(identity: identity, web: web).verify()
        #expect(outcome == .verified)
        #expect(identity.redeemed == ["ref-1234567890abcdef"])
        #expect(web.opened == identity.session.authorizationURL)
    }

    /// Without this check an injected link attaches someone else's identity.
    @Test("a callback for another attempt is refused and not redeemed")
    func foreignState() async {
        let identity = FakeIdentity()
        let web = ScriptedWeb(.success(URL(string: "smartshop://mitid?status=success&reference=ref-1234567890abcdef&state=other")!))

        let outcome = await MitIDVerifier(identity: identity, web: web).verify()
        #expect(outcome == .failed(messageKey: "mitid.errorGeneric"))
        #expect(identity.redeemed.isEmpty)
    }

    @Test("dismissing the browser is a cancel, not an error")
    func dismissed() async {
        let identity = FakeIdentity()
        let outcome = await MitIDVerifier(identity: identity, web: ScriptedWeb(.failure(.cancelled))).verify()
        #expect(outcome == .cancelled)
    }

    @Test("MitID's own refusal reasons map to cancel or expiry")
    func reasons() async {
        let identity = FakeIdentity()
        let denied = ScriptedWeb(.success(URL(string: "smartshop://mitid?status=error&reason=access_denied&state=state-1")!))
        #expect(await MitIDVerifier(identity: identity, web: denied).verify() == .cancelled)

        let expired = ScriptedWeb(.success(URL(string: "smartshop://mitid?status=error&reason=session_expired&state=state-1")!))
        #expect(await MitIDVerifier(identity: identity, web: expired).verify() == .failed(messageKey: "mitid.errorExpired"))
        #expect(identity.redeemed.isEmpty)
    }

    @Test("a return after the session's lifetime is expired")
    func expiredByClock() async {
        let identity = FakeIdentity()
        identity.session.expiresIn = -1
        let outcome = await MitIDVerifier(identity: identity, web: ScriptedWeb(.success(success))).verify()
        #expect(outcome == .failed(messageKey: "mitid.errorExpired"))
        #expect(identity.redeemed.isEmpty)
    }

    @Test("a session that cannot start never opens the browser")
    func startFails() async {
        let identity = FakeIdentity()
        identity.startError = APIError.unavailable(message: "No broker")
        let web = ScriptedWeb(.success(success))

        #expect(await MitIDVerifier(identity: identity, web: web).verify() == .failed(messageKey: "mitid.errorGeneric"))
        #expect(web.opened == nil)
    }
}

// MARK: - Identity over the wire

@Suite("Identity service")
struct APIIdentityServiceTests {
    private func makeService() -> (APIIdentityService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APIIdentityService(client: client), exchange)
    }

    @Test("status carries method, document type and whether MitID is offered")
    func status() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"state":"rejected","isVerified":false,"method":"manual","documentType":"passport",
         "verifiedAt":null,"expiresAt":null,"rejectionReason":"The photo was too blurry to read",
         "ageOver18":null,"mitIdAvailable":true}}
        """))

        let status = try await service.status()
        #expect(status.state == .rejected)
        #expect(status.method == .manual)
        #expect(status.documentType == "passport")
        #expect(status.rejectionReason == "The photo was too blurry to read")
        #expect(status.mitIDAvailable)
    }

    /// Consent and photo are one decision, so they travel in one request.
    @Test("enrolling sends consent with the photo, as multipart")
    func enrolFace() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 202, body: #"{"success":true,"data":{"available":true,"enrolled":false}}"#))

        let face = try await service.enrolFace(photo: Data("jpeg".utf8), consent: true)
        #expect(face == FaceStatus(available: true, enrolled: false))
        let request = try #require(exchange.recorded.first)
        #expect(request.url?.path == "/mobile/identity/face")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        let body = try #require(request.bodyText)
        #expect(body.contains("name=\"consent\"\r\n\r\ntrue"))
        #expect(body.contains("name=\"photo\"; filename=\"face.jpg\""))
    }

    @Test("a 503 from face enrolment surfaces as unavailable")
    func faceUnavailable() async {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 503, body: #"{"success":false,"message":"Face recognition is not configured","code":"SERVICE_UNAVAILABLE","data":null}"#))

        await #expect(throws: APIError.self) { _ = try await service.enrolFace(photo: Data([1]), consent: true) }
    }

    @Test("MitID verification starts as iOS and redeems by reference")
    func mitIDRoundTrip() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"authorizationUrl":"https://broker.test/authorize?x=1","state":"s-1","expiresIn":600}}
        """))
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{}}"#))

        let session = try await service.startMitIDVerification()
        #expect(session.state == "s-1")
        #expect(session.authorizationURL.host() == "broker.test")
        try await service.completeMitIDVerification(reference: "ref-1234567890abcdef")

        #expect(exchange.recorded.map { $0.url?.path } == ["/mobile/identity/mitid/session", "/mobile/identity/mitid/result"])
        #expect(exchange.recorded.first?.bodyText == #"{"deviceType":"ios"}"#)
        // `{reference}`, not the stale Postman example's `{code, state}`.
        #expect(exchange.recorded.last?.bodyText == #"{"reference":"ref-1234567890abcdef"}"#)
    }
}

// MARK: - Ticket statuses

@Suite("Ticket statuses")
struct TicketStatusTests {
    private func ticket(status: String) async throws -> EventTicket {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[{"id":"t1","status":"\(status)","awaitingPayment":false}]}
        """))
        return try #require(try await APIEventService(client: client).myTickets().first)
    }

    @Test("held statuses", arguments: ["confirmed", "paid", "CONFIRMED"])
    func held(status: String) async throws {
        #expect(try await ticket(status: status).isHeld)
    }

    @Test("not-held statuses", arguments: ["cancelled", "canceled", "released", "expired", "refunded", ""])
    func notHeld(status: String) async throws {
        #expect(try await !ticket(status: status).isHeld)
    }

    @Test("reserved with no expiry is held and awaiting payment")
    func reserved() async throws {
        let ticket = try await ticket(status: "reserved")
        #expect(ticket.isHeld)
        #expect(ticket.isAwaitingPayment)
    }
}
