//
//  AppPageLayout.swift
//  SmartShop
//

import SwiftUI

/// The inner-page shell shared by the guest section and the signed-in tabs.
/// Port of `components/app/AppPageLayout.tsx`.
///
/// White canvas, the green greeting header pinned at the top, an optional slot
/// above the title (back link, language bar), the lime-accented title with an
/// optional trailing action, the description, then the content. The bottom tab
/// bar is optional: guest pages render their own, the signed-in shell already
/// has one.
struct AppPageLayout<TopSlot: View, Action: View, Content: View>: View {
    let title: String
    var description: String?
    /// Shown in the greeting header when known.
    var firstName: String?
    /// Guest pages never show a name.
    var guest = false
    /// Rendered below the header, above the title.
    @ViewBuilder var topSlot: TopSlot
    /// Rendered at the trailing end of the title row.
    @ViewBuilder var action: Action
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    topSlot

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack(spacing: Theme.Spacing.md) {
                            Capsule()
                                .fill(Theme.Colors.lime)
                                .frame(width: 6, height: 28)
                                .accessibilityHidden(true)
                            Text(title)
                                .font(Theme.display(.title))
                                .foregroundStyle(Theme.Colors.green)
                            Spacer(minLength: Theme.Spacing.sm)
                            action
                        }
                        if let description {
                            Text(description)
                                .font(Theme.body(.subheadline))
                                .lineSpacing(3)
                                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                        }
                    }
                    .padding(.top, Theme.Spacing.sm)

                    content
                        .padding(.top, Theme.Spacing.sm)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            GreetingHeader(firstName: firstName, guest: guest)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }
}

extension AppPageLayout where Action == EmptyView {
    init(
        title: String,
        description: String? = nil,
        firstName: String? = nil,
        guest: Bool = false,
        @ViewBuilder topSlot: () -> TopSlot,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title, description: description, firstName: firstName, guest: guest,
            topSlot: topSlot, action: { EmptyView() }, content: content
        )
    }
}

extension AppPageLayout where TopSlot == EmptyView, Action == EmptyView {
    init(
        title: String,
        description: String? = nil,
        firstName: String? = nil,
        guest: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title, description: description, firstName: firstName, guest: guest,
            topSlot: { EmptyView() }, action: { EmptyView() }, content: content
        )
    }
}

/// The "back to guest home" link used at the top of every guest content page.
struct GuestBackLink: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "arrow.left")
                Text(title)
            }
            .font(Theme.body(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.Colors.green.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}

/// Rounded lime-tinted card, the inner pages' standard container
/// (`rounded-3xl bg-brand-lime/10 px-5 py-5`).
struct GuestCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.lime.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// The brand's oval icon badge (`.btn-oval` with the 8° tilt).
struct OvalIcon: View {
    let systemName: String
    var background: Color = Theme.Colors.green
    var foreground: Color = .white
    var size: CGSize = CGSize(width: 56, height: 40)

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size.height * 0.45, weight: .semibold))
            .foregroundStyle(foreground)
            .rotationEffect(.degrees(8))
            .frame(width: size.width, height: size.height)
            .background(background, in: .ellipse)
    }
}
