//
//  LaunchGateView.swift
//  SmartShop
//

import SwiftUI

/// Holds the app at launch when the backend says it should be held.
///
/// Wraps the whole app rather than sitting inside it, because `blocked` and
/// `maintenance` must be unreachable-past: a gate the customer can navigate
/// around is not a gate. `updateAvailable` is the one that lets them by.
///
/// **Failing open is deliberate.** If `/app/config` cannot be reached we show
/// the app. The alternative — a blank screen whenever the network is poor —
/// turns an outage into a total outage, and an out-of-date build that still
/// runs is better than no build at all.
struct LaunchGateView<Content: View>: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.strings) private var t
    @Environment(\.openURL) private var openURL

    @ViewBuilder var content: Content

    @State private var gate: LaunchGate = .open
    @State private var dismissedNudge = false

    var body: some View {
        ZStack {
            switch gate {
            case .blocked(let storeURL):
                stop(
                    title: t("launch.blocked.title"),
                    message: t("launch.blocked.message"),
                    action: storeURL.map { (t("launch.update"), $0) }
                )
            case .maintenance(let message):
                stop(
                    title: t("launch.maintenance.title"),
                    // The server's own words when it has some, since it knows
                    // what is wrong and for how long; ours otherwise.
                    message: message ?? t("launch.maintenance.message"),
                    action: nil
                )
            case .updateAvailable(let storeURL) where !dismissedNudge:
                nudge(storeURL: storeURL)
            case .open, .updateAvailable:
                content
            }
        }
        .animation(.easeInOut(duration: 0.2), value: gate)
        .task { await check() }
    }

    private func check() async {
        guard let config = try? await environment.appConfigService.configuration() else { return }
        gate = config.gate(forBuild: Bundle.main.buildNumber)
    }

    /// No way past. Deliberately no dismiss and no back.
    private func stop(title: String, message: String, action: (String, URL)?) -> some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: Theme.Spacing.md) {
                AppLogo(size: .small).padding(.bottom, Theme.Spacing.lg)
                Text(title)
                    .font(Theme.display(.title))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                if let (label, url) = action {
                    Button(label) { openURL(url) }
                        .buttonStyle(.brandPrimary)
                        .padding(.top, Theme.Spacing.md)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// A nudge, not a wall — "later" is a real option here.
    private func nudge(storeURL: URL?) -> some View {
        stop(
            title: t("launch.update.title"),
            message: t("launch.update.message"),
            action: storeURL.map { (t("launch.update"), $0) }
        )
        .overlay(alignment: .bottom) {
            Button(t("launch.later")) { dismissedNudge = true }
                .buttonStyle(.brandLink)
                .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

nonisolated extension Bundle {
    /// `CFBundleVersion`, which is what `minimumBuild` is compared against —
    /// **not** the marketing version. Zero when unreadable, which fails open:
    /// a build we cannot identify is not one we should lock out.
    var buildNumber: Int {
        (object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            .flatMap(Int.init) ?? 0
    }
}
