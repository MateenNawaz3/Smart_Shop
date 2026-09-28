//
//  AppNotification.swift
//  SmartShop
//

import Foundation

/// One inbox entry.
///
/// The inbox is the record of what was sent, whether or not a push ever
/// reached the handset. While the server's `PUSH_TRANSPORT` is `log`, it is
/// the only place a notice appears at all.
nonisolated struct AppNotification: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case receiptReady, verificationApproved, verificationRejected, doorDenied, offer, general
        /// A value added server-side after this build shipped. Show it with a
        /// default icon rather than dropping it.
        case other(String)

        init(wire: String) {
            self = switch wire {
            case "receipt_ready": .receiptReady
            case "verification_approved": .verificationApproved
            case "verification_rejected": .verificationRejected
            case "door_denied": .doorDenied
            case "offer": .offer
            case "general": .general
            default: .other(wire)
            }
        }
    }

    /// Where tapping the notice goes. The server names the thing and the app
    /// decides where that is.
    enum Target: Sendable, Equatable {
        /// `purchase` + an id: that receipt.
        case receipt(id: String)
        /// An `entityType` this build has no screen for. Not tappable.
        case other(type: String, id: String)
    }

    var id: String
    var kind: Kind
    var title: String
    var body: String?
    /// Nil for a notice with nothing to open.
    var target: Target?
    var read: Bool
    var createdAt: Date
}

/// One page of the inbox, with the badge count for the whole of it.
nonisolated struct NotificationInbox: Sendable, Equatable {
    /// Newest first.
    var items: [AppNotification]
    /// Every notice, not just this page.
    var total: Int
    /// Unread across the whole inbox. Use it for the badge as-is; counting
    /// `items` would only count this page.
    var unread: Int
}
