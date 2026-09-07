//
//  BrandOvals.swift
//  SmartShop
//

import SwiftUI

/// The decorative oval motif behind every auth screen.
///
/// Port of `components/app/BrandOvals.tsx`. The web positions each oval with
/// absolute Tailwind offsets; here the same layout is expressed as fractions
/// of the container via `GeometryReader`, so it scales from iPhone SE to iPad
/// instead of being pinned to pixel offsets.
struct BrandOvals: View {
    enum Variant { case spread, a, b, c, mid }
    enum Tone { case brand, light }

    var variant: Variant = .a
    var tone: Tone = .brand

    private var big: Color {
        Theme.Colors.lime.opacity(tone == .light ? 0.20 : 0.25)
    }
    private var small: Color {
        tone == .light ? .white.opacity(0.10) : Theme.Colors.green.opacity(0.15)
    }

    /// size (w, h), unit position of the centre, rotation, colour.
    private var shapes: [Oval] {
        switch variant {
        case .spread:
            [
                Oval(w: 240, h: 130, x: -0.05, y: 0.02, angle: -8, fill: big),
                Oval(w: 140, h: 80, x: 1.02, y: 0.18, angle: 6, fill: small),
                Oval(w: 200, h: 110, x: -0.10, y: 0.52, angle: 10, fill: small),
                Oval(w: 220, h: 120, x: 1.10, y: 0.74, angle: -6, fill: big),
                Oval(w: 140, h: 80, x: 0.15, y: 1.02, angle: 14, fill: small)
            ]
        case .a:
            [Oval(w: 220, h: 120, x: 0.0, y: 0.0, angle: -8, fill: big),
             Oval(w: 130, h: 74, x: 1.0, y: 0.2, angle: 6, fill: small)]
        case .b:
            [Oval(w: 220, h: 120, x: -0.05, y: 0.05, angle: -8, fill: big),
             Oval(w: 130, h: 74, x: 0.95, y: -0.02, angle: 6, fill: small)]
        case .c:
            [Oval(w: 220, h: 120, x: 1.0, y: -0.02, angle: -8, fill: big),
             Oval(w: 130, h: 74, x: 0.1, y: 0.25, angle: 6, fill: small)]
        case .mid:
            [Oval(w: 220, h: 120, x: -0.05, y: 0.5, angle: -8, fill: big),
             Oval(w: 130, h: 74, x: 1.0, y: 0.55, angle: 6, fill: small)]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(shapes.enumerated()), id: \.offset) { _, oval in
                Ellipse()
                    .fill(oval.fill)
                    .frame(width: oval.w, height: oval.h)
                    .rotationEffect(.degrees(oval.angle))
                    .position(
                        x: proxy.size.width * oval.x,
                        y: proxy.size.height * oval.y
                    )
            }
        }
        // Decorative only: hidden from VoiceOver and untouchable, exactly like
        // the web's `aria-hidden` + `pointer-events-none`.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Oval {
        let w, h, x, y, angle: CGFloat
        let fill: Color
    }
}

#Preview {
    ZStack {
        Theme.Colors.green
        BrandOvals(variant: .spread, tone: .light)
    }
    .ignoresSafeArea()
}
