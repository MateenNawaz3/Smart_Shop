//
//  OtpSection.swift
//  SmartShop
//

import SwiftUI

/// One-time-code card for phone or email. Port of `PhoneOtpSection.tsx` and
/// `EmailOtpSection.tsx`, which differ only in copy and the destination field.
struct OtpSection: View {
    enum Kind { case phone, email }
    enum Tone { case light, dark }

    let kind: Kind
    var tone: Tone = .light
    /// Pre-filled destination and current verified state from the profile.
    var initialDestination = ""
    var alreadyVerified = false
    var onVerified: () -> Void = {}
    /// The address or number that was just verified. The sign-up wizard needs
    /// the email to register with, and only this view knows what was typed.
    var onVerifiedDestination: (String) -> Void = { _ in }

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var destination = ""
    @State private var code = ""
    @State private var demoCode: String?
    @State private var sent = false
    @State private var busy = false
    @State private var error: String?
    @State private var done = false
    @State private var seeded = false

    private var k: String { kind == .phone ? "otp.otp" : "emailOtp" }
    private var dark: Bool { tone == .dark }
    private var fg: Color { dark ? .white : Theme.Colors.green }
    private var fgSoft: Color { dark ? .white.opacity(0.75) : Theme.Colors.green.opacity(0.7) }

    var body: some View {
        Group {
            if done || alreadyVerified {
                verifiedCard
            } else {
                form
            }
        }
        .onAppear {
            if !seeded { destination = initialDestination; seeded = true }
        }
        .onChange(of: initialDestination) { _, new in if destination.isEmpty { destination = new } }
    }

    private var card: some ShapeStyle {
        dark ? AnyShapeStyle(.white.opacity(0.05)) : AnyShapeStyle(Theme.Colors.lime.opacity(0.1))
    }

    private var verifiedCard: some View {
        HStack(spacing: 12) {
            OvalIcon(systemName: "checkmark.seal.fill", background: Theme.Colors.lime, size: CGSize(width: 56, height: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text(t("\(k).title")).font(Theme.display(.title2, weight: .bold)).foregroundStyle(fg)
                Text("\(t("\(k).verified")) \(destination)").font(Theme.body(.subheadline)).foregroundStyle(fgSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(card, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay { if dark { RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(.white.opacity(0.15)) } }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                OvalIcon(systemName: kind == .phone ? "iphone" : "envelope", background: Theme.Colors.lime, size: CGSize(width: 56, height: 44))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(t("\(k).title")).font(Theme.display(.title2, weight: .bold)).foregroundStyle(fg)
                        Text(t("\(k).demoBadge"))
                            .font(Theme.body(.caption2, weight: .bold)).textCase(.uppercase).tracking(0.6)
                            .foregroundStyle(Theme.Colors.lime)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .overlay { Capsule().strokeBorder(Theme.Colors.lime) }
                    }
                    Text(t("\(k).intro")).font(Theme.body(.subheadline)).foregroundStyle(fgSoft)
                }
            }

            BrandTextField(
                label: t(kind == .phone ? "otp.otp.phoneLabel" : "emailOtp.emailLabel"),
                text: $destination,
                contentType: kind == .phone ? .telephoneNumber : .emailAddress,
                keyboard: kind == .phone ? .phonePad : .emailAddress,
                autocapitalization: .never,
                tone: dark ? .onGreen : .onLight
            )

            if !sent {
                Button(busy ? t("\(k).sending") : t("\(k).send")) { Task { await send() } }
                    .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                    .disabled(busy)
            } else {
                if let demoCode {
                    VStack(spacing: 2) {
                        Text(t("\(k).demoCodeLabel"))
                            .font(Theme.body(.caption, weight: .semibold)).textCase(.uppercase).tracking(0.6)
                        Text(demoCode).font(Theme.display(.title2)).tracking(10)
                    }
                    .foregroundStyle(fg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.lime.opacity(0.15), in: .rect(cornerRadius: Theme.Radius.field))
                    .overlay { RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.lime.opacity(0.5)) }
                    .accessibilityIdentifier("otpDemoCode")
                }
                BrandTextField(
                    label: t("\(k).codeLabel"), placeholder: t("\(k).codePlaceholder"),
                    text: Binding(get: { code }, set: { code = String($0.filter(\.isNumber).prefix(6)) }),
                    contentType: .oneTimeCode, keyboard: .numberPad, tone: dark ? .onGreen : .onLight
                )
                Button(busy ? t("\(k).verifying") : t("\(k).verify")) { Task { await verify() } }
                    .buttonStyle(WidePillButtonStyle(background: Theme.Colors.lime))
                    .disabled(busy)
                Button(t("\(k).resend")) { Task { await send() } }
                    .font(Theme.body(.subheadline, weight: .semibold)).foregroundStyle(fg).underline()
                    .frame(maxWidth: .infinity)
                    .disabled(busy)
            }

            if let error {
                Text(error).font(Theme.body(.subheadline)).foregroundStyle(dark ? .white : Theme.Colors.red)
            }
            Text(t("\(k).demoNote")).font(Theme.body(.caption)).foregroundStyle(dark ? .white.opacity(0.6) : Theme.Colors.green.opacity(0.6))
        }
        .padding(20)
        .background(card, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay { if dark { RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(.white.opacity(0.15)) } }
    }

    private func send() async {
        error = nil
        let value = destination.trimmingCharacters(in: .whitespaces)
        let valid = kind == .phone ? value.wholeMatch(of: /\+?\d[\d\s-]{6,17}/) != nil : value.isValidEmail
        guard valid else { error = t(kind == .phone ? "otp.otp.errors.phone" : "emailOtp.errors.email"); return }
        busy = true
        defer { busy = false }
        do {
            let result = kind == .phone
                ? try await environment.otpService.sendPhoneCode(to: value)
                : try await environment.otpService.sendEmailCode(to: value)
            demoCode = result.demoCode
            sent = true
            code = ""
        } catch {
            self.error = t("\(k).errors.generic")
        }
    }

    private func verify() async {
        error = nil
        guard code.count == 6 else { error = t("\(k).errors.wrong"); return }
        busy = true
        defer { busy = false }
        do {
            let verdict = kind == .phone
                ? try await environment.otpService.verifyPhoneCode(code)
                : try await environment.otpService.verifyEmailCode(code)
            switch verdict {
            case .ok:
                done = true
                demoCode = nil
                onVerifiedDestination(destination.trimmingCharacters(in: .whitespaces))
                onVerified()
            case .expired: error = t("\(k).errors.expired")
            case .attempts: error = t("\(k).errors.attempts")
            case .wrong: error = t("\(k).errors.wrong")
            }
        } catch {
            self.error = t("\(k).errors.generic")
        }
    }
}
