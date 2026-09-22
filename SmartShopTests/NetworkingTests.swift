//
//  NetworkingTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

// MARK: - Test doubles

/// Serves canned replies to `URLSession` so the layer can be exercised without
/// a backend.
///
/// Swift Testing runs suites in parallel, so the queue cannot live in a global
/// — concurrent tests would hand each other their replies. Each test gets its
/// own `Exchange`, registered under an id that travels to the protocol as a
/// request header set on that test's own `URLSessionConfiguration`.
final class StubURLProtocol: URLProtocol {
    struct Reply: Sendable {
        var status: Int
        var body: String
    }

    /// Requests seen so far, and the replies still to hand out. Locked because
    /// `URLProtocol` runs on whatever thread the session gives it.
    final class Exchange: @unchecked Sendable {
        let id = UUID().uuidString
        private let lock = NSLock()
        private var queued: [Reply] = []
        private var seen: [URLRequest] = []

        func queue(_ replies: Reply...) {
            lock.withLock { queued.append(contentsOf: replies) }
        }

        func next(for request: URLRequest) -> Reply {
            lock.withLock {
                seen.append(request)
                // The last reply repeats, so a test only queues what it cares
                // about rather than counting calls.
                return queued.count > 1
                    ? queued.removeFirst()
                    : (queued.first ?? Reply(status: 500, body: ""))
            }
        }

        var recorded: [URLRequest] { lock.withLock { seen } }
    }

    static let header = "X-Stub-Exchange"

    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var exchanges: [String: Exchange] = [:]

        func register(_ exchange: Exchange) {
            lock.withLock { exchanges[exchange.id] = exchange }
        }

        func exchange(id: String) -> Exchange? {
            lock.withLock { exchanges[id] }
        }
    }

    private static let registry = Registry()

    static func register(_ exchange: Exchange) { registry.register(exchange) }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: Self.header),
              let exchange = Self.registry.exchange(id: id)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let reply = exchange.next(for: request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

/// In-memory stand-in for the Keychain.
final class FakeTokenStore: TokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var access: String?
    private var refresh: String?

    init(access: String? = nil, refresh: String? = nil) {
        self.access = access
        self.refresh = refresh
    }

    var accessToken: String? { lock.withLock { access } }
    var refreshToken: String? { lock.withLock { refresh } }

    func save(accessToken: String, refreshToken: String?) {
        lock.withLock {
            access = accessToken
            if let refreshToken { refresh = refreshToken }
        }
    }

    func clear() { lock.withLock { access = nil; refresh = nil } }
}

func makeStubbedClient(
    tokens: any TokenStoring,
    localization: APILocalization = APILocalization()
) -> (LiveAPIClient, StubURLProtocol.Exchange) {
    let exchange = StubURLProtocol.Exchange()
    StubURLProtocol.register(exchange)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    configuration.httpAdditionalHeaders = [StubURLProtocol.header: exchange.id]
    let session = URLSession(configuration: configuration)

    let apiConfiguration = APIConfiguration(baseURL: URL(string: "https://example.test")!)
    let client = LiveAPIClient(
        configuration: apiConfiguration,
        session: session,
        tokens: tokens,
        refresher: TokenRefresher(
            configuration: apiConfiguration,
            session: session,
            tokens: tokens
        ),
        localization: localization
    )
    return (client, exchange)
}

private struct Health: Decodable, Sendable {
    var status: String
}

// MARK: - Envelope

@Suite("Envelope")
struct EnvelopeTests {
    @Test("unwraps data on success")
    func unwrapsData() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(status: 200, body: #"{"success":true,"message":"Success","data":{"status":"ok"}}"#))

        let health: Health = try await client.send(.get("/health", auth: .forbidden))
        #expect(health.status == "ok")
    }

