//
//  ProfileService.swift
//  SmartShop
//

import Foundation
import Supabase

/// The editable part of a profile row. Port of `Fields` in `ProfileDetailsForm.tsx`.
struct ProfileDetails: Equatable, Sendable {
    var fornavn = ""
    var efternavn = ""
    var telefon = ""
    var adresse = ""
    var postnr = ""
    var by = ""
    var markedsforing = false
    /// The login email; read-only, shown greyed out.
    var email = ""
}

/// Name, town and email for the profile card on More. Port of `useProfileSummary`.
struct ProfileSummary: Equatable, Sendable {
    var fornavn = ""
    var efternavn = ""
    var by = ""
    var email = ""
}

/// The columns behind "my store" and onboarding. Port of `useMyStore`'s row.
struct StoreProfile: Equatable, Sendable {
    var favoriteStore: String?
    var adresse = ""
    var postnr = ""
    var by = ""
    var home: GeoPoint?
    var onboardingDone = false

    /// "Egedalvej 11, 6705 Esbjerg Ø" for the directions hint, or nil when incomplete.
    var homeAddress: String? {
        let street = adresse.trimmingCharacters(in: .whitespaces)
        let town = [postnr, by].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        guard !street.isEmpty, !by.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return "\(street), \(town)"
    }
}

/// Reads and writes the signed-in user's profile row.
protocol ProfileService: Sendable {
    /// First name for the home greeting, or `nil` when not set.
    func firstName() async -> String?
    func summary() async -> ProfileSummary?
    func details() async throws -> ProfileDetails?
    func update(_ details: ProfileDetails) async throws
    func setMarketing(_ enabled: Bool) async throws
    func storeProfile() async throws -> StoreProfile?
    func setFavoriteStore(_ slug: String, home: GeoPoint?) async throws
    func setHome(_ point: GeoPoint) async throws
    func setOnboardingDone() async throws
    /// The MitID contact step: phone and address on the profile, email on the auth user.
    func saveContactDetails(email: String, telefon: String, adresse: String, postnr: String, by: String) async throws
}

struct SupabaseProfileService: ProfileService {
    var client: SupabaseClient = .shared

    private struct Row: Decodable {
        var fornavn: String?
        var efternavn: String?
        var telefon: String?
        var adresse: String?
        var postnr: String?
        var by: String?
        var markedsforing: Bool?
    }

    private struct Update: Encodable {
        var fornavn: String
        var efternavn: String
        var telefon: String
        var adresse: String
        var postnr: String
        var by: String
        var markedsforing: Bool
    }

    private func row(_ columns: String) async throws -> (user: User, row: Row?) {
        let user = try await client.auth.session.user
        let rows: [Row] = try await client
            .from("profiles")
            .select(columns)
            .eq("id", value: user.id)
            .limit(1)
            .execute()
            .value
        return (user, rows.first)
    }

    func firstName() async -> String? {
        guard let (_, row) = try? await row("fornavn") else { return nil }
        let name = row?.fornavn?.trimmingCharacters(in: .whitespacesAndNewlines)
        // The greeting reads badly with an empty string, so normalise to nil.
        return (name?.isEmpty ?? true) ? nil : name
    }

    func summary() async -> ProfileSummary? {
        guard let (user, row) = try? await row("fornavn, efternavn, by") else { return nil }
        let trim = { ($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        return ProfileSummary(
            fornavn: trim(row?.fornavn), efternavn: trim(row?.efternavn),
            by: trim(row?.by), email: user.email ?? ""
        )
    }

    func details() async throws -> ProfileDetails? {
        let (user, row) = try await row("fornavn, efternavn, telefon, adresse, postnr, by, markedsforing")
        return ProfileDetails(
            fornavn: row?.fornavn ?? "", efternavn: row?.efternavn ?? "",
            telefon: row?.telefon ?? "", adresse: row?.adresse ?? "",
            postnr: row?.postnr ?? "", by: row?.by ?? "",
            markedsforing: row?.markedsforing ?? false, email: user.email ?? ""
        )
    }

    func update(_ d: ProfileDetails) async throws {
        let user = try await client.auth.session.user
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        try await client.from("profiles")
            .update(Update(
                fornavn: trim(d.fornavn), efternavn: trim(d.efternavn), telefon: trim(d.telefon),
                adresse: trim(d.adresse), postnr: trim(d.postnr), by: trim(d.by),
                markedsforing: d.markedsforing
            ))
            .eq("id", value: user.id)
            .execute()
    }

    func setMarketing(_ enabled: Bool) async throws {
        try await patch(["markedsforing": .bool(enabled)])
    }

    private struct StoreRow: Decodable {
        var favorit_butik: String?
        var adresse: String?
        var postnr: String?
        var by: String?
        var hjem_lat: Double?
        var hjem_lng: Double?
        var onboarding_gennemfoert: Bool?
    }

    func storeProfile() async throws -> StoreProfile? {
        let user = try await client.auth.session.user
        let rows: [StoreRow] = try await client.from("profiles")
            .select("favorit_butik, adresse, postnr, by, hjem_lat, hjem_lng, onboarding_gennemfoert")
            .eq("id", value: user.id).limit(1).execute().value
        guard let r = rows.first else { return nil }
        var home: GeoPoint?
        if let lat = r.hjem_lat, let lng = r.hjem_lng { home = GeoPoint(lat: lat, lng: lng) }
        return StoreProfile(
            favoriteStore: r.favorit_butik, adresse: r.adresse ?? "", postnr: r.postnr ?? "",
            by: r.by ?? "", home: home, onboardingDone: r.onboarding_gennemfoert ?? false
        )
    }

    func setFavoriteStore(_ slug: String, home: GeoPoint?) async throws {
        var values: [String: AnyJSON] = ["favorit_butik": .string(slug)]
        if let home {
            values["hjem_lat"] = .double(home.lat)
            values["hjem_lng"] = .double(home.lng)
        }
        try await patch(values)
    }

    func setHome(_ point: GeoPoint) async throws {
        try await patch(["hjem_lat": .double(point.lat), "hjem_lng": .double(point.lng)])
    }

    func setOnboardingDone() async throws {
        try await patch(["onboarding_gennemfoert": .bool(true)])
    }

    func saveContactDetails(email: String, telefon: String, adresse: String, postnr: String, by: String) async throws {
        let user = try await client.auth.session.user
        // The web's server function sets the email with the admin key, confirmed.
        // From the client this asks Supabase to send a confirmation link instead.
        if (user.email ?? "").lowercased() != email.lowercased() {
            try await client.auth.update(user: UserAttributes(email: email))
        }
        try await patch([
            "telefon": .string(telefon), "adresse": .string(adresse),
            "postnr": .string(postnr), "by": .string(by),
        ])
    }

    private func patch(_ values: [String: AnyJSON]) async throws {
        let user = try await client.auth.session.user
        try await client.from("profiles").update(values).eq("id", value: user.id).execute()
    }
}
