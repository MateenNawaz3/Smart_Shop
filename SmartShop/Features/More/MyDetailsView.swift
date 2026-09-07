//
//  MyDetailsView.swift
//  SmartShop
//

import SwiftUI

/// Personal details and password change. Port of
/// `routes/_authenticated/mere_.oplysninger.tsx` and `ProfileDetailsForm.tsx`.
///
struct MyDetailsView: View {
    @Binding var path: [MoreRoute]

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var model = DetailsModel()
    @State private var verification = VerificationInfo()
    @State private var verificationLoaded = false
    var onVerify: () -> Void = {}

    var body: some View {
        AppPageLayout(title: t("more.details.title")) {
            GuestBackLink(title: t("more.details.backToMore")) { path.removeAll() }
        } content: {
            if !model.loaded {
                Text(t("more.profileForm.loading"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
            } else {
                ProfileDetailsForm(model: model)
                verificationCard.padding(.top, Theme.Spacing.lg)
                if verificationLoaded {
                    OtpSection(kind: .phone, initialDestination: verification.phone, alreadyVerified: verification.phoneVerified)
                        .padding(.top, Theme.Spacing.lg)
                    OtpSection(kind: .email, initialDestination: verification.email, alreadyVerified: verification.emailVerified)
                        .padding(.top, Theme.Spacing.lg)
                }
                KeyFobSection().padding(.top, Theme.Spacing.lg)
                changePassword
                    .padding(.top, Theme.Spacing.lg)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            model.profiles = environment.profileService
            model.auth = environment.authService
            await model.load()
            if let info = try? await environment.verificationService.info() { verification = info }
            verificationLoaded = true
        }
    }

    private var verificationCard: some View {
        GuestCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text(t("verify.verify.title"))
                        .font(Theme.display(.title2, weight: .bold))
                        .foregroundStyle(Theme.Colors.green)
                    Spacer()
                    VerificationStatusBadge(status: verification.status, method: verification.method)
                }
                if verification.status != .verified {
                    Button("\(t("verify.verify.mitidTitle")) / \(t("verify.verify.passport")) / \(t("verify.verify.driversLicense"))", action: onVerify)
                        .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                }
            }
        }
    }

    private var changePassword: some View {
        GuestCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(t("more.details.changePassword"))
                    .font(Theme.display(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)

                BrandTextField(
                    label: t("more.details.newPassword"), text: $model.password,
                    error: model.passwordErrors.password.map { t($0) },
                    isSecure: true, contentType: .newPassword, tone: .onLight
                )
                BrandTextField(
                    label: t("more.details.repeatPassword"), text: $model.confirm,
                    error: model.passwordErrors.confirm.map { t($0) },
                    isSecure: true, contentType: .newPassword, tone: .onLight
                )

                Button(model.passwordSaving ? t("more.details.saving") : t("more.details.savePassword")) {
                    Task { await model.savePassword() }
                }
                .buttonStyle(LeaveGuestButtonStyle())
                .disabled(model.passwordSaving)
                .opacity(model.passwordSaving ? 0.6 : 1)

                statusLine(ok: model.passwordMessage.map { t($0) }, error: model.passwordError.map { t($0) })
            }
        }
    }

    @ViewBuilder
    private func statusLine(ok: String?, error: String?) -> some View {
        if let ok {
            Text(ok).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
                .frame(maxWidth: .infinity)
        }
        if let error {
            Text(error).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red)
                .frame(maxWidth: .infinity)
        }
    }
}

/// The "Personal details" card: fields, address lookup, marketing consent, save.
struct ProfileDetailsForm: View {
    @Bindable var model: DetailsModel
    var title: String? = nil

    @Environment(\.strings) private var t

