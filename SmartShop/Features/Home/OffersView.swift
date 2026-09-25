//
//  OffersView.swift
//  SmartShop
//

import SwiftUI

/// All of this week's offers in a two-column grid. Port of `routes/_authenticated/tilbud.tsx`.
///
/// The cells are the campaign offers from `GET /offers`. One with artwork is
/// drawn as the design draws it — the poster alone, opening in the lightbox.
/// One without artwork is still shown, as a card carrying its headline and
/// discount: the discount is the point, so it is never dropped for want of a
/// picture.
struct OffersView: View {
    @Environment(\.strings) private var t
    @Environment(LanguageStore.self) private var languages
    @Environment(AppEnvironment.self) private var environment

    @State private var offers: [CampaignOffer] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var lightbox: Int?

    /// Only offers with a picture can be enlarged.
    private var pictured: [CampaignOffer] { offers.filter { $0.artwork != .missing } }

    var body: some View {
        AppPageLayout(title: t("home.offersPageTitle")) {
            Text(t("home.weeklyOffersTitle"))
                .font(Theme.display(.title3, weight: .heavy))
                .foregroundStyle(Theme.Colors.green)
            Text(t("home.offersValidPeriod"))
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.Colors.green.opacity(0.7))
                .padding(.top, 2)

            if loaded && offers.isEmpty {
                Text(failed ? t("home.offersLoadError") : t("home.offersEmpty"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.6))
                    .padding(.top, Theme.Spacing.md)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(offers.enumerated()), id: \.element.id) { offset, offer in
                    cell(offer, number: offset + 1)
                }
            }
            .padding(.top, Theme.Spacing.md)
        }
        .lightbox(images: pictured.map(lightboxImage), index: $lightbox)
        .task { await load() }
    }

    private func load() async {
        do {
            offers = try await environment.offerService.campaignOffers()
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }

    @ViewBuilder
    private func cell(_ offer: CampaignOffer, number: Int) -> some View {
        if offer.artwork == .missing {
            textCard(offer)
        } else {
            Button { lightbox = pictured.firstIndex(of: offer) } label: {
                ArtworkImage(artwork: offer.artwork) { textCard(offer) }
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
            .accessibilityLabel(offer.headline.isEmpty ? "\(t("home.showOfferNumber")) \(number)" : offer.headline)
        }
    }

    /// The offer as words: discount badge, headline, code and end date.
    private func textCard(_ offer: CampaignOffer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let badge = discountBadge(offer.discount) {
                Text(badge)
                    .font(Theme.display(.title2, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Theme.Colors.lime, in: .capsule)
            }
            Text(offer.headline)
                .font(Theme.display(.subheadline, weight: .bold))
                .foregroundStyle(Theme.Colors.green)
                .lineLimit(3)
            if let body = offer.body, !body.isEmpty {
                Text(body)
                    .font(Theme.body(.caption))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            if let code = offer.code {
                Text("\(t("home.offerCode")): \(code)")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.Colors.green)
                    .textSelection(.enabled)
            }
            if let validTo = offer.validTo {
                Text(t("home.offerValidTo").replacingOccurrences(
                    of: "{date}",
                    with: validTo.formatted(Date.FormatStyle(date: .abbreviated).locale(languages.language.locale))
                ))
                .font(Theme.body(.caption2))
                .foregroundStyle(Theme.Colors.green.opacity(0.6))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(Theme.Colors.lime.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.field))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.field)
                .strokeBorder(Theme.Colors.lime.opacity(0.6), lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }

    /// `-20%` or `-20 kr.`; nothing for a discount this build cannot express.
    private func discountBadge(_ discount: CampaignOffer.Discount) -> String? {
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2))
            .locale(languages.language.locale)
        switch discount {
        case .percentage(let value): return "-\(value.formatted(number))%"
        case .amount(let value): return "-\(value.formatted(number)) kr."
        case .other: return nil
        }
    }

    private func lightboxImage(_ offer: CampaignOffer) -> LightboxImage {
        LightboxImage(id: offer.id, artwork: offer.artwork, label: offer.headline.isEmpty ? t("home.offerImageAlt") : offer.headline)
    }
}
