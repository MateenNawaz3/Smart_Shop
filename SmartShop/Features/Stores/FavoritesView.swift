//
//  FavoritesView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/_authenticated/find-butik_.favoritter.tsx`.
///
/// Reached from both the Stores tab and More, so navigation is injected: the
/// web's `?fra=butikker` search param becomes `backTitle`/`onBack`.
struct FavoritesView: View {
    var backTitle: String
    var onBack: () -> Void
    var onOpenStore: (String) -> Void
    var onFindStore: () -> Void

    @Environment(\.strings) private var t
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        AppPageLayout(
            title: t("stores.favoritesTitle"),
            description: t("stores.favoritesDescription")
        ) {
            GuestBackLink(title: backTitle, action: onBack)
        } content: {
            if favorites.stores.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    Text(t("stores.noFavoritesYet"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.green.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    Button(t("stores.findAStore"), action: onFindStore)
                        .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 32)
                .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(favorites.stores) { store in
                        StoreRow(store: store, showsHours: false) { onOpenStore(store.slug) }
                    }
                }
                .animation(.easeOut(duration: 0.2), value: favorites.slugs)
            }
        }
    }
}
