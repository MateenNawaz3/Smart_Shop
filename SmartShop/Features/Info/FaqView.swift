//
//  FaqView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/faq.tsx` — an accordion with the first item open.
struct FaqView: View {
    @Environment(\.strings) private var t

    var onBack: () -> Void

    @State private var open: Int? = 0

    private var items: [(q: String, a: String)] {
        t.list("faq.items", fields: ["q", "a"]).map { ($0["q"] ?? "", $0["a"] ?? "") }
    }

    var body: some View {
        AppPageLayout(title: t("faq.title"), description: t("faq.description")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let expanded = open == index
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                open = expanded ? nil : index
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.q)
                                    .font(Theme.display(.body, weight: .bold))
                                    .foregroundStyle(Theme.Colors.green)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.green.opacity(0.6))
                                    .rotationEffect(.degrees(expanded ? 180 : 0))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, Theme.Spacing.md)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(expanded ? .isSelected : [])

                        if expanded {
                            Text(item.a)
                                .font(Theme.body(.subheadline))
                                .lineSpacing(3)
                                .foregroundStyle(Theme.Colors.green.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
                    .clipped()
                }
            }
        }
    }
}
