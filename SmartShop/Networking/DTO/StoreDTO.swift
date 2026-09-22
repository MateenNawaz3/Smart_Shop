//
//  StoreDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET    /mobile/stores
//   GET    /mobile/stores/{slug}
//   PUT    /mobile/me/favourite-stores/{id}
//   DELETE /mobile/me/favourite-stores/{id}
//   PUT    /mobile/me/store
//   DELETE /mobile/me/store
//   POST   /mobile/me/home-location
//   POST   /mobile/me/onboarding/complete

nonisolated struct StoreDTO: Decodable, Sendable {
    /// The API's own identifier. **Favourites and my-store are addressed by
    /// this, not by the slug** the app has always used as its key.
    var id: String
    var slug: String
    var name: String
    var shortName: String?
    var addressLine1: String?
    var postalCode: String?
    var city: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var phone: String?
    var email: String?
    var facebookUrl: String?
    var openingHours: OpeningHoursDTO?
    var alwaysOpen: Bool?
    /// `online` for a shop that is trading.
    var status: String?
    /// Present only when the list was sorted against a point — either one the
    /// caller passed, or the home location on file.
    var distanceKm: Double?
    var isFavourite: Bool?
    var isPreferred: Bool?
}

/// Opening hours arrive in one of two shapes, and the API documents neither:
///
///     { "open247": true }
///     { "mon": "06:00-22:00", …, "sun": "06:00-22:00" }
///
/// A round-the-clock shop sends the first; `rarup` on dev is the only one
/// currently sending the second.
nonisolated struct OpeningHoursDTO: Decodable, Sendable {
    var open247: Bool?
    var weekdays: [String: String]

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var open247: Bool?
        var weekdays: [String: String] = [:]

        for key in container.allKeys {
            if key.stringValue == "open247" {
                open247 = try? container.decode(Bool.self, forKey: key)
            } else if let value = try? container.decode(String.self, forKey: key) {
                weekdays[key.stringValue.lowercased()] = value
            }
        }
        self.open247 = open247
        self.weekdays = weekdays
    }

    /// Monday first, to match the order the app has always displayed.
    static let order = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    /// Seven entries, Monday first. Empty when the shop is open around the
    /// clock and there is nothing per-day to show.
    var weekly: [String] {
        guard !weekdays.isEmpty else { return [] }
        return Self.order.map { weekdays[$0] ?? "" }
    }
}

nonisolated struct SetMyStoreRequestDTO: Encodable, Sendable {
    var storeId: String
}

nonisolated struct PreferredStoreDTO: Decodable, Sendable {
    var preferredStoreId: String?
}

nonisolated struct ClearedDTO: Decodable, Sendable {
    var cleared: Bool?
}

nonisolated struct FavouriteChangeDTO: Decodable, Sendable {
    var added: Bool?
    var removed: Bool?
}

/// `POST /me/home-location` geocodes the address on file and caches the point.
///
/// Answers `resolved: false` rather than failing when the address cannot be
/// placed — the store finder still works, just without distances.
nonisolated struct HomeLocationDTO: Decodable, Sendable {
    var resolved: Bool
    var latitude: Double?
    var longitude: Double?
}
