//
//  VerificationView.swift
//  SmartShop
//

import SwiftUI

/// Identity verification: status, MitID card, document upload, phone and email codes.
/// Port of `routes/_authenticated/verificering.tsx`.
struct VerificationView: View {
    var onBack: () -> Void
    var onDone: () -> Void

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(DeviceState.self) private var device
    @Environment(AuthSessionStore.self) private var session

    @State private var info = VerificationInfo()
    @State private var loaded = false
    @State private var showsMitID = false

    var body: some View {
        AppPageLayout(title: t("verify.verify.title"), description: t("verify.verify.intro")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            HStack(spacing: 12) {
                Text("\(t("verify.verify.statusLabel")):").font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                VerificationStatusBadge(status: info.status, method: info.method)
            }
            .padding(.bottom, Theme.Spacing.md)

            if info.status == .verified {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Colors.green)
                        Text(t("verify.verify.done")).font(Theme.display(.body, weight: .bold)).foregroundStyle(Theme.Colors.green)
                    }
                    Button(t("verify.verify.continueApp"), action: onDone)
                        .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                }
                .padding(20)
                .background(Theme.Colors.lime.opacity(0.15), in: .rect(cornerRadius: Theme.Radius.card))
            } else if loaded {
                VStack(spacing: 20) {
                    mitIDCard
                    IdVerificationForm { Task { await reload() } }
                    OtpSection(kind: .phone, initialDestination: info.phone, alreadyVerified: info.phoneVerified)
                    OtpSection(kind: .email, initialDestination: info.email, alreadyVerified: info.emailVerified)
                    Button(t("verify.verify.skip"), action: onDone)
                        .font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green).underline()
                }
            }
        }
        .task { await reload() }
        .fullScreenCover(isPresented: $showsMitID) {
            NavigationStack {
                MitIDView(mitID: environment.mitIDService, auth: environment.authService, device: device, session: session)
            }
            .tint(.white)
        }
    }

    private var mitIDCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                OvalIcon(systemName: "checkmark.shield", background: Theme.Colors.lime, size: CGSize(width: 56, height: 44))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("verify.verify.mitidTitle")).font(Theme.display(.title2, weight: .bold)).foregroundStyle(.white)
                    Text(t("verify.verify.mitidSub")).font(Theme.body(.subheadline)).foregroundStyle(.white.opacity(0.75))
                }
            }
            Button(t("verify.verify.mitidCta")) { showsMitID = true }
                .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
        }
        .padding(20)
        .background(Theme.Colors.green, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func reload() async {
        if let i = try? await environment.verificationService.info() { info = i }
        loaded = true
    }
}

/// Save or change the number of a physical key fob. Port of `KeyFobSection.tsx`.
struct KeyFobSection: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var value = ""
    @State private var saving = false
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                OvalIcon(systemName: "key", size: CGSize(width: 56, height: 44))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("verify.keyFob.title")).font(Theme.display(.title2, weight: .bold)).foregroundStyle(Theme.Colors.green)
                    Text(t("verify.keyFob.intro")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                }
            }
            BrandTextField(label: t("verify.keyFob.label"), placeholder: t("verify.keyFob.placeholder"),
                           text: Binding(get: { value }, set: { value = $0; message = nil }),
                           error: error, autocapitalization: .never, tone: .onLight)
            HStack(spacing: 12) {
                Button(saving ? t("verify.keyFob.saving") : t("verify.keyFob.save")) { Task { await save(value) } }
                    .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                    .disabled(saving)
                if !value.isEmpty {
                    Button(t("verify.keyFob.remove")) { Task { await save("") } }
                        .buttonStyle(LeaveGuestButtonStyle())
                        .frame(width: 130)
                        .disabled(saving)
                }
            }
            if let message {
                Text(message).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green).frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
        .task { if let i = try? await environment.verificationService.info() { value = i.keyFob } }
    }

    private func save(_ next: String) async {
        error = nil
        message = nil
        let trimmed = next.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed.wholeMatch(of: /[A-Za-z0-9-]{3,32}/) == nil {
            error = t("verify.keyFob.errors.invalid")
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await environment.verificationService.saveKeyFob(trimmed.isEmpty ? nil : trimmed)
            value = trimmed
            message = t("verify.keyFob.saved")
        } catch {
            self.error = t("verify.keyFob.errors.generic")
        }
    }
}
