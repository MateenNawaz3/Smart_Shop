//
//  AboutView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/om.tsx`.
struct AboutView: View {
    @Environment(\.strings) private var t

    var onBack: () -> Void
    var onContact: () -> Void

    private var mission: [String] {
        (0..<20).lazy
            .map { t("about.mission.\($0)") }
            .prefix { !$0.hasPrefix("about.mission.") }
            .map { $0 }
    }

    var body: some View {
        AppPageLayout(title: t("about.title")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            VStack(spacing: Theme.Spacing.md) {
                InfoCard { paragraph(t("about.intro")) }

                InfoCard(title: t("about.missionTitle")) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(mission, id: \.self) { paragraph($0) }
                    }
                }

                InfoCard(title: t("about.dataTitle")) { paragraph(t("about.data")) }

                InfoCard(title: t("about.contactTitle")) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(t("about.contactPrefix"))
                        Button(t("about.contactLink"), action: onContact)
                            .buttonStyle(.plain)
                            .fontWeight(.semibold)
                            .underline()
                        Text(verbatim: ".")
                    }
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.8))
                }
            }

            Text(t("about.version"))
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.Colors.green.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.lg)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Theme.body(.subheadline))
            .lineSpacing(3)
            .foregroundStyle(Theme.Colors.green.opacity(0.8))
    }
}

/// Lime card with an optional display-font heading — the `<section>` used on
/// the About, Contact and store pages.
struct InfoCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        GuestCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let title {
                    Text(title)
                        .font(Theme.display(.title3, weight: .bold))
                        .foregroundStyle(Theme.Colors.green)
                }
                content
            }
        }
    }
}
