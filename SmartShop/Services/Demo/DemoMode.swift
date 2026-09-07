//
//  DemoMode.swift
//  SmartShop
//

import Foundation

/// The one switch that decides whether the app talks to Supabase or to the
/// in-memory demo backend.
///
/// The web project carries the same idea as a set of constants —
/// `DEMO_SHOW_CODE` in `otp.functions.ts`, `DEMO_AUTO_APPROVE` in
/// `verification.functions.ts`, `DEV_ALWAYS_WIN` in `wheel.config.ts`. This is
/// the app's equivalent, kept in one place instead of three.
///
/// ## Why it exists
///
/// Creating an account needs the Supabase **service_role** key
/// (`admin.createUser` + `generateLink`), which cannot ship inside an app
/// binary. Until those calls live in Edge Functions, sign-up cannot reach a
/// real server — so with no demo mode there is no way to create an account at
/// all, and every screen behind sign-up is unreachable.
///
/// Demo mode runs the *whole* flow locally: every validation rule, every error
/// state, every loading spinner and every screen transition behaves exactly as
/// it will once the functions are deployed. Only the network call at the end is
/// faked.
///
/// ## Turning it off
///
/// Set `isEnabled` to `false` once these Edge Functions exist:
///
/// - `id-signup-start`
/// - `mitid-demo-login`
/// - `otp-send-phone`, `otp-verify-phone`
/// - `otp-send-email`, `otp-verify-email`
/// - `wheel-spin`
///
/// Nothing else in the app changes: every screen already calls a protocol, and
/// the live implementations are written and waiting behind this flag.
enum DemoMode {
    /// `false` = talk to Supabase. `true` = run entirely on the device.
    static let isEnabled = true

    /// Latency added to demo calls so loading states are actually visible.
    /// Without it, "Creating…" flashes for one frame and the flow feels broken.
    static func pause(_ seconds: Double = 0.7) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
