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
            RootView()
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
                .environment(\.strings, Translator(bundle: languages.bundle))
                .onOpenURL { url in handle(url) }
        }
    }

    /// Deep links the app answers:
    ///
    ///   - `smartshop://mitid?status=…&reference=…&state=…` — a MitID return
    ///   - `smartshop://auth-callback#access_token=…&type=recovery` — password
    ///     recovery and email confirmation
    ///
    /// The web has to defend against these landing on the wrong route (see
    /// `src/lib/recovery.ts`); on iOS there is exactly one entry point, so the
    /// handling is a single function.
    private func handle(_ url: URL) {
        guard url.scheme == SupabaseConfig.redirectURL.scheme else { return }

        // A MitID return. The deep link arrives at the app rather than at a
        // screen, so it is routed to the coordinator regardless of what is on
        // screen — the browser trip may well have outlived the view that
        // started it.
        if let callback = MitIDCallback(url: url) {
            Task { await mitIDSignIn.handle(callback) }
            return
        }

        let fragment = URLComponents(string: "?" + (url.fragment() ?? ""))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = (fragment?.queryItems ?? []) + (query?.queryItems ?? [])

        if items.first(where: { $0.name == "type" })?.value == "recovery" {
            session.beginPasswordRecovery()
        }

        // Let the SDK turn the callback into a session either way.
        Task { try? await SupabaseClient.shared.auth.session(from: url) }
    }
}
