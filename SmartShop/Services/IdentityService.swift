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

    /// `pending` is not terminal: a person reviews documents, so re-read this
    /// while a screen that shows it is open.
    func status() async throws -> IdentityStatus

    /// Whether face recognition exists here, and whether this customer is
    /// indexed and usable at a till.
    func faceStatus() async throws -> FaceStatus
    /// `consent` is GDPR art. 9 consent and must be true — it travels with the
    /// photo because the two are one decision.
    func enrolFace(photo: Data, consent: Bool) async throws -> FaceStatus
    /// Removes the indexed face and withdraws the consent. Keeps the photo.
    func withdrawFace() async throws

    /// Whether `startMitIDVerification` can do anything on this backend.
    var supportsMitIDVerification: Bool { get }
    /// Links MitID to the signed-in account. The browser leg and its callback
    /// are the same as MitID sign-in's.
    func startMitIDVerification() async throws -> MitIDSignInSession
    func completeMitIDVerification(reference: String) async throws
}

nonisolated extension IdentityService {
    var supportsMitIDVerification: Bool { false }

    func status() async throws -> IdentityStatus { IdentityStatus(state: .unverified) }
    func faceStatus() async throws -> FaceStatus { FaceStatus(available: false, enrolled: false) }
    func enrolFace(photo: Data, consent: Bool) async throws -> FaceStatus {
        throw APIError.unavailable(message: "Face recognition is not available.")
    }
    func withdrawFace() async throws {}
    func startMitIDVerification() async throws -> MitIDSignInSession {
        throw UnsupportedAuthOperation(operation: "MitID verification")
    }
    func completeMitIDVerification(reference: String) async throws {
        throw UnsupportedAuthOperation(operation: "MitID verification")
    }
}

nonisolated struct IdentityStatus: Sendable, Equatable {
    enum State: String, Sendable {
        case unverified, pending, verified, expired, rejected
    }

    /// How identity was established. The server's own set is
    /// `mitid`, `passport_eid`, `third_party_kyc` and `manual`.
    enum Method: String, Sendable {
        case mitid, passportEID = "passport_eid", thirdPartyKYC = "third_party_kyc", manual
    }

    var state: State
    var rejectionReason: String?
    var method: Method?
    /// `passport`, `driving_licence` or `national_id`.
    var documentType: String?
    var mitIDAvailable = false
}

nonisolated struct FaceStatus: Sendable, Equatable {
    /// False when this environment has no face collection. Enrolment refuses.
    var available: Bool
    var enrolled: Bool
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
