//
//  HowToShopView.swift
//  SmartShop
//

import SwiftUI

/// Port of `src/routes/gaest_.saadan-handler-du.tsx` — a five-step walkthrough.
///
/// The web hand-rolls swipe detection with `onTouchStart`/`onTouchEnd` and a
/// 45px threshold. `TabView(.page)` gives the same gesture natively, with
/// rubber-banding, momentum and VoiceOver support already correct — so the
/// gesture code disappears entirely and only the content remains.
struct HowToShopView: View {
    @Binding var path: [GuestRoute]
    var onCreateAccount: () -> Void
    var onLogIn: () -> Void

    @Environment(\.strings) private var t
    @State private var index = 0
    @State private var scrolledStep: Int?

    private static let images: [ImageResource] = [
        .butikFacade, .butikAabning, .butikIndvendigt, .butikInterior, .appPhone
    ]

    private var steps: [(title: String, body: String)] {
        t.list("tourist.steps", fields: ["title", "body"])
            .map { ($0["title"] ?? "", $0["body"] ?? "") }
    }

    var body: some View {
        AppPageLayout(
            title: t("tourist.howtoTitle"),
            description: t("tourist.howtoDescription"),
        guest: true
        ) {
            GuestBackLink(title: t("tourist.backToStart")) { path.removeLast() }
        } content: {
            if !steps.isEmpty {
                carousel
                controls
            }
            GuestCta(onCreateAccount: onCreateAccount, onLogIn: onLogIn)
        }
    }

    /// A paging horizontal `ScrollView` rather than `TabView(.page)`.
    ///
    /// `TabView` in page style insists on the full screen width and ignores the
    /// content column it sits in, which pushed this page's text off the left
    /// edge. Scroll targets give the same paging gesture while respecting the
    /// layout it is placed in.
    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { offset, step in
                    page(offset: offset, step: step)
                        .containerRelativeFrame(.horizontal)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledStep)
        .frame(height: 430)
        .onChange(of: scrolledStep) { _, new in
            if let new { index = new }
        }
        .onChange(of: index) { _, new in
            // Tapping a pip or "Next" scrolls the carousel.
            guard scrolledStep != new else { return }
            withAnimation(.easeInOut(duration: 0.25)) { scrolledStep = new }
        }
    }

    private func page(offset: Int, step: (title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(Self.images[min(offset, Self.images.count - 1)])
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipped()
                .clipShape(.rect(cornerRadius: Theme.Radius.field))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.field)
                        .strokeBorder(Theme.Colors.lime.opacity(0.4), lineWidth: 1)
                }
                // The illustration repeats the heading, so it adds nothing for
                // a screen reader; the combined label below carries the content.
                .accessibilityHidden(true)

            Text(step.title)
                .font(Theme.display(.title2))
                .foregroundStyle(Theme.Colors.green)
            Text(step.body)
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.green.opacity(0.75))
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        // The source titles already begin with their step number ("1. Find the
        // store"), so no numbering is added here.
        .accessibilityLabel("\(step.title). \(step.body)")
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.md) {
            // The active pip widens into a bar, as on the web.
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(steps.indices, id: \.self) { step in
                    Capsule()
                        .fill(step == index
                              ? Theme.Colors.green
                              : Theme.Colors.green.opacity(0.25))
                        .frame(width: step == index ? 28 : 10, height: 10)
                        .onTapGesture { index = step }
                }
            }
            .accessibilityHidden(true)   // the TabView already announces pages

            Spacer()

            if index == steps.count - 1 {
                Button(t("tourist.done")) { path.removeLast() }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.lime))
            } else {
                Button(t("tourist.next")) { index += 1 }
                    .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }
}

/// Compact solid pill, used for inline actions on the light canvas.
struct PillButtonStyle: ButtonStyle {
    var background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(.subheadline, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .frame(height: 44)
            .background(background, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
