//
//  APIOnboardingService.swift
//  SmartShop
//

import Foundation

/// `OnboardingService` over the Mobile API.
///
/// Covers my-store, onboarding completion and the cached home location. These
/// will fold into `APIProfileService` when module 8 lands; they live here now
/// because they are module 3's whole surface and nothing else of the profile is
/// implemented yet.
nonisolated struct APIOnboardingService: OnboardingService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func setMyStore(id: String) async throws {
        let request = try APIRequest.json(
            .put,
            "/mobile/me/store",
            body: SetMyStoreRequestDTO(storeId: id)
        )
        let _: PreferredStoreDTO = try await client.send(request)
    }

    func clearMyStore() async throws {
        let _: ClearedDTO = try await client.send(.delete("/mobile/me/store"))
    }

    /// The reply is the whole updated profile, which nothing here needs — the
    /// call is made for its effect.
    func completeOnboarding() async throws {
        let _: EmptyResponse = try await client.send(
            .post("/mobile/me/onboarding/complete")
        )
    }

    @discardableResult
    func resolveHomeLocation() async throws -> HomeLocation {
        // The body is empty: the address it geocodes is the one already on the
        // profile, so there is nothing to send.
        let request = try APIRequest.json(
            .post,
            "/mobile/me/home-location",
            body: EmptyBody()
        )
        let dto: HomeLocationDTO = try await client.send(request)
        return HomeLocation(
            resolved: dto.resolved,
            latitude: dto.latitude,
            longitude: dto.longitude
        )
    }

    private struct EmptyBody: Encodable, Sendable {}
}
