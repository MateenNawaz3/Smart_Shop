//
//  AppScreen.swift
//  SmartShop
//

import SwiftUI

/// Full-bleed canvas shared by every Smart Shop screen.
///
/// Port of `components/app/AppScreen.tsx`: brand-green background, a centred
/// column that stays a comfortable width on iPad, and safe-area handling.
///
/// The web reads `env(safe-area-inset-*)` by hand. SwiftUI gives you the safe
/// area for free — the background uses `.ignoresSafeArea()` so colour bleeds
/// under the notch and home indicator, while the content column does not.
struct AppScreen<Content: View>: View {
    enum Tone { case green, light }

    var tone: Tone = .green
    var ovals: BrandOvals?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            (tone == .green ? Theme.Colors.green : Color.white)
                .ignoresSafeArea()

            if let ovals {
                ovals.ignoresSafeArea()
            }

            content
                .frame(maxWidth: 480)          // web: `max-w-md` / `sm:max-w-lg`
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(tone == .green ? .white : Theme.Colors.ink)
    }
}
