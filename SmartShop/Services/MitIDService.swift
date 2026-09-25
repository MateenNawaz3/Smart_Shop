//
//  MitIDService.swift
//  SmartShop
//

import Foundation
import Supabase

/// Resolves a MitID identity into a one-time token the app exchanges for a
/// session — the iOS counterpart of `mitidDemoLogin` in `mitid.functions.ts`.
///
/// ## Why this is a protocol with no live implementation yet
///
/// The web handler runs `supabaseAdmin.auth.admin.createUser()` and
/// `generateLink()`. Both require the **service_role** key, which bypasses
/// every RLS policy. That key cannot ship inside an app binary — extracting
/// strings from an `.ipa` is trivial — so the logic has to move server-side,
/// to a Supabase Edge Function. There is no `supabase/functions/` directory in
/// the Lovable export yet, so that endpoint does not exist.
///
/// `SupabaseMitIDService` below already calls the function by name. Deploy
/// `docs/mitid-edge-function.md` and it starts working with no Swift changes.
protocol MitIDService: Sendable {
    /// Returns the `token_hash` to hand to `AuthService.verifyEmailToken`.
    func demoLogin(name: String, birthDate: String) async throws -> MitIDLogin
}

nonisolated struct MitIDLogin: Decodable, Sendable {
    let email: String
    let tokenHash: String
    let isNew: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case tokenHash = "token_hash"
        case isNew = "is_new"
    }
}

/// Calls the `mitid-demo-login` Edge Function.
struct SupabaseMitIDService: MitIDService {
    var client: SupabaseClient = .shared

    func demoLogin(name: String, birthDate: String) async throws -> MitIDLogin {
        try await client.functions.invoke(
            "mitid-demo-login",
            options: FunctionInvokeOptions(body: ["navn": name, "foedselsdato": birthDate])
        )
    }
}

/// Stands in until the Edge Function is deployed, so the whole MitID flow —
/// form, validation, PIN setup, unlock gate — can be built and demoed now.
struct UnavailableMitIDService: MitIDService {
    func demoLogin(name: String, birthDate: String) async throws -> MitIDLogin {
        throw MitIDUnavailable()
    }
}

struct MitIDUnavailable: LocalizedError {
    var errorDescription: String? {
        "MitID-login kræver Edge Function 'mitid-demo-login'. Se docs/mitid-edge-function.md."
    }
}
