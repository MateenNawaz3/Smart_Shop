//
//  DeviceServiceTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

/// In-memory stand-in for the Keychain.
///
/// Suites run in parallel even when each is `.serialized`, so sharing the real
/// Keychain meant one suite's handset id turning up in another's test.
final class MemoryIdentityStorage: DeviceIdentityStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func get(_ key: String) -> String? { lock.withLock { values[key] } }
    func set(_ value: String, for key: String) { lock.withLock { values[key] = value } }
    func remove(_ key: String) { lock.withLock { values[key] = nil } }
}

/// A handset of this test's own.
func makeIdentity() -> DeviceIdentity {
    DeviceIdentity(storage: MemoryIdentityStorage())
}

@Suite("API device service", .serialized)
struct APIDeviceServiceTests {
    private func makeService() -> (APIDeviceService, StubURLProtocol.Exchange, DeviceIdentity) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        let identity = makeIdentity()
        return (APIDeviceService(client: client, identity: identity), exchange, identity)
    }

    @Test("registering stores the id every PIN call is addressed by")
    func registerStoresID() async throws {
        let (service, exchange, identity) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#))

        let id = try await service.registerCurrentDevice(pushToken: nil)
        #expect(id == "dev-1")
        #expect(identity.serverDeviceID == "dev-1")
    }

    /// The server upserts on `deviceIdentifier`, so the same handset must send
    /// the same value at every launch or it accumulates duplicates.
    @Test("registering twice sends the same device identifier")
    func registerIsStable() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#))

        _ = try await service.registerCurrentDevice(pushToken: nil)
        _ = try await service.registerCurrentDevice(pushToken: nil)

        let bodies = exchange.recorded.compactMap { $0.bodyText }
        #expect(bodies.count == 2)
        let identifiers = bodies.map { $0.jsonValue(for: "deviceIdentifier") }
        #expect(identifiers[0] == identifiers[1])
        #expect(identifiers[0]?.isEmpty == false)
    }

    /// Claiming a push provider with no token would advertise a route that does
    /// not exist.
    @Test("no push token means no push provider")
    func providerOnlyWithToken() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#))

        _ = try await service.registerCurrentDevice(pushToken: nil)
        let body = try #require(exchange.recorded.first?.bodyText)
        #expect(!body.contains("pushProvider"))
    }

    @Test("a push token registers as apns")
    func apnsProvider() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#))

        _ = try await service.registerCurrentDevice(pushToken: "push-1")
        let body = try #require(exchange.recorded.first?.bodyText)
        #expect(body.jsonValue(for: "pushProvider") == "apns")
        #expect(body.jsonValue(for: "platform") == "ios")
    }

    /// The listing calls the id `id`; registration calls the same value
    /// `deviceId`. Both have to decode.
    @Test("the device list decodes")
    func listDecodes() async throws {
        let (service, exchange, _) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[{"id":"dev-1","platform":"ios","appVersion":"1.0.0",
          "isTrusted":false,"hasPin":true,"lastSeenAt":"2026-09-22T06:51:48.400Z",
          "registeredAt":"2026-09-22T06:51:48.401Z"}]}
        """))

        let devices = try await service.devices()
        #expect(devices.count == 1)
        #expect(devices[0].id == "dev-1")
        #expect(devices[0].hasPin)
        #expect(devices[0].lastSeenAt != nil)
    }

    @Test("forgetting this handset drops its stored id")
    func forgetClearsIdentity() async throws {
        let (service, exchange, identity) = makeService()
        exchange.queue(
            .init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#),
            .init(status: 200, body: #"{"success":true,"data":{}}"#)
        )

        _ = try await service.registerCurrentDevice(pushToken: nil)
        try await service.forgetDevice(id: "dev-1")
        #expect(identity.serverDeviceID == nil)
    }

    @Test("forgetting another handset leaves this one registered")
    func forgetOtherKeepsIdentity() async throws {
        let (service, exchange, identity) = makeService()
        exchange.queue(
            .init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#),
            .init(status: 200, body: #"{"success":true,"data":{}}"#)
        )

        _ = try await service.registerCurrentDevice(pushToken: nil)
        try await service.forgetDevice(id: "dev-2")
        #expect(identity.serverDeviceID == "dev-1")
    }
}

// MARK: - PIN

@Suite("Device PIN", .serialized)
struct DevicePinTests {
    private func makeService() -> (APIDeviceService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APIDeviceService(client: client, identity: makeIdentity()), exchange)
    }

    @Test("a correct PIN unlocks")
    func correct() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"ok":true,"attemptsLeft":5}}"#))

        #expect(try await service.verifyPin("1234", deviceID: "dev-1") == .correct)
    }

    /// The load-bearing one: a wrong PIN is a **200 with `success: true`**, not
    /// an error. Reading it as a failed request would lose the attempt counter
    /// and show a generic error instead of "wrong PIN".
    @Test("a wrong PIN is a successful response carrying the count")
    func wrongCarriesCount() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: #"{"success":true,"data":{"ok":false,"attemptsLeft":3}}"#))

        #expect(try await service.verifyPin("9999", deviceID: "dev-1") == .wrong(attemptsLeft: 3))
    }

    @Test("running out of attempts reports the lockout")
    func lockout() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 200,
            body: #"{"success":true,"data":{"ok":false,"attemptsLeft":0,"lockedForSeconds":900}}"#
        ))

        #expect(try await service.verifyPin("9999", deviceID: "dev-1") == .locked(forSeconds: 900))
    }

    /// While locked, even the correct PIN answers `ok: false`. Calling that
    /// merely "wrong" would have the user try again pointlessly.
    @Test("a correct PIN during a lockout still reports locked")
    func correctWhileLocked() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 200,
            body: #"{"success":true,"data":{"ok":false,"attemptsLeft":0,"lockedForSeconds":899}}"#
        ))

        #expect(try await service.verifyPin("1234", deviceID: "dev-1") == .locked(forSeconds: 899))
    }

    /// The handset was forgotten from another device. There is no PIN left to
    /// check, so the gate must not strand the user.
    @Test("a forgotten device reads as having no PIN")
    func forgottenDevice() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        let identity = makeIdentity()
        identity.serverDeviceID = "dev-1"
        let service = APIDeviceService(client: client, identity: identity)

        exchange.queue(.init(
            status: 404,
            body: #"{"success":false,"message":"Device not found","code":"NOT_FOUND","data":null}"#
        ))

        #expect(try await service.verifyPin("1234", deviceID: "dev-1") == .notSet)
        #expect(identity.serverDeviceID == nil)
    }

    @Test("a PIN that is not four digits is refused by the server")
    func shortPin() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(
            status: 400,
            body: #"{"success":false,"message":["pin must be 4 digits"],"code":"VALIDATION_ERROR","data":null}"#
        ))

        await #expect(throws: APIError.self) {
            try await service.setPin("123", deviceID: "dev-1")
        }
    }
}

// MARK: - PinService bridge

@Suite("API PIN service", .serialized)
struct APIPinServiceTests {
    /// The existing screens ask for a PIN without knowing about devices, so an
    /// unregistered handset registers itself rather than refusing.
    @Test("setting a PIN registers the handset first")
    func setRegistersFirst() async throws {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        let identity = makeIdentity()
        let service = APIPinService(
            devices: APIDeviceService(client: client, identity: identity),
            identity: identity
        )
        exchange.queue(
            .init(status: 200, body: #"{"success":true,"data":{"deviceId":"dev-1"}}"#),
            .init(status: 200, body: #"{"success":true,"data":{"ok":true}}"#)
        )

        try await service.setPin("1234")

        let paths = exchange.recorded.compactMap(\.url?.path)
        #expect(paths == ["/mobile/me/devices", "/mobile/me/devices/dev-1/pin"])
    }

    /// No registration means nothing on the server to check against — which is
    /// `.notSet`, so the gate lets them past rather than trapping them.
    @Test("an unregistered handset has no PIN to check")
    func unregisteredIsNotSet() async throws {
        let (client, _) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        let identity = makeIdentity()
        let service = APIPinService(
            devices: APIDeviceService(client: client, identity: identity),
            identity: identity
        )

        #expect(try await service.verifyPin("1234") == .notSet)
    }
}

// MARK: - Helpers

extension String {
    /// Minimal field read, so the tests do not need a matching Decodable.
    func jsonValue(for key: String) -> String? {
        guard let data = data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object[key] as? String
    }
}
