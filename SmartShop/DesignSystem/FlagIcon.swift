//
//  FlagIcon.swift
//  SmartShop
//

import SwiftUI

enum FlagCode: Sendable { case dk, gb, de }

/// Drawn flags, port of `components/app/FlagIcon.tsx`.
///
/// The web draws these as inline SVG rather than using emoji, because emoji
/// flags don't render on Windows. iOS renders 🇩🇰 fine, but drawing them keeps
/// all three the same size and shape — emoji flags vary in aspect ratio and
/// ignore your frame, which would make the pills in the language bar jitter.
struct FlagIcon: View {
    let code: FlagCode
    var width: CGFloat = 28

    private var height: CGFloat { width * 20 / 28 }

    var body: some View {
        Group {
            switch code {
            case .dk: denmark
            case .de: germany
            case .gb: unitedKingdom
            }
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.15), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    /// Nordic cross: offset vertical bar, centred horizontal bar.
    private var denmark: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            Color(hex: 0xC8102E)
            Color.white.frame(width: w * 4 / 28).offset(x: w * 9 / 28)
            Color.white.frame(height: h * 4 / 20).offset(y: h * 8 / 20)
        }
    }

    private var germany: some View {
        VStack(spacing: 0) {
            Color.black
            Color(hex: 0xDD0000)
            Color(hex: 0xFFCE00)
        }
    }

    private var unitedKingdom: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            Color(hex: 0x012169)
            // Saltire, then the cross of St George over it.
            diagonals.stroke(.white, lineWidth: w * 4 / 28)
            diagonals.stroke(Color(hex: 0xC8102E), lineWidth: w * 2 / 28)
            cross(w, h).stroke(.white, lineWidth: w * 6.5 / 28)
            cross(w, h).stroke(Color(hex: 0xC8102E), lineWidth: w * 4 / 28)
        }
    }

    private var diagonals: Path {
        Path { path in
            path.move(to: .zero); path.addLine(to: CGPoint(x: width, y: height))
            path.move(to: CGPoint(x: width, y: 0)); path.addLine(to: CGPoint(x: 0, y: height))
        }
    }

    private func cross(_ w: CGFloat, _ h: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: w / 2, y: 0)); path.addLine(to: CGPoint(x: w / 2, y: h))
            path.move(to: CGPoint(x: 0, y: h / 2)); path.addLine(to: CGPoint(x: w, y: h / 2))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        FlagIcon(code: .dk)
        FlagIcon(code: .gb)
        FlagIcon(code: .de)
    }
    .padding()
}
