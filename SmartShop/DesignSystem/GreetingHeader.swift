//
//  GreetingHeader.swift
//  SmartShop
//

import SwiftUI

/// The green banner with the greeting and the logo plate that tops every inner
/// page. Port of the `<header>` in `AppPageLayout.tsx` and `hjem.tsx`.
///
/// The web fakes a full-bleed header with negative margins (`-mx-6`); here the
/// header is meant to be placed with `.safeAreaInset(edge: .top)` so its colour
/// runs under the status bar and content scrolls beneath it.
struct GreetingHeader: View {
    @Environment(\.strings) private var t
    @Environment(ProfileCache.self) private var cache
    @Environment(DeviceState.self) private var device

    /// Guests have no name; the greeting is then just "Hi 👋".
    var firstName: String?
    /// Guests must never show a cached name from a previous session.
    var guest = false

    private var name: String? { firstName ?? (guest || device.isGuest ? nil : cache.firstName) }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(t("home.greeting"))\(name.map { " \($0)" } ?? "") 👋")
                    .font(Theme.display(.title2))
                    .lineLimit(1)
                Text(t("home.welcomeBack"))
                    .font(Theme.body(.footnote))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.sm)
            AppLogo(size: .extraSmall)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Theme.Colors.green
                .clipShape(.rect(
                    bottomLeadingRadius: Theme.Radius.header,
                    bottomTrailingRadius: Theme.Radius.header
                ))
                .ignoresSafeArea(edges: .top)
        }
    }
}
