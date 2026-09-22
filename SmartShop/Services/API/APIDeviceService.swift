//
//  APIDeviceService.swift
//  SmartShop
//

import Foundation
import UIKit

/// `DeviceService` over the Mobile API.
///
/// Covers handset registration and the per-device PIN.
nonisolated struct APIDeviceService: DeviceService {
    var client: any APIClient
    var identity = DeviceIdentity()

    init(client: any APIClient, identity: DeviceIdentity = DeviceIdentity()) {
        self.client = client
        self.identity = identity
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    // MARK: - Registration

    @discardableResult
    func registerCurrentDevice(pushToken: String? = nil) async throws -> String {
        let request = try APIRequest.json(
            .post,
            "/mobile/me/devices",
            body: RegisterDeviceRequestDTO(
                platform: "ios",
                appVersion: Self.appVersion,
                deviceIdentifier: identity.installationIdentifier,
                pushToken: pushToken,
                // Only meaningful alongside a token; sending a provider with no
                // token claims a push route that does not exist.
                pushProvider: pushToken == nil ? nil : "apns"
            )
        )
        let registered: RegisteredDeviceIdDTO = try await client.send(request)

        // Every PIN call is addressed by this id, so it is persisted before
        // anyone can ask for it.
        identity.serverDeviceID = registered.deviceId
        return registered.deviceId
    }

    func devices() async throws -> [RegisteredDevice] {
        let devices: [DeviceDTO] = try await client.send(.get("/mobile/me/devices"))
        return devices.map {
            RegisteredDevice(
                id: $0.id,
                platform: $0.platform,
                appVersion: $0.appVersion,
                isTrusted: $0.isTrusted,
                hasPin: $0.hasPin,
                lastSeenAt: $0.lastSeenAt,
                registeredAt: $0.registeredAt
            )
        }
    }

    func forgetDevice(id: String) async throws {
        let _: EmptyResponse = try await client.send(.delete("/mobile/me/devices/\(id)"))

        // Forgetting *this* handset orphans the stored id — the next PIN call
        // would address a device the server no longer has.
        if id == identity.serverDeviceID {
            identity.clear()
        }
    }

    // MARK: - PIN

    func setPin(_ pin: String, deviceID: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/me/devices/\(deviceID)/pin",
            body: SetPinRequestDTO(pin: pin)
        )
        let _: PinMutationDTO = try await client.send(request)
    }

    func verifyPin(_ pin: String, deviceID: String) async throws -> PinCheck {
        let request = try APIRequest.json(
            .post,
            "/mobile/me/devices/\(deviceID)/pin/verify",
            body: SetPinRequestDTO(pin: pin)
        )

        let result: PinVerificationDTO
        do {
            result = try await client.send(request)
        } catch APIError.failure(let code, _, _) where code == "NOT_FOUND" {
            // The device was forgotten from another handset. There is no PIN to
            // check, so the gate should not hold anyone here.
            identity.clear()
            return .notSet
        }

        // A wrong PIN is a 200 with `ok: false`, so the flags decide, not the
        // status code. Lockout is checked first: while locked, even the correct
        // PIN answers `ok: false`, and reporting that as merely "wrong" would
        // have the user try again pointlessly.
        if let lockedForSeconds = result.lockedForSeconds, lockedForSeconds > 0 {
            return .locked(forSeconds: lockedForSeconds)
        }
        return result.ok ? .correct : .wrong(attemptsLeft: result.attemptsLeft)
    }

    func removePin(deviceID: String) async throws {
        let _: EmptyResponse = try await client.send(
            .delete("/mobile/me/devices/\(deviceID)/pin")
        )
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

/// `PinService` over the device endpoints.
///
/// The existing screens ask for a PIN without knowing about devices; this keeps
/// that shape and supplies the device id from `DeviceIdentity`, registering the
/// handset first if it has never been registered.
nonisolated struct APIPinService: PinService {
    var devices: any DeviceService
    var identity = DeviceIdentity()

    init(devices: any DeviceService, identity: DeviceIdentity = DeviceIdentity()) {
        self.devices = devices
        self.identity = identity
    }

    init(configuration: APIConfiguration = .current) {
        let identity = DeviceIdentity()
        self.init(
            devices: APIDeviceService(
                client: LiveAPIClient(configuration: configuration),
                identity: identity
            ),
            identity: identity
        )
    }

    func setPin(_ pin: String) async throws {
        try await devices.setPin(pin, deviceID: try await deviceID())
    }

    func verifyPin(_ pin: String) async throws -> PinCheck {
        // Not registered means there is nothing on the server to check against,
        // which is `.notSet` rather than a failure — the gate lets them past.
        guard let deviceID = identity.serverDeviceID else { return .notSet }
        return try await devices.verifyPin(pin, deviceID: deviceID)
    }

    func hasPin() async throws -> Bool {
        guard let deviceID = identity.serverDeviceID else { return false }
        return try await devices.devices().first { $0.id == deviceID }?.hasPin ?? false
    }

    /// Setting a PIN on a handset that has never registered is a legitimate
    /// first run, so it registers rather than refusing.
    private func deviceID() async throws -> String {
        if let existing = identity.serverDeviceID { return existing }
        return try await devices.registerCurrentDevice(pushToken: nil)
    }
}
