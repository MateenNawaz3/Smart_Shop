//
//  TokenRefresher.swift
//  SmartShop
//

import Foundation

/// Single-flight refresh through `POST /mobile/auth/refresh`.
///
/// Single-flight matters: on a cold launch the app fires several requests at
/// once, and without coordination each 401 would start its own refresh and the
/// losers would race — every one of them spending the same refresh token, and
/// all but one getting an answer that is already stale.
///
/// One refresh in flight; everyone else awaits it.
///
/// This talks to `URLSession` directly rather than going back through
/// `APIClient`, which keeps a refresh from being able to trigger a refresh.
actor TokenRefresher {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let tokens: any TokenStoring

    /// The refresh currently in flight, if any. Callers arriving mid-flight
    /// await this task instead of starting their own.
    private var inFlight: Task<String, any Error>?

    init(
        configuration: APIConfiguration = .current,
        session: URLSession = .shared,
        tokens: any TokenStoring
    ) {
        self.configuration = configuration
        self.session = session
        self.tokens = tokens
    }

    /// Returns a fresh access token, refreshing only if nobody else already is.
    ///
    /// `expiredToken` is the token the caller just had rejected. If the stored
    /// token has changed since then, somebody else's refresh already landed and
    /// this caller can simply use the new one.
    func freshToken(replacing expiredToken: String?) async throws -> String {
        if let current = tokens.accessToken, current != expiredToken {
            return current
        }

        if let inFlight {
            return try await inFlight.value
        }

        let task = Task<String, any Error> { try await performRefresh() }
        inFlight = task
        defer { inFlight = nil }

        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken = tokens.refreshToken else {
            tokens.clear()
            throw APIError.unauthorized(message: "No refresh token on this device")
        }

        var request = URLRequest(
            url: configuration.baseURL.appending(path: "/mobile/auth/refresh")
        )
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.api.encode(RefreshBody(refreshToken: refreshToken))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // A refresh that could not be *asked* is not a refusal. Surfacing it
            // as transport keeps a tunnel dropping out from signing the user
            // out of the app.
            throw APIError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let envelope = try? JSONDecoder.api.decode(APIEnvelope<RefreshData>.self, from: data)

        guard status == 200, let envelope, envelope.success, let session = envelope.data else {
            // A refusal here is terminal: the refresh token is spent, revoked,
            // or was invalidated by a password change. Sign the user out.
            tokens.clear()
            throw APIError.unauthorized(
                message: envelope?.message?.text ?? "Refresh refused"
            )
        }

        tokens.save(accessToken: session.accessToken, refreshToken: session.refreshToken)
        return session.accessToken
    }

    private struct RefreshBody: Encodable, Sendable {
        var refreshToken: String
    }

    /// The refresh token is usually absent from the reply, meaning the one we
    /// sent is still valid — hence optional rather than required.
    private struct RefreshData: Decodable, Sendable {
        var accessToken: String
        var refreshToken: String?
    }
}
