//
//  NotificationService.swift
//  SmartShop
//

import Foundation

/// The notification inbox and the unread badge.
///
/// Not the "Notifications" screen under More, which is the marketing-email
/// opt-in. The design has no inbox screen yet, so nothing calls this today.
nonisolated protocol NotificationService: Sendable {
    /// Newest first. `unread` on the result is the badge for the whole inbox.
    func inbox(limit: Int, offset: Int) async throws -> NotificationInbox
    /// Returns the server's `ok`.
    @discardableResult
    func markRead(id: String) async throws -> Bool
    /// Returns how many notices this changed, not the new unread count: that
    /// is 0 afterwards by definition, so set the badge to 0 without
    /// re-fetching.
    @discardableResult
    func markAllRead() async throws -> Int
}

nonisolated extension NotificationService {
    func inbox() async throws -> NotificationInbox {
        try await inbox(limit: 20, offset: 0)
    }
}

/// An in-memory inbox for previews and UI tests.
nonisolated final class DemoNotificationService: NotificationService, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [AppNotification]

    init(items: [AppNotification] = DemoNotificationService.sample) {
        self.items = items
    }

    func inbox(limit: Int, offset: Int) async throws -> NotificationInbox {
        lock.withLock {
            NotificationInbox(
                items: Array(items.dropFirst(offset).prefix(limit)),
                total: items.count,
                unread: items.count { !$0.read }
            )
        }
    }

    func markRead(id: String) async throws -> Bool {
        lock.withLock {
            guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
            items[index].read = true
            return true
        }
    }

    func markAllRead() async throws -> Int {
        lock.withLock {
            let marked = items.count { !$0.read }
            for index in items.indices { items[index].read = true }
            return marked
        }
    }

    static let sample: [AppNotification] = [
        AppNotification(
            id: "n1", kind: .receiptReady, title: "Din kvittering er klar",
            body: "Tak for dit køb.", target: .receipt(id: "demo-receipt"),
            read: false, createdAt: .now.addingTimeInterval(-3_600)
        ),
        AppNotification(
            id: "n2", kind: .general, title: "Velkommen til SmartShop 24-7",
            body: nil, target: nil,
            read: true, createdAt: .now.addingTimeInterval(-86_400)
        ),
    ]
}
