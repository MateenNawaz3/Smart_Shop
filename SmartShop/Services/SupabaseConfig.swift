//
//  SupabaseConfig.swift
//  SmartShop
//

import Foundation
import Supabase

/// Backend configuration.
///
/// The **publishable** key is designed to be public — it is the same key the
/// web app ships to every browser, and it grants nothing on its own. Row Level
/// Security on the `profiles` / `mitid_identities` tables is what actually
/// protects the data. Shipping it inside the app binary is therefore expected
/// and safe.
///
/// The **secret** key (`sb_secret_…` / service_role) must NEVER appear in this
/// target. It bypasses every RLS policy, and anything shipped in an app bundle
/// can be extracted in minutes. Server-side work that needs it belongs in a
/// Supabase Edge Function — see `docs/mitid-edge-function.md`.
nonisolated enum SupabaseConfig {
    static let url = URL(string: "https://vjexegjpyzppjhqdfans.supabase.co")!
    static let publishableKey = "sb_publishable_VrXGbpFOGXCYm66UimohvQ_IMo0j2ii"

    /// Deep link the password-recovery email returns to.
    /// Must be added to Supabase → Authentication → URL Configuration →
    /// Redirect URLs, and to `CFBundleURLTypes` in Info.plist.
    static let redirectURL = URL(string: "smartshop://auth-callback")!
}

nonisolated extension SupabaseClient {
    /// The app's shared client. Session storage defaults to the Keychain in
    /// supabase-swift, so tokens survive relaunch and are protected by the
    /// device passcode — a genuine improvement over the web's `localStorage`.
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.publishableKey
    )
}
