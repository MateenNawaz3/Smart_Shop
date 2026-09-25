//
//  BulletinBoardList.swift
//  SmartShop
//

import SwiftUI
import AVKit

/// News, upcoming openings and photos. Port of `BulletinBoard.tsx`.
///
/// Images open in the shared lightbox; video posts play muted and looped.
///
/// Posts come from `postService`. On dev none of them has a picture, so the
/// cards are text-only there — which is a real card layout, not a fallback.
struct BulletinBoardList: View {
    var limit: Int?

    @Environment(LanguageStore.self) private var languages
    @Environment(\.strings) private var t
    @Environment(AppEnvironment.self) private var environment

    @State private var posts: [Post] = []
    @State private var failed = false
    @State private var lightbox: Int?

    private var images: [LightboxImage] {
        posts.compactMap { post in
            guard post.media?.type == "image", let artwork = post.media?.artwork else { return nil }
            return LightboxImage(id: post.id, artwork: artwork, label: post.media?.alt(languages.language) ?? "")
        }
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 320), spacing: 20)],
            spacing: 20
        ) {
            ForEach(posts) { post in
                card(for: post)
            }
        }
        .overlay(alignment: .topLeading) {
            if failed && posts.isEmpty {
                Text(t("home.postsLoadError"))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.6))
            }
        }
        .lightbox(images: images, index: $lightbox)
        .task {
            do {
                posts = try await environment.postService.posts(limit: limit)
                failed = false
            } catch {
                failed = true
            }
        }
    }

    private func card(for post: Post) -> some View {
        let language = languages.language

        return VStack(alignment: .leading, spacing: 0) {
            if post.media?.type == "image", let artwork = post.media?.artwork {
                Button {
                    lightbox = images.firstIndex { $0.id == post.id }
                } label: {
                    ArtworkImage(artwork, label: post.media?.alt(language) ?? "", contentMode: .fill)
                        .frame(height: 176)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .contentShape(.rect)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("\(t("home.showBulletinImage")): \(post.title(language))")
            } else if post.media?.type == "video", let url = post.media?.videoURL {
                LoopingVideo(url: url)
                    .frame(height: 176)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.green.opacity(0.05))
                    .accessibilityLabel(post.media?.alt(language) ?? "")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    if let category = post.categoryKey {
                        Text(t(category.labelKey))
                            .font(Theme.display(.caption, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.lime, in: .capsule)
                    }

                    if let date = post.publishedOn {
                        // `.formatted` renders in the app's chosen language, not
                        // the device locale, so a Dane reading German sees
                        // German month names.
                        Text(date.formatted(
                            Date.FormatStyle(date: .abbreviated)
                                .locale(language.locale)
                        ))
                        .font(Theme.body(.caption, weight: .medium))
                        .foregroundStyle(Theme.Colors.green.opacity(0.6))
                    }
                }

                Text(post.title(language))
                    .font(Theme.display(.title3, weight: .heavy))
                    .foregroundStyle(Theme.Colors.green)

                Text(post.body(language))
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.Colors.green.opacity(0.7))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(.white, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.green.opacity(0.1), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

/// Muted, looping, autoplaying video — the web's `<video muted loop autoPlay>`.
private struct LoopingVideo: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let item = AVPlayerItem(url: url)
                let queue = AVQueuePlayer()
                queue.isMuted = true
                looper = AVPlayerLooper(player: queue, templateItem: item)
                player = queue
                queue.play()
            }
            .onDisappear { player?.pause() }
    }
}
