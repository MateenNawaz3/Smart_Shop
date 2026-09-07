//
//  HomeView.swift
//  SmartShop
//

import SwiftUI
import Supabase

/// Loads the signed-in user's first name for the greeting.
/// Port of `hooks/useProfileName.ts`.
@MainActor
@Observable
final class HomeModel {
    private(set) var firstName: String?
    private(set) var weekendOffers: [Offer] = []
    private(set) var weeklyOffers: [Offer] = []

    var weekendLightbox: Int?
    var weeklyLightbox: Int?

    private let profiles: any ProfileService
    private let offers: any OfferService

    init(profiles: any ProfileService, offers: any OfferService) {
        self.profiles = profiles
        self.offers = offers
    }

    func load() async {
        // Offers are local, so they resolve immediately; the name needs a round
        // trip. Running them concurrently means the rails are never gated on it.
        async let weekend = offers.weekendOffers()
        async let weekly = offers.weeklyOffers()
        async let name = profiles.firstName()

        weekendOffers = await weekend
        weeklyOffers = await weekly
        firstName = await name
    }
}

struct HomeView: View {
    @Binding var path: [HomeRoute]

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.strings) private var t

    @State private var model: HomeModel?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if let model {
                content(model)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil {
                model = HomeModel(
                    profiles: environment.profileService,
                    offers: environment.offerService
                )
            }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(_ model: HomeModel) -> some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ShopGuideCard()

                    WeekendOffersRail(offers: model.weekendOffers) {
                        model.weekendLightbox = $0
                    }

                    weeklyOffers(model)

                    bulletinBoard
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        // Pinned above the scroll view: `safeAreaInset` places it outside the
        // scrolling content, so its background can genuinely run to the top
        // edge of the screen rather than being clipped to the safe area.
        .safeAreaInset(edge: .top, spacing: 0) {
            GreetingHeader(firstName: model.firstName)
        }
        .lightbox(
            images: model.weekendOffers.map { $0.lightboxImage(t) },
            index: $model.weekendLightbox,
            wide: true
        )
    }

    private func weeklyOffers(_ model: HomeModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeading(title: t("home.weeklyOffersTitle")) {
                Button { path.append(.offers) } label: {
                    Text(t("home.seeAllOffers"))
                        .font(Theme.body(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.Colors.green)
                        .underline()
                }
                .buttonStyle(.plain)
            }

            // The web's `linkToOffers`: a card on Home opens the offers page.
            WeeklyOffersRail(offers: model.weeklyOffers) { _ in path.append(.offers) }
                // Cancel the parent's inset so the rail scrolls edge to edge.
                .padding(.horizontal, -Theme.Spacing.lg)
        }
    }

    private var bulletinBoard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeading(title: t("home.bulletinBoardTitle"))

            Text(t("home.bulletinBoardIntro"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.green.opacity(0.7))

            BulletinBoardList(limit: 2)

            Button(t("home.seeAllPosts")) { path.append(.posts) }
                .buttonStyle(PillButtonStyle(background: Theme.Colors.green))
                .padding(.top, Theme.Spacing.xs)
        }
    }
}

/// Lime bar, heading, optional trailing link — the home screen's section rule.
struct SectionHeading<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Capsule()
                .fill(Theme.Colors.lime)
                .frame(width: 6, height: 28)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.display(.title))
                .foregroundStyle(Theme.Colors.green)

            Spacer(minLength: Theme.Spacing.sm)
            accessory
        }
    }
}

extension SectionHeading where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
