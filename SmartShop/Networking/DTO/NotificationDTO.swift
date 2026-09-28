//
//  NotificationDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/notifications
//   POST /mobile/notifications/read-all
//   POST /mobile/notifications/{id}/read
//
// Typed in the spec (`NotificationPageDto`, `NotificationDto`) since
// 2026-09-24, and confirmed by the backend on 2026-09-28.

/// `NotificationDto`.
nonisolated struct NotificationDTO: Decodable, Sendable {
    var id: String
    /// `receipt_ready`, `verification_approved`, `verification_rejected`,
    /// `door_denied`, `offer` or `general`. A database enum, but a phone
    /// already installed cannot be redeployed alongside a migration, so an
    /// unknown value still has to be survivable.
    var type: String
    var title: String
    /// Plain text; may contain newlines.
    var body: String?
    /// Half of the deep link: `purchase` + `entityId` means that receipt. Null
    /// when there is nothing to open. There is no URL field.
    var entityType: String?
    var entityId: String?
    /// Derived from `readAt`, which is not returned.
    var read: Bool
    var createdAt: Date
}

/// `NotificationPageDto`.
nonisolated struct NotificationPageDTO: Decodable, Sendable {
    var items: [NotificationDTO]
    /// Matching rows, not the page size.
    var total: Int
    /// Unread across the WHOLE inbox, not this page: the badge, directly.
    var unread: Int
    var limit: Int?
    var offset: Int?
}

/// `NotificationReadDto`.
nonisolated struct NotificationReadDTO: Decodable, Sendable {
    var ok: Bool
}

/// `NotificationsReadAllDto`.
nonisolated struct NotificationsReadAllDTO: Decodable, Sendable {
    /// How many rows this call changed — NOT the new unread count, which is 0
    /// afterwards by definition. 0 when everything was already read.
    var marked: Int
}
