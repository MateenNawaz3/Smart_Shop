//
//  OfferRails.swift
//  SmartShop
//

import SwiftUI
import Combine

/// The full-width weekend banner carousel. Port of `WeekendOffers.tsx`.
///
/// The web auto-advances every 5 seconds and pauses on interaction. The same
/// behaviour is here, plus the `accessibilityReduceMotion` check the web does
/// via `prefers-reduced-motion` — auto-advancing carousels are a genuine
/// problem for people with vestibular disorders.
struct WeekendOffersRail: View {
    let offers: [Offer]
    var onSelect: (Int) -> Void

    @Environment(\.strings) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var scrolled: Int?
    @State private var isPaused = false

    private let advance = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(offers.enumerated()), id: \.element.id) { offset, offer in
                        Button { onSelect(offset) } label: {
                            Image(offer.image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                // Width must be pinned to the page *before*
                                // clipping: `scaledToFill` leaves the image far
                                // wider than the page, so clipping afterwards
                                // let the next banner bleed into this one.
                                .containerRelativeFrame(.horizontal)
                                .clipped()
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .accessibilityLabel(t(offer.altKey))
                        .id(offset)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrolled)
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: Theme.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.field)
                    .strokeBorder(Theme.Colors.lime.opacity(0.6), lineWidth: 2)
            }
            .onChange(of: scrolled) { _, new in
                if let new { index = new; isPaused = true }
            }

            PageDots(count: offers.count, index: $index)
        }
        .onChange(of: index) { _, new in
            guard scrolled != new else { return }
            withAnimation(.easeInOut(duration: 0.4)) { scrolled = new }
        }
        .onReceive(advance) { _ in
            guard !isPaused, !reduceMotion, offers.count > 1 else { return }
            index = (index + 1) % offers.count
        }
    }
}

/// This week's favourites — a square-card rail. Port of `OfferCarousel.tsx`.
struct WeeklyOffersRail: View {
    let offers: [Offer]
    var onSelect: (Int) -> Void

    @Environment(\.strings) private var t

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(Array(offers.enumerated()), id: \.element.id) { offset, offer in
                    Button { onSelect(offset) } label: {
                        Image(offer.image)
                            .resizable()
                            .scaledToFit()
                            .padding(Theme.Spacing.sm)
                            .frame(width: 190, height: 190)
                            .background(.white, in: .rect(cornerRadius: Theme.Radius.field))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.field)
                                    .strokeBorder(Theme.Colors.lime.opacity(0.6), lineWidth: 2)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(t("home.showOfferImage"))
                }
            }
            .scrollTargetLayout()
            // Content is inset rather than the ScrollView being padded, so cards
            // scroll edge to edge instead of being clipped at the margin.
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

/// Shared pip row: the active dot widens into a bar.
struct PageDots: View {
    let count: Int
    @Binding var index: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<count, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? Theme.Colors.green : Theme.Colors.green.opacity(0.25))
                    .frame(width: dot == index ? 24 : 8, height: 8)
                    .onTapGesture { index = dot }
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .accessibilityHidden(true)
    }
}
