//
//  SignUpView.swift
//  SmartShop
//

import SwiftUI

/// The five-step ID sign-up wizard. Port of `src/routes/opret-konto.tsx`,
/// plus a password step the web does not have.
///
/// Step 1 collects name and address, then the ID document, a phone code and an
/// email code. Step 5 chooses a password: the web never needed one, because
/// sign-in there is by one-time code or MitID, but the Mobile API's
/// `POST /auth/register` requires a password and there is no endpoint that sets
/// one afterwards without knowing the current one.
@MainActor
@Observable
final class SignUpModel {
    enum Field: Hashable { case fornavn, efternavn, adresse, postnr, by, password, confirm }

    var step = 1
    var fornavn = ""
    var efternavn = ""
    var adresse = ""
    var postnr = ""
    var by = ""
    var acceptedTerms = false
    var wantsMarketing = false
    var password = ""
    var confirmPassword = ""
    /// Captured from the email step, because registering needs an address to
    /// register *with* and only that step knows what was typed.
    var verifiedEmail = ""
    var passwordSaved = false
    /// Field -> error *key*; the view translates on display.
    var errors: [Field: String] = [:]
    var termsErrorKey: String?
    var formErrorKey: String?
    var isSubmitting = false

    private let idSignup: any IdSignupService
    private let auth: any AuthService
    private let device: DeviceState
    private let session: AuthSessionStore
    private let addresses = DanishAddressService()
    private var postalTask: Task<Void, Never>?

    init(idSignup: any IdSignupService, auth: any AuthService, device: DeviceState, session: AuthSessionStore) {
        self.idSignup = idSignup
        self.auth = auth
        self.device = device
        self.session = session
    }

    func apply(_ s: DanishAddressService.Suggestion) {
        adresse = s.street
        postnr = s.postalCode
        by = s.city
    }

    func postalCodeChanged(_ code: String) {
        postalTask?.cancel()
        guard code.count == 4 else { return }
        postalTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let city = await addresses.city(forPostalCode: code), !Task.isCancelled else { return }
            by = city
        }
    }

    private func validate() -> Bool {
        var next: [Field: String] = [:]
        func e(_ name: String) -> String { "signup.errors.\(name)" }
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if trim(fornavn).isEmpty { next[.fornavn] = e("firstName") }
        if trim(efternavn).isEmpty { next[.efternavn] = e("lastName") }
        if trim(adresse).isEmpty { next[.adresse] = e("address") }
        if trim(postnr).wholeMatch(of: /\d{4}/) == nil { next[.postnr] = e("zip") }
        if trim(by).isEmpty { next[.by] = e("city") }
        errors = next
        termsErrorKey = acceptedTerms ? nil : "signup.errors.terms"
        return next.isEmpty && acceptedTerms
    }

    func submitDetails() async {
        formErrorKey = nil
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        do {
            let tokenHash = try await idSignup.start(IdSignupDetails(
                fornavn: trim(fornavn), efternavn: trim(efternavn), adresse: trim(adresse),
                postnr: trim(postnr), by: trim(by), markedsforing: wantsMarketing
            ))
            session.beginEnrollment()
            try await auth.verifyEmailToken(hash: tokenHash)
            device.stopGuest()
            step = 2
        } catch {
            session.finishEnrollment()
            formErrorKey = "signup.errors.generic"
        }
    }

    func advance() {
        if step < 5 {
            step += 1
        } else {
            session.finishEnrollment()
        }
    }

    /// Step 5. Same rules the rest of the app applies to a new password:
    /// at least 8 characters, and typed the same way twice.
    func savePassword() async {
        formErrorKey = nil
        var next: [Field: String] = [:]
        if password.isEmpty {
            next[.password] = "signup.errors.enterPassword"
        } else if password.count < 8 {
            next[.password] = "signup.errors.passwordTooShort"
        }
        if confirmPassword.isEmpty {
            next[.confirm] = "signup.errors.repeatPassword"
        } else if confirmPassword != password {
            next[.confirm] = "signup.errors.passwordsDontMatch"
        }
        errors = next
        guard next.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        do {
            try await auth.setSignUpPassword(
                password,
                email: verifiedEmail,
                profile: SignUpProfile(
                    fornavn: trim(fornavn), efternavn: trim(efternavn),
                    adresse: trim(adresse), postnr: trim(postnr), by: trim(by),
                    telefon: "", markedsforing: wantsMarketing,
                    acceptsTerms: acceptedTerms
                )
            )
            password = ""
            confirmPassword = ""
            passwordSaved = true
            session.finishEnrollment()
        } catch {
            formErrorKey = "signup.errors.passwordGeneric"
        }
    }
}

struct SignUpView: View {
    @Environment(\.strings) private var t
    @State private var model: SignUpModel

    init(idSignup: any IdSignupService, auth: any AuthService, device: DeviceState, session: AuthSessionStore) {
        _model = State(initialValue: SignUpModel(idSignup: idSignup, auth: auth, device: device, session: session))
    }

    private var stepLabels: [String] {
        ["details", "id", "phone", "email", "password"].map { t("signup.steps.\($0)") }
    }

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AuthHeader(showsBack: model.step == 1)
                    .padding(.top, Theme.Spacing.md)

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        stepIndicator

                        switch model.step {
                        case 1: detailsForm
                        case 2: IdVerificationForm { model.advance() }
                            .padding(4).background(.white.opacity(0.95), in: .rect(cornerRadius: Theme.Radius.card))
                        case 3: OtpSection(kind: .phone, tone: .dark) { model.advance() }
                        case 4:
                            OtpSection(
                                kind: .email,
                                tone: .dark,
                                onVerified: { model.advance() },
                                onVerifiedDestination: { model.verifiedEmail = $0 }
                            )
                        default: passwordForm
                        }

