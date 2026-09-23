//
//  ResetPasswordView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/nulstil-kodeord.tsx`.
///
/// Reached from the recovery email. The web has to guard against the link
/// landing on the wrong page and against the app auto-navigating the user into
/// `/hjem` mid-recovery — that is what `src/lib/recovery.ts` is for. On iOS the
/// deep link arrives at exactly one place, so `AuthSessionStore.phase` is simply
/// pinned to `.recovering` until this screen finishes.
struct ResetPasswordView: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSessionStore.self) private var session

    @State private var password = ""
    @State private var confirmation = ""
    @State private var passwordError: String?
    @State private var confirmationError: String?
    @State private var formError: String?
    @State private var isSaving = false
    @State private var didSave = false
    /// nil until the link has been checked; false means expired or already used.
    @State private var linkIsValid: Bool?

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    AppLogo(size: .small).padding(.top, Theme.Spacing.lg)

                    if didSave {
                        done
                    } else if linkIsValid == false {
                        expired
                    } else {
                        form
                    }
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task { await checkLink() }
    }

    /// Asks the backend whether the link is still good before showing the form,
    /// so an expired link says so instead of taking a password and then
    /// refusing it. Only the Mobile API can answer this; Supabase's link has
    /// already become a session by the time this screen appears, and its
    /// `isResetTokenValid` refuses, which is read as "nothing to check".
    private func checkLink() async {
        guard let token = session.recoveryToken, linkIsValid == nil else { return }
        linkIsValid = (try? await environment.authService.isResetTokenValid(token)) ?? true
    }

    private var expired: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(t("reset.errExpired")).font(Theme.display(.title))
                .multilineTextAlignment(.center)
            Text(t("reset.expiredNote"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button(t("reset.backToLogin")) {
                Task {
                    await session.signOut()
                    session.endPasswordRecovery()
                }
            }
            .buttonStyle(.brandPrimary)
            .padding(.top, Theme.Spacing.md)
        }
    }

    private var form: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.sm) {
                Text(t("reset.title")).font(Theme.display(.title))
                Text(t("reset.subtitle"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(.white.opacity(0.8))
            }

            BrandTextField(
                label: t("reset.newPassword"),
                text: $password,
                error: passwordError,
                isSecure: true,
                contentType: .newPassword
            )
            BrandTextField(
                label: t("reset.repeatPassword"),
                text: $confirmation,
                error: confirmationError,
                isSecure: true,
                contentType: .newPassword
            )

            Button {
                Task { await save() }
            } label: {
                Text(isSaving ? t("reset.submitting") : t("reset.submit"))
            }
            .buttonStyle(.brandPrimary)
            .disabled(isSaving)

            if let formError {
                Text(formError).font(Theme.body(.subheadline)).multilineTextAlignment(.center)
            }
        }
    }

    private var done: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.lime)
            Text(t("reset.doneTitle")).font(Theme.display(.title))
            Text(t("reset.doneText"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button(t("reset.backToLogin")) {
                Task {
                    // The recovery session is a live session; signing out means
                    // the new password is actually exercised on next login.
                    await session.signOut()
                    session.endPasswordRecovery()
                }
            }
            .buttonStyle(.brandPrimary)
            .padding(.top, Theme.Spacing.md)
        }
    }

    private func save() async {
        formError = nil
        passwordError = password.isEmpty ? t("reset.errPassword")
            : password.count < 8 ? t("reset.errPasswordShort") : nil
        confirmationError = confirmation.isEmpty ? t("reset.errRepeat")
            : confirmation != password ? t("reset.errMismatch") : nil
        guard passwordError == nil, confirmationError == nil else { return }

        isSaving = true
        defer { isSaving = false }
        do {
            // Two shapes of the same flow. The Mobile API sets the password
            // straight from the emailed token; Supabase has already exchanged
            // that token for a recovery session, so there is nothing to carry.
            if let token = session.recoveryToken {
                try await environment.authService.resetPassword(
                    token: token, newPassword: password
                )
            } else {
                try await environment.authService.updatePassword(password)
            }
            didSave = true
        } catch {
            // A token works once and expires in an hour, so the likeliest
            // failure at this point is that the link is spent.
            if session.recoveryToken != nil, error is APIError {
                linkIsValid = false
            } else {
                formError = t("reset.errGeneric")
            }
        }
    }
}
