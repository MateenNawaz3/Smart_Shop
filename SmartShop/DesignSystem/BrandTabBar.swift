//
//  BrandTabBar.swift
//  SmartShop
//

import SwiftUI

/// The four app sections. The web's tab bar `items` as one value.
enum AppTab: Hashable, CaseIterable {
    case home, stores, contests, more

    var systemImage: String {
        switch self {
        case .home: "house"
        case .stores: "mappin.and.ellipse"
        case .contests: "gift"
        case .more: "square.grid.2x2"
        }
    }

    var labelKey: String {
        switch self {
        case .home: "tabs.home"
        case .stores: "tabs.stores"
        case .contests: "tabs.contests"
        case .more: "tabs.more"
        }
    }

    /// Whether a guest may open the tab. Port of `guestOk` in `AppTabBar.tsx`.
    var guestOk: Bool {
        switch self {
        case .stores, .more: true
        case .home, .contests: false
        }
    }
}

/// The lime bottom bar with white icons. Port of `components/app/AppTabBar.tsx`.
///
/// This is a plain view rather than a styled `TabView` bar: on iOS 26 the
/// system bar is Liquid Glass and resists a solid brand colour, and the design
/// also needs the display font and the guest lock badge on two of the tabs.
/// Place it with `.safeAreaInset(edge: .bottom)`.
struct BrandTabBar: View {
    @Environment(\.strings) private var t

    var selection: AppTab?
    /// When true, Home and Contests are locked and open the account gate.
    var guest = false
    var onSelect: (AppTab) -> Void
    var onLocked: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let locked = guest && !tab.guestOk
                let active = tab == selection
                Button {
                    if locked { onLocked() } else { onSelect(tab) }
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 22, weight: .regular))
                            .frame(height: 26)
                            .overlay(alignment: .topTrailing) {
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8, weight: .black))
                                        .padding(3)
                                        .background(Theme.Colors.lime, in: .circle)
                                        .offset(x: 8, y: -4)
                                        .accessibilityHidden(true)
                                }
                            }
                        Text(t(tab.labelKey))
                            .font(Theme.display(.caption2, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(.white.opacity(locked ? 0.6 : active ? 1 : 0.75))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(.rect)
                }
                .buttonStyle(TabPressStyle())
                .accessibilityLabel(locked ? "\(t(tab.labelKey)) — \(t("gate.locked"))" : t(tab.labelKey))
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background {
            Theme.Colors.lime
                .overlay(alignment: .top) {
                    Theme.Colors.green.opacity(0.15).frame(height: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("tabs.menu"))
    }
}

/// `active:scale-[0.96]` on the web's tab links.
private struct TabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Signed in") {
    Color.white.safeAreaInset(edge: .bottom) {
        BrandTabBar(selection: .home, onSelect: { _ in })
    }
}

#Preview("Guest") {
    Color.white.safeAreaInset(edge: .bottom) {
        BrandTabBar(selection: .more, guest: true, onSelect: { _ in })
    }
}
