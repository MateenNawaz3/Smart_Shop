//
//  RootView.swift
//  SmartShop
//

import SwiftUI
import Supabase

/// Renders whichever phase the app is in.
///
/// This is the whole of `_authenticated/route.tsx`, expressed as a `switch`
/// instead of redirect-throwing guards: no session → auth flow; PIN set but not
/// entered → unlock; recovering → reset screen; otherwise the app.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSessionStore.self) private var session

    var body: some View {
        ZStack {
            switch session.phase {
            case .loading:
                LaunchView()
            case .signedOut:
                AuthFlowView()
            case .locked:
                UnlockView()
            case .recovering:
                ResetPasswordView()
            case .ready:
                SignedInRoot()
            }
        }
        // A phase change is a whole-app transition, so it should be felt.
        .animation(
            UITesting.animationsDisabled ? nil : .easeInOut(duration: 0.25),
            value: session.phase
        )
        .task { await session.start() }
    }
}

/// Signed in and unlocked: the onboarding guide until it has been completed
/// once, then the tab shell. The web gates this on `profiles.onboarding_gennemfoert`
/// in `/velkommen`; here the flag is read once per session.
struct SignedInRoot: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(ProfileCache.self) private var profileCache

    private enum Gate { case unknown, onboarding, app }
    @State private var gate: Gate = .unknown

    var body: some View {
        ZStack {
            switch gate {
            case .unknown: LaunchView()
            case .onboarding: OnboardingView { gate = .app }
            case .app: AppTabBar()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: gate == .app)
        .task {
            await profileCache.load(from: environment.profileService)
            let done = (try? await environment.profileService.storeProfile())?.onboardingDone ?? true
            gate = done ? .app : .onboarding
        }
    }
}

/// The signed-out navigation stack. Destinations are declared once here, so no
/// screen needs to know what comes after it — the value-based navigation the
/// Catalog example used, applied to a real flow.
struct AuthFlowView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(DeviceState.self) private var device
    @Environment(AuthSessionStore.self) private var session

    @State private var path = NavigationPath()
    @State private var showsGuest = false

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(onGuest: { showsGuest = true })
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .login:
                        LoginView(auth: environment.authService, device: device)
                    case .signUp:
                        SignUpView(
                            idSignup: environment.idSignupService,
                            auth: environment.authService,
                            device: device,
                            session: session
                        )
                    case .mitID:
                        MitIDView(
                            mitID: environment.mitIDService,
                            auth: environment.authService,
                            device: device,
                            session: session
                        )
                    case .pinSetup:
                        PinSetupView()
                    }
                }
        }
        .tint(.white)
        // A NavigationStack must not be pushed inside another stack's
        // destination — SwiftUI traps on the nested path. Guest mode is its own
        // stack, so it is presented over the auth flow instead.
        .fullScreenCover(isPresented: $showsGuest) {
            GuestFlowView(
                onCreateAccount: { leaveGuest(for: .signUp) },
                onLogIn: { leaveGuest(for: .login) }
            )
        }
    }

    /// Closes guest mode and continues into the auth flow.
    private func leaveGuest(for route: AuthRoute) {
        showsGuest = false
        path.append(route)
    }
}

/// Shown while the stored session is being read on launch.
struct LaunchView: View {
    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            AppLogo()
        }
    }
}
