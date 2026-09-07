//
//  BrandButton.swift
//  SmartShop
//

import SwiftUI

/// Solid lime pill — the primary call to action.
///
/// Web equivalent: `h-14 rounded-full bg-brand-lime ... active:scale-[0.98]`.
struct BrandPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.title3, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.Colors.lime, in: .capsule)
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined pill on the green canvas — the secondary action.
struct BrandOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.title3, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 2)
            }
            .background(configuration.isPressed ? .white.opacity(0.1) : .clear, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Underlined text link — tertiary actions ("Opret konto", "Gæst").
struct BrandLinkButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.body, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed || prominent ? 1 : 0.85))
            .underline()
            .frame(minHeight: 44)               // Apple's minimum tap target
    }
}

extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: BrandPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == BrandOutlineButtonStyle {
    static var brandOutline: BrandOutlineButtonStyle { .init() }
}
extension ButtonStyle where Self == BrandLinkButtonStyle {
    static var brandLink: BrandLinkButtonStyle { .init() }
}

#Preview {
    ZStack {
        Theme.Colors.green.ignoresSafeArea()
        VStack(spacing: 16) {
            Button("Opret med MitID") {}.buttonStyle(.brandPrimary)
            Button("Log ind") {}.buttonStyle(.brandOutline)
            Button("Opret konto") {}.buttonStyle(.brandLink)
            Button("Deaktiveret") {}.buttonStyle(.brandPrimary).disabled(true)
        }
        .padding(24)
    }
}
