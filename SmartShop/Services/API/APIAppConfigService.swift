//
//  APIAppConfigService.swift
//  SmartShop
//

import Foundation

/// `AppConfigService` over the Mobile API.
///
/// Covers app config and health. Both are `auth: .forbidden` — the launch gate
/// has to answer before anyone has signed in, and `/health` exists precisely
/// for the case where the token is the problem.
nonisolated struct APIAppConfigService: AppConfigService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func configuration() async throws -> AppConfig {
        let dto: AppConfigDTO = try await client.send(
            .get("/mobile/app/config", auth: .forbidden)
        )

        return AppConfig(
            minimumBuild: dto.minimumBuild,
            recommendedBuild: dto.recommendedBuild,
            maintenance: dto.maintenance,
            message: dto.message,
            storeURL: dto.storeUrl?.ios.flatMap(URL.init(string:)),
            features: FeatureFlags(dto.features),
            languages: dto.languages ?? [],
            serverTime: dto.serverTime
        )
    }

    func health() async throws -> HealthReport {
        let dto: HealthDTO = try await client.send(.get("/health", auth: .forbidden))
        return HealthReport(
            status: dto.status,
            service: dto.service,
            databaseUp: dto.dependencies?.database == "up",
            redisUp: dto.dependencies?.redis == "up"
        )
    }
}

nonisolated private extension FeatureFlags {
    /// Known flags are lifted out by name; anything else is kept rather than
    /// dropped, so a flag added server-side is still readable here.
    init(_ raw: [String: Bool]) {
        self.init(
            contests: raw["contests"] ?? false,
            events: raw["events"] ?? false,
            bulletinBoard: raw["bulletinBoard"] ?? false,
            faceEnrolment: raw["faceEnrolment"] ?? false,
            mitID: raw["mitid"] ?? false,
            guestMode: raw["guestMode"] ?? false,
            others: raw.filter { !Self.known.contains($0.key) }
        )
    }

    static let known: Set<String> = [
        "contests", "events", "bulletinBoard", "faceEnrolment", "mitid", "guestMode"
    ]
}
