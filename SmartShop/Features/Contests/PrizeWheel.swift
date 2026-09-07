//
//  PrizeWheel.swift
//  SmartShop
//

import SwiftUI

/// The wheel itself. Rotation is decoration: the result comes from the server
/// and the wheel lands on a matching segment. Port of `PrizeWheel.tsx`.
struct PrizeWheel: View {
    struct Segment { var labelKey: String; var kind: SpinOutcome }

    /// Eight segments, alternating win and try again, as on the web.
    static let segments: [Segment] = [
        .init(labelKey: "wheel.segWin", kind: .win), .init(labelKey: "wheel.segRetry", kind: .retry),
        .init(labelKey: "wheel.segLose", kind: .lose), .init(labelKey: "wheel.segRetry", kind: .retry),
        .init(labelKey: "wheel.segWin", kind: .win), .init(labelKey: "wheel.segLose", kind: .lose),
        .init(labelKey: "wheel.segRetry", kind: .retry), .init(labelKey: "wheel.segLose", kind: .lose),
    ]

    /// Which segment kind to land on; nil keeps the wheel still.
    var target: SpinOutcome?
    /// Increments per spin so the same outcome can repeat.
    var spinCount: Int
    var onSettled: () -> Void
    var disabled: Bool
    var label: String
    var onSpin: () -> Void

    @Environment(\.strings) private var t
    @State private var rotation: Double = 0
    @State private var lastKey = ""

    private var seg: Double { 360 / Double(Self.segments.count) }

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                wheel
                    .rotationEffect(.degrees(rotation))
                // Pointer
                Triangle().fill(Theme.Colors.green).frame(width: 24, height: 20)
                    .frame(maxHeight: .infinity, alignment: .top).offset(y: -6)
                Circle().fill(.white).strokeBorder(Theme.Colors.green, lineWidth: 4).frame(width: 48, height: 48)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 320)
            .onChange(of: "\(target.map(\.rawValue) ?? "")-\(spinCount)") { _, key in
                guard let target, key != lastKey else { return }
                lastKey = key
                let pool = Self.segments.indices.filter { Self.segments[$0].kind == target }
                let pick = pool.randomElement() ?? 0
                let landing = 360.0 * 6 - (Double(pick) * seg + seg / 2)
                let current = rotation.truncatingRemainder(dividingBy: 360)
                let next = rotation + ((landing - current) + 360).truncatingRemainder(dividingBy: 360) + 360 * 5
                withAnimation(.timingCurve(0.17, 0.67, 0.12, 0.99, duration: 4.2)) { rotation = next }
                Task {
                    try? await Task.sleep(for: .seconds(4.3))
                    onSettled()
                }
            }

            Button(label, action: onSpin)
                .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                .frame(maxWidth: 320)
                .disabled(disabled)
                .opacity(disabled ? 0.5 : 1)
        }
    }

    private var wheel: some View {
        ZStack {
            ForEach(Self.segments.indices, id: \.self) { i in
                let color: Color = Self.segments[i].kind == .win ? Theme.Colors.lime
                    : i % 2 == 0 ? Theme.Colors.green : Theme.Colors.green.mix(with: .white, by: 0.22)
                Wedge(start: .degrees(Double(i) * seg - 90), end: .degrees(Double(i + 1) * seg - 90))
                    .fill(color)
            }
            GeometryReader { geo in
                let r = geo.size.width / 2
                ForEach(Self.segments.indices, id: \.self) { i in
                    let angle = Double(i) * seg + seg / 2
                    Text(t(Self.segments[i].labelKey))
                        .font(Theme.display(.caption, weight: .heavy)).textCase(.uppercase).tracking(0.8)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .offset(y: -r * 0.68)
                        .rotationEffect(.degrees(angle))
                        .position(x: r, y: r)
                }
            }
        }
        .clipShape(.circle)
        .overlay { Circle().strokeBorder(Theme.Colors.green, lineWidth: 6) }
        .shadow(color: .black.opacity(0.3), radius: 24, y: 16)
        .accessibilityHidden(true)
    }
}

private struct Wedge: Shape {
    var start: Angle
    var end: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: rect.width / 2, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
