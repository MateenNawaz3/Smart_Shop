//
//  IdSignupService.swift
//  SmartShop
//

import Foundation
import Supabase

/// Creates an account from name and address alone — the iOS counterpart of
/// `startIdSignup` in `idsignup.functions.ts`. Email and phone are collected
/// and verified afterwards with one-time codes.
///
/// Like MitID, the web handler uses the service-role key (`admin.createUser`,
/// `generateLink`), which cannot ship in an app. It has to become a Supabase
/// Edge Function; `SupabaseIdSignupService` already calls it by name.
protocol IdSignupService: Sendable {
    /// Returns the `token_hash` to hand to `AuthService.verifyEmailToken`.
    func start(_ details: IdSignupDetails) async throws -> String
}

struct IdSignupDetails: Encodable, Sendable {
    var fornavn: String
    var efternavn: String
    var adresse: String
    var postnr: String
    var by: String
    var markedsforing: Bool
}

/// Calls the `id-signup-start` Edge Function.
struct SupabaseIdSignupService: IdSignupService {
    var client: SupabaseClient = .shared

    private nonisolated struct Response: Decodable { let tokenHash: String
        enum CodingKeys: String, CodingKey { case tokenHash = "token_hash" }
    }

    func start(_ details: IdSignupDetails) async throws -> String {
        let response: Response = try await client.functions.invoke(
            "id-signup-start", options: FunctionInvokeOptions(body: details)
        )
        return response.tokenHash
    }
}

/// Stands in until the Edge Function is deployed.
struct UnavailableIdSignupService: IdSignupService {
    func start(_ details: IdSignupDetails) async throws -> String {
        throw MitIDUnavailable()
    }
}
