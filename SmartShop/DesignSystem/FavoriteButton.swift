//
//  FavoriteButton.swift
//  SmartShop
//

import SwiftUI

/// Heart toggle used to mark a store as a favourite.
/// Port of `components/app/FavoriteButton.tsx`.
struct FavoriteButton: View {
    enum Size { case small, medium }

    @Environment(\.strings) private var t

    var active: Bool
    /// The store's short name, read into the accessibility label.
    var label: String
    var size: Size = .small
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: active ? "heart.fill" : "heart")
                .font(.system(size: size == .medium ? 22 : 18, weight: .semibold))
                .foregroundStyle(active ? Theme.Colors.green : Theme.Colors.green.opacity(0.6))
                .rotationEffect(.degrees(8))
                .frame(width: size == .medium ? 64 : 56, height: size == .medium ? 44 : 40)
                .background {
                    Ellipse()
                        .fill(active ? Theme.Colors.lime.opacity(0.25) : .white)
                        .strokeBorder(
                            active ? Theme.Colors.lime : Theme.Colors.green.opacity(0.15),
                            lineWidth: 2
                        )
                }
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(
            t(active ? "stores.removeFromFavorites" : "stores.addToFavorites")
                .replacingOccurrences(of: "{label}", with: label)
        )
        .accessibilityAddTraits(active ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: active)
    }
}
