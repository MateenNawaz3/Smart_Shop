//
//  ShopGuideScenes.swift
//  SmartShop
//

import SwiftUI

/// The four animated scenes of the home screen guide.
/// Port of `components/app/ShopGuideScenes.tsx` and its `guide-*` keyframes.
///
/// Everything is drawn with shapes so it scales crisply, and each looping
/// animation is driven by one `phase` value so the scenes stay in step with
/// the web's 4 s cycle. All motion is disabled under Reduce Motion.
enum ShopGuideScene: Int, CaseIterable {
    case openApp, door, shelf, checkout
}

struct ShopGuideStage: View {
    let scene: ShopGuideScene
    let phoneLabel: String
    let doorLabel: String
    let checkoutLabel: String

    var body: some View {
        ZStack {
            Theme.Colors.cream
            Group {
                switch scene {
                case .openApp: SceneOpenApp(label: phoneLabel)
                case .door: SceneDoor(label: doorLabel)
                case .shelf: SceneShelf()
                case .checkout: SceneCheckout(label: checkoutLabel)
                }
            }
            .id(scene)
            .transition(.opacity.combined(with: .offset(y: 14)))
        }
        .frame(height: 190)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Building blocks

/// A looping 0→1 driver. `duration` is the full cycle length.
private struct Loop<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var duration: Double
    @ViewBuilder var content: (Double) -> Content

    var body: some View {
        if reduceMotion {
            content(0.6)
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: duration) / duration
                content(t)
            }
        }
    }
}

/// Piecewise-linear keyframe helper: `keyframes` is [(time 0…1, value)].
private func kf(_ t: Double, _ keyframes: [(Double, Double)]) -> Double {
    guard let first = keyframes.first else { return 0 }
    if t <= first.0 { return first.1 }
    for (a, b) in zip(keyframes, keyframes.dropFirst()) where t <= b.0 {
        let span = b.0 - a.0
        let p = span == 0 ? 1 : (t - a.0) / span
        // ease in-out
        let e = p * p * (3 - 2 * p)
        return a.1 + (b.1 - a.1) * e
    }
    return keyframes.last!.1
}

private struct PhoneFrame<Screen: View>: View {
    var size: CGSize = CGSize(width: 62, height: 120)
    @ViewBuilder var screen: Screen

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.28)
                .fill(Theme.Colors.ink)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 10)
            RoundedRectangle(cornerRadius: size.width * 0.22)
                .fill(.white)
                .padding(4)
                .overlay {
                    screen
                        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.22))
                        .padding(4)
                }
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: size.width * 0.45, height: 5)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 7)
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct AppScreen_: View {
    var body: some View {
        ZStack {
            Theme.Colors.green
            VStack(spacing: 5) {
                Image(.logo).resizable().scaledToFit()
                    .frame(width: 22, height: 22)
                    .padding(6)
                    .background(.white, in: .rect(cornerRadius: 8))
                Capsule().fill(.white.opacity(0.4)).frame(width: 30, height: 4)
                Capsule().fill(.white.opacity(0.25)).frame(width: 22, height: 4)
            }
        }
    }
}

private struct NfcReader: View {
    var caption: String
    var ledOn: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(caption)
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 46, height: 66)
        .background(Theme.Colors.green, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.Colors.green.opacity(0.15), lineWidth: 4)
                .padding(-4)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(ledOn ? Theme.Colors.lime : Theme.Colors.orange.opacity(0.9))
                .frame(width: 7, height: 7)
                .shadow(color: ledOn ? Theme.Colors.lime.opacity(0.7) : .clear, radius: 5)
                .padding(5)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
    }
}

private struct NfcWaves: View {
    var t: Double

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let local = ((t - Double(i) * 0.11) + 1).truncatingRemainder(dividingBy: 1)
                Circle()
                    .strokeBorder(Theme.Colors.lime.opacity(0.7), lineWidth: 3)
                    .frame(width: 64, height: 64)
                    .scaleEffect(0.35 + 1.1 * local)
                    .opacity(local < 0.25 ? local / 0.25 * 0.95 : 0.95 * (1 - (local - 0.25) / 0.75))
            }
        }
    }
}

/// Phone sliding in to a reader, with waves and LED. Shared by door and checkout.
private struct PhoneToReader: View {
    var caption: String
    var t: Double

    var body: some View {
        let approach = kf(t, [(0, 0), (0.35, 1), (0.72, 1), (1, 0)])
        HStack(spacing: -2) {
            PhoneFrame(size: CGSize(width: 50, height: 96)) { AppScreen_() }
                .rotationEffect(.degrees(-8 * (1 - approach)))
                .offset(x: -26 + 30 * approach)
                .zIndex(1)
            ZStack {
                NfcWaves(t: t)
                NfcReader(caption: caption, ledOn: t > 0.4 && t < 0.8)
            }
        }
    }
}

