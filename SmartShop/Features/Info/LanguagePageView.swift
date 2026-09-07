//
//  LanguagePageView.swift
//  SmartShop
//

import SwiftUI

/// Port of `routes/sprog.tsx` — the full-page language picker.
struct LanguagePageView: View {
    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages

    var onBack: () -> Void

    var body: some View {
        AppPageLayout(title: t("language.title"), description: t("language.description")) {
            GuestBackLink(title: t("common.backToMore"), action: onBack)
        } content: {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(AppLanguage.allCases) { language in
                    let active = language == languages.language
                    Button { languages.select(language) } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            FlagIcon(code: language.flag)
                            Text(language.native)
                                .font(Theme.display(.title3, weight: .bold))
                                .foregroundStyle(Theme.Colors.green)
                            Spacer(minLength: 0)
                            if active {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Theme.Colors.green)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .background(
                            Theme.Colors.lime.opacity(active ? 0.25 : 0.1),
                            in: .rect(cornerRadius: Theme.Radius.card)
                        )
                        .overlay {
                            if active {
                                RoundedRectangle(cornerRadius: Theme.Radius.card)
                                    .strokeBorder(Theme.Colors.lime, lineWidth: 2)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(language.native)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }

            Text(t("language.note"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .padding(.top, Theme.Spacing.md + 4)
        }
    }
}
