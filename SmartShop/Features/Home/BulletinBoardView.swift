//
//  BulletinBoardView.swift
//  SmartShop
//

import SwiftUI

/// All posts, with the Posts / Calendar switch. Port of `routes/_authenticated/opslagstavle.tsx`.
///
struct BulletinBoardView: View {
    @Environment(\.strings) private var t

    private enum Tab { case board, calendar }
    @State private var tab: Tab = .board

    var body: some View {
        AppPageLayout(
            title: tab == .board ? t("home.bulletinBoardTitle") : t("events.calendarTitle"),
            description: tab == .board ? t("home.bulletinBoardIntro") : t("events.calendarIntro")
        ) {
            HStack(spacing: 8) {
                segment(t("events.tabBoard"), .board)
                segment(t("events.tabCalendar"), .calendar)
            }
            .padding(6)
            .background(Theme.Colors.lime.opacity(0.1), in: .capsule)
            .padding(.bottom, Theme.Spacing.md)

            switch tab {
            case .board:
                BulletinBoardList()
            case .calendar:
                EventCalendarView()
            }
        }
    }

    private func segment(_ title: String, _ value: Tab) -> some View {
        let active = tab == value
        return Button { withAnimation(.easeOut(duration: 0.2)) { tab = value } } label: {
            Text(title)
                .font(Theme.display(.subheadline, weight: .bold))
                .foregroundStyle(active ? .white : Theme.Colors.green)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(active ? Theme.Colors.green : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
