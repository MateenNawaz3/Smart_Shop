//
//  PostService.swift
//  SmartShop
//

import Foundation

/// The bulletin board: news, upcoming openings and pictures from recent ones.
nonisolated protocol PostService: Sendable {
    /// Newest first. `limit` caps the count; nil takes the server's default.
    func posts(limit: Int?) async throws -> [Post]
    func post(id: String) async throws -> Post
}

/// The bundled `posts.json`. Used by the UI tests and previews.
nonisolated struct BundledPostService: PostService {
    func posts(limit: Int?) async throws -> [Post] {
        limit.map(Post.latest) ?? Post.all
    }

    func post(id: String) async throws -> Post {
        guard let post = Post.all.first(where: { $0.id == id }) else {
            throw APIError.failure(code: "NOT_FOUND", message: "Post not found", status: 404)
        }
        return post
    }
}
