//
//  GuestCta.swift
//  SmartShop
//

import SwiftUI

/// The "create an account" prompt at the foot of each guest content page.
/// Port of `components/app/GuestCta.tsx`.
struct GuestCta: View {
    @Environment(\.strings) private var t

    var onCreateAccount: () -> Void
    var onLogIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(t("tourist.ctaTitle"))
                .font(Theme.display(.title3, weight: .bold))
            Text(t("tourist.ctaText"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(3)

            // Side by side where there's room, stacked when there isn't.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) { actions }
                VStack(spacing: Theme.Spacing.sm) { actions }
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.green, in: .rect(cornerRadius: Theme.Radius.card))
        .padding(.top, Theme.Spacing.lg)
    }

    @ViewBuilder
    private var actions: some View {
        Button(t("common.createAccount"), action: onCreateAccount)
            .buttonStyle(GuestCtaButtonStyle(filled: true))
        Button(t("common.login"), action: onLogIn)
            .buttonStyle(GuestCtaButtonStyle(filled: false))
    }
}

private struct GuestCtaButtonStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.body, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if filled {
                    Capsule().fill(Theme.Colors.lime)
                } else {
                    Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
