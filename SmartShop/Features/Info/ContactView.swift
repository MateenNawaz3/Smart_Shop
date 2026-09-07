//
//  ContactView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/kontakt.tsx`.
struct ContactView: View {
    @Environment(\.strings) private var t
    @Environment(\.openURL) private var openURL

    var onBack: () -> Void
    /// Signed-in users get a third card that jumps to Find store; guests do not.
    var onFindStore: (() -> Void)? = nil

    var body: some View {
        AppPageLayout(title: t("contact.title"), description: t("contact.description")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            VStack(spacing: 12) {
                InfoRow(systemImage: "envelope", title: t("contact.writeTitle"),
                        subtitle: "info@smartshop24-7.dk") {
                    if let url = URL(string: "mailto:info@smartshop24-7.dk") { openURL(url) }
                }
                InfoRow(systemImage: "phone", title: t("contact.callTitle"),
                        subtitle: "+45 70 22 03 60") {
                    if let url = URL(string: "tel:+4570220360") { openURL(url) }
                }
                if let onFindStore {
                    InfoRow(systemImage: "mappin.and.ellipse", title: t("contact.storeTitle"),
                            subtitle: t("contact.storeSub"), action: onFindStore)
                }
            }

            Text(t("contact.note"))
                .font(Theme.body(.subheadline))
                .lineSpacing(3)
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .padding(.top, Theme.Spacing.lg)
        }
    }
}

/// Lime row with a green oval icon, title and subtitle — the list item used on
/// Contact and the More page.
struct InfoRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    var showsChevron = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                OvalIcon(systemName: systemImage, size: CGSize(width: 56, height: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.display(.title3, weight: .bold))
                        .foregroundStyle(Theme.Colors.green)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.green.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
