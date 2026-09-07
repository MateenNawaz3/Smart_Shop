//
//  GuestStoresView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/gaest_.butikker.tsx` — every store, with directions and
/// a phone link.
struct GuestStoresView: View {
    @Binding var path: [GuestRoute]
    var onCreateAccount: () -> Void
    var onLogIn: () -> Void

    @Environment(\.strings) private var t
    @Environment(\.openURL) private var openURL

    var body: some View {
        AppPageLayout(
            title: t("tourist.storesTitle"),
            description: t("tourist.storesDescription"),
        guest: true
        ) {
            GuestBackLink(title: t("tourist.backToStart")) { path.removeLast() }
        } content: {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(Store.all) { store in
                    card(for: store)
                }
            }

            GuestCta(onCreateAccount: onCreateAccount, onLogIn: onLogIn)
        }
    }

    private func card(for store: Store) -> some View {
        GuestCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    OvalIcon(systemName: "mappin.and.ellipse")

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(store.shortName)
                            .font(Theme.display(.title3, weight: .bold))
                            .foregroundStyle(Theme.Colors.green)

                        Text(store.displayAddress.joined(separator: "\n"))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green.opacity(0.7))

                        Label(
                            store.isAlwaysOpen
                                ? t("tourist.open247")
                                : "\(t("tourist.openLimited")) · \(store.hours.first ?? "")",
                            systemImage: "clock"
                        )
                        .font(Theme.body(.caption, weight: .semibold))
                        .foregroundStyle(Theme.Colors.green.opacity(0.7))
                        .padding(.top, Theme.Spacing.xs)
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        if let url = store.directionsURL { openURL(url) }
                    } label: {
                        Label(t("tourist.directions"), systemImage: "location.north.line")
                    }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.green))

                    Button {
                        if let url = store.dialURL { openURL(url) }
                    } label: {
                        Label(t("tourist.call"), systemImage: "phone")
                            .font(Theme.display(.subheadline, weight: .bold))
                            .foregroundStyle(Theme.Colors.green)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background {
                                Capsule().strokeBorder(
                                    Theme.Colors.green.opacity(0.3), lineWidth: 2
                                )
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }
}
