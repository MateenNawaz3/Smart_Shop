//
//  ShopGuideCard.swift
//  SmartShop
//

import SwiftUI

/// The four-step "how to shop here" guide on the home screen.
/// Port of `components/app/ShopGuide.tsx`.
///
/// Auto-advances every 6.5 s until it reaches the last step, stops the moment
/// the user takes over, and offers "watch again" at the end.
struct ShopGuideCard: View {
    @Environment(\.strings) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var playing = true

    private static let stepSeconds: Double = 6.5

    private var steps: [(title: String, body: String, hint: String)] {
        t.list("guide.steps", fields: ["title", "body", "hint"])
            .map { ($0["title"] ?? "", $0["body"] ?? "", $0["hint"] ?? "") }
    }

    var body: some View {
        let steps = steps
        let total = steps.count
        VStack(spacing: 0) {
            header(total: total)

            if !steps.isEmpty {
                ShopGuideStage(
                    scene: ShopGuideScene(rawValue: min(step, ShopGuideScene.allCases.count - 1)) ?? .openApp,
                    phoneLabel: t("guide.phoneLabel"),
                    doorLabel: t("guide.doorLabel"),
                    checkoutLabel: t("guide.checkoutLabel")
                )
                .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: step)

                let current = steps[min(step, total - 1)]
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(current.title)
                        .font(Theme.display(.headline, weight: .heavy))
                        .foregroundStyle(Theme.Colors.green)
                    Text(current.body)
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.Colors.ink.opacity(0.75))
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md - 4)
                .id(step)
                .transition(.opacity)
                .accessibilityElement(children: .combine)

                controls(total: total)
            }
        }
        .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.lime.opacity(0.5), lineWidth: 2)
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .shadow(color: Theme.Colors.green.opacity(0.12), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .task(id: "\(step)-\(playing)") {
            // The web's setTimeout: advance after STEP_MS while playing, and stop
            // playing once the last step is reached.
            guard playing, !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(Self.stepSeconds))
            guard !Task.isCancelled else { return }
            if step + 1 < total {
                withAnimation { step += 1 }
                if step >= total - 1 { playing = false }
            } else {
                playing = false
            }
        }
    }

    private func header(total: Int) -> some View {
        HStack {
            Text(t("guide.title"))
                .font(Theme.display(.headline, weight: .heavy))
                .lineLimit(1)
            Spacer()
            Text("\(step + 1)/\(total)")
                .font(Theme.body(.caption, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
                .accessibilityIdentifier("howToShopCounter")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.green)
    }

    private func go(_ next: Int, total: Int) {
        playing = false
        withAnimation { step = min(total - 1, max(0, next)) }
    }

    private func controls(total: Int) -> some View {
        let isLast = step == total - 1
        return HStack(spacing: Theme.Spacing.md) {
            circleButton(systemName: "arrow.left", style: .outline, label: t("guide.back")) {
                go(step - 1, total: total)
            }
            .disabled(step == 0)
            .opacity(step == 0 ? 0.4 : 1)

            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Theme.Colors.green : Theme.Colors.green.opacity(0.25))
                        .frame(width: i == step ? 24 : 10, height: 10)
                        .onTapGesture { go(i, total: total) }
                        .accessibilityLabel("\(t("guide.step")) \(i + 1)")
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.2), value: step)

            if isLast {
                circleButton(systemName: "arrow.counterclockwise", style: .green, label: t("guide.replay")) {
                    withAnimation { step = 0 }
                    playing = true
                }
            } else {
                circleButton(systemName: "arrow.right", style: .lime, label: t("guide.next")) {
                    go(step + 1, total: total)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    private enum CircleStyle { case outline, lime, green }

    private func circleButton(
        systemName: String, style: CircleStyle, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(style == .outline ? Theme.Colors.green : .white)
                .frame(width: 44, height: 44)
                .background {
                    switch style {
                    case .outline: Circle().strokeBorder(Theme.Colors.green.opacity(0.25), lineWidth: 2)
                    case .lime: Circle().fill(Theme.Colors.lime)
                    case .green: Circle().fill(Theme.Colors.green)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }
}
