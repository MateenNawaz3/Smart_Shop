//
//  APIAccessService.swift
//  SmartShop
//

import Foundation

/// `AccessService` over the Mobile API.
///
/// The response shapes are not documented anywhere yet — see `AccessDTO`.
nonisolated struct APIAccessService: AccessService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func credentials() async throws -> [AccessCredential] {
        let list: AccessListDTO<AccessCredentialDTO> = try await client.send(.get("/mobile/access/credentials"))
        return list.items.filter { !$0.revoked }.map(Self.map)
    }

    func addKeyFob(_ number: String) async throws -> AccessCredential {
        let request = try APIRequest.json(
            .post,
            "/mobile/access/credentials",
            body: AddCredentialRequestDTO(type: AccessCredential.Kind.keyFob.rawValue, identifier: number)
        )
        let created: AccessCredentialDTO = try await client.send(request)
        var credential = Self.map(created)
        // The server keeps only the last four; if it does not echo them, we
        // still know them.
        if credential.lastFour == nil { credential.lastFour = String(number.suffix(4)) }
        return credential
    }

    func revoke(credentialID: String) async throws {
        let _: EmptyResponse = try await client.send(.delete("/mobile/access/credentials/\(credentialID)"))
    }

    func unlock(accessPointID: String?) async throws -> UnlockOutcome {
        let request = try APIRequest.json(
            .post,
            "/mobile/access/unlock",
            body: UnlockRequestDTO(method: "app_button", accessPointId: accessPointID)
        )
        let result: UnlockResultDTO = try await client.send(request)
        return UnlockOutcome(
            granted: result.granted,
            doorOpened: result.doorOpened,
            reason: result.reason,
            message: result.message
        )
    }

    func history(limit: Int) async throws -> [AccessEvent] {
        let request = APIRequest.get(
            "/mobile/access/history",
            query: [URLQueryItem(name: "limit", value: String(limit))]
        )
        let list: AccessListDTO<AccessEventDTO> = try await client.send(request)
        return list.items.map { AccessEvent(id: $0.id, at: $0.at, granted: $0.granted, reason: $0.reason) }
    }

    func help(accessPointID: String?, storeID: String?, note: String?) async throws -> String? {
        let request = try APIRequest.json(
            .post,
            "/mobile/access/help",
            body: DoorHelpRequestDTO(accessPointId: accessPointID, storeId: storeID, note: note)
        )
        let result: DoorHelpResultDTO = try await client.send(request)
        return result.phone
    }

    private static func map(_ dto: AccessCredentialDTO) -> AccessCredential {
        AccessCredential(
            id: dto.id,
            kind: AccessCredential.Kind(rawValue: dto.type),
            label: dto.label,
            lastFour: dto.lastFour
        )
    }
}
