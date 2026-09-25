//
//  IdentityService.swift
//  SmartShop
//

import Foundation

/// Identity verification by document, as the Mobile API does it.
///
/// Kept apart from `VerificationService`, which also carries the key fob, NFC
/// log and tickets from the Supabase schema. Only the document upload has a
/// Mobile API endpoint the sign-up wizard needs today.
///
/// **Nothing is approved on submit.** A member of staff reviews the photos,
/// so a successful upload means "queued", and `pending` can last hours.
nonisolated protocol IdentityService: Sendable {
    func submitDocument(
        _ method: VerificationMethod,
        front: Data,
        back: Data?
    ) async throws -> IdentityStatus
}

nonisolated struct IdentityStatus: Sendable, Equatable {
    enum State: String, Sendable {
        case unverified, pending, verified, expired, rejected
    }

    var state: State
    var rejectionReason: String?
}

/// Raised for a method the document endpoint does not take. MitID goes
/// through `/identity/mitid/*` instead.
nonisolated struct UnsupportedDocumentMethod: LocalizedError {
    var method: VerificationMethod
    var errorDescription: String? { "\(method.rawValue) is not an identity document." }
}

/// Queues every submission, exactly as the server does, so UI tests and
/// previews see the same "awaiting approval" state as a real device.
nonisolated struct DemoIdentityService: IdentityService {
    func submitDocument(
        _ method: VerificationMethod,
        front: Data,
        back: Data?
    ) async throws -> IdentityStatus {
        IdentityStatus(state: .pending)
    }
}
