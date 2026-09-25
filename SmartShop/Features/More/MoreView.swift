//
//  MoreView.swift
//  SmartShop
//

import SwiftUI

/// The More tab: profile card, account links, about, help, sign out.
/// Port of `routes/_authenticated/mere.tsx`.
struct MoreView: View {
    @Binding var path: [MoreRoute]

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(AuthSessionStore.self) private var session

    @State private var profile: ProfileSummary?
    @State private var showsDelete = false
    @State private var showsGuide = false

    var body: some View {
        AppPageLayout(title: t("more.title"), firstName: firstName) {
            profileCard

            sectionHeading(t("more.myAccount"))
            VStack(spacing: 12) {
                row("doc.text", "receipts.more.title", "receipts.more.sub") { path.append(.receipts) }
                row("person", "more.details", "more.detailsSub") { path.append(.details) }
                row("heart", "more.favorites", "more.favoritesSub") { path.append(.favorites) }
                row("checkmark.seal", "verify.more.verifyTitle", "verify.more.verifySub") { path.append(.verification) }
                row("wave.3.right", "verify.more.accessTitle", "verify.more.accessSub") { path.append(.access) }
                row("bell", "more.notifications", "more.notificationsSub") { path.append(.notifications) }
                row("globe", "language.title", "more.languageSub") { path.append(.language) }
            }

            sectionHeading(t("more.aboutSection"))
            VStack(spacing: 12) {
                comingSoon("storefront", "more.concept", "more.conceptSub")
                comingSoon("book", "more.howto", "more.howtoSub")
                row("info.circle", "more.about", "more.aboutSub") { path.append(.about) }
                comingSoon("key", "more.keys", "more.keysSub")
                row("envelope", "more.contact", "more.contactSub") { path.append(.contact) }
            }

            sectionHeading(t("more.help"))
            VStack(spacing: 12) {
                row("questionmark.circle", "more.faq", "more.faqSub") { path.append(.faq) }
                row("sparkles", "more.guide", "more.guideSub") { showsGuide = true }
            }

            Button(t("more.signOut")) { Task { await session.signOut() } }
                .buttonStyle(LeaveGuestButtonStyle())
                .padding(.top, 32)

            Button(t("more.deleteAccount")) { showsDelete = true }
                .font(Theme.body(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.Colors.red)
                .underline()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.md + 4)
        }
        .sheet(isPresented: $showsDelete) { DeleteAccountSheet() }
        .fullScreenCover(isPresented: $showsGuide) { OnboardingView { showsGuide = false } }
        .task { profile = await environment.profileService.summary() }
    }

    private var firstName: String? {
        let name = profile?.fornavn ?? ""
        return name.isEmpty ? nil : name
    }

    private var fullName: String {
        [profile?.fornavn, profile?.efternavn].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var initials: String {
        let letters = [profile?.fornavn, profile?.efternavn].compactMap { $0?.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    /// Green card with the initials oval, name, email and town.
    private var profileCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(initials)
                .font(Theme.display(.title3, weight: .heavy))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(8))
                .frame(width: 64, height: 48)
                .background(Theme.Colors.lime, in: .ellipse)
            VStack(alignment: .leading, spacing: 2) {
                Text(fullName.isEmpty ? t("more.accountFallback") : fullName)
                    .font(Theme.display(.title3, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let email = profile?.email, !email.isEmpty {
                    Text(email).font(Theme.body(.subheadline)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                }
                if let by = profile?.by, !by.isEmpty {
                    Text(by).font(Theme.body(.subheadline)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Theme.Colors.green, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(Theme.display(.subheadline, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.Colors.green.opacity(0.6))
            .padding(.top, 28)
            .padding(.bottom, 12)
    }

    private func row(_ icon: String, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        InfoRow(systemImage: icon, title: t(title), subtitle: t(sub), showsChevron: true, action: action)
    }

    /// Dimmed row with a "coming soon" pill, for features the web also stubs.
    private func comingSoon(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            OvalIcon(systemName: icon, size: CGSize(width: 56, height: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text(t(title))
                    .font(Theme.display(.title3, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)
                Text(t(sub))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
                Text(t("more.comingSoon"))
                    .font(Theme.body(.caption2, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.Colors.green.opacity(0.1), in: .capsule)
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
        .opacity(0.8)
    }
}

/// Bottom sheet for asking to have the account deleted.
/// Port of `components/app/DeleteAccountDialog.tsx`.
///
/// The web's `mailto:` link produced no record at all; the Mobile API records
/// the request (`POST /me/deletion-request`) for a person to action. The
/// address stays as the way out when the request cannot be sent, so this sheet
/// never leaves someone with nowhere to go.
struct DeleteAccountSheet: View {
    @Environment(\.strings) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var environment

    private enum Phase { case idle, sending, sent, failed }
    @State private var phase: Phase = .idle

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: phase == .sent ? "checkmark" : "exclamationmark.triangle")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(phase == .sent ? Theme.Colors.green : Theme.Colors.red)
                .frame(width: 56, height: 56)
                .background((phase == .sent ? Theme.Colors.lime : Theme.Colors.red).opacity(0.1), in: .circle)

            Text(t("more.deleteAccount.title"))
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.top, Theme.Spacing.md)

            VStack(spacing: 4) {
                switch phase {
                case .idle, .sending:
                    Text(t("more.deleteAccount.requestDescription"))
                case .sent:
                    Text(t("more.deleteAccount.sent"))
                case .failed:
                    Text(t("more.deleteAccount.failed"))
                    Button("info@smartshop24-7.dk") {
                        if let url = URL(string: "mailto:info@smartshop24-7.dk?subject=Sletning%20af%20konto") { openURL(url) }
                    }
                    .buttonStyle(.plain)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.green)
                    .underline()
                }
            }
            .font(Theme.body(.subheadline))
            .foregroundStyle(Theme.Colors.ink.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.top, Theme.Spacing.sm)

            if phase == .idle || phase == .sending {
                Button(phase == .sending ? t("more.deleteAccount.sending") : t("more.deleteAccount.request")) {
                    Task { await send() }
                }
                .buttonStyle(WidePillButtonStyle(background: Theme.Colors.red))
                .disabled(phase == .sending)
                .padding(.top, Theme.Spacing.lg)
            }

            Button(t("more.deleteAccount.close")) { dismiss() }
                .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                .padding(.top, phase == .idle || phase == .sending ? Theme.Spacing.sm : Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.card)
        .presentationBackground(.white)
    }

    private func send() async {
        phase = .sending
        do {
            try await environment.profileService.requestDeletion(reason: nil)
            phase = .sent
        } catch {
            phase = .failed
        }
    }
}

