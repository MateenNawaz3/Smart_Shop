//
//  GoodToKnowView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/gaest_.godt-at-vide.tsx` — payment, deposit, age limits
/// and where to get help.
struct GoodToKnowView: View {
    @Binding var path: [GuestRoute]
    var onCreateAccount: () -> Void
    var onLogIn: () -> Void

    @Environment(\.strings) private var t

    private var items: [(title: String, body: String)] {
        t.list("tourist.gtkItems", fields: ["title", "body"])
            .map { ($0["title"] ?? "", $0["body"] ?? "") }
    }

    var body: some View {
        AppPageLayout(
            title: t("tourist.gtkTitle"),
            description: t("tourist.gtkDescription"),
        guest: true
        ) {
            GuestBackLink(title: t("tourist.backToStart")) { path.removeLast() }
        } content: {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    GuestCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            HStack(spacing: Theme.Spacing.sm) {
                                OvalIcon(systemName: "info.circle")
                                Text(item.title)
                                    .font(Theme.display(.title3, weight: .bold))
                                    .foregroundStyle(Theme.Colors.green)
                            }
                            Text(item.body)
                                .font(Theme.body(.subheadline))
                                .foregroundStyle(Theme.Colors.green.opacity(0.75))
                                .lineSpacing(3)
                        }
                    }
                }
            }

            GuestCta(onCreateAccount: onCreateAccount, onLogIn: onLogIn)
        }
    }
}
