//
//  AppLogo.swift
//  SmartShop
//

import SwiftUI

/// The Smart Shop 24-7 mark, optionally on the white rounded plate used on the
/// green canvas. Port of `components/app/AppLogo.tsx`.
struct AppLogo: View {
    enum Size {
        case extraSmall, small, large

        var plate: CGFloat {
            switch self {
            case .extraSmall: 56
            case .small: 78
            case .large: 150
            }
        }

        var mark: CGFloat {
            switch self {
            case .extraSmall: 38
            case .small: 53
            case .large: 106
            }
        }
    }

    var size: Size = .large
    /// Turn the plate off on light backgrounds, where it would be invisible.
    var plate = true

    var body: some View {
        Group {
            if plate {
                mark
                    .frame(width: size.plate, height: size.plate)
                    .background(.white, in: .rect(cornerRadius: size.plate * 0.24))
                    .shadow(color: .black.opacity(0.45), radius: 25, x: 0, y: 20)
            } else {
                mark
            }
        }
        // The mark carries the app's name, so it is content, not decoration.
        .accessibilityLabel("Smart Shop 24-7")
    }

    private var mark: some View {
        Image(.logo)
            .resizable()
            .scaledToFit()
            .frame(width: size.mark, height: size.mark)
    }
}

#Preview {
    ZStack {
        Theme.Colors.green
        VStack(spacing: 24) {
            AppLogo()
            AppLogo(size: .small)
            AppLogo(size: .extraSmall)
        }
    }
    .ignoresSafeArea()
}
