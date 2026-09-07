//
//  OtpService.swift
//  SmartShop
//

import Foundation
import Supabase

/// Phone and email one-time codes. Port of `send*/verify*Otp` in `otp.functions.ts`.
///
/// The web handlers hash the code, write the `telefon_otp` / `email_otp` rows
/// with the admin client and check attempts and expiry server-side. That has to
/// stay server-side, so the iOS client calls Edge Functions of the same names.
protocol OtpService: Sendable {
    func sendPhoneCode(to phone: String) async throws -> OtpSent
    func verifyPhoneCode(_ code: String) async throws -> OtpVerdict
    func sendEmailCode(to email: String) async throws -> OtpSent
    func verifyEmailCode(_ code: String) async throws -> OtpVerdict
}

struct OtpSent: Decodable, Sendable {
    /// The normalised destination the code went to.
    var destination: String
    /// Shown in the app while `DEMO_SHOW_CODE` is on server-side.
    var demoCode: String?

    enum CodingKeys: String, CodingKey {
        case telefon, email, demoKode
    }

    init(destination: String, demoCode: String?) {
        self.destination = destination
        self.demoCode = demoCode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        destination = try c.decodeIfPresent(String.self, forKey: .telefon)
            ?? c.decodeIfPresent(String.self, forKey: .email) ?? ""
        demoCode = try c.decodeIfPresent(String.self, forKey: .demoKode)
    }
}

enum OtpVerdict: Sendable, Equatable {
    case ok
    case wrong, expired, attempts
}

private struct OtpVerdictResponse: Decodable {
    var ok: Bool
    var reason: String?
    var verdict: OtpVerdict {
        if ok { return .ok }
        switch reason {
        case "expired": return .expired
        case "attempts": return .attempts
        default: return .wrong
        }
    }
}

/// Calls the `otp-send-phone`, `otp-verify-phone`, `otp-send-email` and
/// `otp-verify-email` Edge Functions.
struct SupabaseOtpService: OtpService {
    var client: SupabaseClient = .shared

    func sendPhoneCode(to phone: String) async throws -> OtpSent {
        try await client.functions.invoke("otp-send-phone", options: FunctionInvokeOptions(body: ["telefon": phone]))
    }
    func verifyPhoneCode(_ code: String) async throws -> OtpVerdict {
        let r: OtpVerdictResponse = try await client.functions.invoke("otp-verify-phone", options: FunctionInvokeOptions(body: ["kode": code]))
        return r.verdict
    }
    func sendEmailCode(to email: String) async throws -> OtpSent {
        try await client.functions.invoke("otp-send-email", options: FunctionInvokeOptions(body: ["email": email]))
    }
    func verifyEmailCode(_ code: String) async throws -> OtpVerdict {
        let r: OtpVerdictResponse = try await client.functions.invoke("otp-verify-email", options: FunctionInvokeOptions(body: ["kode": code]))
        return r.verdict
    }
}

/// Local stand-in: the demo code is always 123456, shown on screen exactly as
/// the server does while `DEMO_SHOW_CODE` is on.
///
/// A wrong code is still rejected, so the error states are real. Pass a
/// `backend` (demo mode does) and a successful check also flips the profile's
/// verified flag, so the "Your phone number is verified" state persists the way
/// it will in production.
struct DemoOtpService: OtpService {
    static let code = "123456"
    var backend: DemoBackend?

    func sendPhoneCode(to phone: String) async throws -> OtpSent {
        await DemoMode.pause(0.6)
        backend?.updateAccount { $0.telefon = phone; $0.telefonVerificeret = false }
        return OtpSent(destination: phone, demoCode: Self.code)
    }

    func verifyPhoneCode(_ code: String) async throws -> OtpVerdict {
        await DemoMode.pause(0.4)
        guard code == Self.code else { return .wrong }
        backend?.updateAccount { $0.telefonVerificeret = true }
        return .ok
    }

    func sendEmailCode(to email: String) async throws -> OtpSent {
        await DemoMode.pause(0.6)
        backend?.updateAccount { $0.email = email; $0.emailVerificeret = false }
        return OtpSent(destination: email, demoCode: Self.code)
    }

    func verifyEmailCode(_ code: String) async throws -> OtpVerdict {
        await DemoMode.pause(0.4)
        guard code == Self.code else { return .wrong }
        backend?.updateAccount { $0.emailVerificeret = true }
        return .ok
    }
}
