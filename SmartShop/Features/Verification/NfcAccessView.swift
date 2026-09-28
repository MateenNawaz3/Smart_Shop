//
//  NfcAccessView.swift
//  SmartShop
//

import SwiftUI

/// Simulated NFC door and checkout. Port of `routes/_authenticated/adgang.tsx`.
struct NfcAccessView: View {
    var onBack: () -> Void
    var onVerify: () -> Void

    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages
    @Environment(AppEnvironment.self) private var environment

    private enum Point: String { case door = "doer", checkout = "kasse" }
    /// `message` is the server's sentence, which replaces the app's copy.
    private enum Phase: Equatable { case scanning(Point), ok(Point, doorOpened: Bool, message: String?), denied(message: String?, reason: String?) }

    @State private var info = VerificationInfo()
    @State private var store: Store?
    @State private var log: [NfcAccessEntry] = []
    @State private var phase: Phase?

    var body: some View {
        AppPageLayout(title: t("verify.nfc.title"), description: t("verify.nfc.intro")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            HStack(spacing: 12) {
                VerificationStatusBadge(status: info.status, method: info.method)
                if let store {
                    Text("\(t("verify.nfc.storeLabel")): ").font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                    + Text(store.name).font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                }
            }
            .padding(.bottom, 20)

            if let phase {
                result(phase)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    reader(.door, icon: "door.left.hand.open", title: t("verify.nfc.doorTitle"), sub: t("verify.nfc.doorSub"))
                    reader(.checkout, icon: "barcode.viewfinder", title: t("verify.nfc.checkoutTitle"), sub: t("verify.nfc.checkoutSub"))
                }
            }

            DemoNote(badge: t("verify.nfc.demoBadge"), text: t("verify.nfc.demoNote"))
                .padding(.top, 20)

            Text(t("verify.nfc.recent"))
                .font(Theme.display(.subheadline, weight: .bold)).textCase(.uppercase).tracking(0.8)
                .foregroundStyle(Theme.Colors.green.opacity(0.6))
                .padding(.top, 32).padding(.bottom, 12)
            if log.isEmpty {
                Text(t("verify.nfc.noRecent")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.6))
            } else {
                VStack(spacing: 8) {
                    ForEach(log) { entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.point == "doer" ? t("verify.nfc.pointDoor") : t("verify.nfc.pointCheckout"))
                                    .font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
                                if let storeName = entry.storeName {
                                    Text(storeName).font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.6))
                                }
                            }
                            Spacer()
                            Text(entry.at.formatted(Date.FormatStyle(date: .numeric, time: .shortened).locale(languages.language.locale)))
                                .font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.6))
                            Text(entry.approved ? t("verify.nfc.resultOk") : t("verify.nfc.resultDenied"))
                                .font(Theme.body(.subheadline, weight: .semibold))
                                .foregroundStyle(entry.approved ? Theme.Colors.green : Theme.Colors.red)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.field))
                    }
                }
            }
        }
        .task {
            if let i = try? await environment.verificationService.info() { info = i }
            if let p = try? await environment.profileService.storeProfile() { store = p.favoriteStore.flatMap(Store.named) }
            log = (try? await environment.verificationService.recentNfcAccess()) ?? []
        }
    }

    private func reader(_ point: Point, icon: String, title: String, sub: String) -> some View {
        Button { Task { await tap(point) } } label: {
            VStack(spacing: 10) {
                OvalIcon(systemName: icon, size: CGSize(width: 80, height: 56))
                Text(title).font(Theme.display(.title3, weight: .bold)).foregroundStyle(Theme.Colors.green)
                Text(sub).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                Label(t("verify.nfc.tap"), systemImage: "iphone")
                    .font(Theme.body(.caption, weight: .semibold)).foregroundStyle(Theme.Colors.green.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28).padding(.horizontal, 20)
            .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    @ViewBuilder
    private func result(_ phase: Phase) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            switch phase {
            case .scanning:
                Image(systemName: "wave.3.right").font(.system(size: 44)).foregroundStyle(Theme.Colors.lime)
                    .symbolEffect(.pulse)
                Text(t("verify.nfc.scanning")).font(Theme.display(.title2)).foregroundStyle(.white)
            case .ok(let point, let doorOpened, let message):
                Image(systemName: point == .door ? "door.left.hand.open" : "barcode.viewfinder").font(.system(size: 44)).foregroundStyle(Theme.Colors.lime)
                // A grant is not an open door: never say "the door is open"
                // when no door moved.
                Text(point == .checkout ? t("verify.nfc.checkoutOk") : doorOpened ? t("verify.nfc.doorOk") : t("verify.nfc.doorSilent"))
                    .font(Theme.display(.title2)).foregroundStyle(.white).multilineTextAlignment(.center)
                if let message {
                    Text(message).font(Theme.body(.subheadline)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                }
                Button(t("verify.nfc.again")) { self.phase = nil }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.lime))
                    .padding(.top, 8)
            case .denied(let message, let reason):
                Image(systemName: "xmark.shield").font(.system(size: 44)).foregroundStyle(Theme.Colors.red)
                Text(t("verify.nfc.denied")).font(Theme.display(.title2)).foregroundStyle(Theme.Colors.green)
                Text(message ?? t("verify.nfc.deniedReason"))
                    .font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7)).multilineTextAlignment(.center)
                // Verifying only helps when that is why the door said no.
                if reason == nil || reason == "not_verified" {
                    Button(t("verify.nfc.verifyCta"), action: onVerify)
                        .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
                        .padding(.top, 8)
                }
                Button(t("verify.nfc.again")) { self.phase = nil }
                    .font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green).underline()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32).padding(.horizontal, 20)
        .background(isDenied(phase) ? Theme.Colors.red.opacity(0.1) : Theme.Colors.green, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func isDenied(_ phase: Phase) -> Bool {
        if case .denied = phase { true } else { false }
    }

    private func tap(_ point: Point) async {
        phase = .scanning(point)
        async let answer = (try? environment.verificationService.logNfcAccess(point: point.rawValue, storeSlug: store?.slug))
            ?? NfcAccessResult(approved: false)
        try? await Task.sleep(for: .seconds(1.2))
        let result = await answer
        phase = result.approved
            ? .ok(point, doorOpened: result.doorOpened, message: result.message)
            : .denied(message: result.message, reason: result.reason)
        log = (try? await environment.verificationService.recentNfcAccess()) ?? []
    }
}
