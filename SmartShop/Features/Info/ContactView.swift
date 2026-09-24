//
//  ContactView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/kontakt.tsx`.
struct ContactView: View {
    @Environment(\.strings) private var t
    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var environment

    var onBack: () -> Void
    /// Signed-in users get a third card that jumps to Find store; guests do not.
    var onFindStore: (() -> Void)? = nil

    @State private var form = ContactFormModel()

    var body: some View {
        AppPageLayout(title: t("contact.title"), description: t("contact.description")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            VStack(spacing: 12) {
                InfoRow(systemImage: "envelope", title: t("contact.writeTitle"),
                        subtitle: "info@smartshop24-7.dk") {
                    if let url = URL(string: "mailto:info@smartshop24-7.dk") { openURL(url) }
                }
                InfoRow(systemImage: "phone", title: t("contact.callTitle"),
                        subtitle: "+45 70 22 03 60") {
                    if let url = URL(string: "tel:+4570220360") { openURL(url) }
                }
                if let onFindStore {
                    InfoRow(systemImage: "mappin.and.ellipse", title: t("contact.storeTitle"),
                            subtitle: t("contact.storeSub"), action: onFindStore)
                }
            }

            formCard
                .padding(.top, Theme.Spacing.lg)

            Text(t("contact.note"))
                .font(Theme.body(.subheadline))
                .lineSpacing(3)
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .padding(.top, Theme.Spacing.lg)
        }
    }
}

private extension ContactView {
    /// The form, replacing a `mailto:` link that left the app and lost anyone
    /// without a configured mail client.
    @ViewBuilder
    var formCard: some View {
        GuestCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("contact.form.title"))
                    .font(Theme.display(.title2, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)

                if form.sent {
                    // Shown whether or not the mail actually left the building.
                    // The message is stored either way, and "it failed" would
                    // only invite someone to send it twice.
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Colors.lime)
                        Text(t("contact.form.sent"))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green)
                    }
                } else {
                    BrandTextField(label: t("contact.form.name"), text: $form.name,
                                   error: form.errors[.name].map { t($0) },
                                   contentType: .name, autocapitalization: .words, tone: .onLight)
                    BrandTextField(label: t("common.email"), text: $form.email,
                                   error: form.errors[.email].map { t($0) },
                                   contentType: .emailAddress, keyboard: .emailAddress,
                                   autocapitalization: .never, tone: .onLight)
                    BrandTextField(label: t("contact.form.subject"), text: $form.subject,
                                   error: form.errors[.subject].map { t($0) }, tone: .onLight)
                    BrandTextField(label: t("contact.form.message"), text: $form.body,
                                   error: form.errors[.body].map { t($0) }, tone: .onLight)

                    Button(form.sending ? t("contact.form.sending") : t("contact.form.send")) {
                        Task { await form.send(using: environment.contactService) }
                    }
                    .buttonStyle(LeaveGuestButtonStyle())
                    .disabled(form.sending)
                    .opacity(form.sending ? 0.6 : 1)

                    if let error = form.formError {
                        Text(t(error))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.red)
                    }
                }
            }
        }
    }
}

/// State and validation for the contact form.
@MainActor
@Observable
final class ContactFormModel {
    enum Field: Hashable { case name, email, subject, body }

    var name = ""
    var email = ""
    var subject = ""
    var body = ""
    var errors: [Field: String] = [:]
    var formError: String?
    var sending = false
    var sent = false

    func send(using contact: any ContactService) async {
        formError = nil
        var next: [Field: String] = [:]
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if trim(name).isEmpty { next[.name] = "contact.form.errors.name" }
        if !trim(email).isValidEmail { next[.email] = "contact.form.errors.email" }
        if trim(subject).isEmpty { next[.subject] = "contact.form.errors.subject" }
        if trim(body).isEmpty { next[.body] = "contact.form.errors.message" }
        errors = next
        guard next.isEmpty else { return }

        sending = true
        defer { sending = false }
        do {
            // `delivered == false` means stored but not mailed. Deliberately
            // not surfaced: the customer has done their part either way.
            try await contact.send(
                ContactMessage(
                    name: trim(name), email: trim(email),
                    subject: trim(subject), body: trim(body)
                )
            )
            sent = true
        } catch {
            formError = "contact.form.errors.generic"
        }
    }
}

/// Lime row with a green oval icon, title and subtitle — the list item used on
/// Contact and the More page.
struct InfoRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    var showsChevron = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                OvalIcon(systemName: systemImage, size: CGSize(width: 56, height: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.display(.title3, weight: .bold))
                        .foregroundStyle(Theme.Colors.green)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.green.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
