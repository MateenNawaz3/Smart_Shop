//
//  BrandTextField.swift
//  SmartShop
//

import SwiftUI

/// White rounded field with a label above and an inline error below.
///
/// Bundling label + field + error into one component is what stops the error
/// message from being visually near the field but disconnected from it for a
/// screen reader. `accessibilityValue` ties them together.
struct BrandTextField: View {
    enum Tone { case onGreen, onLight }

    @Environment(\.strings) private var t
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var error: String?

    /// Set to `true` to render a secure field with a reveal toggle.
    var isSecure = false
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    /// `.onGreen` is the auth canvas; `.onLight` is the white inner pages.
    var tone: Tone = .onGreen
    var isDisabled = false

    @State private var isRevealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.body(.subheadline, weight: .semibold))
                .foregroundStyle(tone == .onLight ? Theme.Colors.green : .white)

            field
                .textFieldStyle(.plain)
                .font(Theme.body(.body))
                .foregroundStyle(isDisabled ? Theme.Colors.green.opacity(0.6) : Theme.Colors.ink)
                .disabled(isDisabled)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.trailing, isSecure ? 40 : 0)
                .frame(height: 56)
                .background(
                    isDisabled ? Theme.Colors.green.opacity(0.05) : .white,
                    in: .rect(cornerRadius: Theme.Radius.field)
                )
                .overlay {
                    // The web shows a lime focus ring; mirror it here.
                    RoundedRectangle(cornerRadius: Theme.Radius.field)
                        .strokeBorder(
                            error != nil ? Theme.Colors.red
                                : focused ? Theme.Colors.lime
                                : tone == .onLight ? Theme.Colors.green.opacity(0.2) : .white.opacity(0.2),
                            lineWidth: tone == .onLight && !focused && error == nil ? 1 : 2
                        )
                }
                .overlay(alignment: .trailing) { revealToggle }
                .focused($focused)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .animation(.easeOut(duration: 0.15), value: focused)

            if let error {
                Text(error)
                    .font(Theme.body(.footnote))
                    .foregroundStyle(tone == .onLight ? Theme.Colors.red : .white.opacity(0.9))
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(error ?? "")
        .animation(.easeOut(duration: 0.15), value: error)
    }

    @ViewBuilder
    private var field: some View {
        if isSecure && !isRevealed {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    @ViewBuilder
    private var revealToggle: some View {
        if isSecure {
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    // Not `.secondary`: that resolves against the inherited
                    // foreground, which is white here — invisible on the field.
                    .foregroundStyle(Theme.Colors.ink.opacity(0.45))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isRevealed ? t("login.hidePassword") : t("login.showPassword"))
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = "hemmelig"

    ZStack {
        Theme.Colors.green.ignoresSafeArea()
        VStack(spacing: 20) {
            BrandTextField(
                label: "Email", placeholder: "din@email.dk", text: $email,
                contentType: .emailAddress, keyboard: .emailAddress,
                autocapitalization: .never
            )
            BrandTextField(
                label: "Kodeord", text: $password, error: "Forkert kodeord",
                isSecure: true, contentType: .password
            )
        }
        .padding(24)
    }
}
