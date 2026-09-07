//
//  StorePicker.swift
//  SmartShop
//

import SwiftUI

/// Suggests the store closest to the user's address and lets them pick
/// another. Port of `components/app/StorePicker.tsx`.
struct StorePicker: View {
    @Bindable var model: MyStoreModel

    @Environment(\.strings) private var t
    @State private var showAll = false

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if model.locating {
                note(t("stores.locatingStores"))
            }
            if !model.hasAddress && !model.locating && model.loaded {
                note(t("stores.missingAddress"))
            }

            if let nearest = model.nearest, !showAll {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("stores.nearestStore"))
                        .font(Theme.display(.caption, weight: .bold))
                        .textCase(.uppercase).tracking(0.8)
                        .foregroundStyle(Theme.Colors.green.opacity(0.6))
                    Text(nearest.store.shortName)
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.Colors.green)
                    Label(nearest.store.displayAddress.joined(separator: ", "), systemImage: "mappin.and.ellipse")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.green.opacity(0.75))
                    if let km = nearest.km {
                        Text(t("stores.approxFromYou").replacingOccurrences(of: "{km}", with: Store.formatKm(km)))
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green.opacity(0.6))
                    }

                    Button {
                        Task { await model.setStore(nearest.store.slug) }
                    } label: {
                        if model.slug == nearest.store.slug {
                            Label(t("stores.selectedAsYourStore"), systemImage: "checkmark")
                        } else {
                            Text(t("stores.chooseThisStore"))
                        }
                    }
                    .buttonStyle(WidePillButtonStyle())
                    .disabled(model.saving)
                    .padding(.top, Theme.Spacing.md)

                    Button(t("stores.chooseAnotherStore")) { showAll = true }
                        .font(Theme.body(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.Colors.green.opacity(0.7))
                        .underline()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Theme.Colors.lime.opacity(0.15), in: .rect(cornerRadius: Theme.Radius.card))
            }

            if showAll || model.nearest == nil, model.loaded {
                VStack(spacing: 8) {
                    ForEach(model.sorted, id: \.store.id) { entry in
                        let active = model.slug == entry.store.slug
                        Button {
                            Task { await model.setStore(entry.store.slug) }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.store.shortName)
                                        .font(Theme.display(.body, weight: .bold))
                                        .foregroundStyle(Theme.Colors.green)
                                    Text(entry.store.displayAddress.joined(separator: ", ")
                                         + (entry.km.map { " · " + t("stores.approxFromYou").replacingOccurrences(of: "{km}", with: Store.formatKm($0)) } ?? ""))
                                        .font(Theme.body(.subheadline))
                                        .foregroundStyle(Theme.Colors.green.opacity(0.7))
                                }
                                .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.Colors.green)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.lime.opacity(active ? 0.3 : 0.1), in: .rect(cornerRadius: Theme.Radius.card))
                            .contentShape(.rect)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .disabled(model.saving)
                    }
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.body(.subheadline))
            .foregroundStyle(Theme.Colors.green.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// "Set as my store" on a store's page. Port of `SetMyStoreButton`.
struct SetMyStoreButton: View {
    @Bindable var model: MyStoreModel
    let slug: String

    @Environment(\.strings) private var t

    var body: some View {
        let active = model.slug == slug
        Button {
            Task { await model.setStore(slug) }
        } label: {
            if active {
                Label(t("stores.yourStore"), systemImage: "checkmark").frame(maxWidth: .infinity)
            } else {
                Text(t("stores.chooseAsMyStore")).frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(WidePillButtonStyle(background: active ? Theme.Colors.lime.opacity(0.25) : Theme.Colors.green))
        .foregroundStyle(active ? Theme.Colors.green : .white)
        .disabled(model.saving || active)
    }
}
