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
    var email: String
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
    var registeredAt: Date
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