    var body: some View {
        GuestCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(title ?? t("more.profileForm.title"))
                    .font(Theme.display(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)

                field("more.profileForm.firstName", \.fornavn, .firstName, content: .givenName, caps: .words)
                field("more.profileForm.lastName", \.efternavn, .lastName, content: .familyName, caps: .words)
                field("more.profileForm.phone", \.telefon, .telefon, content: .telephoneNumber, keyboard: .phonePad)

                AddressField(
                    label: t("more.profileForm.address"),
                    text: $model.details.adresse,
                    error: model.errors[.adresse].map { t($0) }
                ) { suggestion in
                    model.apply(suggestion)
                }

                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    field("more.profileForm.postalCode", \.postnr, .postnr, content: .postalCode, keyboard: .numberPad)
                        .frame(width: 112)
                    field("more.profileForm.city", \.by, .by, content: .addressCity, caps: .words)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    BrandTextField(
                        label: t("more.profileForm.email"), text: .constant(model.details.email),
                        contentType: .emailAddress, keyboard: .emailAddress,
                        autocapitalization: .never, tone: .onLight, isDisabled: true
                    )
                    Text(t("more.profileForm.emailNote"))
                        .font(Theme.body(.caption))
                        .foregroundStyle(Theme.Colors.green.opacity(0.6))
                }

                Toggle(isOn: $model.details.markedsforing) {
                    Text(t("more.profileForm.marketingLabel"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.green.opacity(0.8))
                }
                .toggleStyle(CheckboxToggleStyle())

                Button(model.saving ? t("more.profileForm.saving") : t("more.profileForm.saveChanges")) {
                    Task { await model.save() }
                }
                .buttonStyle(WidePillButtonStyle())
                .disabled(model.saving)
                .opacity(model.saving ? 0.6 : 1)

                if let ok = model.savedMessage {
                    Text(t(ok)).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
                        .frame(maxWidth: .infinity)
                }
                if let error = model.saveError {
                    Text(t(error)).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: model.details.postnr) { _, new in model.postalCodeChanged(new) }
        .onChange(of: model.details.by) { _, new in model.cityChanged(new) }
    }

    private func field(
        _ label: String, _ keyPath: WritableKeyPath<ProfileDetails, String>, _ key: DetailsModel.Field,
        content: UITextContentType? = nil, keyboard: UIKeyboardType = .default,
        caps: TextInputAutocapitalization = .sentences
    ) -> some View {
        BrandTextField(
            label: t(label),
            text: Binding(get: { model.details[keyPath: keyPath] }, set: { model.set(keyPath, $0) }),
            error: model.errors[key].map { t($0) },
            contentType: content, keyboard: keyboard, autocapitalization: caps, tone: .onLight
        )
    }
}

/// Square lime checkbox, the web's `accent-brand-lime` checkbox.
struct CheckboxToggleStyle: ToggleStyle {
    /// On the green auth canvas the box border is white instead of green.
    var onGreen = false

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isOn ? Theme.Colors.lime : .white)
                    .strokeBorder(onGreen ? .white.opacity(0.4) : Theme.Colors.green.opacity(0.3), lineWidth: 1)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                configuration.label
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// Address field with DAWA suggestions under it. Port of `AddressAutocomplete.tsx`.
struct AddressField: View {
    let label: String
    @Binding var text: String
    var error: String?
    var placeholder: String = ""
    var tone: BrandTextField.Tone = .onLight
    var onSelect: (DanishAddressService.Suggestion) -> Void

    @State private var suggestions: [DanishAddressService.Suggestion] = []
    @State private var skipNext = false
    @State private var lookup: Task<Void, Never>?

    private let service = DanishAddressService()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BrandTextField(
                label: label, placeholder: placeholder, text: $text, error: error,
                contentType: .streetAddressLine1, autocapitalization: .words, tone: tone
            )
            .autocorrectionDisabled()

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { s in
                        Button {
                            skipNext = true
                            suggestions = []
                            onSelect(s)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.street).font(Theme.body(.subheadline, weight: .medium))
                                Text("\(s.postalCode) \(s.city)").font(Theme.body(.caption))
                                    .foregroundStyle(Theme.Colors.ink.opacity(0.7))
                            }
                            .foregroundStyle(Theme.Colors.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(.white, in: .rect(cornerRadius: Theme.Radius.field))
                .overlay { RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.green.opacity(0.15)) }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            }
        }
        .onChange(of: text) { _, new in
            lookup?.cancel()
            if skipNext { skipNext = false; suggestions = []; return }
            guard new.trimmingCharacters(in: .whitespaces).count >= 3 else { suggestions = []; return }
            lookup = Task {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                let found = await service.suggestions(for: new)
                guard !Task.isCancelled else { return }
                suggestions = found
            }
        }
    }
}

/// State and validation for the details page. Port of the hooks in
/// `ProfileDetailsForm.tsx` and the password form in `mere_.oplysninger.tsx`.
@MainActor
@Observable
final class DetailsModel {
    enum Field: Hashable { case firstName, lastName, telefon, adresse, postnr, by }
    struct PasswordErrors { var password: String?; var confirm: String? }

