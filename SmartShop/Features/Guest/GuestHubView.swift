//
//  GuestHubView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/gaest_.mere.tsx` — the guest home.
///
/// The web guards this with a `useEffect` that redirects when `isGuest()` is
/// false, because a browser can deep-link straight to `/gaest/mere`. On iOS the
/// only way in is through the language chooser, which sets guest mode first, so
/// the guard is unnecessary rather than merely reimplemented.
struct GuestHubView: View {
    @Binding var path: [GuestRoute]

    @Environment(DeviceState.self) private var device
    @Environment(\.strings) private var t
    @Environment(\.dismiss) private var dismiss

    /// Set by the "create account" card to hand the user back to the auth flow.
    var onCreateAccount: () -> Void

    var body: some View {
        AppPageLayout(
            title: t("tourist.title"),
            description: t("tourist.description"),
        guest: true
        ) {
            HStack {
                GuestBackLink(title: t("tourist.backToStart"), action: leaveGuest)
                Spacer()
                LanguageBar(tone: .onLight, showsLabels: false)
            }
        } content: {
            GuestCard {
                Text(t("tourist.intro"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.8))
                    .lineSpacing(3)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: Theme.Spacing.sm)],
                      spacing: Theme.Spacing.sm) {
                bigCard(
                    icon: "book", title: t("tourist.howto"), subtitle: t("tourist.howtoSub"),
                    background: Theme.Colors.green
                ) { path.append(.howToShop) }

                bigCard(
                    icon: "mappin.and.ellipse", title: t("tourist.stores"),
                    subtitle: t("tourist.storesSub"), background: Theme.Colors.green
                ) { path.append(.stores) }

                bigCard(
                    icon: "info.circle", title: t("tourist.goodToKnow"),
                    subtitle: t("tourist.goodToKnowSub"), background: Theme.Colors.green
                ) { path.append(.goodToKnow) }

                bigCard(
                    icon: "person.badge.plus", title: t("tourist.account"),
                    subtitle: t("tourist.accountSub"), background: Theme.Colors.lime,
                    action: onCreateAccount
                )
            }
            .padding(.top, Theme.Spacing.xs)

            // The second list: the public info pages (`gaest_.mere.tsx`).
            VStack(spacing: 12) {
                InfoRow(systemImage: "info.circle", title: t("more.about"),
                        subtitle: t("more.aboutSub"), showsChevron: true) { path.append(.about) }
                InfoRow(systemImage: "envelope", title: t("more.contact"),
                        subtitle: t("more.contactSub"), showsChevron: true) { path.append(.contact) }
                InfoRow(systemImage: "questionmark.circle", title: t("more.faq"),
                        subtitle: t("more.faqSub"), showsChevron: true) { path.append(.faq) }
                InfoRow(systemImage: "globe", title: t("language.title"),
                        subtitle: t("more.languageSub"), showsChevron: true) { path.append(.language) }
            }
            .padding(.top, Theme.Spacing.md)

            Button(t("guestMore.leaveGuest"), action: leaveGuest)
                .buttonStyle(LeaveGuestButtonStyle())
                .padding(.top, Theme.Spacing.lg)
        }
    }

    private func bigCard(
        icon: String,
        title: String,
        subtitle: String,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                OvalIcon(systemName: icon, background: .white.opacity(0.15),
                         size: CGSize(width: 64, height: 48))
                Text(title)
                    .font(Theme.display(.title3))
                    .padding(.top, Theme.Spacing.sm)
                Text(subtitle)
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(background, in: .rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func leaveGuest() {
        device.stopGuest()
        path.removeAll()
        dismiss()
    }
}

/// Outlined green pill on the light canvas.
struct LeaveGuestButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.title3, weight: .bold))
            .foregroundStyle(Theme.Colors.green)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                Capsule().strokeBorder(Theme.Colors.green.opacity(0.7), lineWidth: 2)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Card press feedback, matching the web's `active:scale-[0.99]`.
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