                        if model.step == 1 {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(t("signup.hasAccount")).foregroundStyle(.white.opacity(0.8))
                                NavigationLink(t("common.login"), value: AuthRoute.login)
                                    .fontWeight(.semibold).underline()
                            }
                            .font(Theme.body(.subheadline))
                            .padding(.top, Theme.Spacing.sm)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(model.step > 1)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(t("signup.title")).font(Theme.display(.largeTitle))
            Text(stepLabels[model.step - 1])
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    /// Numbered circles: lime tick when passed, white when active, dim otherwise.
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { n in
                let passed = model.step > n
                let active = model.step == n
                Group {
                    if passed {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                    } else {
                        Text("\(n)").font(Theme.body(.subheadline, weight: .bold))
                    }
                }
                .foregroundStyle(passed ? .white : active ? Theme.Colors.green : .white.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(passed ? Theme.Colors.lime : active ? .white : .white.opacity(0.2), in: .circle)
                .accessibilityLabel("\(stepLabels[n - 1])")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("signup.title"))
    }

    /// Step 5. Deliberately the same card as "Change password" in My details —
    /// it is the same job, and someone who has seen one should recognise the
    /// other.
    @ViewBuilder
    private var passwordForm: some View {
        @Bindable var model = model
        GuestCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(t("signup.password.title"))
                    .font(Theme.display(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)

                if model.passwordSaved {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Colors.lime)
                        Text(t("signup.password.saved"))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green)
                    }
                } else {
                    Text(t("signup.password.subtitle"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.green.opacity(0.75))

                    BrandTextField(
                        label: t("signup.password.newPassword"),
                        text: $model.password,
                        error: model.errors[.password].map { t($0) },
                        isSecure: true,
                        contentType: .newPassword,
                        tone: .onLight
                    )
                    BrandTextField(
                        label: t("signup.password.repeatPassword"),
                        text: $model.confirmPassword,
                        error: model.errors[.confirm].map { t($0) },
                        isSecure: true,
                        contentType: .newPassword,
                        tone: .onLight
                    )

                    Button(
                        model.isSubmitting
                            ? t("signup.password.saving")
                            : t("signup.password.save")
                    ) {
                        Task { await model.savePassword() }
                    }
                    .buttonStyle(LeaveGuestButtonStyle())
                    .disabled(model.isSubmitting)
                    .opacity(model.isSubmitting ? 0.6 : 1)

                    if let key = model.formErrorKey {
                        Text(t(key))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.red)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    @ViewBuilder
    private var detailsForm: some View {
        @Bindable var model = model
        VStack(spacing: 20) {
            Text(t("signup.danishAddressNote"))
                .font(Theme.body(.caption))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            BrandTextField(label: t("signup.fields.firstName"), placeholder: t("signup.placeholders.firstName"),
                           text: $model.fornavn, error: model.errors[.fornavn].map { t($0) },
                           contentType: .givenName, autocapitalization: .words)
            BrandTextField(label: t("signup.fields.lastName"), placeholder: t("signup.placeholders.lastName"),
                           text: $model.efternavn, error: model.errors[.efternavn].map { t($0) },
                           contentType: .familyName, autocapitalization: .words)
            AddressField(label: t("signup.fields.address"), text: $model.adresse,
                         error: model.errors[.adresse].map { t($0) },
                         placeholder: t("signup.placeholders.address"), tone: .onGreen) { model.apply($0) }
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                BrandTextField(label: t("signup.fields.zip"), placeholder: t("signup.placeholders.zip"),
                               text: Binding(get: { model.postnr }, set: { model.postnr = String($0.filter(\.isNumber).prefix(4)) }),
                               error: model.errors[.postnr].map { t($0) },
                               contentType: .postalCode, keyboard: .numberPad)
                    .frame(width: 112)
                BrandTextField(label: t("signup.fields.city"), placeholder: t("signup.placeholders.city"),
                               text: Binding(get: { model.by }, set: { model.by = $0.filter { $0.isLetter || $0.isWhitespace || $0 == "'" || $0 == "-" } }),
                               error: model.errors[.by].map { t($0) },
                               contentType: .addressCity, autocapitalization: .words)
            }
            .onChange(of: model.postnr) { _, new in model.postalCodeChanged(new) }

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(get: { model.acceptedTerms }, set: { model.acceptedTerms = $0; if $0 { model.termsErrorKey = nil } })) {
                    // The web styles these as links but they do not navigate.
                    Text("\(t("signup.termsPrefix")) **\(t("signup.termsLink"))** \(t("signup.termsAnd")) **\(t("signup.privacyLink"))**")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .toggleStyle(CheckboxToggleStyle(onGreen: true))
                .accessibilityIdentifier("signupTerms")
                if let key = model.termsErrorKey {
                    Text(t(key)).font(Theme.body(.subheadline)).foregroundStyle(.white.opacity(0.9))
                }
                Toggle(isOn: $model.wantsMarketing) {
                    Text(t("signup.marketing"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .toggleStyle(CheckboxToggleStyle(onGreen: true))
            }

            Button(model.isSubmitting ? t("signup.submitting") : t("signup.ok")) {
                Task { await model.submitDetails() }
            }
            .buttonStyle(.brandPrimary)
            .disabled(!model.acceptedTerms || model.isSubmitting)
            // The web greys the button until the terms are accepted.
            .opacity(model.acceptedTerms ? 1 : 0.45)

            if let key = model.formErrorKey {
                Text(t(key)).font(Theme.body(.subheadline)).multilineTextAlignment(.center)
            }
        }
    }

}
