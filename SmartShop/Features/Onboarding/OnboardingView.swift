//
//  OnboardingView.swift
//  SmartShop
//

import SwiftUI

/// The four-slide welcome guide shown once after sign-up, with the store
/// picker on slide three. Port of `components/app/OnboardingGuide.tsx`.
struct OnboardingView: View {
    /// Called after the profile flag is written (or when skipped).
    var onFinish: () -> Void

    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var index = 0
    @State private var saving = false
    @State private var storeModel: MyStoreModel?

    private struct Slide {
        var image: ImageResource?
        var altKey: String?
        var titleKey: String
        var bodyKey: String
        var bullets = false
        var store = false
    }

    private let slides: [Slide] = [
        Slide(image: .butikFacade, altKey: "auth.onboarding.slide1.alt", titleKey: "auth.onboarding.slide1.title", bodyKey: "auth.onboarding.slide1.body"),
        Slide(image: .appPhone, altKey: "auth.onboarding.slide2.alt", titleKey: "auth.onboarding.slide2.title", bodyKey: "auth.onboarding.slide2.body", bullets: true),
        Slide(titleKey: "auth.onboarding.slide3.title", bodyKey: "auth.onboarding.slide3.body", store: true),
        Slide(image: .butikAabning, altKey: "auth.onboarding.slide4.alt", titleKey: "auth.onboarding.slide4.title", bodyKey: "auth.onboarding.slide4.body"),
    ]

    private var bullets: [String] {
        (0..<10).lazy.map { t("auth.onboarding.slide2.bullets.\($0)") }
            .prefix { !$0.hasPrefix("auth.onboarding.") }.map { $0 }
    }

    var body: some View {
        let slide = slides[index]
        let isLast = index == slides.count - 1
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let image = slide.image {
                            Image(image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 224)
                                .frame(maxWidth: .infinity)
                                .clipShape(.rect(cornerRadius: Theme.Radius.field))
                                .overlay { RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.lime.opacity(0.4)) }
                                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                                .padding(.top, Theme.Spacing.md)
                                .accessibilityLabel(slide.altKey.map { t($0) } ?? "")
                        }
                        Text(t(slide.titleKey))
                            .font(Theme.display(.title))
                            .foregroundStyle(Theme.Colors.green)
                            .padding(.top, 32)
                        Text(t(slide.bodyKey))
                            .font(Theme.body(.subheadline))
                            .lineSpacing(3)
                            .foregroundStyle(Theme.Colors.green.opacity(0.75))
                            .padding(.top, 12)
                        if slide.bullets {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(bullets, id: \.self) { b in
                                    HStack(alignment: .top, spacing: 12) {
                                        Ellipse().fill(Theme.Colors.lime).frame(width: 14, height: 10).padding(.top, 5)
                                        Text(b).font(Theme.body(.subheadline)).foregroundStyle(Theme.Colors.green.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.top, 20)
                        }
                        if slide.store, let storeModel {
                            StorePicker(model: storeModel).padding(.top, Theme.Spacing.lg)
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                    .id(index)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .animation(.easeOut(duration: 0.28), value: index)
                .gesture(
                    DragGesture(minimumDistance: 45).onEnded { value in
                        go(value.translation.width < 0 ? index + 1 : index - 1)
                    }
                )

                footer(isLast: isLast)
            }
        }
        .task {
            if storeModel == nil {
                let model = MyStoreModel(profiles: environment.profileService)
                storeModel = model
                await model.load()
            }
        }
    }

    private var header: some View {
        HStack {
            Group {
                if index > 0 {
                    Button { go(index - 1) } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Colors.green)
                            .rotationEffect(.degrees(8))
                            .frame(width: 56, height: 40)
                            .background(Theme.Colors.green.opacity(0.1), in: .ellipse)
                    }
                    .accessibilityLabel(t("auth.onboarding.back"))
                }
            }
            .frame(width: 64, alignment: .leading)
            Spacer()
            AppLogo(size: .small, plate: false)
            Spacer()
            Button(t("auth.onboarding.skip")) { Task { await finish() } }
                .font(Theme.body(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.Colors.green.opacity(0.6))
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
    }

    private func footer(isLast: Bool) -> some View {
        HStack {
            HStack(spacing: 8) {
                ForEach(slides.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Theme.Colors.green : Theme.Colors.green.opacity(0.25))
                        .frame(width: i == index ? 28 : 10, height: 10)
                        .onTapGesture { go(i) }
                        .accessibilityLabel("\(t("auth.onboarding.slideAriaLabel")) \(i + 1)")
                }
            }
            .animation(.easeOut(duration: 0.2), value: index)
            Spacer()
            if isLast {
                Button(saving ? t("auth.onboarding.wait") : t("auth.onboarding.done")) { Task { await finish() } }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.lime))
                    .disabled(saving)
            } else {
                Button(t("auth.onboarding.next")) { go(index + 1) }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private func go(_ next: Int) {
        index = min(slides.count - 1, max(0, next))
    }

    private func finish() async {
        saving = true
        try? await environment.profileService.setOnboardingDone()
        saving = false
        onFinish()
    }
}
