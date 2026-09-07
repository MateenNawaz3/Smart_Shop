//
//  OfferLightbox.swift
//  SmartShop
//

import SwiftUI

/// One image shown in the lightbox, with its spoken description.
struct LightboxImage: Identifiable, Hashable {
    var id: String
    var image: ImageResource
    var label: String
}

/// Full-screen image viewer with paging. Port of `OfferLightbox.tsx`.
///
/// Dark green backdrop, lime oval close and prev/next buttons, a white pip row
/// and tap-outside-to-close. `wide` letterboxes landscape banners.
struct OfferLightbox: View {
    let images: [LightboxImage]
    @Binding var index: Int?
    var wide = false

    @Environment(\.strings) private var t

    var body: some View {
        if let current = index, images.indices.contains(current) {
            ZStack {
                // color-mix(brand-green 88%, black) at 95%
                Theme.Colors.green.mix(with: .black, by: 0.12).opacity(0.95)
                    .ignoresSafeArea()
                    .onTapGesture { index = nil }

                TabView(selection: Binding(get: { current }, set: { index = $0 })) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { offset, item in
                        Image(item.image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: Theme.Radius.field))
                            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                            .padding(.horizontal, wide ? 8 : 28)
                            .padding(.vertical, 72)
                            .tag(offset)
                            .accessibilityLabel(item.label)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Close
                VStack {
                    HStack {
                        Spacer()
                        ovalButton(systemName: "xmark", label: t("home.lightboxClose")) { index = nil }
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)

                if images.count > 1 {
                    HStack {
                        ovalButton(systemName: "chevron.left", label: t("home.lightboxPrev")) {
                            index = (current - 1 + images.count) % images.count
                        }
                        Spacer()
                        ovalButton(systemName: "chevron.right", label: t("home.lightboxNext")) {
                            index = (current + 1) % images.count
                        }
                    }
                    .padding(.horizontal, 12)

                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(images.indices, id: \.self) { i in
                                Capsule()
                                    .fill(i == current ? .white : .white.opacity(0.4))
                                    .frame(width: i == current ? 24 : 8, height: 8)
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: current)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                    .accessibilityHidden(true)
                }
            }
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func ovalButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(8))
                .frame(width: 56, height: 40)
                .background(Theme.Colors.lime.opacity(0.9), in: .ellipse)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }
}

extension View {
    /// Presents `OfferLightbox` over the whole screen (tab bar included), as
    /// the web's `createPortal(document.body)` does, whenever `index` is set.
    func lightbox(images: [LightboxImage], index: Binding<Int?>, wide: Bool = false) -> some View {
        fullScreenCover(isPresented: Binding(
            get: { index.wrappedValue != nil },
            set: { if !$0 { index.wrappedValue = nil } }
        )) {
            OfferLightbox(images: images, index: index, wide: wide)
                .presentationBackground(.clear)
        }
        .transaction { $0.disablesAnimations = false }
    }
}

extension Offer {
    /// The lightbox entry for an offer, with its description resolved.
    func lightboxImage(_ t: Translator) -> LightboxImage {
        LightboxImage(id: id, image: image, label: t(altKey))
    }
}
