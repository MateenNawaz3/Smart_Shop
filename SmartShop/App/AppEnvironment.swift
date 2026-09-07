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

    init(
        authService: any AuthService,
        pinService: any PinService,
        mitIDService: any MitIDService,
        profileService: any ProfileService,
        offerService: any OfferService,
        idSignupService: any IdSignupService = UnavailableIdSignupService(),
        otpService: any OtpService = SupabaseOtpService(),
        verificationService: any VerificationService = SupabaseVerificationService(),
        wheelService: any WheelService = SupabaseWheelService()
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
                wheelService: DemoWheelService(backend: backend)
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
            verificationService: UITesting.isSignedIn ? StubVerificationService() : SupabaseVerificationService()
        )
    }
}