private struct SceneLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.body(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.Colors.green.opacity(0.7))
    }
}

// MARK: - Scenes

/// Step 1: a finger taps the Smart Shop icon and the app opens.
private struct SceneOpenApp: View {
    let label: String

    var body: some View {
        Loop(duration: 3.6) { t in
            VStack(spacing: 10) {
                PhoneFrame(size: CGSize(width: 76, height: 150)) {
                    ZStack {
                        // Home screen
                        LinearGradient(colors: [Theme.Colors.cream, .white], startPoint: .top, endPoint: .bottom)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                            ForEach(0..<6, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 5).fill(Theme.Colors.ink.opacity(0.1)).frame(height: 18)
                            }
                            Color.clear.frame(height: 18)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Theme.Colors.green)
                                .frame(height: 18)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.Colors.lime, lineWidth: 2)
                                }
                                .overlay { Image(.logo).resizable().scaledToFit().frame(width: 12, height: 12) }
                        }
                        .padding(8)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .opacity(kf(t, [(0, 1), (0.35, 1), (0.5, 0), (1, 0)]))
                        .scaleEffect(kf(t, [(0, 1), (0.35, 1), (0.5, 1.08), (1, 1.08)]))

                        // App open
                        AppScreen_()
                            .opacity(kf(t, [(0, 0), (0.4, 0), (0.55, 1), (0.92, 1), (1, 0)]))
                            .scaleEffect(kf(t, [(0, 1.06), (0.4, 1.06), (0.55, 1), (0.92, 1), (1, 1.06)]))
                    }
                }
                .overlay(alignment: .top) {
                    // Fingertip
                    Circle()
                        .fill(Theme.Colors.ink.opacity(0.1))
                        .strokeBorder(Theme.Colors.ink.opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .offset(x: 14, y: 52 + kf(t, [(0, 14), (0.3, 0), (1, 0)]))
                        .opacity(kf(t, [(0, 0), (0.15, 1), (0.3, 1), (0.45, 0), (1, 0)]))
                }
                SceneLabel(text: label)
            }
        }
    }
}

/// Step 2: the phone is held to the reader and the sliding door opens.
private struct SceneDoor: View {
    let label: String

    var body: some View {
        Loop(duration: 4) { t in
            let open = kf(t, [(0, 0), (0.4, 0), (0.55, 1), (0.85, 1), (1, 0)])
            HStack(alignment: .bottom, spacing: 16) {
                // Store door
                VStack(spacing: 0) {
                    Text("SMART SHOP 24-7")
                        .font(.system(size: 7, weight: .bold)).tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 18)
                        .background(Theme.Colors.green)
                    ZStack {
                        Theme.Colors.cream
                        HStack(alignment: .bottom, spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.lime.opacity(0.4)).frame(width: 14, height: 30)
                            RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.lime.opacity(0.3)).frame(width: 14, height: 46)
                            Spacer()
                            RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.lime.opacity(0.4)).frame(width: 14, height: 38)
                        }
                        .padding(8)
                        GeometryReader { geo in
                            let half = geo.size.width / 2
                            HStack(spacing: 0) {
                                Rectangle().fill(.white.opacity(0.85))
                                    .overlay(alignment: .trailing) { Theme.Colors.green.opacity(0.25).frame(width: 1) }
                                    .frame(width: half)
                                    .offset(x: -half * 0.96 * open)
                                Rectangle().fill(.white.opacity(0.85))
                                    .overlay(alignment: .leading) { Theme.Colors.green.opacity(0.25).frame(width: 1) }
                                    .frame(width: half)
                                    .offset(x: half * 0.96 * open)
                            }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 6))
                    .padding(6)
                }
                .frame(width: 128, height: 150)
                .background(.white)
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Colors.green, lineWidth: 4) }
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                VStack(spacing: 10) {
                    PhoneToReader(caption: "SCAN", t: t)
                    SceneLabel(text: label)
                }
                .padding(.bottom, 8)
            }
            .padding(.bottom, 12)
        }
    }
}

/// Step 3: items on the shelves bob, and one drops into the basket.
private struct SceneShelf: View {
    private let rows: [[Int]] = [[0, 1, 2, 0], [2, 0, 1, 1], [1, 2, 0, 2]]

