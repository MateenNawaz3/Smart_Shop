//
//  GuestLanguageView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/gaest.tsx` — the language chooser that starts guest mode.
///
/// This is the entry point to tourist mode, so the language question comes
/// first: everything past here is content a visitor has to be able to read.
struct GuestLanguageView: View {
    @Environment(LanguageStore.self) private var languages
    @Environment(DeviceState.self) private var device
    @Environment(\.strings) private var t
    @Environment(\.dismiss) private var dismiss

    /// Pushed once a language is chosen.
    @Binding var path: [GuestRoute]

    var body: some View {
        AppScreen(ovals: BrandOvals(variant: .spread, tone: .light)) {
            VStack(spacing: 0) {
                AppLogo(size: .large)
                    .padding(.top, Theme.Spacing.lg)

                Spacer()

                VStack(spacing: Theme.Spacing.sm) {
                    Text(t("guestLang.title"))
                        .font(Theme.display(.title))
                        .multilineTextAlignment(.center)
                    Text(t("guestLang.subtitle"))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Theme.Spacing.md) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            choose(language)
                        } label: {
                            // Flag pinned left, label centred — the web's
                            // `absolute left-8` inside a centred flex row.
                            Text(language.native)
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .leading) {
                                    FlagIcon(code: language.flag)
                                        .padding(.leading, Theme.Spacing.xl)
                                }
                        }
                        .buttonStyle(LanguageChoiceButtonStyle())
                        .accessibilityLabel(language.native)
                    }
                }
                .padding(.top, Theme.Spacing.xl)

                Spacer()

                Button(t("common.back")) { dismiss() }
                    .buttonStyle(.brandLink)
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
        .navigationBarBackButtonHidden()
    }

    private func choose(_ language: AppLanguage) {
        languages.select(language)
        device.startGuest()
        path.append(.hub)
    }
}

/// White pill on the green canvas, used only by the language chooser.
private struct LanguageChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.title3, weight: .bold))
            .foregroundStyle(Theme.Colors.green)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(.white.opacity(configuration.isPressed ? 1 : 0.95), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @State var path: [GuestRoute] = []
    NavigationStack {
        GuestLanguageView(path: $path)
    }
    .environment(LanguageStore())
    .environment(DeviceState())
}
