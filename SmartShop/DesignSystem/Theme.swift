//
//  Theme.swift
//  SmartShop
//

import SwiftUI
import UIKit

/// Smart Shop brand tokens, ported 1:1 from the web app's `styles.css`.
///
/// The web defines these as OKLCH custom properties. SwiftUI has no OKLCH
/// literal, so each colour is given here as the sRGB hex the web comments
/// document, and the OKLCH source is kept alongside it for traceability.
enum Theme {
    enum Colors {
        /// `--brand-green: oklch(0.45 0.13 152)` — the auth canvas.
        static let green = Color(hex: 0x006130)
        /// `--brand-lime: oklch(0.66 0.18 138)` — primary CTA.
        static let lime = Color(hex: 0x4EAD33)
        /// `--brand-cream: oklch(0.97 0.003 100)` — app background.
        static let cream = Color(hex: 0xF5F5F5)
        /// `--brand-ink: oklch(0.20 0 0)` — body text.
        static let ink = Color(hex: 0x0C0C0C)
        /// `--brand-red: oklch(0.58 0.22 27)` — sRGB approximation; the web
        /// gives no hex for this one.
        static let red = Color(hex: 0xE0342A)
        /// `--brand-orange: oklch(0.75 0.17 60)` — sRGB approximation.
        static let orange = Color(hex: 0xF0913A)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
    }

    /// The web's radius scale: `--radius: 1.125rem` (18px) and the Tailwind
    /// steps derived from it. Names follow the Tailwind classes the web uses.
    enum Radius {
        /// `rounded-2xl` — text fields and small chips.
        static let field: CGFloat = 16
        /// `rounded-3xl` (`--radius` + 12px) — every card on the inner pages.
        static let card: CGFloat = 30
        /// `rounded-b-[2rem]` — the green page header's bottom corners.
        static let header: CGFloat = 32
    }

    // MARK: Fonts

    /// PostScript names of the bundled Inter faces (see `Resources/Fonts` and
    /// `UIAppFonts` in Info.plist). The web loads Inter 400/500/600 from
    /// Google Fonts for body text.
    private enum Inter {
        static let regular = "Inter18pt-Regular"
        static let medium = "Inter18pt-Medium"
        static let semibold = "Inter18pt-SemiBold"
        static let bold = "Inter18pt-Bold"
    }

    /// The web's display face is `all-round-gothic`, served from Adobe Fonts
    /// under the site's Typekit licence. It cannot be redistributed in an app
    /// bundle, so we look for it at runtime: drop the licensed `.otf` files
    /// into `Resources/Fonts`, add them to `UIAppFonts`, and this picks them
    /// up. Until then SF Pro Rounded, the closest system face, is used.
    private static let allRoundGothicAvailable: Bool =
        UIFont.familyNames.contains { $0.localizedCaseInsensitiveContains("All Round Gothic") }

    /// Heading font — `font-display`. Heavy by default, like the web's
    /// `font-extrabold` headings.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .heavy) -> Font {
        if allRoundGothicAvailable {
            let name = weight == .heavy || weight == .bold
                ? "AllRoundGothic-Bold" : "AllRoundGothic-Medium"
            return .custom(name, size: UIFont.preferredFont(forTextStyle: style.uiKit).pointSize,
                           relativeTo: style)
        }
        return .system(style, design: .rounded).weight(weight)
    }

    /// Body font — `font-body`, i.e. Inter. Scales with Dynamic Type.
    static func body(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let name: String = switch weight {
        case .medium: Inter.medium
        case .semibold: Inter.semibold
        case .bold, .heavy, .black: Inter.bold
        default: Inter.regular
        }
        return .custom(name, size: UIFont.preferredFont(forTextStyle: style.uiKit).pointSize,
                       relativeTo: style)
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}

extension Color {
    /// `Color(hex: 0x006130)` — convenience for the brand palette above.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
