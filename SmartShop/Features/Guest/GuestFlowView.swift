//
//  GuestFlowView.swift
//  SmartShop
//

import SwiftUI

/// The whole guest section as one navigation stack.
///
/// Owning the path here (rather than in each screen) is what lets the content
/// pages implement "back to guest home" as `path.removeLast()` and the hub
/// implement "leave guest mode" as clearing it — no screen needs to know where
/// it sits in the flow. It is also what lets the tab bar below drive the stack:
/// the web's guest tab bar links to `/gaest/butikker` and `/gaest/mere`, which
/// here is just setting the path.
struct GuestFlowView: View {
    /// Called when a guest chooses to create an account; the auth flow takes over.
    var onCreateAccount: () -> Void
    /// Called when a guest chooses to sign in instead.
    var onLogIn: () -> Void

    @State private var path: [GuestRoute] = []
    @State private var showsGate = false

    var body: some View {
        NavigationStack(path: $path) {
            GuestLanguageView(path: $path)
                .navigationDestination(for: GuestRoute.self) { route in
                    switch route {
                    case .hub:
                        GuestHubView(path: $path, onCreateAccount: onCreateAccount)
                    case .howToShop:
                        HowToShopView(path: $path, onCreateAccount: onCreateAccount, onLogIn: onLogIn)
                    case .stores:
                        GuestStoresView(path: $path, onCreateAccount: onCreateAccount, onLogIn: onLogIn)
                    case .goodToKnow:
                        GoodToKnowView(path: $path, onCreateAccount: onCreateAccount, onLogIn: onLogIn)
                    case .about:
                        AboutView(onBack: backToHub, onContact: { path.append(.contact) })
                    case .contact:
                        ContactView(onBack: backToHub)
                    case .faq:
                        FaqView(onBack: backToHub)
                    case .language:
                        LanguagePageView(onBack: backToHub)
                    }
                }
        }
        .tint(.white)
        // The language chooser (empty path) is a green auth-style screen with
        // no tab bar, exactly as `/gaest` on the web. Every page after it has one.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !path.isEmpty {
                BrandTabBar(selection: selectedTab, guest: true) { tab in
                    switch tab {
                    case .stores: path = [.hub, .stores]
                    case .more: path = [.hub]
                    case .home, .contests: break
                    }
                } onLocked: {
                    showsGate = true
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeOut(duration: 0.2), value: path.isEmpty)
        .sheet(isPresented: $showsGate) {
            GuestGateSheet(onCreateAccount: onCreateAccount, onLogIn: onLogIn)
        }
    }

    /// "Back to More" on the info pages. The web links to `/gaest/mere`.
    private func backToHub() {
        path = [.hub]
    }

    private var selectedTab: AppTab? {
        switch path.last {
        case .stores: .stores
        case .hub, .howToShop, .goodToKnow, .about, .contact, .faq, .language: .more
        case nil: nil
        }
    }
}
