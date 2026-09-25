//
//  AccessService.swift
//  SmartShop
//

import Foundation

/// Door credentials, door history, unlocking, and asking for help.
///
/// The decision is the server's. The Supabase app decided the outcome itself
/// in `VerificationService.logNfcAccess` and then wrote its own verdict, which
/// is not a defensible place for it.
///
/// `help` must always have somewhere to send someone: a refusal a customer
/// cannot act on, at three in the morning outside an unmanned shop, is the one
/// outcome this flow must not produce.
nonisolated protocol AccessService: Sendable {
    func credentials() async throws -> [AccessCredential]
    /// Registers the number printed on a physical fob.
    func addKeyFob(_ number: String) async throws -> AccessCredential
    /// Permanent. A revoked credential cannot be re-enabled.
    func revoke(credentialID: String) async throws
    /// `accessPointId` is the door, and comes off the reader the customer
    /// taps. Nil for an in-app unlock with no reader in hand.
    func unlock(accessPointID: String?) async throws -> UnlockOutcome
    func history(limit: Int) async throws -> [AccessEvent]
    /// Returns the store's phone number, when the server has one.
    func help(accessPointID: String?, storeID: String?, note: String?) async throws -> String?
}

nonisolated struct AccessCredential: Sendable, Equatable, Identifiable {
    enum Kind: String, Sendable { case phone = "phone_nfc", keyFob = "key_fob", qr }

    var id: String
    /// Nil for a type this build does not know.
    var kind: Kind?
    var label: String?
    /// All that stays readable of a fob number.
    var lastFour: String?
}

nonisolated struct AccessEvent: Sendable, Equatable, Identifiable {
    var id: String
    var at: Date
    var granted: Bool
    var reason: String?
}

nonisolated struct UnlockOutcome: Sendable, Equatable {
    var granted: Bool
    /// False on a grant when no physical door moved. Only this says "walk in".
    var doorOpened: Bool
    /// One of the seven refusal reasons, such as `not_verified`.
    var reason: String?
    var message: String?
}
