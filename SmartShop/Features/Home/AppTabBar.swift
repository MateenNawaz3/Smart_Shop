//
//  AppTabBar.swift
//  SmartShop
//

import SwiftUI

/// The signed-in tab shell. Port of `AppTabBar.tsx`.
///
/// A `TabView` keeps each tab's navigation state alive, but its own bar is
/// hidden: the brand's lime bar is `BrandTabBar`, pinned with a bottom safe
/// area inset so every page's scroll content clears it automatically.
struct AppTabBar: View {
    @Environment(\.strings) private var t

    @State private var selection: AppTab = .home
    @State private var storesPath: [StoresRoute] = []
    @State private var homePath: [HomeRoute] = []
    @State private var morePath: [MoreRoute] = []

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: AppTab.home) {
                NavigationStack(path: $homePath) {
                    HomeView(path: $homePath)
                        .navigationDestination(for: HomeRoute.self) { route in
                            switch route {
                            case .offers: OffersView()
                            case .posts: BulletinBoardView()
                            }
                        }
                }
            }
            Tab(value: AppTab.stores) {
                NavigationStack(path: $storesPath) {
                    FindStoreView(path: $storesPath)
                        .navigationDestination(for: StoresRoute.self) { route in
                            switch route {
                            case .store(let slug):
                                StoreDetailView(path: $storesPath, slug: slug) {
                                    morePath = [.details]
                                    selection = .more
                                }
                            case .favorites:
                                FavoritesView(
                                    backTitle: t("stores.backToAllStores"),
                                    onBack: { storesPath.removeLast() },
                                    onOpenStore: { storesPath.append(.store(slug: $0)) },
                                    onFindStore: { storesPath.removeAll() }
                                )
                            }
                        }
                }
            }
            Tab(value: AppTab.contests) {
                NavigationStack { ContestsView() }
            }
            Tab(value: AppTab.more) {
                NavigationStack(path: $morePath) {
                    MoreView(path: $morePath)
                        .navigationDestination(for: MoreRoute.self) { route in
                            moreDestination(route)
                        }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BrandTabBar(selection: selection) { tab in
                // Re-selecting the current tab pops it to its root, the iOS
                // convention that stands in for the web's tab links always
                // pointing at the section's index route.
                if tab == selection {
                    switch tab {
                    case .home: homePath.removeAll()
                    case .stores: storesPath.removeAll()
                    case .more: morePath.removeAll()
                    case .contests: break
                    }
                }
                selection = tab
            }
        }
        .tint(Theme.Colors.green)
    }
}

extension AppTabBar {
    /// Jumps to the Stores tab at a given page; used by More's favourites and
    /// the Contact page, which the web links straight to `/find-butik`.
    private func openStores(_ path: [StoresRoute] = []) {
        storesPath = path
        selection = .stores
    }

    @ViewBuilder
    private func moreDestination(_ route: MoreRoute) -> some View {
        switch route {
        case .receipts:
            ReceiptsView(path: $morePath)
        case .receipt(let id):
            ReceiptDetailView(path: $morePath, id: id)
        case .details:
            MyDetailsView(path: $morePath, onVerify: { morePath.append(.verification) })
        case .favorites:
            FavoritesView(
                backTitle: t("stores.backToMore"),
                onBack: { morePath.removeAll() },
                onOpenStore: { openStores([.store(slug: $0)]) },
                onFindStore: { openStores() }
            )
        case .notifications:
            NotificationsView(path: $morePath)
        case .language:
            LanguagePageView(onBack: { morePath.removeAll() })
        case .about:
            AboutView(onBack: { morePath.removeAll() }, onContact: { morePath.append(.contact) })
        case .contact:
            ContactView(onBack: { morePath.removeAll() }, onFindStore: { openStores() })
        case .faq:
            FaqView(onBack: { morePath.removeAll() })
        case .verification:
            VerificationView(onBack: { morePath.removeAll() }, onDone: { morePath.removeAll() })
        case .access:
            NfcAccessView(onBack: { morePath.removeAll() }, onVerify: { morePath = [.verification] })
        }
    }
}

