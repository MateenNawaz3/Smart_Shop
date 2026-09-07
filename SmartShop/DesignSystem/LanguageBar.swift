//
//  LanguageBar.swift
//  SmartShop
//

import SwiftUI

/// The always-visible language switcher. Port of `GuestLanguageBar.tsx`.
///
/// Two tones, because it sits on both canvases: `.onGreen` for the auth and
/// welcome screens, `.onLight` for the guest content pages.
struct LanguageBar: View {
    enum Tone { case onGreen, onLight }

    var tone: Tone = .onGreen
    /// When true, labels appear only where they fit — the native equivalent of
    /// the web's `hidden sm:inline`. Flags alone on a phone, flags plus names
    /// on iPad or in landscape.
    var showsLabels = true

    @Environment(LanguageStore.self) private var languages
    @Environment(\.strings) private var t

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if showsLabels { row(labelled: true) }
            row(labelled: false)
        }
        // `children: .contain` keeps each pill individually focusable; a bare
        // `.accessibilityLabel` here would replace all three labels with this one.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("tourist.changeLanguage"))
    }

    private func row(labelled: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(AppLanguage.allCases) { language in
                pill(for: language, labelled: labelled)
            }
        }
    }

    private func pill(for language: AppLanguage, labelled: Bool) -> some View {
        let isActive = language == languages.language

        return Button {
            languages.select(language)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                FlagIcon(code: language.flag, width: 24)
                if labelled {
                    Text(language.native)
                        .font(Theme.body(.caption, weight: .semibold))
                        .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .foregroundStyle(foreground(isActive))
            .background(background(isActive), in: .capsule)
        }
        .buttonStyle(.plain)
        // A pressed/unpressed pill group is a picker, so say so rather than
        // leaving VoiceOver to announce three unrelated buttons.
        .accessibilityLabel(language.native)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    private func foreground(_ isActive: Bool) -> Color {
        switch tone {
        case .onGreen: isActive ? .white : .white.opacity(0.55)
        case .onLight: isActive ? .white : Theme.Colors.green.opacity(0.7)
        }
    }

    private func background(_ isActive: Bool) -> Color {
        switch tone {
        case .onGreen: isActive ? .white.opacity(0.18) : .white.opacity(0.07)
        case .onLight: isActive ? Theme.Colors.green : Theme.Colors.lime.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        ZStack {
            Theme.Colors.green
            LanguageBar(tone: .onGreen)
        }
        ZStack {
            Color.white
            LanguageBar(tone: .onLight)
        }
    }
    .environment(LanguageStore())
    .ignoresSafeArea()
}
