//
//  MitIDSignInView.swift
//  SmartShop
//

import SwiftUI

/// The real MitID sign-in: a browser round trip, not a simulation.
///
/// Replaces `MitIDView`'s demo stages, which asked for a name and a birth date
/// and pretended to be the MitID app. MitID supplies the identity itself, so
/// this screen collects nothing — it opens MitID and waits to be deep-linked
/// back.
///
/// The work lives in `MitIDSignInCoordinator` rather than here, because the
/// browser trip outlives this view: the deep link arrives at the app, and the
/// app may well have been terminated and relaunched in between.
struct MitIDSignInView: View {
    @Environment(\.strings) private var t
    @Environment(MitIDSignInCoordinator.self) private var coordinator
    @Environment(DeviceState.self) private var device
    @Environment(AuthSessionStore.self) private var session

    /// A brand new MitID account has contact details and a PIN still to set.
    @State private var goToContactDetails = false

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AuthHeader()
                    .padding(.top, Theme.Spacing.md)

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        switch coordinator.phase {
                        case .idle, .starting, .failed:
                            intro
                        case .awaitingCallback, .completing:
                            waiting
                        case .signedIn(let didRegister):
                            signedIn(didRegister: didRegister)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: coordinator.phase)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goToContactDetails) { ContactDetailsView() }
        .onChange(of: coordinator.phase) { _, phase in
            switch phase {
            case .signedIn(let didRegister):
                // Ask whenever we are actually missing something, not only on
                // the first sign-in ever. `registered` is true exactly once per
                // identity, so branching on it alone meant a customer who
                // abandoned this screen could never be asked again — and MitID
                // gives us neither an email nor a phone number, so there is
                // always something missing until someone types it.
                //
                // `registered` now only chooses the wording.
                if didRegister || coordinator.profile.needsContactDetails {
                    goToContactDetails = true
                } else {
                    session.finishEnrollment()
                }
            case .idle, .failed:
                // Cancelled or failed: nothing was created, so let the app
                // resolve its own phase again rather than stranding it.
                session.finishEnrollment()
            case .starting, .awaitingCallback, .completing:
                break
            }
        }
        .onDisappear {
            // Leaving the screen abandons the attempt, so a late deep link
            // cannot sign someone in behind a screen they walked away from.
            if case .signedIn = coordinator.phase {} else { coordinator.reset() }
        }
    }

    // MARK: - Before the trip

    private var intro: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text(t("mitid.signIn.title")).font(Theme.display(.largeTitle))
            Text(t("mitid.signIn.subtitle"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button(isStarting ? t("mitid.signIn.starting") : t("mitid.signIn.start")) {
                Task {
                    // Held until the flow finishes, or the session landing
                    // mid-trip would swap the whole app to the tab shell and
                    // tear this screen down underneath the customer.
                    session.beginEnrollment()
                    await coordinator.start()
                }
            }
            .buttonStyle(.brandPrimary)
            .disabled(isStarting)
            .opacity(isStarting ? 0.6 : 1)

            // Terms are accepted here because a MitID sign-in can create an
            // account, and by the time the subject is known to be new the
            // customer has left MitID.
            Text(t("mitid.signIn.termsNote"))
                .font(Theme.body(.footnote))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            if case .failed(let key) = coordinator.phase {
                Text(t(key))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.lime)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var isStarting: Bool { coordinator.phase == .starting }

    // MARK: - While away

    private var waiting: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.lime)
            Text(
                coordinator.phase == .completing
                    ? t("mitid.signIn.completing")
                    : t("mitid.signIn.waiting")
            )
            .font(Theme.body(.subheadline))
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)

            if coordinator.phase == .awaitingCallback {
                Button(t("mitid.signIn.tryAgain")) {
                    Task {
                    // Held until the flow finishes, or the session landing
                    // mid-trip would swap the whole app to the tab shell and
                    // tear this screen down underneath the customer.
                    session.beginEnrollment()
                    await coordinator.start()
                }
                }
                .buttonStyle(.brandOutline)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Back, and signed in

    private func signedIn(didRegister: Bool) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Theme.Colors.lime, in: .circle)

            // A new MitID subject gets an account made for them, and has setup
            // left to do; a returning one does not.
            Text(
                didRegister
                    ? t("mitid.signIn.accountCreated")
                    : t("mitid.signIn.welcomeBack")
            )
            .font(Theme.display(.title2))
            .multilineTextAlignment(.center)
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .onAppear { device.stopGuest() }
    }
}
