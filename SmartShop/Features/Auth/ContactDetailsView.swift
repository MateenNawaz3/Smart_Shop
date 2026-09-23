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
    enum Field: Hashable { case fornavn, efternavn, email, telefon, adresse, postnr, by }

    var fornavn = ""
    var efternavn = ""
    var email = ""
    var telefon = ""
    var adresse = ""
    var postnr = ""
    var by = ""
    var errors: [Field: String] = [:]
    var formError: String?
    var saving = false
    var saved = false

    /// What MitID told us, when this screen follows a MitID sign-in.
    ///
    /// Takes precedence over the stored profile because it is fresher, but
    /// every field is optional — see `MitIDProfile`.
    private let mitID: MitIDProfile

    private let profiles: any ProfileService
    private let addresses = DanishAddressService()
    private var postalTask: Task<Void, Never>?

    init(profiles: any ProfileService, mitID: MitIDProfile = MitIDProfile()) {
        self.profiles = profiles
        self.mitID = mitID
    }

    func load() async {
        let details = try? await profiles.details()
        if let details {
            // MitID accounts start with a placeholder address the user must replace.
            email = details.email.hasSuffix("@mitid.local") ? "" : details.email
            telefon = details.telefon
            adresse = details.adresse
            postnr = details.postnr
            by = details.by
            fornavn = details.fornavn
            efternavn = details.efternavn
        }

        // MitID last, so a fresh sign-in overrides anything stale on file —
        // but only where it actually told us something. It never gives an
        // address, and it gives no email at all.
        fornavn = mitID.firstName ?? fornavn
        efternavn = mitID.lastName ?? efternavn
        email = mitID.email ?? email
        telefon = mitID.phone ?? telefon
        adresse = mitID.addressLine1 ?? adresse
        postnr = mitID.postalCode ?? postnr
        by = mitID.city ?? by
    }

    /// The birth date MitID gave us, ready to display, or nil.
    var dateOfBirth: String? { mitID.formattedDateOfBirth }

    /// Translation key for the gender MitID reported, or nil.
    var genderKey: String? { mitID.genderLabelKey }

    /// Whether MitID vouched for the name, which is what makes it read-only.
    ///
    /// A verified name is not ours to let someone overwrite — it is what will
    /// appear on their receipts. But MitID releases **no** name for an identity
    /// under Danish name-and-address protection, and that customer still has to
    /// be able to finish signing up, so the fields stay editable when it told
    /// us nothing.
    var nameIsFromMitID: Bool { (mitID.firstName ?? mitID.lastName) != nil }

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
        if trim(fornavn).isEmpty { next[.fornavn] = "otp.contact.errors.firstName" }
        if trim(efternavn).isEmpty { next[.efternavn] = "otp.contact.errors.lastName" }
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
                fornavn: trim(fornavn), efternavn: trim(efternavn),
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

    @Environment(MitIDSignInCoordinator.self) private var mitIDSignIn

    @State private var model: ContactDetailsModel?
    @State private var goToPin = false
    @State private var phoneDone = false

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AuthHeader().padding(.top, Theme.Spacing.md)
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
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goToPin) { PinSetupView() }
        .task {
            if model == nil {
                // The coordinator holds what MitID released. Empty when this
                // screen is reached any other way, which is the same as
                // "nothing to pre-fill".
                let m = ContactDetailsModel(
                    profiles: environment.profileService,
                    mitID: mitIDSignIn.profile
                )
                model = m
                await m.load()
            }
        }
    }

    @ViewBuilder
    private func form(_ model: ContactDetailsModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 20) {
            // What MitID vouched for is shown but not editable. What it could
            // not tell us stays a normal field, or a name-protected customer
            // would have no way to finish.
            if model.nameIsFromMitID {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    LockedField(label: t("otp.contact.firstName"), value: model.fornavn)
                    LockedField(label: t("otp.contact.lastName"), value: model.efternavn)
                }
            } else {
                Text(t("otp.contact.nameNotGiven"))
                    .font(Theme.body(.footnote))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    BrandTextField(label: t("otp.contact.firstName"), text: $model.fornavn,
                                   error: model.errors[.fornavn].map { t($0) },
                                   contentType: .givenName, autocapitalization: .words)
                    BrandTextField(label: t("otp.contact.lastName"), text: $model.efternavn,
                                   error: model.errors[.efternavn].map { t($0) },
                                   contentType: .familyName, autocapitalization: .words)
                }
            }
            if model.dateOfBirth != nil || model.genderKey != nil {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    if let dateOfBirth = model.dateOfBirth {
                        LockedField(label: t("otp.contact.dateOfBirth"), value: dateOfBirth)
                    }
                    if let genderKey = model.genderKey {
                        LockedField(label: t("otp.contact.gender"), value: t(genderKey))
                    }
                }
            }
            if model.nameIsFromMitID || model.dateOfBirth != nil || model.genderKey != nil {
                Text(t("otp.contact.lockedNote"))
                    .font(Theme.body(.footnote))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

/// A value the customer may read but not change, because something
/// authoritative supplied it.
///
/// Shaped like `BrandTextField` on purpose — it sits in the same column as the
/// editable fields, so it has to read as the same kind of thing, only closed.
private struct LockedField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.body(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: Theme.Spacing.sm) {
                Text(value)
                    .foregroundStyle(Theme.Colors.green)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.green.opacity(0.45))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(height: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.7), in: .rect(cornerRadius: Theme.Radius.field))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
