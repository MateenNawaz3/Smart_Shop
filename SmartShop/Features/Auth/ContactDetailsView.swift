//
//  ContactDetailsView.swift
//  SmartShop
//

import SwiftUI

/// After MitID: email, phone and address, then on to the PIN.
/// Port of `routes/mitid_.oplysninger.tsx`.
///
@MainActor
@Observable
final class ContactDetailsModel {
    enum Field: Hashable { case email, telefon, adresse, postnr, by }

    var email = ""
    var telefon = ""
    var adresse = ""
    var postnr = ""
    var by = ""
    var errors: [Field: String] = [:]
    var formError: String?
    var saving = false
    var saved = false

    private let profiles: any ProfileService
    private let addresses = DanishAddressService()
    private var postalTask: Task<Void, Never>?

    init(profiles: any ProfileService) {
        self.profiles = profiles
    }

    func load() async {
        guard let details = try? await profiles.details() else { return }
        // MitID accounts start with a placeholder address the user must replace.
        email = details.email.hasSuffix("@mitid.local") ? "" : details.email
        telefon = details.telefon
        adresse = details.adresse
        postnr = details.postnr
        by = details.by
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

    func save() async {
        formError = nil
        var next: [Field: String] = [:]
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        if !trim(email).isValidEmail { next[.email] = "otp.contact.errors.email" }
        if trim(telefon).wholeMatch(of: /\+?\d[\d\s-]{6,17}/) == nil { next[.telefon] = "otp.contact.errors.phone" }
        if trim(adresse).isEmpty { next[.adresse] = "otp.contact.errors.address" }
        if !(trim(postnr).count == 4 && trim(postnr).allSatisfy(\.isNumber)) { next[.postnr] = "otp.contact.errors.postalCode" }
        if trim(by).isEmpty { next[.by] = "otp.contact.errors.city" }
        errors = next
        guard next.isEmpty else { return }

        saving = true
        defer { saving = false }
        do {
            try await profiles.saveContactDetails(
                email: trim(email), telefon: trim(telefon), adresse: trim(adresse),
                postnr: trim(postnr), by: trim(by)
            )
            saved = true
        } catch {
            formError = "otp.contact.errors.generic"
        }
    }
}

struct ContactDetailsView: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var model: ContactDetailsModel?
    @State private var goToPin = false
    @State private var phoneDone = false

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AppLogo(size: .small).padding(.top, Theme.Spacing.md)
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        VStack(spacing: Theme.Spacing.sm) {
                            Text(t("otp.contact.title")).font(Theme.display(.largeTitle))
                                .multilineTextAlignment(.center)
                            Text(t("otp.contact.intro"))
                                .font(Theme.body(.subheadline))
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        if let model {
                            if model.saved {
                                afterSave
                            } else {
                                form(model)
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goToPin) { PinSetupView() }
        .task {
            if model == nil {
                let m = ContactDetailsModel(profiles: environment.profileService)
                model = m
                await m.load()
            }
        }
    }

    @ViewBuilder
    private func form(_ model: ContactDetailsModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 20) {
            BrandTextField(label: t("otp.contact.email"), text: $model.email,
                           error: model.errors[.email].map { t($0) },
                           contentType: .emailAddress, keyboard: .emailAddress, autocapitalization: .never)
            BrandTextField(label: t("otp.contact.phone"), text: $model.telefon,
                           error: model.errors[.telefon].map { t($0) },
                           contentType: .telephoneNumber, keyboard: .phonePad)
            AddressField(label: t("otp.contact.address"), text: $model.adresse,
                         error: model.errors[.adresse].map { t($0) }, tone: .onGreen) { model.apply($0) }
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                BrandTextField(label: t("otp.contact.postalCode"),
                               text: Binding(get: { model.postnr }, set: { model.postnr = String($0.filter(\.isNumber).prefix(4)) }),
                               error: model.errors[.postnr].map { t($0) },
                               contentType: .postalCode, keyboard: .numberPad)
                    .frame(width: 112)
                BrandTextField(label: t("otp.contact.city"), text: $model.by,
                               error: model.errors[.by].map { t($0) },
                               contentType: .addressCity, autocapitalization: .words)
            }
            .onChange(of: model.postnr) { _, new in model.postalCodeChanged(new) }

            Button(model.saving ? t("otp.contact.saving") : t("otp.contact.save")) {
                Task { await model.save() }
            }
            .buttonStyle(.brandPrimary)
            .disabled(model.saving)

            if let error = model.formError {
                Text(t(error)).font(Theme.body(.subheadline)).multilineTextAlignment(.center)
            }
        }
    }

    /// Phone code first, then email, then the PIN; "skip for now" at any point.
    private var afterSave: some View {
        VStack(spacing: Theme.Spacing.lg) {
            OtpSection(kind: .phone, tone: .dark, initialDestination: model?.telefon ?? "") { phoneDone = true }
            if phoneDone {
                OtpSection(kind: .email, tone: .dark, initialDestination: model?.email ?? "") { goToPin = true }
            }
            Button(t("otp.otp.skip")) { goToPin = true }
                .buttonStyle(.brandLink)
        }
    }
}