    /// A `VALIDATION_ERROR` answers with an array of messages rather than one
    /// string. Decoding it as a plain `String` would throw on every 400 and
    /// lose the only useful part of the response.
    @Test("reads a message that arrives as an array")
    func arrayMessage() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(
            status: 400,
            body: #"{"success":false,"message":["email must be an email","password should not be empty"],"code":"VALIDATION_ERROR","data":null}"#
        ))

        await #expect(throws: APIError.self) {
            let _: Health = try await client.send(.get("/mobile/me", auth: .forbidden))
        }

        do {
            let _: Health = try await client.send(.get("/mobile/me", auth: .forbidden))
        } catch let error as APIError {
            #expect(error.code == "VALIDATION_ERROR")
            #expect(error.serverMessage?.contains("email must be an email") == true)
            #expect(error.serverMessage?.contains("password should not be empty") == true)
        }
    }

    @Test("a success with no data satisfies a caller that wanted none")
    func emptyData() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(status: 200, body: #"{"success":true,"message":"Success","data":null}"#))

        let _: EmptyResponse = try await client.send(.post("/mobile/me/onboarding/complete", auth: .forbidden))
    }

    /// Five failed logins lock an account for 15 minutes, and the correct
    /// password is refused during it — so this must not reach the login screen
    /// as "wrong password".
    @Test("maps 429 to rateLimited rather than a wrong-credentials failure")
    func rateLimited() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(
            status: 429,
            body: #"{"success":false,"message":"Too many failed attempts. Try again in 15 minute(s).","code":"RATE_LIMITED","data":null}"#
        ))

        do {
            let _: Health = try await client.send(.get("/mobile/auth/login", auth: .forbidden))
            Issue.record("expected a failure")
        } catch let error as APIError {
            guard case .rateLimited = error else {
                Issue.record("expected .rateLimited, got \(error)")
                return
            }
            #expect(error.serverMessage?.contains("15 minute") == true)
        }
    }

    /// 503 is the normal answer for the wheel with contests switched off, and
    /// for face enrolment without a collection — not a misconfiguration.
    @Test("maps 503 to unavailable rather than a generic failure")
    func unavailable() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(
            status: 503,
            body: #"{"success":false,"message":"Contests are disabled","code":"SERVICE_UNAVAILABLE","data":null}"#
        ))

        do {
            let _: Health = try await client.send(.get("/mobile/contests/wheel/status", auth: .forbidden))
            Issue.record("expected a failure")
        } catch let error as APIError {
            guard case .unavailable = error else {
                Issue.record("expected .unavailable, got \(error)")
                return
            }
        }
    }
}

// MARK: - Auth

@Suite("Request auth")
struct RequestAuthTests {
    @Test("required auth sends the bearer token")
    func requiredSendsToken() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "abc", refresh: "r"))
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#))

        let _: Health = try await client.send(.get("/mobile/me"))
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
    }

    /// Guest mode depends on the difference between no header and an empty one.
    @Test("forbidden auth sends no Authorization header at all")
    func forbiddenSendsNothing() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "abc", refresh: "r"))
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#))

        let _: Health = try await client.send(.get("/mobile/app/config", auth: .forbidden))
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("optional auth works with no token")
    func optionalWithoutToken() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#))

        let _: Health = try await client.send(.get("/mobile/stores", auth: .optional))
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("every request advertises the UI language")
    func localizationHeader() async throws {
        let localization = APILocalization()
        localization.current = "de"

        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(), localization: localization)
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#))

        let _: Health = try await client.send(.get("/mobile/translations", auth: .forbidden))
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "x-localization") == "de")
    }

    /// Danish is the fallback because that is what the server itself falls back
    /// to — an unset header and a `da` header mean the same thing.
    @Test("defaults to Danish")
    func localizationDefault() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#))

        let _: Health = try await client.send(.get("/mobile/translations", auth: .forbidden))
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "x-localization") == "da")
    }
}

// MARK: - Refresh

