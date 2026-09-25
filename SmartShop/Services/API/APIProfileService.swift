//
//  APIProfileService.swift
//  SmartShop
//

import Foundation

/// `ProfileService` over the Mobile API.
///
/// Three things the Supabase conformance did in one call now take three
/// different routes, and the split is deliberate rather than incidental:
///
///   - **Name and address** are an ordinary `PATCH /mobile/me`.
///   - **Email and phone are not editable here.** They are the sign-in
///     identity, and they change only by proving the new one through the OTP
///     flow. `PATCH /me` rejects them outright.
///   - **Marketing is a consent record**, written through `/me/consents`, not a
///     boolean on the profile. A flag cannot record *when* consent was given
///     or under which version; a record can.
///
/// The store and onboarding calls are `APIOnboardingService`'s, composed in
/// here so screens keep talking to one protocol.
nonisolated struct APIProfileService: ProfileService {
    private let client: any APIClient
    private let onboarding: any OnboardingService
    /// Needed only to turn a slug into the API's store id — see
    /// `setFavoriteStore`.
    private let stores: any StoreService

    init(
        client: any APIClient,
        onboarding: any OnboardingService,
        stores: any StoreService
    ) {
        self.client = client
        self.onboarding = onboarding
        self.stores = stores
    }

    init(configuration: APIConfiguration = .current) {
        let client = LiveAPIClient(configuration: configuration)
        self.init(
            client: client,
            onboarding: APIOnboardingService(client: client),
            stores: APIStoreService(client: client)
        )
    }

    // MARK: - Deletion

    /// `202`: recorded, not erased.
    func requestDeletion(reason: String?) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/me/deletion-request",
            body: DeletionRequestDTO(reason: reason?.nilWhenEmpty)
        )
        let _: EmptyResponse = try await client.send(request)
    }

    // MARK: - Reads

    private func me() async throws -> CurrentCustomerDTO {
        try await client.send(.get("/mobile/me"))
    }

    /// Returns nil rather than throwing: the home greeting is decoration, and a
    /// screen that fails to load because a name did not arrive is worse than
    /// one that says hello without it.
    func firstName() async -> String? {
        try? await me().firstName?.nilWhenEmpty
    }

    func summary() async -> ProfileSummary? {
        guard let customer = try? await me() else { return nil }
        return ProfileSummary(
            fornavn: customer.firstName ?? "",
            efternavn: customer.lastName ?? "",
            by: customer.city ?? "",
            email: customer.email ?? ""
        )
    }

    func details() async throws -> ProfileDetails? {
        let customer = try await me()
        // Marketing lives in the consent list, not on the profile, so it needs
        // its own read. A failure there must not lose the whole screen — the
        // switch defaults to off, which is also the safe default for consent.
        let marketing = (try? await consents())?
            .first { $0.type == "marketing" }?.active ?? false

        return ProfileDetails(
            fornavn: customer.firstName ?? "",
            efternavn: customer.lastName ?? "",
            telefon: customer.phone ?? "",
            adresse: customer.addressLine1 ?? "",
            postnr: customer.postalCode ?? "",
            by: customer.city ?? "",
            markedsforing: marketing,
            email: customer.email ?? ""
        )
    }

    private func consents() async throws -> [ConsentDTO] {
        try await client.send(.get("/mobile/me/consents"))
    }

    // MARK: - Writes

    /// Writes only what `PATCH /me` accepts.
    ///
    /// `details.email` and `details.telefon` are deliberately dropped: the
    /// screen shows them, but changing either means proving the new one through
    /// OTP. Sending them here is rejected, and silently pretending to save them
    /// would be worse than not offering it.
    func update(_ details: ProfileDetails) async throws {
        let request = try APIRequest.json(
            .patch,
            "/mobile/me",
            body: UpdateProfileRequestDTO(
                firstName: details.fornavn.nilWhenEmpty,
                lastName: details.efternavn.nilWhenEmpty,
                addressLine1: details.adresse.nilWhenEmpty,
                postalCode: details.postnr.nilWhenEmpty,
                city: details.by.nilWhenEmpty
            )
        )
        let _: EmptyResponse = try await client.send(request)
    }

    func setMarketing(_ enabled: Bool) async throws {
        let request = try APIRequest.json(
            .put,
            "/mobile/me/consents",
            body: SetConsentRequestDTO.marketing(enabled)
        )
        let _: EmptyResponse = try await client.send(request)
    }

    /// The post-MitID contact step.
    ///
    /// Same restriction as `update`: the name and address are written, while
    /// the email and phone are established by the OTP steps the screen runs
    /// immediately afterwards. That is not a gap — proving the address is what
    /// sets it.
    func saveContactDetails(
        fornavn: String, efternavn: String, email: String, telefon: String,
        adresse: String, postnr: String, by: String
    ) async throws {
        try await update(
            ProfileDetails(
                fornavn: fornavn, efternavn: efternavn, telefon: telefon,
                adresse: adresse, postnr: postnr, by: by,
                markedsforing: false, email: email
            )
        )
    }

    // MARK: - Store and onboarding

    /// ⚠️ **`preferredStoreId` is the API's UUID; `StoreProfile.favoriteStore`
    /// is the app's slug.** They are not interchangeable, and deep links depend
    /// on the slug, so the id is translated here rather than leaked upwards.
    func storeProfile() async throws -> StoreProfile? {
        let customer = try await me()
        // Best effort: without it the screen loses the highlighted store, which
        // is better than losing the screen.
        let slug = try? await slug(forStoreID: customer.preferredStoreId)
        let home = try? await onboarding.resolveHomeLocation()

        return StoreProfile(
            favoriteStore: slug,
            adresse: customer.addressLine1 ?? "",
            postnr: customer.postalCode ?? "",
            by: customer.city ?? "",
            home: home.flatMap { resolved in
                guard let latitude = resolved.latitude,
                      let longitude = resolved.longitude
                else { return nil }
                return GeoPoint(lat: latitude, lng: longitude)
            },
            onboardingDone: customer.onboardingCompleted
        )
    }

    /// The app keys a store by slug and the API addresses it by UUID, so this
    /// has to look the store up. `Store.remoteID` carries the API's id and is
    /// nil for a bundled record.
    func setFavoriteStore(_ slug: String, home: GeoPoint?) async throws {
        let store = try await stores.store(slug: slug)
        guard let remoteID = store.remoteID else {
            throw APIError.failure(
                code: "NO_REMOTE_ID",
                message: "Store \(slug) has no API id, so it cannot be set as my store.",
                status: 0
            )
        }
        try await onboarding.setMyStore(id: remoteID)
        if home != nil { try await setHome(home!) }
    }

    /// Translates the API's store id back into the slug the app keys on.
    private func slug(forStoreID id: String?) async throws -> String? {
        guard let id else { return nil }
        return try await stores.stores().first { $0.remoteID == id }?.id
    }

    /// The point is **ignored**, and deliberately.
    ///
    /// `POST /me/home-location` takes no body: the server geocodes the address
    /// already on the profile. There is no endpoint that accepts a coordinate,
    /// so the honest thing is to ask the server to resolve again — which is
    /// what makes the cached point follow an address change — rather than
    /// pretend a client-supplied point was stored.
    func setHome(_ point: GeoPoint) async throws {
        _ = try await onboarding.resolveHomeLocation()
    }

    func setOnboardingDone() async throws {
        try await onboarding.completeOnboarding()
    }
}
