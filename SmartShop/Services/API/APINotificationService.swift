//
//  APINotificationService.swift
//  SmartShop
//

import Foundation

/// `NotificationService` over the Mobile API.
nonisolated struct APINotificationService: NotificationService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func inbox(limit: Int, offset: Int) async throws -> NotificationInbox {
        let page: NotificationPageDTO = try await client.send(
            .get(
                "/mobile/notifications",
                query: [
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "offset", value: String(offset))
                ]
            )
        )
        return NotificationInbox(items: page.items.map(Self.map), total: page.total, unread: page.unread)
    }

    func markRead(id: String) async throws -> Bool {
        let result: NotificationReadDTO = try await client.send(.post("/mobile/notifications/\(id)/read"))
        return result.ok
    }

    func markAllRead() async throws -> Int {
        let result: NotificationsReadAllDTO = try await client.send(.post("/mobile/notifications/read-all"))
        return result.marked
    }

    static func map(_ dto: NotificationDTO) -> AppNotification {
        AppNotification(
            id: dto.id,
            kind: AppNotification.Kind(wire: dto.type),
            title: dto.title,
            body: dto.body,
            target: target(type: dto.entityType, id: dto.entityId),
            read: dto.read,
            createdAt: dto.createdAt
        )
    }

    /// Both halves or nothing: a type with no id has nowhere to go.
    private static func target(type: String?, id: String?) -> AppNotification.Target? {
        guard let type, let id, !id.isEmpty else { return nil }
        return type == "purchase" ? .receipt(id: id) : .other(type: type, id: id)
    }
}
