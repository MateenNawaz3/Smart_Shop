//
//  FindStoreView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/_authenticated/find-butik.tsx` — searchable store list.
struct FindStoreView: View {
    @Binding var path: [StoresRoute]

    @Environment(\.strings) private var t
    @Environment(FavoritesStore.self) private var favorites

    @State private var query = ""

    private var results: [Store] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Store.all }
        return Store.all.filter { store in
            ([store.name] + store.displayAddress).joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        AppPageLayout(
            title: t("stores.findStoreTitle"),
            description: t("stores.findStoreDescription"),
            topSlot: { EmptyView() },
            action: { favoritesButton },
            content: { content }
        )
    }

    /// Lime heart on a green oval, with a count badge when there are favourites.
    private var favoritesButton: some View {
        Button { path.append(.favorites) } label: {
            Image(systemName: "heart.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Colors.lime)
                .rotationEffect(.degrees(8))
                .frame(width: 64, height: 44)
                .background(Theme.Colors.green, in: .ellipse)
                .overlay(alignment: .topTrailing) {
                    if !favorites.slugs.isEmpty {
                        Text("\(favorites.slugs.count)")
                            .font(Theme.display(.caption2, weight: .bold))
                            .foregroundStyle(Theme.Colors.green)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.Colors.lime, in: .capsule)
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(t("stores.seeFavoritesAria"))
    }

    @ViewBuilder
    private var content: some View {
        searchField

        LazyVStack(spacing: 12) {
            ForEach(results) { store in
                StoreRow(store: store) { path.append(.store(slug: store.slug)) }
            }
        }
        .padding(.top, Theme.Spacing.sm)

        if results.isEmpty {
            Text(t("stores.noResults"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
                .padding(.top, Theme.Spacing.md)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.green.opacity(0.5))
            TextField(t("stores.searchPlaceholder"), text: $query)
                .font(Theme.body(.body))
                .foregroundStyle(Theme.Colors.green)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(t("stores.searchAria"))
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.green.opacity(0.4))
                }
                .accessibilityLabel(t("common.close"))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background {
            Capsule()
                .fill(.white)
                .strokeBorder(Theme.Colors.green.opacity(0.15), lineWidth: 2)
        }
    }
}
