//
//  ReceiptsView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/_authenticated/mere_.kvitteringer.index.tsx`.
struct ReceiptsView: View {
    @Binding var path: [MoreRoute]

    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages

    var body: some View {
        AppPageLayout(title: t("receipts.title"), description: t("receipts.intro")) {
            GuestBackLink(title: t("common.backToMore")) { path.removeAll() }
        } content: {
            DemoNote(badge: t("receipts.demoBadge"), text: t("receipts.demoNote"))

            if Receipt.all.isEmpty {
                Text(t("receipts.empty"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
            } else {
                VStack(spacing: 12) {
                    ForEach(Receipt.all) { receipt in
                        InfoRow(
                            systemImage: "doc.text",
                            title: receipt.store,
                            subtitle: subtitle(for: receipt),
                            showsChevron: true
                        ) { path.append(.receipt(id: receipt.id)) }
                    }
                }
                .padding(.top, Theme.Spacing.md)
            }
        }
    }

    private func subtitle(for receipt: Receipt) -> String {
        let date = receipt.purchasedAt?.formatted(
            Date.FormatStyle(date: .abbreviated).locale(languages.language.locale)
        ) ?? receipt.date
        return "\(date) · \(receipt.lines.count) \(t("receipts.items"))\n\(t("receipts.total")) \(Receipt.kr(receipt.total))"
    }
}

/// "DEMO" badge with a note — the web's demo banner on receipts and NFC.
struct DemoNote: View {
    let badge: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(badge)
                .font(Theme.body(.caption2, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Theme.Colors.green, in: .capsule)
            Text(text)
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.field))
    }
}
