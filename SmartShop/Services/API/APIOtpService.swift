//
//  APIOtpService.swift
//  SmartShop
//

import Foundation

/// `OtpService` over the Mobile API.
///
/// Replaces four Supabase Edge Functions with four real endpoints. Three things
/// differ from the Supabase shape and all three can bite:
///
///   1. **Both routes need a token.** The account must exist before a code can
///      be sent, which is why the sign-up wizard has to register first rather
///      than verifying its way towards an account.
///   2. **Verify takes the code alone.** Sending the destination too is
///      rejected outright — see `VerifyCodeRequestDTO`.
///   3. **A wrong code is `HTTP 200`.** The verdict is `ok` in the body, not the
///      status. Treating a 200 as success verifies everybody.
///
/// Sending is budgeted three ways at once: the per-IP route limit, 5 per
/// customer per hour and 5 per destination per hour. The last two are what a
/// real person hits, and they surface as `.rateLimited`.
nonisolated struct APIOtpService: OtpService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func sendPhoneCode(to phone: String) async throws -> OtpSent {
        let request = try APIRequest.json(
            .post,
            "/mobile/otp/phone/send",
            body: SendPhoneCodeRequestDTO(phone: phone)
        )
        let sent: OtpSentDTO = try await client.send(request)
        return Self.map(sent, fallbackDestination: phone)
    }

    func verifyPhoneCode(_ code: String) async throws -> OtpVerdict {
        try await verify(code, at: "/mobile/otp/phone/verify")
    }

    func sendEmailCode(to email: String) async throws -> OtpSent {
        let request = try APIRequest.json(
            .post,
            "/mobile/otp/email/send",
            body: SendEmailCodeRequestDTO(email: email)
        )
        let sent: OtpSentDTO = try await client.send(request)
        return Self.map(sent, fallbackDestination: email)
    }

    func verifyEmailCode(_ code: String) async throws -> OtpVerdict {
        try await verify(code, at: "/mobile/otp/email/verify")
    }

    private func verify(_ code: String, at path: String) async throws -> OtpVerdict {
        let request = try APIRequest.json(.post, path, body: VerifyCodeRequestDTO(code: code))
        let result: VerifyCodeResultDTO = try await client.send(request)
        guard !result.ok else { return .ok }
        return switch result.reason {
        case "expired": .expired
        case "attempts": .attempts
        default: .wrong
        }
    }

    /// `sentTo` comes back masked, which is what the screen should show. The
    /// destination we were given is the fallback, not the preference — echoing
    /// an unmasked address defeats the point of masking it.
    ///
    /// `devCode` is deliberately dropped. It exists on dev so a developer can
    /// finish the flow by hand, and reading it in app code would let someone
    /// verify an address they do not own.
    private static func map(_ dto: OtpSentDTO, fallbackDestination: String) -> OtpSent {
        OtpSent(
            destination: dto.sentTo ?? fallbackDestination,
            demoCode: nil
        )
    }
}
