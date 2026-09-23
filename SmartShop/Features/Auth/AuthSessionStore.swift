//
//  AuthSessionStore.swift
//  SmartShop
//

import Foundation

/// App-wide auth state — the single source of truth for which screen the app
/// should be showing.
///
/// This replaces `_authenticated/route.tsx`. The web re-runs a `beforeLoad`
/// guard on every navigation and throws redirects. SwiftUI has no router to
/// intercept, so instead the app derives one `Phase` and `RootView` renders it.
/// The result is the same two locks the web has, but they are now a value you
/// can read, test and preview rather than control flow scattered across routes.
@MainActor
@Observable
final class AuthSessionStore {
    enum Phase: Equatable {
        /// Checking for a stored session on launch.
        case loading
        /// Signed out — show the welcome / login flow.
        case signedOut
        /// Signed in, but this device has a PIN that has not been entered yet.
        case locked
        /// Signed in and unlocked.
        case ready
        /// A password-recovery deep link is being handled; do not enter the app.
        case recovering
    }

    private(set) var phase: Phase = .loading
    /// The reset token from a password-recovery deep link, when there was one.
    private(set) var recoveryToken: String?
    private(set) var session: AuthSession?
    /// True while a multi-step sign-up (MitID → contact details → PIN, or the
    /// ID wizard) is in progress. The session exists from the first step, so
    /// without this hold the app would jump into the tab shell mid-flow.
    private(set) var isEnrolling = false

    private let auth: any AuthService
    private let device: DeviceState
    private var watcher: Task<Void, Never>?

    init(auth: any AuthService, device: DeviceState) {
        self.auth = auth
        self.device = device
    }

    /// Starts observing the backend. Called once from `RootView.task`.
    func start() async {
        // UI tests cannot create a real Supabase session, so screens behind the
        // gate would be unreachable and untested. This skips straight to the
        // signed-in phase; nothing else about the app changes.
        if UITesting.isSignedIn {
            phase = .ready
            return
        }
        // Supabase keeps its session in the Keychain, which survives app
        // reinstalls on a simulator. Without this, a real sign-in done by hand
        // months ago silently sends every signed-out test straight to Home.
        if UITesting.isActive {
            try? await auth.signOut()
        }
        session = await auth.currentSession()
        recompute()

        watcher?.cancel()
        // `authStateChanges` also fires on silent token refresh, so the app
        // notices an expired or revoked session without polling.
        watcher = Task { [weak self] in
            guard let self else { return }
            for await session in auth.sessionUpdates() {
                self.session = session
                self.recompute()
            }
        }
    }

    /// Recomputes the phase from session + device flags. Mirrors the web guard:
    /// no user → login; PIN on device and not unlocked → unlock; else in.
    func recompute() {
        guard phase != .recovering, !isEnrolling else { return }
        guard session != nil else {
            phase = .signedOut
            return
        }
        phase = device.hasPinOnDevice && !device.isUnlocked ? .locked : .ready
    }

    func beginEnrollment() { isEnrolling = true }

    func finishEnrollment() {
        isEnrolling = false
        recompute()
    }

    /// Enters recovery, carrying the reset token when the backend sends one.
    ///
    /// Supabase has no token to carry: its link turns into a live recovery
    /// session and the new password is set on that. The Mobile API has no
    /// recovery session at all — the token from the link *is* the credential,
    /// and it has to reach the reset screen, which the deep link is the only
    /// source for.
    func beginPasswordRecovery(token: String? = nil) {
        recoveryToken = token
        phase = .recovering
    }

    func endPasswordRecovery() {
        recoveryToken = nil
        phase = .loading
        recompute()
    }

    func signOut() async {
        device.clearPinOnDevice()
        device.stopGuest()
        try? await auth.signOut()
        session = nil
        phase = .signedOut
    }

    /// Stops observing. There is no `deinit` cleanup here: a `@MainActor` type
    /// cannot touch its isolated state from a nonisolated `deinit`. This store
    /// lives for the whole process, so the watcher is torn down explicitly
    /// rather than implicitly.
    func stop() {
        watcher?.cancel()
        watcher = nil
    }
}
