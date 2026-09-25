//
//  APIIdentityService.swift
//  SmartShop
//

import Foundation

/// `IdentityService` over the Mobile API.
///
/// `POST /mobile/identity/document` is one of the app's two multipart calls;
/// `POST /mobile/identity/face` is the other. It takes
/// `documentType` plus a `front` image, and a `back` image for a driving
/// licence or ID card. It answers `202` with the queued status.
nonisolated struct APIIdentityService: IdentityService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func submitDocument(
        _ method: VerificationMethod,
        front: Data,
        back: Data?
    ) async throws -> IdentityStatus {
        var parts: [MultipartPart] = [
            .field(name: "documentType", value: try Self.documentType(for: method)),
            .file(name: "front", filename: "front.jpg", mimeType: "image/jpeg", data: front),
        ]
        if let back {
            parts.append(.file(name: "back", filename: "back.jpg", mimeType: "image/jpeg", data: back))
        }
        let request = APIRequest.multipart(.post, "/mobile/identity/document", parts: parts)
        let status: IdentityStatusDTO = try await client.send(request)
        return Self.map(status)
    }

    func status() async throws -> IdentityStatus {
        let status: IdentityStatusDTO = try await client.send(.get("/mobile/identity/status"))
        return Self.map(status)
    }

    // MARK: - Face

    func faceStatus() async throws -> FaceStatus {
        let face: FaceStatusDTO = try await client.send(.get("/mobile/identity/face"))
        return FaceStatus(available: face.available, enrolled: face.enrolled)
    }

    /// 503 is the ordinary answer where no face collection is configured,
    /// which is every environment today.
    func enrolFace(photo: Data, consent: Bool) async throws -> FaceStatus {
        let request = APIRequest.multipart(.post, "/mobile/identity/face", parts: [
            .field(name: "consent", value: consent ? "true" : "false"),
            .file(name: "photo", filename: "face.jpg", mimeType: "image/jpeg", data: photo),
        ])
        let face: FaceStatusDTO = try await client.send(request)
        // `202` means accepted for indexing. An absent `available` would read
        // as false, which is untrue of an environment that just accepted it.
        return FaceStatus(available: true, enrolled: face.enrolled)
    }

    /// Idempotent server-side: withdrawing twice is the same wish.
    func withdrawFace() async throws {
        let _: EmptyResponse = try await client.send(.delete("/mobile/identity/face"))
    }

    // MARK: - MitID verification

    var supportsMitIDVerification: Bool { true }

    func startMitIDVerification() async throws -> MitIDSignInSession {
        let request = try APIRequest.json(
            .post,
            "/mobile/identity/mitid/session",
            body: StartIdentityMitIDRequestDTO()
        )
        let started: MitIDSignInSessionDTO = try await client.send(request)
        guard let url = URL(string: started.authorizationUrl) else {
            throw APIError.decoding(URLError(.badURL))
        }
        return MitIDSignInSession(authorizationURL: url, state: started.state, expiresIn: started.expiresIn)
    }

    /// The answer carries the verified identity, but the CPR is never in it
    /// and nothing here needs the rest: callers re-read `status()`.
    func completeMitIDVerification(reference: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/identity/mitid/result",
            body: IdentityMitIDResultRequestDTO(reference: reference)
        )
        let _: EmptyResponse = try await client.send(request)
    }

    /// The app's enum carries the Supabase schema's Danish raw values; the
    /// Mobile API has its own English ones.
    private static func documentType(for method: VerificationMethod) throws -> String {
        switch method {
        case .passport: "passport"
        case .license: "driving_licence"
        case .idCard: "national_id"
        case .mitid: throw UnsupportedDocumentMethod(method: method)
        }
    }

    private static func map(_ dto: IdentityStatusDTO) -> IdentityStatus {
        IdentityStatus(
            // An unknown state is read as `pending`, the one that promises
            // nothing, rather than as verified or as a failure.
            state: IdentityStatus.State(rawValue: dto.state) ?? .pending,
            rejectionReason: dto.rejectionReason,
            method: dto.method.flatMap(IdentityStatus.Method.init(rawValue:)),
            documentType: dto.documentType,
            mitIDAvailable: dto.mitIdAvailable
        )
    }
}
