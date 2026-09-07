//
//  PinPad.swift
//  SmartShop
//

import SwiftUI

/// Four-digit entry with an on-screen keypad.
///
/// The web's `PinPad` is an `<input>` styled as dots. On iOS a custom keypad is
/// the better choice: it stops the system keyboard covering half the screen,
/// and it means the PIN never passes through a text input that a third-party
/// keyboard extension could observe.
struct PinPad: View {
    @Environment(\.strings) private var t
    @Binding var value: String
    var length = 4
    var isDisabled = false

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            dots
            keypad
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var dots: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .fill(index < value.count ? Theme.Colors.lime : .white.opacity(0.25))
                    .frame(width: 18, height: 18)
                    .animation(.spring(duration: 0.2), value: value.count)
            }
        }
        // A row of circles means nothing to VoiceOver; describe the state.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("mitid.pinLabel"))
        .accessibilityValue(String(format: t("pin.entered"), value.count, length))
    }

    private var keypad: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: Theme.Spacing.lg) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 76, height: 76)
        } else {
            Button {
                tap(key)
            } label: {
                Text(key)
                    .font(Theme.display(.title, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(key == "⌫" ? t("pin.delete") : key)
        }
    }

    private func tap(_ key: String) {
        if key == "⌫" {
            guard !value.isEmpty else { return }
            value.removeLast()
        } else {
            guard value.count < length else { return }
            value.append(key)
        }
        // Matches the physical feel of the system passcode screen.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    @Previewable @State var pin = "12"
    ZStack {
        Theme.Colors.green.ignoresSafeArea()
        PinPad(value: $pin)
    }
}
