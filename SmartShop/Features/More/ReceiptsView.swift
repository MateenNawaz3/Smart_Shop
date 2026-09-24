//
//  ReceiptsView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/_authenticated/mere_.kvitteringer.index.tsx`.
struct ReceiptsView: View {
    @Binding var path: [MoreRoute]

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var languages

    @State private var purchases: [Purchase] = []
    @State private var loaded = false
    @State private var failed = false

    var body: some View {
        AppPageLayout(title: t("receipts.title"), description: t("receipts.intro")) {
            GuestBackLink(title: t("common.backToMore")) { path.removeAll() }
        } content: {
            if !loaded {
                ProgressView()
                    .tint(Theme.Colors.green)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)
            } else if failed {
                // A load that failed is not an empty shop history, and saying
                // "no receipts" would be a lie that invites nobody to retry.
                Text(t("receipts.loadFailed"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
            } else if purchases.isEmpty {
                Text(t("receipts.empty"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
            } else {
                VStack(spacing: 12) {
                    ForEach(purchases) { purchase in
                        InfoRow(
                            systemImage: purchase.isRefund ? "arrow.uturn.left" : "doc.text",
                            title: purchase.storeName,
                            subtitle: subtitle(for: purchase),
                            showsChevron: true
                        ) { path.append(.receipt(id: purchase.id)) }
                    }
                }
                .padding(.top, Theme.Spacing.md)
            }
        }
        .task {
            guard !loaded else { return }
            do {
                purchases = try await environment.purchaseService.purchases()
            } catch {
                failed = true
            }
            loaded = true
        }
    }

    /// **Kroner, not øre** — every amount on a receipt is already the major
    /// unit, so it is formatted rather than divided. See `PurchaseSummaryDTO`.
    private func subtitle(for purchase: Purchase) -> String {
        let date = purchase.occurredAt.formatted(
            Date.FormatStyle(date: .abbreviated).locale(languages.language.locale)
        )
        let items = "\(purchase.itemCount) \(t("receipts.items"))"
        return "\(date) · \(items)\n\(t("receipts.total")) \(Receipt.kr(purchase.total))"
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
