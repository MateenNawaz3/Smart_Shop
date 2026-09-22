//
//  ContestsView.swift
//  SmartShop
//

import SwiftUI

/// The daily prize wheel and won gift cards. Port of `routes/_authenticated/konkurrencer.tsx`.
struct ContestsView: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var languages

    @State private var wins: [WheelWin] = []
    @State private var pending: SpinResult?
    @State private var spinning = false
    @State private var revealed: SpinResult?
    @State private var spinCount = 0
    @State private var busy = false
    @State private var error: String?

    private var blocked: Bool { revealed?.alreadySpun ?? false }

    var body: some View {
        AppPageLayout(title: t("wheel.pageTitle"), description: t("wheel.pageDescription")) {
            PrizeWheel(
                target: spinning ? pending?.outcome : nil,
                spinCount: spinCount,
                onSettled: settle,
                disabled: busy || spinning || blocked,
                label: spinning ? t("wheel.spinning") : blocked ? t("wheel.tryTomorrow")
                    : revealed?.outcome == .retry ? t("wheel.spinAgain") : t("wheel.spinWheel"),
                onSpin: { Task { await spin() } }
            )
            .frame(maxWidth: .infinity)

            if spinning {
                Text(t("wheel.goodLuck")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.md)
            }
            if let error {
                Text(error).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.red)
                    .frame(maxWidth: .infinity).padding(.top, Theme.Spacing.md)
            }
            if let revealed, !spinning {
                resultCard(revealed).padding(.top, Theme.Spacing.lg)
            }

            if !wins.isEmpty {
                Text(t("wheel.yourGiftCards"))
                    .font(Theme.display(.subheadline, weight: .bold)).textCase(.uppercase).tracking(0.8)
                    .foregroundStyle(Theme.Colors.green.opacity(0.6))
                    .padding(.top, 32).padding(.bottom, 12)
                VStack(spacing: 12) {
                    ForEach(wins) { win in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(t("wheel.giftCardAmount").replacingOccurrences(of: "{amount}", with: "\(win.prizeAmount)"), systemImage: "ticket")
                                    .font(Theme.display(.body, weight: .bold)).foregroundStyle(Theme.Colors.green)
                                Spacer()
                                Text(win.spinDate).font(Theme.body(.caption)).foregroundStyle(Theme.Colors.green.opacity(0.6))
                            }
                            BarcodeView(value: win.code)
                        }
                        .padding(20)
                        .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
                    }
                }
            }
        }
        .task {
            if let status = try? await environment.wheelService.status(), revealed == nil { revealed = status }
            wins = (try? await environment.wheelService.wins()) ?? []
        }
    }

    @ViewBuilder
    private func resultCard(_ r: SpinResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch r.outcome {
            case .win:
                Text(t("wheel.winTitle").replacingOccurrences(of: "{amount}", with: "\(r.prizeAmount.orZero)"))
                    .font(Theme.display(.title2)).foregroundStyle(Theme.Colors.green)
                Text(t("wheel.winDesc")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.75)).lineSpacing(3)
                if let code = r.code {
                    BarcodeView(value: code).padding(.top, 8)
                }
            case .retry:
                Text(t("wheel.retryTitle")).font(Theme.display(.title2)).foregroundStyle(Theme.Colors.green)
                Text(t("wheel.retryDesc")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.75))
            case .lose:
                Text(t("wheel.loseTitle")).font(Theme.display(.title2)).foregroundStyle(Theme.Colors.green)
                Text(t("wheel.loseDesc")).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(r.won ? Theme.Colors.lime.opacity(0.15) : Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func spin() async {
        error = nil
        busy = true
        defer { busy = false }
        do {
            let result = try await environment.wheelService.spin()
            if result.alreadySpun {
                revealed = result
                return
            }
            pending = result
            revealed = nil
            spinCount += 1
            spinning = true
        } catch {
            self.error = t("wheel.errorGeneric")
        }
    }

    private func settle() {
        withAnimation(.easeOut(duration: 0.3)) {
            revealed = pending
            spinning = false
        }
        Task { wins = (try? await environment.wheelService.wins()) ?? [] }
    }
}
