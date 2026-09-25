//
//  APIClient.swift
//  SmartShop
//

import Foundation

/// The protocol every API service talks through.
///
/// Everything in here is generic; nothing knows about any particular endpoint.
nonisolated protocol APIClient: Sendable {
    /// Sends the request and returns the envelope's `data`, decoded.
    func send<Response: Decodable & Sendable>(
        _ request: APIRequest,
        as type: Response.Type
    ) async throws -> Response
}

nonisolated extension APIClient {
    /// Sugar for the common case where the return type is already known from
    /// context.
    func send<Response: Decodable & Sendable>(_ request: APIRequest) async throws -> Response {
        try await send(request, as: Response.self)
    }

    /// For calls whose `data` we do not care about.
    @discardableResult
    func send(_ request: APIRequest) async throws -> EmptyResponse {
        try await send(request, as: EmptyResponse.self)
    }
}

/// `URLSession`-backed implementation.
///
/// Responsibilities, in order: build a `URLRequest` from an `APIRequest`,
/// attach the bearer token and `x-localization`, decode the envelope and hand
/// back `.data`, map a failure into `APIError`, and on a 401 ask
/// `TokenRefresher` for a new access token and retry **once**.
nonisolated struct LiveAPIClient: APIClient {
    var configuration: APIConfiguration = .current
    var session: URLSession = .shared
    var tokens: any TokenStoring
    var refresher: TokenRefresher
    var localization: APILocalization = .shared

    init(
        configuration: APIConfiguration = .current,
        session: URLSession = .shared,
        tokens: any TokenStoring = KeychainTokenStore(),
        refresher: TokenRefresher? = nil,
        localization: APILocalization = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.tokens = tokens
        self.refresher = refresher ?? TokenRefresher(
            configuration: configuration,
            session: session,
            tokens: tokens
        )
        self.localization = localization
    }

    func send<Response: Decodable & Sendable>(
        _ request: APIRequest,
        as type: Response.Type
    ) async throws -> Response {
        let token = request.auth == .forbidden ? nil : tokens.accessToken

        do {
            return try await perform(request, token: token, as: type)
        } catch APIError.unauthorized(let message)
            where request.auth == .required && request.retriesOnUnauthorized {
            // One retry, and only one. If the refreshed token is refused too,
            // the problem is the account, not the clock.
            let refreshed = try await refresher.freshToken(replacing: token)
            do {
                return try await perform(request, token: refreshed, as: type)
            } catch APIError.unauthorized {
                throw APIError.unauthorized(message: message)
            }
        }
    }

    // MARK: - One attempt

    private func perform<Response: Decodable & Sendable>(
        _ request: APIRequest,
        token: String?,
        as type: Response.Type
    ) async throws -> Response {
        let urlRequest = try buildURLRequest(request, token: token)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        APIBodyDump.ifWanted(path: request.path, status: status, body: data)
        let envelope: APIEnvelope<Response>
        do {
            envelope = try JSONDecoder.api.decode(APIEnvelope<Response>.self, from: data)
        } catch {
            // A body we cannot read at all. When the status already explains
            // itself, say that instead of blaming the decoder — an HTML error
            // page from a proxy is not a decoding bug in the app.
            if !(200..<300).contains(status) {
                throw mapStatus(status, code: nil, message: nil)
            }
            throw APIError.decoding(error)
        }

        guard envelope.success else {
            throw mapStatus(status, code: envelope.code, message: envelope.message?.text)
        }

        guard let payload = envelope.data else {
            // `data: null` on a success is normal for endpoints that return
            // nothing. It is only a failure when the caller wanted something.
            if let empty = EmptyResponse() as? Response { return empty }
            throw APIError.decoding(
                DecodingError.valueNotFound(
                    Response.self,
                    .init(codingPath: [], debugDescription: "Envelope succeeded with no data")
                )
            )
        }

        return payload
    }

    private func buildURLRequest(_ request: APIRequest, token: String?) throws -> URLRequest {
        var components = URLComponents(
            url: configuration.baseURL.appending(path: request.path),
            resolvingAgainstBaseURL: false
        )
        if !request.query.isEmpty {
            components?.queryItems = request.query
        }

        guard let url = components?.url else {
            throw APIError.decoding(
                URLError(.badURL, userInfo: [NSURLErrorFailingURLStringErrorKey: request.path])
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue(localization.current, forHTTPHeaderField: "x-localization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")
        }

        // `.forbidden` means no header at all, not an empty one — guest mode
        // depends on the difference.
        if request.auth != .forbidden, let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }

    private func mapStatus(_ status: Int, code: String?, message: String?) -> APIError {
        let text = message ?? "Request failed"
        switch status {
        case 401:
            return .unauthorized(message: text)
        case 429:
            return .rateLimited(message: text)
        case 503:
            return .unavailable(message: text)
        case 200..<300:
            // `success: false` with a 2xx. Unusual, but the envelope is the
            // authority on whether a call worked, not the status line.
            return .failure(code: code, message: text, status: status)
        default:
            return code == nil && message == nil
                ? .unexpectedStatus(status)
                : .failure(code: code, message: text, status: status)
        }
    }
}
