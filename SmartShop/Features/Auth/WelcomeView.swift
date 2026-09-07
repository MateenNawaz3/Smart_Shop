//
//  WelcomeView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/index.tsx`.
///
/// The web version also runs recovery-link detection here, because a browser
/// can land on `/` with a token in the URL. On iOS that arrives as a deep link
/// instead, so it is handled once in `SmartShopApp` — this screen stays purely
/// presentational.
struct WelcomeView: View {
    /// Guest mode is a separate stack, so the welcome screen asks its parent
    /// to present it rather than pushing it here.
    var onGuest: () -> Void

    @Environment(\.strings) private var t
    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AppLogo()
                    .padding(.top, Theme.Spacing.lg)

                Spacer()

                VStack(spacing: Theme.Spacing.md) {
                    Text(t("welcome.title"))
                        .font(Theme.display(.largeTitle))
                    Text(t("welcome.subtitle"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: Theme.Spacing.md) {
                    NavigationLink(value: AuthRoute.mitID) {
                        // Two lines of label inside one pill, as on the web.
                        VStack(spacing: 2) {
                            Text(t("mitid.cta"))
                            Text(t("mitid.ctaHint"))
                                .font(Theme.body(.caption, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(.brandPrimary)

                    NavigationLink(value: AuthRoute.login) {
                        Text(t("common.login"))
                    }
                    .buttonStyle(.brandOutline)

                    NavigationLink(value: AuthRoute.signUp) {
                        Text(t("common.createAccountId"))
                    }
                    .buttonStyle(.brandLink)
                }
                .padding(.top, Theme.Spacing.xl)

                Button(t("common.guest"), action: onGuest)
                    .buttonStyle(.brandLink)
                .padding(.top, Theme.Spacing.lg)

                Spacer()
            }
        }
    }
}

/// Every destination in the signed-out flow, as one value type.
///
/// This is the SwiftUI equivalent of the web's file-based routes. Because it is
/// `Hashable`, screens push it with `NavigationLink(value:)` and the stack
/// declares each destination once — see `AuthFlowView`.
enum AuthRoute: Hashable {
    case login
    case signUp
    case mitID
    case pinSetup
}

#Preview {
    NavigationStack { WelcomeView(onGuest: {}) }
}