@Suite("Token refresh")
struct RefreshTests {
    @Test("a 401 refreshes once and retries")
    func refreshesAndRetries() async throws {
        let tokens = FakeTokenStore(access: "stale", refresh: "r")
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        exchange.queue(
            .init(status: 401, body: #"{"success":false,"message":"Invalid or expired token","code":"UNAUTHORIZED","data":null}"#),
            .init(status: 200, body: #"{"success":true,"data":{"accessToken":"fresh"}}"#),
            .init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#)
        )

        let health: Health = try await client.send(.get("/mobile/me"))
        #expect(health.status == "ok")
        #expect(tokens.accessToken == "fresh")

        let recorded = exchange.recorded
        #expect(recorded.count == 3)
        #expect(recorded[1].url?.path == "/mobile/auth/refresh")
        #expect(recorded[2].value(forHTTPHeaderField: "Authorization") == "Bearer fresh")
    }

    /// The refresh reply usually omits the refresh token, meaning the one we
    /// sent is still good. Clearing it would sign the user out on the first
    /// successful refresh.
    @Test("an omitted refresh token leaves the stored one in place")
    func keepsRefreshToken() async throws {
        let tokens = FakeTokenStore(access: "stale", refresh: "keep-me")
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        exchange.queue(
            .init(status: 401, body: #"{"success":false,"code":"UNAUTHORIZED","data":null}"#),
            .init(status: 200, body: #"{"success":true,"data":{"accessToken":"fresh"}}"#),
            .init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#)
        )

        let _: Health = try await client.send(.get("/mobile/me"))
        #expect(tokens.refreshToken == "keep-me")
    }

    @Test("a second 401 after refreshing gives up rather than looping")
    func retriesOnlyOnce() async throws {
        let tokens = FakeTokenStore(access: "stale", refresh: "r")
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        exchange.queue(
            .init(status: 401, body: #"{"success":false,"message":"Invalid or expired token","code":"UNAUTHORIZED","data":null}"#),
            .init(status: 200, body: #"{"success":true,"data":{"accessToken":"fresh"}}"#),
            .init(status: 401, body: #"{"success":false,"message":"Invalid or expired token","code":"UNAUTHORIZED","data":null}"#)
        )

        do {
            let _: Health = try await client.send(.get("/mobile/me"))
            Issue.record("expected a failure")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                Issue.record("expected .unauthorized, got \(error)")
                return
            }
        }
        #expect(exchange.recorded.count == 3)
    }

    @Test("a refused refresh signs the device out")
    func refusedRefreshClearsTokens() async throws {
        let tokens = FakeTokenStore(access: "stale", refresh: "spent")
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        exchange.queue(
            .init(status: 401, body: #"{"success":false,"code":"UNAUTHORIZED","data":null}"#),
            .init(status: 401, body: #"{"success":false,"message":"Refresh token revoked","code":"UNAUTHORIZED","data":null}"#)
        )

        await #expect(throws: APIError.self) {
            let _: Health = try await client.send(.get("/mobile/me"))
        }
        #expect(tokens.accessToken == nil)
        #expect(tokens.refreshToken == nil)
    }

    /// On a cold launch several requests 401 at once. Without single-flight each
    /// would start its own refresh, every one spending the same refresh token.
    @Test("concurrent 401s share one refresh")
    func singleFlight() async throws {
        let tokens = FakeTokenStore(access: "stale", refresh: "r")
        let (client, exchange) = makeStubbedClient(tokens: tokens)
        exchange.queue(
            .init(status: 401, body: #"{"success":false,"code":"UNAUTHORIZED","data":null}"#),
            .init(status: 401, body: #"{"success":false,"code":"UNAUTHORIZED","data":null}"#),
            .init(status: 401, body: #"{"success":false,"code":"UNAUTHORIZED","data":null}"#),
            .init(status: 200, body: #"{"success":true,"data":{"accessToken":"fresh"}}"#),
            .init(status: 200, body: #"{"success":true,"data":{"status":"ok"}}"#)
        )

        try await withThrowingTaskGroup(of: Health.self) { group in
            for _ in 0..<3 {
                group.addTask { try await client.send(.get("/mobile/me")) }
            }
            for try await health in group {
                #expect(health.status == "ok")
            }
        }

        let refreshes = exchange.recorded.filter { $0.url?.path == "/mobile/auth/refresh" }
        #expect(refreshes.count == 1)
    }
}


// MARK: - Request helpers

extension URLRequest {
    /// `httpBody` is nil once `URLSession` has turned a body into a stream, so
    /// read whichever one is actually there.
    var bodyText: String? {
        if let httpBody { return String(decoding: httpBody, as: UTF8.self) }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(contentsOf: buffer[0..<read])
        }
        return String(decoding: data, as: UTF8.self)
    }
}
