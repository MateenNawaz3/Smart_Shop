//
//  ArtworkImage.swift
//  SmartShop
//

import SwiftUI

/// Draws an `Artwork` the way the bundled images were drawn, with a
/// placeholder for the missing and failed cases.
///
/// On dev the placeholder is the normal case — the seeded image keys have no
/// files behind them — so it is designed as a real state, carrying the alt
/// text, rather than a grey box that looks like a bug.
struct ArtworkImage<Placeholder: View>: View {
    let artwork: Artwork
    var contentMode: ContentMode = .fit
    @ViewBuilder var placeholder: () -> Placeholder

    var body: some View {
        switch artwork {
        case .bundled(let resource):
            Image(resource).resizable().aspectRatio(contentMode: contentMode)
        case .remote(let url):
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: contentMode)
                case .failure:
                    placeholder()
                case .empty:
                    ProgressView().tint(Theme.Colors.green).frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    placeholder()
                }
            }
        case .missing:
            placeholder()
        }
    }
}

extension ArtworkImage where Placeholder == ArtworkPlaceholder {
    /// The standard placeholder: a lime-tinted panel with the alt text.
    init(_ artwork: Artwork, label: String, contentMode: ContentMode = .fit) {
        self.init(artwork: artwork, contentMode: contentMode) { ArtworkPlaceholder(label: label) }
    }
}

struct ArtworkPlaceholder: View {
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.Colors.green.opacity(0.35))
            if !label.isEmpty {
                Text(label)
                    .font(Theme.display(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.lime.opacity(0.12))
        .accessibilityElement(children: .combine)
    }
}
