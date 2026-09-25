//
//  APIIdentityService.swift
//  SmartShop
//

import Foundation

/// `IdentityService` over the Mobile API.
///
/// `POST /mobile/identity/document` is the app's only multipart call. It takes
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
            rejectionReason: dto.rejectionReason
        )
    }
}
