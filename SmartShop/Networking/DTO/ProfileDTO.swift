//
//  ProfileDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET/PATCH /mobile/me
//
// The rest of this file's eventual surface — /me/home-location,
// /me/onboarding/complete, /me/store, /me/favourite-stores/{id} — belongs to
// modules 3 and 4 and is not implemented yet.
//
// Note what PATCH /me does NOT accept: email and phone. Those are the sign-in
// identity and move only through the OTP flow. It also rejects
// `marketingOptIn`, which is read here but written through /me/consents.

/// The full profile from `GET /mobile/me`.
///
/// Wider than the `CustomerSummaryDTO` that rides along with a session — this
/// one carries the surname, the address and the onboarding flags.
nonisolated struct CurrentCustomerDTO: Decodable, Sendable {
    var id: String
    var customerCode: String
    var firstName: String?
    var lastName: String?
    /// Server-composed display name.
    var name: String?
    /// **Nullable.** A MitID account has no email until the customer gives us
    /// one — MitID releases no address. Same trap as `CustomerSummaryDTO`,
    /// where a non-optional `String` made `/auth/mitid/complete` throw a
    /// decoding error for exactly the accounts it exists to create.
    var email: String?
    var emailVerified: Bool
    var phone: String?
    var phoneVerified: Bool
    var addressLine1: String?
    var postalCode: String?
    var city: String?
    var country: String?
    var preferredStoreId: String?
    /// A full locale such as `da-DK`.
    var preferredLanguage: String?
    var status: String
    var identityVerified: Bool
    var marketingOptIn: Bool
    var onboardingCompleted: Bool
    var registeredAt: Date?
    var dateOfBirth: String?
    var gender: String?
    var middleName: String?
}

/// The name half of `PATCH /mobile/me`.
///
/// Separate from the address so a screen that edits one cannot silently blank
/// the other: every field here is omitted when nil.
nonisolated struct ProfileNamePatchDTO: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
}

/// The address half of `PATCH /mobile/me`.
///
/// Every field is optional and omitted when nil, because a PATCH that sends
/// `null` would clear a field the caller never meant to touch.
nonisolated struct ProfileAddressPatchDTO: Encodable, Sendable {
    var addressLine1: String?
    var postalCode: String?
    var city: String?
}

/// `PATCH /mobile/me`.
///
/// Note what it does **not** accept: `email`, `phone` and `marketingOptIn`.
/// The first two are the sign-in identity and change only by proving the new
/// one through OTP; marketing is a consent record written through
/// `/me/consents`. Every field is omitted when nil, because a PATCH that sends
/// `null` clears a field the caller never meant to touch.
nonisolated struct UpdateProfileRequestDTO: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
    var addressLine1: String?
    var postalCode: String?
    var city: String?
}

/// `RequestDeletionDto`. The reason is omitted when nil.
nonisolated struct DeletionRequestDTO: Encodable, Sendable {
    var reason: String?
}
