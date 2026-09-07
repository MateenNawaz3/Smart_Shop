//
//  AuthHeader.swift
//  SmartShop
//

import SwiftUI

/// The row at the top of every auth screen: back button, logo plate, language
/// switcher — the layout in the reference design.
///
/// The web builds this inline in each route's `<header>`. Extracting it means
/// the six auth screens can never drift apart, and the language bar is present
/// on all of them rather than only where someone remembered to add it.
struct AuthHeader: View {
    /// Omitted on the welcome screen, which has nothing to go back to.
    var showsBack = true
    var logoSize: AppLogo.Size = .small

    @Environment(\.dismiss) private var dismiss
    @Environment(\.strings) private var t

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if showsBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(Theme.body(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 40)
                        .background {
                            // The brand's oval button shape (`.btn-oval`).
                            Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        }
                }
                .accessibilityLabel(t("common.back"))
            }

            AppLogo(size: logoSize)

            Spacer(minLength: Theme.Spacing.sm)

            LanguageBar(tone: .onGreen, showsLabels: false)
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.green
        VStack {
            AuthHeader()
            Spacer()
        }
        .padding()
    }
    .environment(LanguageStore())
    .ignoresSafeArea()
}
