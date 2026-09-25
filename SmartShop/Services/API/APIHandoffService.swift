//
//  APIHandoffService.swift
//  SmartShop
//

import Foundation

/// `HandoffService` over the Mobile API.
nonisolated struct APIHandoffService: HandoffService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func token() async throws -> HandoffToken {
        let requestedAt = Date.now
        let dto: HandoffTokenDTO = try await client.send(.post("/mobile/handoff/token"))
        // The server's own expiry wins; failing that its lifetime counted from
        // when we asked, not when the answer arrived, so a slow network cannot
        // stretch it.
        let expiresAt = dto.expiresAt
            ?? requestedAt.addingTimeInterval(TimeInterval(dto.expiresIn ?? 60))
        return HandoffToken(value: dto.token, expiresAt: expiresAt)
    }
}
