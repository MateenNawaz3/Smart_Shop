//
//  ContactService.swift
//  SmartShop
//

import Foundation

/// The contact form and the marketing unsubscribe.
nonisolated protocol ContactService: Sendable {
    /// Sends a message from the contact form.
    ///
    /// Returns whether the mail actually went out. The screen should say thank
    /// you either way — see `ContactReceipt`.
    @discardableResult
    func send(_ message: ContactMessage) async throws -> ContactReceipt

    /// Marketing unsubscribe. Always succeeds, whether or not the address was
    /// subscribed, for the same non-oracle reason as password/forgot.
    func unsubscribe(email: String) async throws
}

nonisolated struct ContactMessage: Sendable, Equatable {
    var name: String
    var email: String
    var subject: String
    var body: String
}

nonisolated struct ContactReceipt: Sendable, Equatable {
    var id: String
    /// False means the message is stored but no mail left the building.
    ///
    /// **Not a failure from the customer's side.** Their message is safe, and
    /// telling them it failed would invite them to send it again. Worth logging,
    /// not worth showing.
    var delivered: Bool
}

/// Does nothing, for the build that has no backend for this yet.
nonisolated struct UnavailableContactService: ContactService {
    @discardableResult
    func send(_ message: ContactMessage) async throws -> ContactReceipt {
        throw UnsupportedContactOperation()
    }

    func unsubscribe(email: String) async throws {
        throw UnsupportedContactOperation()
    }
}

nonisolated struct UnsupportedContactOperation: LocalizedError {
    var errorDescription: String? { "This backend cannot send contact messages." }
}
