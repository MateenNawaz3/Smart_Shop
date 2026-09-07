//
//  OffersView.swift
//  SmartShop
//

import SwiftUI

/// All of this week's offers in a two-column grid. Port of `routes/_authenticated/tilbud.tsx`.
struct OffersView: View {
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var offers: [Offer] = []
    @State private var lightbox: Int?

    var body: some View {
        AppPageLayout(title: t("home.offersPageTitle")) {
            Text(t("home.weeklyOffersTitle"))
                .font(Theme.display(.title3, weight: .heavy))
                .foregroundStyle(Theme.Colors.green)
            Text(t("home.offersValidPeriod"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(offers.enumerated()), id: \.element.id) { offset, offer in
                    Button { lightbox = offset } label: {
                        Image(offer.image)
                            .resizable()
                            .scaledToFit()
                            .padding(Theme.Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(.white, in: .rect(cornerRadius: Theme.Radius.field))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.field)
                                    .strokeBorder(Theme.Colors.lime.opacity(0.6), lineWidth: 2)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("\(t("home.showOfferNumber")) \(offset + 1)")
                }
            }
            .padding(.top, Theme.Spacing.md)
        }
        .lightbox(images: offers.map { $0.lightboxImage(t) }, index: $lightbox)
        .task { offers = await environment.offerService.weeklyOffers() }
    }
}
