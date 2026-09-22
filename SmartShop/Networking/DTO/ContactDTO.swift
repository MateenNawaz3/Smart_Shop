//
//  ContactDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   POST /mobile/contact
//   POST /mobile/unsubscribe

nonisolated struct ContactMessageDTO: Encodable, Sendable {
    var name: String
    var email: String
    var subject: String
    var body: String
}

/// Stored first, emailed second.
///
/// `delivered: false` means the message is safely stored but no mail left the
/// building — the app should still say thank you, because from the customer's
/// side nothing went wrong.
nonisolated struct ContactReceiptDTO: Decodable, Sendable {
    var id: String
    var delivered: Bool
}

nonisolated struct UnsubscribeRequestDTO: Encodable, Sendable {
    var email: String
}
