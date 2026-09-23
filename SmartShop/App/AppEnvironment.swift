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
    /// The backend a MitID sign-in talks to.
    ///
    /// Separate from `authService` only because the UI-test builds point
    /// `authService` at a stand-in, and MitID sign-in exists on the Mobile API
    /// alone. Everywhere else the two must be **the same object**, not two
    /// `APIAuthService`s: `sessionUpdates()` fans out from a per-instance list
    /// of listeners, so a session adopted by one instance is invisible to
    /// anything watching another. `AuthSessionStore` watches `authService`,
    /// which is how a completed MitID sign-in used to leave the app signed out.
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
            let api = APIAuthService()
            return AppEnvironment(
                // Off demo, for the same reason stores went: demo mode exists
                // because the Supabase Edge Functions listed in `DemoMode` were
                // never deployed, and auth is not one of them — the Mobile API
                // registers, signs in and changes passwords for real. Leaving
                // this on `DemoAuthService` would mean the flip below never
                // ran in the app at all, which is exactly what happened to
                // `APIStoreService` the first time.
                authService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? DemoAuthService(backend: backend)
                    : api,
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
                    : APIStoreService(),
                mitIDSignIn: api
            )
        }

        let api = APIAuthService()
        return AppEnvironment(
            // Module 2. Sign-in, sign-out, both password flows and MitID
            // sign-in now run on the Mobile API. The UI tests keep their own
            // signed-in stubs, which need no network.
            authService: UITesting.isSignedIn
                ? DemoAuthService(backend: DemoBackend.shared)
                : api,
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
                    : APIStoreService(),
            mitIDSignIn: api
        )
    }
}
