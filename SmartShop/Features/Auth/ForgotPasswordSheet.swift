//
//  ForgotPasswordSheet.swift
//  SmartShop
//

import SwiftUI

/// White bottom sheet for requesting a password reset.
/// Port of `components/app/ForgotPasswordDialog.tsx`.
///
/// Always reports success, whether or not the address exists. Confirming which
/// emails have accounts would turn this form into an account-enumeration oracle.
struct ForgotPasswordSheet: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var error: String?
    @State private var isSending = false
    @State private var didSend = false

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    var body: some View {
        VStack(spacing: 0) {
            if didSend {
                sent
            } else {
                form
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(didSend ? 340 : 380)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.card)
        .presentationBackground(.white)
        .animation(.easeOut(duration: 0.2), value: didSend)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(t("forgot.title"))
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.Colors.ink)
            Text(t("forgot.description"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.ink.opacity(0.6))

            BrandTextField(
                label: t("forgot.label"),
                placeholder: t("forgot.placeholder"),
                text: $email,
                error: error,
                contentType: .emailAddress,
                keyboard: .emailAddress,
                autocapitalization: .never,
                tone: .onLight
            )
            .padding(.top, Theme.Spacing.xs)

            Button(isSending ? t("forgot.submitting") : t("forgot.send")) {
                Task { await send() }
            }
            .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
            .disabled(isSending)
            .opacity(isSending ? 0.6 : 1)

            Button(t("common.cancel")) { dismiss() }
                .font(Theme.body(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.Colors.ink.opacity(0.55))
                .underline()
                .frame(maxWidth: .infinity)
        }
    }

    private var sent: some View {
        VStack(spacing: 0) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.Colors.lime)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.lime.opacity(0.15), in: .circle)
            Text(t("forgot.sentTitle"))
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.md)
            (Text(t("forgot.sentBefore"))
                + Text(email.trimmingCharacters(in: .whitespaces)).fontWeight(.semibold).foregroundColor(Theme.Colors.ink)
                + Text(t("forgot.sentAfter")))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.sm)
            Button(t("common.close")) { dismiss() }
                .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                .padding(.top, Theme.Spacing.lg)
        }
    }

    private func send() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = t("forgot.errEmail"); return }
        guard trimmed.isValidEmail else { error = t("forgot.errEmailInvalid"); return }
        error = nil
        isSending = true
        defer { isSending = false }
        do {
            try await environment.authService.sendPasswordReset(to: trimmed)
            didSend = true
        } catch {
            self.error = t("forgot.errSend")
        }
    }
}
