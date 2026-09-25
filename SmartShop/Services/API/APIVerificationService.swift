//
//  APIVerificationService.swift
//  SmartShop
//

import Foundation

/// `VerificationService` over the Mobile API.
///
/// The protocol is the Supabase schema's grab-bag — identity status, key fob,
/// door log and event tickets on one profile row — so this conformance is a
/// facade over three services rather than one endpoint family:
///
/// - status, method and document upload → `IdentityService` (`/identity/*`)
/// - key fob, door taps and door history → `AccessService` (`/access/*`)
/// - phone and email, with their verified flags → `GET /me`
/// - tickets → `tickets`, the previous service. Nothing calls these any more:
///   the calendar moved to `EventService`. They stay only because the
///   protocol still declares them.
///
/// The screens are unchanged: they follow the design, which has a door reader,
/// a checkout reader, a recent-activity list and a single key-fob field.
nonisolated struct APIVerificationService: VerificationService {
    private let client: any APIClient
    private let identity: any IdentityService
    private let access: any AccessService
    private let tickets: any VerificationService

    init(
        client: any APIClient,
        identity: any IdentityService,
        access: any AccessService,
        tickets: any VerificationService
    ) {
        self.client = client
        self.identity = identity
        self.access = access
        self.tickets = tickets
    }

    init(tickets: any VerificationService, configuration: APIConfiguration = .current) {
        let client = LiveAPIClient(configuration: configuration)
        self.init(
            client: client,
            identity: APIIdentityService(client: client),
            access: APIAccessService(client: client),
            tickets: tickets
        )
    }

    // MARK: - Status

    func info() async throws -> VerificationInfo {
        async let status = identity.status()
        async let me: CurrentCustomerDTO = client.send(.get("/mobile/me"))
        // A failed credential list must not hide the verification status,
        // which is the part of this screen that matters.
        async let fobs = (try? access.credentials()) ?? []

        let (s, profile, credentials) = try await (status, me, fobs)
        let fob = credentials.first { $0.kind == .keyFob }
        return VerificationInfo(
            status: Self.status(s.state),
            method: Self.method(s),
            keyFob: fob.map(Self.maskedFob) ?? "",
            phone: profile.phone ?? "",
            phoneVerified: profile.phoneVerified,
            email: profile.email ?? "",
            emailVerified: profile.emailVerified
        )
    }

    /// Queued for a person to review, so this answers `pending`, never
    /// `verified` — the demo's auto-approval does not exist here.
    func submit(method: VerificationMethod, front: Data, back: Data?) async throws -> VerificationStatus {
        Self.status(try await identity.submitDocument(method, front: front, back: back).state)
    }

    // MARK: - Key fob

    /// A fob is a door credential now, not a profile field. Replacing one adds
    /// the new fob before revoking the old, so a failure part-way leaves the
    /// customer with a working fob rather than none.
    func saveKeyFob(_ number: String?) async throws {
        let existing = try await access.credentials().filter { $0.kind == .keyFob }
        if let number {
            // The field shows the masked fob it was loaded with. Saving that
            // unchanged is not a new fob.
            if existing.contains(where: { Self.maskedFob($0) == number }) { return }
            _ = try await access.addKeyFob(number)
        }
        for fob in existing {
            try await access.revoke(credentialID: fob.id)
        }
    }

    /// Only the last four of a fob number are kept readable.
    private static func maskedFob(_ fob: AccessCredential) -> String {
        "••••" + (fob.lastFour ?? "")
    }

    // MARK: - Door and checkout

    /// The door reader asks the server, which decides and logs the outcome.
    /// There is no reader id in a simulated tap, so this is an in-app unlock.
    ///
    /// The checkout has no endpoint. It reads the same fact the door does —
    /// `isVerified` — and is not logged, because there is nowhere to log it.
    func logNfcAccess(point: String, storeSlug: String?) async throws -> Bool {
        guard point == "doer" else {
            return try await identity.status().state == .verified
        }
        return try await access.unlock(accessPointID: nil).granted
    }

    /// The server's history is door events only.
    func recentNfcAccess() async throws -> [NfcAccessEntry] {
        try await access.history(limit: 5).map {
            NfcAccessEntry(id: $0.id, point: "doer", approved: $0.granted, at: $0.at)
        }
    }

    // MARK: - Tickets (superseded by EventService)

    func boughtTicketEventIds() async throws -> [String] {
        try await tickets.boughtTicketEventIds()
    }

    func buyTicket(for event: AppEvent) async throws {
        try await tickets.buyTicket(for: event)
    }

    // MARK: - Mapping

    /// `expired` reads as not verified: the door refuses it just the same.
    private static func status(_ state: IdentityStatus.State) -> VerificationStatus {
        switch state {
        case .verified: .verified
        case .pending: .pending
        case .rejected: .rejected
        case .unverified, .expired: .none
        }
    }

    private static func method(_ status: IdentityStatus) -> VerificationMethod? {
        if status.method == .mitid { return .mitid }
        return switch status.documentType {
        case "passport": .passport
        case "driving_licence": .license
        case "national_id": .idCard
        default: nil
        }
    }
}