    var profiles: (any ProfileService)?
    var auth: (any AuthService)?

    var details = ProfileDetails()
    var loaded = false
    var errors: [Field: String] = [:]
    var saving = false
    var savedMessage: String?
    var saveError: String?

    var password = ""
    var confirm = ""
    var passwordErrors = PasswordErrors()
    var passwordSaving = false
    var passwordMessage: String?
    var passwordError: String?

    private let addresses = DanishAddressService()
    private var postalTask: Task<Void, Never>?
    private var cityTask: Task<Void, Never>?

    func load() async {
        if let d = try? await profiles?.details() { details = d }
        loaded = true
    }

    func set(_ keyPath: WritableKeyPath<ProfileDetails, String>, _ value: String) {
        var v = value
        // The web strips non-digits from the postcode and non-letters from the town.
        if keyPath == \.postnr { v = String(v.filter(\.isNumber).prefix(4)) }
        if keyPath == \.by { v = v.filter { $0.isLetter || $0.isWhitespace || $0 == "'" || $0 == "-" } }
        details[keyPath: keyPath] = v
        savedMessage = nil
    }

    func apply(_ s: DanishAddressService.Suggestion) {
        details.adresse = s.street
        details.postnr = s.postalCode
        details.by = s.city
        savedMessage = nil
    }

    /// Four-digit postcode fills in the town.
    func postalCodeChanged(_ code: String) {
        postalTask?.cancel()
        guard code.count == 4 else { return }
        postalTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let city = await addresses.city(forPostalCode: code), !Task.isCancelled else { return }
            details.by = city
        }
    }

    /// A town name fills in the postcode when there is exactly one match.
    func cityChanged(_ name: String) {
        cityTask?.cancel()
        guard name.count >= 3, details.postnr.count != 4 else { return }
        cityTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let match = await addresses.postalCode(forCity: name), !Task.isCancelled else { return }
            details.postnr = match.code
            details.by = match.city
        }
    }

    func save() async {
        saveError = nil
        savedMessage = nil
        var next: [Field: String] = [:]
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        if trim(details.fornavn).isEmpty { next[.firstName] = "more.profileForm.errors.firstName" }
        if trim(details.efternavn).isEmpty { next[.lastName] = "more.profileForm.errors.lastName" }
        if trim(details.adresse).isEmpty { next[.adresse] = "more.profileForm.errors.address" }
        if !(trim(details.postnr).count == 4 && trim(details.postnr).allSatisfy(\.isNumber)) {
            next[.postnr] = "more.profileForm.errors.postalCode"
        }
        if trim(details.by).isEmpty { next[.by] = "more.profileForm.errors.city" }
        let phone = details.telefon.filter { !$0.isWhitespace && $0 != "-" }
        if phone.isEmpty { next[.telefon] = "more.profileForm.errors.phoneRequired" }
        else if phone.wholeMatch(of: /(\+45)?\d{8}/) == nil { next[.telefon] = "more.profileForm.errors.phoneInvalid" }
        errors = next
        guard next.isEmpty, let profiles else { return }

        saving = true
        do {
            try await profiles.update(details)
            savedMessage = "more.profileForm.savedMessage"
        } catch {
            saveError = "more.profileForm.saveError"
        }
        saving = false
    }

    func savePassword() async {
        passwordError = nil
        passwordMessage = nil
        var next = PasswordErrors()
        if password.isEmpty { next.password = "more.details.errors.enterNewPassword" }
        else if password.count < 8 { next.password = "more.details.errors.passwordTooShort" }
        if confirm.isEmpty { next.confirm = "more.details.errors.repeatPassword" }
        else if confirm != password { next.confirm = "more.details.errors.passwordsDontMatch" }
        passwordErrors = next
        guard next.password == nil, next.confirm == nil, let auth else { return }

        passwordSaving = true
        do {
            try await auth.updatePassword(password)
            password = ""
            confirm = ""
            passwordMessage = "more.details.passwordUpdated"
        } catch {
            let text = error.localizedDescription.lowercased()
            passwordError = text.contains("pwned") || text.contains("weak")
                ? "more.details.errors.passwordWeak"
                : "more.details.errors.passwordUpdateFailed"
        }
        passwordSaving = false
    }
}
