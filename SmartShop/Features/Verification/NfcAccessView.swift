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
    private enum Phase: Equatable { case scanning(Point), ok(Point), denied }

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
                            Text(entry.point == "doer" ? t("verify.nfc.pointDoor") : t("verify.nfc.pointCheckout"))
                                .font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green)
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
            case .ok(let point):
                Image(systemName: point == .door ? "door.left.hand.open" : "barcode.viewfinder").font(.system(size: 44)).foregroundStyle(Theme.Colors.lime)
                Text(point == .door ? t("verify.nfc.doorOk") : t("verify.nfc.checkoutOk"))
                    .font(Theme.display(.title2)).foregroundStyle(.white).multilineTextAlignment(.center)
                Button(t("verify.nfc.again")) { self.phase = nil }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.lime))
                    .padding(.top, 8)
            case .denied:
                Image(systemName: "xmark.shield").font(.system(size: 44)).foregroundStyle(Theme.Colors.red)
                Text(t("verify.nfc.denied")).font(Theme.display(.title2)).foregroundStyle(Theme.Colors.green)
                Text(t("verify.nfc.deniedReason")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                Button(t("verify.nfc.verifyCta"), action: onVerify)
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
                    .padding(.top, 8)
                Button(t("verify.nfc.again")) { self.phase = nil }
                    .font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(Theme.Colors.green).underline()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32).padding(.horizontal, 20)
        .background(phase == .denied ? Theme.Colors.red.opacity(0.1) : Theme.Colors.green, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func tap(_ point: Point) async {
        phase = .scanning(point)
        async let ok = (try? environment.verificationService.logNfcAccess(point: point.rawValue, storeSlug: store?.slug)) ?? false
        try? await Task.sleep(for: .seconds(1.2))
        phase = await ok ? .ok(point) : .denied
        log = (try? await environment.verificationService.recentNfcAccess()) ?? []
    }
}