    var body: some View {
        Loop(duration: 2.4) { t in
            HStack(alignment: .bottom, spacing: 24) {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { r in
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(rows[r].indices, id: \.self) { i in
                                let local = ((t - Double(i + r) * 0.1) + 1).truncatingRemainder(dividingBy: 1)
                                shelfItem(kind: rows[r][i])
                                    .offset(y: -6 * sin(local * .pi))
                            }
                        }
                        .padding(.horizontal, 6).padding(.bottom, 2)
                        .overlay(alignment: .bottom) { Theme.Colors.green.frame(height: 4) }
                    }
                }
                .padding(.top, 6)
                .background(Theme.Colors.cream.opacity(0.6))
                .overlay(alignment: .top) { Theme.Colors.green.frame(height: 4) }
                .overlay(alignment: .leading) { Theme.Colors.green.frame(width: 4) }
                .overlay(alignment: .trailing) { Theme.Colors.green.frame(width: 4) }

                // Basket with a falling item
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.green)
                        .frame(width: 16, height: 20)
                        .rotationEffect(.degrees(-6 + 12 * kf(t, [(0, 0), (0.6, 1), (1, 1)])))
                        .offset(y: -100 + 52 * kf(t, [(0, 0), (0.6, 1), (1, 1)]))
                        .opacity(kf(t, [(0, 0), (0.15, 1), (0.6, 0), (1, 0)]))
                    VStack(spacing: -2) {
                        UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                            .strokeBorder(Theme.Colors.green, lineWidth: 4)
                            .frame(width: 48, height: 22)
                            .mask(alignment: .top) { Rectangle().frame(height: 22) }
                        BasketShape()
                            .fill(.white)
                            .overlay { BasketShape().stroke(Theme.Colors.green, lineWidth: 4) }
                            .overlay {
                                VStack(spacing: 14) {
                                    Theme.Colors.green.opacity(0.25).frame(height: 2)
                                    Theme.Colors.green.opacity(0.25).frame(height: 2)
                                }.padding(.top, 8).frame(maxHeight: .infinity, alignment: .top)
                            }
                            .frame(width: 96, height: 56)
                    }
                }
                .frame(width: 96, height: 112, alignment: .bottom)
            }
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func shelfItem(kind: Int) -> some View {
        switch kind {
        case 1: // bottle
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1).fill(Theme.Colors.green).frame(width: 6, height: 8)
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5)
                    .fill(Theme.Colors.lime).frame(width: 14, height: 32)
            }
        case 2: // box
            RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.green.opacity(0.85))
                .frame(width: 20, height: 28)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(Theme.Colors.cream.opacity(0.8)).frame(width: 12, height: 4)
                        Capsule().fill(Theme.Colors.cream.opacity(0.5)).frame(width: 8, height: 4)
                    }.padding(4)
                }
        default: // can
            RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.lime)
                .frame(width: 16, height: 24)
                .overlay(alignment: .top) { Theme.Colors.green.opacity(0.4).frame(height: 6).padding(.top, 8) }
        }
    }
}

private struct BasketShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Step 4: phone to the terminal, then the scanner beam and the receipt.
private struct SceneCheckout: View {
    let label: String

    var body: some View {
        Loop(duration: 4) { t in
            HStack(alignment: .bottom, spacing: 16) {
                VStack(spacing: 10) {
                    PhoneToReader(caption: "PAY", t: t)
                    SceneLabel(text: label)
                }
                .padding(.bottom, 20)

                // Self-checkout
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 6) {
                            Capsule().fill(Theme.Colors.green.opacity(0.4)).frame(width: 40, height: 6)
                            Capsule().fill(Theme.Colors.green.opacity(0.25)).frame(width: 56, height: 6)
                            Spacer()
                            Text("OK")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).frame(height: 20)
                                .background(Theme.Colors.lime, in: .rect(cornerRadius: 4))
                                .opacity(kf(t, [(0, 0.25), (0.55, 0.25), (0.7, 1), (0.95, 1), (1, 0.25)]))
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Theme.Colors.cream, in: .rect(cornerRadius: 4))
                        .padding(8)
                    }
                    .frame(width: 120, height: 104)
                    .background(.white)
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.green, lineWidth: 4) }
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(alignment: .leading) {
                        // Scanner beam
                        Capsule().fill(Theme.Colors.red.opacity(0.7))
                            .frame(width: 32, height: 2)
                            .offset(x: -4 + 6 * kf(t, [(0, 0), (0.3, 1), (0.6, 0), (1, 0)]), y: -20)
                            .opacity(kf(t, [(0, 0), (0.3, 1), (0.6, 0.2), (1, 0)]))
                    }
                    .overlay(alignment: .bottomLeading) {
                        // Receipt
                        UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 2)
                            .fill(.white)
                            .overlay { UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 2).strokeBorder(Theme.Colors.green.opacity(0.2)) }
                            .frame(width: 24, height: 26 * kf(t, [(0, 0), (0.45, 0), (0.7, 1), (0.95, 1), (1, 0)]))
                            .offset(x: 12, y: 26 * kf(t, [(0, 0), (0.45, 0), (0.7, 1), (0.95, 1), (1, 0)]) - 4)
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                        .fill(Theme.Colors.green.opacity(0.8))
                        .frame(width: 120, height: 32)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    VStack {
        ForEach(ShopGuideScene.allCases, id: \.self) {
            ShopGuideStage(scene: $0, phoneLabel: "Your phone", doorLabel: "The door", checkoutLabel: "The checkout")
        }
    }
}
