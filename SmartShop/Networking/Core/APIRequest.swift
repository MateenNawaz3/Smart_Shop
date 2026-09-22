//
//  APIRequest.swift
//  SmartShop
//

import Foundation

/// One value describing a call: method, path, query items, body, and whether it
/// needs a bearer token.
nonisolated struct APIRequest: Sendable {
    var method: HTTPMethod
    /// Path from the host root, leading slash included. Most paths carry the
    /// `/mobile` prefix, but `/health` deliberately does not.
    var path: String
    var query: [URLQueryItem] = []
    var body: Data?
    var auth: AuthRequirement = .required

    /// Whether a 401 should be read as "the token went stale" and answered with
    /// a refresh and one retry.
    ///
    /// Almost always yes. The exception is an endpoint that answers 401 about
    /// the *request* rather than the caller: `/auth/password/change` returns
    /// 401 for a wrong **current password**. Refreshing there spends a refresh
    /// token for nothing and reports "session expired" to someone who simply
    /// mistyped their password.
    var retriesOnUnauthorized = true

    /// Auth is a three-state choice, not a `Bool` — the API has endpoints that
    /// are required (most), optional (`/stores`, `/stores/{slug}` — they work
    /// signed out and say more signed in) and forbidden (`/app/config`,
    /// `/health`, `/pages`).
    ///
    /// Guest mode depends on the forbidden case sending no `Authorization`
    /// header at all, rather than an empty one.
    enum AuthRequirement: Sendable {
        /// Send the token; a missing one is a programming error, and a rejected
        /// one is worth a refresh and a retry.
        case required
        /// Send the token when we have one, and proceed happily when we do not.
        case optional
        /// Never send a token, even when signed in.
        case forbidden
    }

    static func get(
        _ path: String,
        query: [URLQueryItem] = [],
        auth: AuthRequirement = .required
    ) -> APIRequest {
        APIRequest(method: .get, path: path, query: query, auth: auth)
    }

    static func delete(_ path: String, auth: AuthRequirement = .required) -> APIRequest {
        APIRequest(method: .delete, path: path, auth: auth)
    }

    /// Builds a request whose body is JSON-encoded from `body`.
    ///
    /// Encoding failures surface here rather than at send time, because a value
    /// this app controls failing to encode is a bug in the call site, not a
    /// network condition.
    static func json(
        _ method: HTTPMethod,
        _ path: String,
        body: some Encodable & Sendable,
        query: [URLQueryItem] = [],
        auth: AuthRequirement = .required
    ) throws -> APIRequest {
        APIRequest(
            method: method,
            path: path,
            query: query,
            body: try JSONEncoder.api.encode(body),
            auth: auth
        )
    }

    /// A POST with no body at all, for the several endpoints that take none
    /// (`/me/onboarding/complete`, `/notifications/read-all`, …).
    static func post(_ path: String, auth: AuthRequirement = .required) -> APIRequest {
        APIRequest(method: .post, path: path, auth: auth)
    }

    /// Marks this request as one whose 401 means the request, not the token.
    func withoutUnauthorizedRetry() -> APIRequest {
        var copy = self
        copy.retriesOnUnauthorized = false
        return copy
    }
}

nonisolated extension JSONEncoder {
    /// The encoder every request body goes through. The API speaks camelCase
    /// (`refreshToken`, `minimumBuild`), so the default key strategy is right;
    /// dates go over the wire as ISO-8601.
    ///
    /// Built fresh each time rather than shared: `JSONEncoder` is not
    /// `Sendable`, and a request costs orders of magnitude more than allocating
    /// one.
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

nonisolated extension JSONDecoder {
    /// The decoder every response goes through.
    ///
    /// `serverTime` and `timestamp` carry fractional seconds
    /// (`2026-09-22T06:19:40.126Z`), which `.iso8601` alone rejects, so parse
    /// both shapes rather than losing every timestamp in the API to a decoding
    /// error.
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: .iso8601WithFraction) { return date }
            if let date = try? Date(text, strategy: .iso8601) { return date }
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Not an ISO-8601 date: \(text)"
                )
            )
        }
        return decoder
    }
}

nonisolated extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    /// `Date.ISO8601FormatStyle` is a `Sendable` value type, unlike
    /// `ISO8601DateFormatter`, so it can be a shared constant off the main
    /// actor without a lock.
    static var iso8601WithFraction: Date.ISO8601FormatStyle {
        .iso8601.year().month().day()
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: true)
            .timeZone(separator: .omitted)
    }
}
