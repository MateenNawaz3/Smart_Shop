//
//  SmartShopApp.swift
//  SmartShop
//
//  Created by mateen nawaz on 03/09/2026.
//

import SwiftUI
import Supabase
import UIKit

@main
struct SmartShopApp: App {
    /// `@State` at the App level owns these for the process lifetime.
    @State private var environment = AppEnvironment.live
    @State private var device = DeviceState()
    @State private var session: AuthSessionStore
    @State private var languages = LanguageStore()
    @State private var catalog: StoreCatalog
    @State private var mitIDSignIn: MitIDSignInCoordinator
    @State private var profileCache = ProfileCache()

    init() {
        // Must run before any store reads UserDefaults or the Keychain.
        UITesting.resetPersistedState()
        if UITesting.animationsDisabled {
            UIView.setAnimationsEnabled(false)
        }

        let environment = AppEnvironment.live
        let device = DeviceState()
        _environment = State(initialValue: environment)
        _device = State(initialValue: device)
        _session = State(
            initialValue: AuthSessionStore(auth: environment.authService, device: device)
        )
        _catalog = State(initialValue: StoreCatalog(service: environment.storeService))
        _mitIDSignIn = State(
            initialValue: MitIDSignInCoordinator(auth: environment.mitIDSignIn)
        )
    }

    var body: some Scene {
        WindowGroup {
            LaunchGateView { RootView() }
                // Injected once; every screen reads them with @Environment.
                .environment(environment)
                .environment(device)
                .environment(session)
                .environment(languages)
                .environment(catalog)
                .environment(mitIDSignIn)
                .environment(profileCache)
                // Re-published as a value so changing language re-renders
                // every view that reads a string.
                .environment(
                    \.strings,
                    Translator(bundle: languages.bundle, overrides: languages.overrides)
                )
                .onOpenURL { url in handle(url) }
                .task {
                    // Server-owned copy, layered over the compiled bundle so a
                    // wording change does not need a new build. Failure is
                    // silent: the bundle is a complete set on its own.
                    //
                    // UI tests stay on the bundle alone — a string changing
                    // server-side would otherwise change what a test sees.
                    guard !UITesting.isActive || UITesting.usesLiveAPI else { return }
                    languages.translations = APITranslationService()
                    await languages.refreshOverrides()
                }
        }
    }

    /// Deep links the app answers:
    ///
    /// Each arrives either on our custom scheme or, once the Universal Link is
    /// live, as an `https://` link on one of our own domains. `AppLinks` treats
    /// the two identically; only the last path component and the query matter.
    ///
    ///   - `smartshop://mitid?status=…&reference=…&state=…` — a MitID return
    ///   - `smartshop://auth-callback#access_token=…&type=recovery` — password
    ///     recovery and email confirmation, Supabase's shape
    ///   - `smartshop://reset-password?token=…` — password recovery, the Mobile
    ///     API's shape. Which host the backend actually sends is item 9 in
    ///     `docs/mobile-api-backend-requests.md`; the token is matched wherever
    ///     it arrives, so any host on our scheme works.
    ///
    /// The web has to defend against these landing on the wrong route (see
    /// `src/lib/recovery.ts`); on iOS there is exactly one entry point, so the
    /// handling is a single function.
    private func handle(_ url: URL) {
        guard AppLinks.isOurs(url) else { return }

        switch AppLinks.route(for: url) {
        case .mitID:
            // Routed to the coordinator rather than to a screen, because the
            // trip may well have outlived the view that started it. The web
            // session usually intercepts this itself; this is the path taken
            // when the MitID *app* handled the return instead. Redeeming is
            // idempotent, so a duplicate is harmless.
            guard let callback = MitIDCallback(url: url) else { return }
            Task { await mitIDSignIn.handle(callback) }

        case .passwordReset(let token):
            // The Mobile API's reset carries a one-time token and creates no
            // session, so there is nothing for the Supabase SDK to do with it.
            session.beginPasswordRecovery(token: token)

        case .supabaseRecovery:
            session.beginPasswordRecovery()
            Task { try? await SupabaseClient.shared.auth.session(from: url) }

        case .none:
            // An email-confirmation callback or similar. Let the SDK make what
            // it can of it while Supabase is still in the tree.
            Task { try? await SupabaseClient.shared.auth.session(from: url) }
        }
    }
}
