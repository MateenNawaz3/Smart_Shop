//
//  VerificationService.swift
//  SmartShop
//

import Foundation
import Supabase

enum VerificationStatus: String, Sendable {
    case none = "ikke_verificeret", pending = "afventer", verified = "verificeret", rejected = "afvist"
}

enum VerificationMethod: String, Sendable, CaseIterable {
    case mitid, passport = "pas", license = "koerekort", idCard = "id_kort"
}

/// Port of `VerificationInfo` in `useVerification.ts`, plus the OTP flags.
struct VerificationInfo: Equatable, Sendable {
    var status: VerificationStatus = .none
    var method: VerificationMethod?
    var keyFob = ""
    var phone = ""
    var phoneVerified = false
    var email = ""
    var emailVerified = false
}

struct NfcAccessEntry: Identifiable, Sendable, Hashable {
    var id: String
    var point: String
    var approved: Bool
    var at: Date
}

/// Identity verification, key fob, NFC access log and event tickets — the
/// parts of `verification.functions.ts` that run under the user's own row
/// policies and so can be called straight from the client.
protocol VerificationService: Sendable {
    func info() async throws -> VerificationInfo
    /// Uploads the document photos and records the verification.
    /// Returns the resulting status (auto-approved in the demo).
    func submit(method: VerificationMethod, front: Data, back: Data?) async throws -> VerificationStatus
    func saveKeyFob(_ number: String?) async throws
    /// Logs a simulated tap; returns whether access was granted.
    func logNfcAccess(point: String, storeSlug: String?) async throws -> Bool
    func recentNfcAccess() async throws -> [NfcAccessEntry]
    func boughtTicketEventIds() async throws -> [String]
    func buyTicket(for event: AppEvent) async throws
}

struct SupabaseVerificationService: VerificationService {
    var client: SupabaseClient = .shared
    /// Mirrors `DEMO_AUTO_APPROVE` on the web.
    var autoApprove = true

    private struct Row: Decodable {
        var verifikation_status: String?
        var verifikation_metode: String?
        var noeglebrik_nummer: String?
        var telefon: String?
        var telefon_verificeret: Bool?
        var email_verificeret: Bool?
    }

    func info() async throws -> VerificationInfo {
        let user = try await client.auth.session.user
        let rows: [Row] = try await client.from("profiles")
            .select("verifikation_status, verifikation_metode, noeglebrik_nummer, telefon, telefon_verificeret, email_verificeret")
            .eq("id", value: user.id).limit(1).execute().value
        let r = rows.first
        let email = user.email ?? ""
        return VerificationInfo(
            status: VerificationStatus(rawValue: r?.verifikation_status ?? "") ?? .none,
            method: r?.verifikation_metode.flatMap(VerificationMethod.init(rawValue:)),
            keyFob: r?.noeglebrik_nummer ?? "",
            phone: (r?.telefon ?? "").trimmingCharacters(in: .whitespaces),
            phoneVerified: r?.telefon_verificeret ?? false,
            email: email.hasSuffix("@mitid.local") || email.hasSuffix("@id-konto.local") ? "" : email,
            emailVerified: r?.email_verificeret ?? false
        )
    }

    func submit(method: VerificationMethod, front: Data, back: Data?) async throws -> VerificationStatus {
        let user = try await client.auth.session.user
        let stamp = Int(Date.now.timeIntervalSince1970 * 1000)
        func upload(_ data: Data, side: String) async throws -> String {
            let path = "\(user.id.uuidString.lowercased())/\(method.rawValue)-\(side)-\(stamp).jpg"
            try await client.storage.from("id-dokumenter")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
            return path
        }
        let frontPath = try await upload(front, side: "front")
        var backPath: String?
        if let back { backPath = try await upload(back, side: "back") }

        struct Insert: Encodable { var user_id: String; var metode: String; var status: String; var fil_sti: String }
        let status = autoApprove ? "godkendt" : "afventer"
        var rows = [Insert(user_id: user.id.uuidString, metode: method.rawValue, status: status, fil_sti: frontPath)]
        if let backPath { rows.append(Insert(user_id: user.id.uuidString, metode: method.rawValue, status: status, fil_sti: backPath)) }
        try await client.from("id_verifikationer").insert(rows).execute()

        let profileStatus: VerificationStatus = autoApprove ? .verified : .pending
        try await client.from("profiles")
            .update(["verifikation_metode": AnyJSON.string(method.rawValue), "verifikation_status": .string(profileStatus.rawValue)])
            .eq("id", value: user.id).execute()
        return profileStatus
    }

    func saveKeyFob(_ number: String?) async throws {
        let user = try await client.auth.session.user
        try await client.from("profiles")
            .update(["noeglebrik_nummer": number.map(AnyJSON.string) ?? .null])
            .eq("id", value: user.id).execute()
    }

    func logNfcAccess(point: String, storeSlug: String?) async throws -> Bool {
        let user = try await client.auth.session.user
        let verified = try await info().status == .verified
        struct Insert: Encodable { var user_id: String; var punkt: String; var butik_slug: String?; var resultat: String }
        try await client.from("nfc_adgang_log")
            .insert(Insert(user_id: user.id.uuidString, punkt: point, butik_slug: storeSlug, resultat: verified ? "godkendt" : "naegtet"))
            .execute()
        return verified
    }

    func recentNfcAccess() async throws -> [NfcAccessEntry] {
        struct Row: Decodable { var id: String; var punkt: String; var resultat: String; var created_at: Date }
        let rows: [Row] = try await client.from("nfc_adgang_log")
            .select("id, punkt, resultat, created_at")
            .order("created_at", ascending: false).limit(5).execute().value
        return rows.map { NfcAccessEntry(id: $0.id, point: $0.punkt, approved: $0.resultat == "godkendt", at: $0.created_at) }
    }

    func boughtTicketEventIds() async throws -> [String] {
        struct Row: Decodable { var event_id: String }
        let rows: [Row] = try await client.from("event_billetter").select("event_id").execute().value
        return rows.map(\.event_id)
    }

    func buyTicket(for event: AppEvent) async throws {
        let user = try await client.auth.session.user
        struct Insert: Encodable { var user_id: String; var event_id: String; var antal: Int; var pris_kr: Int }
        try await client.from("event_billetter")
            .insert(Insert(user_id: user.id.uuidString, event_id: event.id, antal: 1, pris_kr: event.priceKr))
            .execute()
    }
}

/// In-memory stand-in for UI tests and previews.
final class StubVerificationService: VerificationService, @unchecked Sendable {
    var state = VerificationInfo(phone: "+45 12345678", email: "mateen@example.com")
    var log: [NfcAccessEntry] = []
    var tickets: [String] = []

    func info() async throws -> VerificationInfo { state }
    func submit(method: VerificationMethod, front: Data, back: Data?) async throws -> VerificationStatus {
        state.status = .verified; state.method = method; return .verified
    }
    func saveKeyFob(_ number: String?) async throws { state.keyFob = number ?? "" }
    func logNfcAccess(point: String, storeSlug: String?) async throws -> Bool {
        let ok = state.status == .verified
        log.insert(NfcAccessEntry(id: UUID().uuidString, point: point, approved: ok, at: .now), at: 0)
        return ok
    }
    func recentNfcAccess() async throws -> [NfcAccessEntry] { Array(log.prefix(5)) }
    func boughtTicketEventIds() async throws -> [String] { tickets }
    func buyTicket(for event: AppEvent) async throws { tickets.append(event.id) }
}
