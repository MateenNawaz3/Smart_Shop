//
//  LoginView.swift
//  SmartShop
//

import SwiftUI

/// State and validation for the login screen. Port of the `LogIn` component's
/// hooks in `src/routes/log-ind.tsx`.
@MainActor
@Observable
final class LoginModel {
    var email = ""
    var password = ""
    /// Error *keys*, not sentences: the view translates them, so switching
    /// language re-renders errors that are already on screen.
    var emailErrorKey: String?
    var passwordErrorKey: String?
    var formErrorKey: String?
    var isSubmitting = false
    var showForgotSheet = false

    private let auth: any AuthService
    private let device: DeviceState

    init(auth: any AuthService, device: DeviceState) {
        self.auth = auth
        self.device = device
    }

    /// Same rules as the web, including its email regex.
    private func validate() -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        emailErrorKey = trimmed.isEmpty ? "login.errEmail"
            : trimmed.isValidEmail ? nil : "login.errEmailInvalid"
        passwordErrorKey = password.isEmpty ? "login.errPassword" : nil
        return emailErrorKey == nil && passwordErrorKey == nil
    }

    func submit() async {
        formErrorKey = nil
        guard validate() else { return }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            // The web calls stopGuest() here; leaving guest mode on would keep
            // the app showing the restricted guest UI to a signed-in user.
            device.stopGuest()
        } catch {
            formErrorKey = AuthErrorText.signIn(error)
        }
    }
}

struct LoginView: View {
    @Environment(\.strings) private var t
    @State private var model: LoginModel

    init(auth: any AuthService, device: DeviceState) {
        _model = State(initialValue: LoginModel(auth: auth, device: device))
    }

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AuthHeader()
                    .padding(.top, Theme.Spacing.md)

                ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(t("login.title"))
                            .font(Theme.display(.largeTitle))
                        Text(t("login.subtitle"))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, Theme.Spacing.xl)

                    BrandTextField(
                        label: t("common.email"),
                        placeholder: t("login.emailPlaceholder"),
                        text: $model.email,
                        error: model.emailErrorKey.map { t($0) },
                        contentType: .emailAddress,
                        keyboard: .emailAddress,
                        autocapitalization: .never
                    )

                    BrandTextField(
                        label: t("common.password"),
                        text: $model.password,
                        error: model.passwordErrorKey.map { t($0) },
                        isSecure: true,
                        contentType: .password
                    )

                    Button(t("login.forgot")) { model.showForgotSheet = true }
                        .font(Theme.body(.subheadline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    Button {
                        Task { await model.submit() }
                    } label: {
                        Text(model.isSubmitting ? t("login.submitting") : t("login.title"))
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(model.isSubmitting)

                    if let key = model.formErrorKey {
                        Text(t(key))
                            .font(Theme.body(.subheadline))
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: Theme.Spacing.xs) {
                        Text(t("login.noAccount"))
                            .foregroundStyle(.white.opacity(0.8))
                        NavigationLink(t("common.createAccount"), value: AuthRoute.signUp)
                            .fontWeight(.semibold)
                            .underline()
                    }
                    .font(Theme.body(.subheadline))
                    .padding(.top, Theme.Spacing.md)
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $model.showForgotSheet) {
            ForgotPasswordSheet(email: model.email)
        }
    }
}

extension String {
    /// Mirrors the web's `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`.
    var isValidEmail: Bool {
        wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil
    }
}

#Preview {
    NavigationStack {
        LoginView(auth: SupabaseAuthService(), device: DeviceState())
    }
}
