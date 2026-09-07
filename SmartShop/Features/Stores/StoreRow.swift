//
//  StoreRow.swift
//  SmartShop
//

import SwiftUI

/// One store in the Find store and Favourites lists: heart, name, address,
/// optional opening-hours chip, chevron. The `<li>` in `find-butik.tsx`.
struct StoreRow: View {
    @Environment(\.strings) private var t
    @Environment(FavoritesStore.self) private var favorites

    let store: Store
    /// The Find store list shows an opening-hours chip; the favourites list does not.
    var showsHours = true
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm + 4) {
            FavoriteButton(active: favorites.isFavorite(store.slug), label: store.shortName) {
                favorites.toggle(store.slug)
            }

            Button(action: onOpen) {
                HStack(spacing: Theme.Spacing.sm + 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.shortName)
                            .font(Theme.display(.title3, weight: .bold))
                            .foregroundStyle(Theme.Colors.green)
                        Text(store.displayAddress.joined(separator: ", "))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green.opacity(0.7))
                        if showsHours {
                            Text(store.isAlwaysOpen ? t("stores.alwaysOpen") : (store.hours.first ?? ""))
                                .font(Theme.display(.caption2, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Theme.Colors.green, in: .capsule)
                                .padding(.top, Theme.Spacing.sm)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.green.opacity(0.6))
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
    }
}
