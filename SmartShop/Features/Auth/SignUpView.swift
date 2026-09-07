//
//  SignUpView.swift
//  SmartShop
//

import SwiftUI

/// The four-step ID sign-up wizard. Port of `src/routes/opret-konto.tsx`.
///
/// Step 1 collects name and address and creates the account through the
/// ID sign-up function; there is no password. Then the ID document, a phone
/// code and an email code, and the onboarding guide takes over.
@MainActor
@Observable
final class SignUpModel {
    enum Field: Hashable { case fornavn, efternavn, adresse, postnr, by }

    var step = 1
    var fornavn = ""
    var efternavn = ""
    var adresse = ""
    var postnr = ""
    var by = ""
    var acceptedTerms = false
    var wantsMarketing = false
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
        if step < 4 {
            step += 1
        } else {
            session.finishEnrollment()
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
        ["details", "id", "phone", "email"].map { t("signup.steps.\($0)") }
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
                        default: OtpSection(kind: .email, tone: .dark) { model.advance() }
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
            ForEach(1...4, id: \.self) { n in
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
