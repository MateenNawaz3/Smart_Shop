//
//  Event.swift
//  SmartShop
//

import Foundation

/// A calendar event, free or ticketed. Port of `AppEvent` in `src/data/events.ts`.
struct AppEvent: Identifiable, Codable, Hashable, Sendable {
    var id: String
    /// ISO date (YYYY-MM-DD).
    var date: String
    /// "16:00-18:00".
    var time: String
    var title: Post.Localized
    var body: Post.Localized
    var place: Post.Localized
    /// 0 means a free event.
    var priceKr: Int

    var day: Date? {
        try? Date(date, strategy: .iso8601.year().month().day().dateSeparator(.dash))
    }
}

extension AppEvent {
    /// Earliest first.
    static let all: [AppEvent] = {
        guard let url = Bundle.main.url(forResource: "events", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([AppEvent].self, from: data)
        else {
            assertionFailure("events.json missing or malformed")
            return []
        }
        return events.sorted { $0.date < $1.date }
    }()
}
