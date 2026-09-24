//
//  OtpDTO.swift
//  SmartShop
//

import Foundation

/// `POST /mobile/otp/phone/send`
nonisolated struct SendPhoneCodeRequestDTO: Encodable, Sendable {
    var phone: String
}

/// `POST /mobile/otp/email/send`
nonisolated struct SendEmailCodeRequestDTO: Encodable, Sendable {
    var email: String
}

/// `POST /mobile/otp/{email,phone}/verify`
///
/// **The code and nothing else.** Sending `email` or `phone` alongside is
/// rejected — "property email should not exist" — because the destination is
/// already on the code row server-side, and an unverified address must not be
/// able to steer which one gets verified.
nonisolated struct VerifyCodeRequestDTO: Encodable, Sendable {
    var code: String
}

nonisolated struct OtpSentDTO: Decodable, Sendable {
    /// Masked, e.g. `o***6@example.dk`, so the app can say where the code went
    /// without echoing an address back at someone who has not proved they own
    /// it.
    var sentTo: String?
    /// ISO-8601. **Authoritative** — the five-minute lifetime is the server's to
    /// change, so never hard-code it.
    var expiresAt: String?
    /// Present on dev only, and deliberately **never read by app code**.
    ///
    /// A code proves control of an address, and email and phone are unique —
    /// so an app that read its own code could verify an address it does not
    /// own. It is decoded here only so its presence is documented; read it in
    /// Postman or the debugger.
    var devCode: String?
}

/// `POST /mobile/otp/{email,phone}/verify`
///
/// ⚠️ **A wrong code is `HTTP 200` with `ok: false`.** The status says the
/// request was processed, not that verification succeeded. Branch on `ok`.
nonisolated struct VerifyCodeResultDTO: Decodable, Sendable {
    var ok: Bool
    /// The address or number just proven. Present only when `ok`.
    var verified: String?
    /// `wrong` · `expired` · `attempts`. Present only when `ok` is false.
    var reason: String?
    /// Guesses left before the code is burned. Five to start; on the fifth
    /// wrong guess the code dies and the next attempt reports `attempts`.
    var attemptsLeft: Int?
}
