//
//  UITestingSupport.swift
//  SmartShop
//

import Foundation

/// Launch arguments that make UI tests reach screens behind authentication and
/// run independently of each other.
///
/// Without `-uiTestingSignedIn` a test can only ever see the signed-out flow:
/// the home screen needs a live Supabase session, which a test has no way to
/// create — and real credentials in a test target would be worse than useless.
///
/// Without the reset below, tests leak into one another: the app persists the
/// chosen language, guest mode and the PIN flag, so a test that switches to
/// German changes what the *next* test sees. These are read only from
/// `ProcessInfo`, so nothing but the launching process can set them.
enum UITesting {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    /// Start the app as if a session already existed.
    static var isSignedIn: Bool {
        environment["UITEST_SIGNED_IN"] == "1" || arguments.contains("-uiTestingSignedIn")
    }

    /// `-uiTestingOnboarding` starts the signed-in session on the onboarding guide.
    static var showsOnboarding: Bool { arguments.contains("-uiTestingOnboarding") }

    /// `UITEST_LIVE_API=1` lets a test opt back into the real Mobile API.
    ///
    /// UI tests otherwise run on bundled data so they need no network. One test
    /// deliberately does not: the point of it is to prove the app really reads
    /// the API, which nothing can show while every service is a stand-in.
    static var usesLiveAPI: Bool { environment["UITEST_LIVE_API"] == "1" }

    static var isActive: Bool {
        environment["UITEST"] == "1" || arguments.contains("-uiTesting") || isSignedIn
    }

    /// `-uiTestingLanguage en` pins the language regardless of what a previous
    /// test left behind or what the simulator's locale happens to be.
    static var forcedLanguage: AppLanguage? {
        if let code = environment["UITEST_LANGUAGE"], let language = AppLanguage(rawValue: code) {
            return language
        }
        guard let index = arguments.firstIndex(of: "-uiTestingLanguage"),
              arguments.indices.contains(index + 1)
        else { return nil }
        return AppLanguage(rawValue: arguments[index + 1])
    }

    /// Animations are non-deterministic for a test runner: it can read an
    /// element's frame while the screen is still sliding in and tap where the
    /// control *was*, off the edge of the screen. Turning them off under test
    /// removes that whole class of flakiness.
    static var animationsDisabled: Bool { isActive }

    /// Clears everything the app persists, so each test starts from a known state.
    static func resetPersistedState() {
        guard isActive else { return }
        for key in ["smartshop-lang", "smartshop_guest", "smartshop.favorites"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        Keychain.remove("ss247_pin_device")
        DemoBackend.shared.reset()
    }
}

/// Fixed profile data so greetings are deterministic in tests and previews.
struct StubProfileService: ProfileService {
    var name: String? = "Mateen"
    func firstName() async -> String? { name }
    func summary() async -> ProfileSummary? {
        ProfileSummary(fornavn: name ?? "", efternavn: "Nawaz", by: "Esbjerg", email: "mateen@example.com")
    }
    func details() async throws -> ProfileDetails? {
        ProfileDetails(fornavn: name ?? "", efternavn: "Nawaz", telefon: "+45 12345678",
                       adresse: "Egedalvej 11", postnr: "6705", by: "Esbjerg Ø",
                       markedsforing: true, email: "mateen@example.com")
    }
    func update(_ details: ProfileDetails) async throws {}
    func setMarketing(_ enabled: Bool) async throws {}
    func storeProfile() async throws -> StoreProfile? {
        StoreProfile(favoriteStore: nil, adresse: "Egedalvej 11", postnr: "6705", by: "Esbjerg Ø",
                     home: GeoPoint(lat: 55.4923, lng: 8.6772),
                     onboardingDone: !UITesting.showsOnboarding)
    }
    func setFavoriteStore(_ slug: String, home: GeoPoint?) async throws {}
    func setHome(_ point: GeoPoint) async throws {}
    func setOnboardingDone() async throws {}
    func saveContactDetails(email: String, telefon: String, adresse: String, postnr: String, by: String) async throws {}
}
