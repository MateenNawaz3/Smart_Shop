//
//  AppEnvironment.swift
//  SmartShop
//

import SwiftUI

/// Composition root: the one place concrete service implementations are chosen.
///
/// `@Observable` so it can be handed down through `.environment(...)` and read
/// by any screen with `@Environment(AppEnvironment.self)`.
@MainActor
@Observable
final class AppEnvironment {
    let authService: any AuthService
    let pinService: any PinService
    let mitIDService: any MitIDService
    let profileService: any ProfileService
    let offerService: any OfferService
    let idSignupService: any IdSignupService
    let otpService: any OtpService
    let verificationService: any VerificationService
    let wheelService: any WheelService
    let storeService: any StoreService
    /// The backend a MitID sign-in talks to.
    ///
    /// Separate from `authService` on purpose. MitID sign-in exists only on the
    /// Mobile API — `SupabaseMitIDService` was always a stub — so this points
    /// there while everything else is still on Supabase. When `authService`
    /// moves to `APIAuthService` the two become the same thing and this can go.
    let mitIDSignIn: any AuthService

    init(
        authService: any AuthService,
        pinService: any PinService,
        mitIDService: any MitIDService,
        profileService: any ProfileService,
        offerService: any OfferService,
        idSignupService: any IdSignupService = UnavailableIdSignupService(),
        otpService: any OtpService = SupabaseOtpService(),
        verificationService: any VerificationService = SupabaseVerificationService(),
        wheelService: any WheelService = SupabaseWheelService(),
        storeService: any StoreService = BundledStoreService(),
        mitIDSignIn: (any AuthService)? = nil
    ) {
        self.authService = authService
        self.pinService = pinService
        self.mitIDService = mitIDService
        self.profileService = profileService
        self.offerService = offerService
        self.idSignupService = idSignupService
        self.otpService = otpService
        self.verificationService = verificationService
        self.wheelService = wheelService
        self.storeService = storeService
        self.mitIDSignIn = mitIDSignIn ?? APIAuthService()
    }

    /// Production wiring.
    ///
    /// While `DemoMode.isEnabled` is true the whole app runs against
    /// `DemoBackend` instead of Supabase, because account creation needs the
    /// service_role key and therefore an Edge Function that is not deployed
    /// yet. Every screen, validation rule and error state is the real one — see
    /// `DemoMode` for what to deploy and how to switch back.
    static var live: AppEnvironment {
        if DemoMode.isEnabled && !UITesting.isSignedIn {
            let backend = DemoBackend.shared
            return AppEnvironment(
                authService: DemoAuthService(backend: backend),
                pinService: DemoPinService(backend: backend),
                mitIDService: DemoMitIDService(backend: backend),
                profileService: DemoProfileService(backend: backend),
                offerService: BundledOfferService(),
                idSignupService: DemoIdSignupService(backend: backend),
                otpService: DemoOtpService(backend: backend),
                verificationService: DemoVerificationService(backend: backend),
                wheelService: DemoWheelService(backend: backend),
                // Demo mode exists because account creation needs Edge
                // Functions that are not deployed. Stores have no such
                // constraint — they are public and need no session — so even
                // the demo build reads them from the Mobile API.
                storeService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? BundledStoreService()
                    : APIStoreService()
            )
        }

        return AppEnvironment(
            authService: SupabaseAuthService(),
            pinService: SupabasePinService(),
            mitIDService: SupabaseMitIDService(),
            profileService: UITesting.isSignedIn
                ? StubProfileService()
                : SupabaseProfileService(),
            offerService: BundledOfferService(),
            idSignupService: SupabaseIdSignupService(),
            otpService: UITesting.isSignedIn ? DemoOtpService() : SupabaseOtpService(),
            verificationService: UITesting.isSignedIn ? StubVerificationService() : SupabaseVerificationService(),
            // Module 4 is the first slice to run against the Mobile API. UI
            // tests stay on the bundled list so they need no network.
            storeService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? BundledStoreService()
                    : APIStoreService()
        )
    }
}
