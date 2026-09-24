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
    /// The launch gate: build blocking, maintenance and feature flags.
    let appConfigService: any AppConfigService
    /// The contact form and the marketing unsubscribe.
    let contactService: any ContactService
    /// Server-managed copy for the info pages.
    let contentService: any ContentService
    /// Till receipts.
    let purchaseService: any PurchaseService
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
        // No default. Both call sites choose explicitly, because a default
        // here is invisible at the call site — which is exactly how the live
        // branch kept `SupabaseWheelService` after the demo branch had moved.
        wheelService: any WheelService,
        storeService: any StoreService = BundledStoreService(),
        appConfigService: any AppConfigService = APIAppConfigService(),
        contactService: any ContactService = APIContactService(),
        contentService: any ContentService = APIContentService(),
        purchaseService: any PurchaseService = APIPurchaseService(),
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
        self.appConfigService = appConfigService
        self.contactService = contactService
        self.contentService = contentService
        self.purchaseService = purchaseService
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
                // Off demo for the same reason auth and stores went: the PIN
                // endpoints are real and the Edge Functions `DemoMode` waits on
                // are not among them. `APIPinService` registers the handset on
                // the first `setPin`, so a fresh install needs no extra step.
                pinService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? DemoPinService(backend: backend)
                    : APIPinService(),
                mitIDService: DemoMitIDService(backend: backend),
                // Module 8's first slice. My details stops showing demo
                // data behind a real session.
                profileService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? DemoProfileService(backend: backend)
                    : APIProfileService(),
                offerService: BundledOfferService(),
                idSignupService: DemoIdSignupService(backend: backend),
                // Both OTP routes need a token, so the account must exist
                // before a code can be sent — which is why the sign-up wizard
                // has to register first rather than verify its way in.
                otpService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? DemoOtpService(backend: backend)
                    : APIOtpService(),
                verificationService: DemoVerificationService(backend: backend),
                // The wheel mints a real gift card server-side, so the demo
                // service's locally generated barcode is a code the till has
                // never heard of. That is the reason this one had to move.
                wheelService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? DemoWheelService(backend: backend)
                    : APIWheelService(),
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
            pinService: UITesting.isSignedIn
                ? DemoPinService(backend: DemoBackend.shared)
                : APIPinService(),
            mitIDService: SupabaseMitIDService(),
            profileService: UITesting.isSignedIn
                ? StubProfileService()
                : APIProfileService(),
            offerService: BundledOfferService(),
            idSignupService: SupabaseIdSignupService(),
            otpService: UITesting.isSignedIn ? DemoOtpService() : APIOtpService(),
            verificationService: UITesting.isSignedIn ? StubVerificationService() : SupabaseVerificationService(),
            wheelService: UITesting.isSignedIn
                ? DemoWheelService(backend: DemoBackend.shared)
                : APIWheelService(),
            // Module 4 is the first slice to run against the Mobile API. UI
            // tests stay on the bundled list so they need no network.
            storeService: UITesting.isActive && !UITesting.usesLiveAPI
                    ? BundledStoreService()
                    : APIStoreService(),
            mitIDSignIn: api
        )
    }
}
