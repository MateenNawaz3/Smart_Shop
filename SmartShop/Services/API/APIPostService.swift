//
//  APIPostService.swift
//  SmartShop
//

import Foundation

/// `PostService` over the Mobile API. Public: the board works signed out.
///
/// `/posts` takes `?limit=` (at most 100) and has no cursor, so "all posts"
/// means the first hundred.
nonisolated struct APIPostService: PostService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func posts(limit: Int?) async throws -> [Post] {
        let request = APIRequest.get(
            "/mobile/posts",
            query: [URLQueryItem(name: "limit", value: String(min(limit ?? 100, 100)))],
            auth: .optional
        )
        let posts: [PostDTO] = try await client.send(request)
        return posts.map(Self.map)
    }

    func post(id: String) async throws -> Post {
        let post: PostDTO = try await client.send(.get("/mobile/posts/\(id)", auth: .optional))
        return Self.map(post)
    }

    /// The server translates by `x-localization`, so the response is already
    /// in the chosen language; it fills every slot of `Localized`. Changing
    /// language shows the new one on the next load.
    private static func map(_ dto: PostDTO) -> Post {
        func same(_ text: String) -> Post.Localized { Post.Localized(da: text, en: text, de: text) }
        // A media key that is not a URL yet is no picture, not a broken one.
        let media = AssetURL.resolve(dto.media).map { url in
            Post.Media(
                type: Self.isVideo(url) ? "video" : "image",
                src: url.lastPathComponent,
                alt: same(dto.title),
                url: url
            )
        }
        return Post(
            id: dto.id,
            date: dto.date,
            categoryKey: Post.Category(apiValue: dto.category),
            title: same(dto.title),
            body: same(dto.body ?? ""),
            media: media
        )
    }

    private static func isVideo(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v", "webm"].contains(url.pathExtension.lowercased())
    }
}
