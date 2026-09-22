//
//  APIContentService.swift
//  SmartShop
//

import Foundation

/// `ContentService` over the Mobile API.
///
/// Both reads are `auth: .forbidden` — the info screens are readable in guest
/// mode and before sign-in.
nonisolated struct APIContentService: ContentService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func pages() async throws -> [Page] {
        let dtos: [PageDTO] = try await client.send(.get("/mobile/pages", auth: .forbidden))
        return dtos.map(Page.init)
    }

    func page(key: String) async throws -> Page {
        do {
            let dto: PageDTO = try await client.send(
                .get("/mobile/pages/\(key)", auth: .forbidden)
            )
            return Page(dto)
        } catch APIError.failure(let code, _, _) where code == "NOT_FOUND" {
            throw PageNotFound(key: key)
        }
    }
}

nonisolated extension Page {
    init(_ dto: PageDTO) {
        self.init(key: dto.key, title: dto.title, body: dto.body, updatedAt: dto.updatedAt)
    }
}
