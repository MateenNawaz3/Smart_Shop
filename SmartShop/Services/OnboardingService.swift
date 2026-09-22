//
//  OnboardingService.swift
//  SmartShop
//

import Foundation

/// My store, the onboarding guide, and the cached home location.
///
/// These three travel together: they are the things the app records *about* a
/// customer's setup rather than about the customer.
nonisolated protocol OnboardingService: Sendable {
    /// The shop the home screen greets you with.
    ///
    /// Convenience only — a customer may shop anywhere in the chain, and the
    /// door decision never reads this. Addressed by the API's store id.
    func setMyStore(id: String) async throws
    func clearMyStore() async throws

    /// Idempotent — replaying the guide does not reset the date.
    func completeOnboarding() async throws

    /// Geocodes the address on file and caches the point, so "your nearest
    /// store" works for someone who declined location access.
    ///
    /// The server-side counterpart of `LocationFinder`: keep both, since one
    /// covers a granted location permission and the other covers a refused one.
    @discardableResult
    func resolveHomeLocation() async throws -> HomeLocation
}

/// Where the address on file turned out to be.
///
/// `resolved` is false rather than an error when the address cannot be placed —
/// the store finder still works, just without distances.
nonisolated struct HomeLocation: Sendable, Equatable {
    var resolved: Bool
    var latitude: Double?
    var longitude: Double?
}

/// Does nothing, for the build that still runs on Supabase.
nonisolated struct UnavailableOnboardingService: OnboardingService {
    func setMyStore(id: String) async throws {}
    func clearMyStore() async throws {}
    func completeOnboarding() async throws {}

    @discardableResult
    func resolveHomeLocation() async throws -> HomeLocation {
        HomeLocation(resolved: false, latitude: nil, longitude: nil)
    }
}
