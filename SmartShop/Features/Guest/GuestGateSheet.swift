//
//  GuestGateSheet.swift
//  SmartShop
//

import SwiftUI

/// Bottom sheet asking a guest to create an account before entering a locked
/// tab. Port of `components/app/GuestGateDialog.tsx`.
struct GuestGateSheet: View {
    @Environment(\.strings) private var t
    @Environment(\.dismiss) private var dismiss

    var onCreateAccount: () -> Void
    var onLogIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OvalIcon(systemName: "lock.fill", background: Theme.Colors.lime,
                     size: CGSize(width: 64, height: 48))

            Text(t("gate.title"))
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.md)

            Text(t("gate.description"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, Theme.Spacing.sm)

            VStack(spacing: 12) {
                Button(t("common.createAccount")) {
                    dismiss()
                    onCreateAccount()
                }
                .buttonStyle(GatePillStyle(filled: true))

                Button(t("common.login")) {
                    dismiss()
                    onLogIn()
                }
                .buttonStyle(GatePillStyle(filled: false))

                Button(t("common.close")) { dismiss() }
                    .font(Theme.body(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink.opacity(0.55))
                    .underline()
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(.top, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.card)
        .presentationBackground(.white)
    }
}

private struct GatePillStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.body, weight: .bold))
            .foregroundStyle(filled ? .white : Theme.Colors.green)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if filled {
                    Capsule().fill(Theme.Colors.lime)
                } else {
                    Capsule().strokeBorder(Theme.Colors.green.opacity(0.7), lineWidth: 2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
