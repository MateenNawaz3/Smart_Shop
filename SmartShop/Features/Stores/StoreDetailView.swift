//
//  StoreDetailView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/_authenticated/find-butik_.$slug.tsx` — one store's page.
struct StoreDetailView: View {
    @Binding var path: [StoresRoute]
    let slug: String
    /// Opens My details, for the "add your address" hint.
    var onEditAddress: () -> Void = {}

    @Environment(\.strings) private var t
    @Environment(\.openURL) private var openURL
    @Environment(FavoritesStore.self) private var favorites
    @Environment(AppEnvironment.self) private var environment

    @State private var myStore: MyStoreModel?

    var body: some View {
        if let store = Store.named(slug) {
            page(for: store)
        } else {
            AppPageLayout(title: t("stores.storeNotFoundTitle")) {
                Text(t("stores.storeNotFoundBody"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.8))
                Button(t("stores.backToStores")) { path.removeAll() }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
                    .padding(.top, Theme.Spacing.md)
            }
        }
    }

    private func page(for store: Store) -> some View {
        AppPageLayout(
            title: store.shortName,
            description: store.displayAddress.joined(separator: ", "),
            topSlot: {
                GuestBackLink(title: t("stores.allStores")) { path.removeAll() }
            },
            action: {
                FavoriteButton(
                    active: favorites.isFavorite(store.slug),
                    label: store.shortName,
                    size: .medium
                ) { favorites.toggle(store.slug) }
            },
            content: {
                if let myStore {
                    SetMyStoreButton(model: myStore, slug: store.slug)
                        .padding(.bottom, Theme.Spacing.md)
                }
                contactCard(store)
                hoursCard(store)
                    .padding(.top, Theme.Spacing.md + 4)

                Button {
                    if let url = URL(string: store.facebookUrl) { openURL(url) }
                } label: {
                    Label(t("stores.followOnFacebook"), systemImage: "hand.thumbsup")
                }
                .buttonStyle(LeaveGuestButtonStyle())
                .padding(.top, Theme.Spacing.md + 4)
            }
        )
        .task {
            if myStore == nil {
                let model = MyStoreModel(profiles: environment.profileService)
                myStore = model
                await model.load()
            }
        }
    }

    /// Google Maps on the web; Apple Maps here, with the home address as origin when known.
    private func directionsURL(for store: Store) -> URL? {
        var components = URLComponents(string: "http://maps.apple.com/")
        var items = [URLQueryItem(name: "daddr", value: store.address)]
        if let home = myStore?.profile?.homeAddress { items.append(URLQueryItem(name: "saddr", value: home)) }
        components?.queryItems = items
        return components?.url
    }

    private func contactCard(_ store: Store) -> some View {
        GuestCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("stores.contact"))
                    .font(Theme.display(.title3, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)

                contactLine(systemImage: "phone", text: store.phone) {
                    if let url = store.dialURL { openURL(url) }
                }
                .padding(.top, Theme.Spacing.xs)

                contactLine(systemImage: "envelope", text: store.email) {
                    if let url = URL(string: "mailto:\(store.email)") { openURL(url) }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .frame(width: 20)
                        .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    Text(store.displayAddress.joined(separator: "\n"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.green)
                }

                Button {
                    if let url = directionsURL(for: store) { openURL(url) }
                } label: {
                    Label(t("stores.showDirections"), systemImage: "location.north.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WidePillButtonStyle())
                .padding(.top, Theme.Spacing.sm)

                Group {
                    if let home = myStore?.profile?.homeAddress {
                        HStack(spacing: 4) {
                            Text("\(t("stores.routeFromAddress")): \(home) ·")
                            Button(t("stores.editAddress"), action: onEditAddress).fontWeight(.bold).underline()
                        }
                    } else if myStore?.loaded == true {
                        HStack(spacing: 4) {
                            Button(t("stores.addYourAddress"), action: onEditAddress).fontWeight(.bold).underline()
                            Text(t("stores.forDirectionsFromHome"))
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.Colors.green.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
        }
    }

    private func contactLine(systemImage: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 20)
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
                Text(text)
                    .font(Theme.body(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.green)
            }
        }
        .buttonStyle(.plain)
    }

    private func hoursCard(_ store: Store) -> some View {
        // Monday-first index, as the web computes `(getDay() + 6) % 7`.
        let today = (Calendar(identifier: .iso8601).component(.weekday, from: .now) + 5) % 7
        return GuestCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(t("stores.openingHours"))
                    .font(Theme.display(.title3, weight: .bold))
                    .foregroundStyle(Theme.Colors.green)
                    .padding(.bottom, Theme.Spacing.sm)

                ForEach(0..<7, id: \.self) { index in
                    HStack {
                        Text(t("stores.weekdays.\(index)"))
                        Spacer()
                        Text(store.hours.indices.contains(index) ? store.hours[index] : "")
                    }
                    .font(Theme.body(.subheadline, weight: index == today ? .bold : .regular))
                    .foregroundStyle(index == today ? Theme.Colors.green : Theme.Colors.green.opacity(0.75))
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if index < 6 {
                            Theme.Colors.green.opacity(0.1).frame(height: 1)
                        }
                    }
                }
            }
        }
    }
}

/// Full-width green pill, 56pt tall — the web's `h-14 w-full rounded-full bg-brand-green`.
struct WidePillButtonStyle: ButtonStyle {
    var background: Color = Theme.Colors.green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.body, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(background, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
