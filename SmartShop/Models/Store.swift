//
//  Store.swift
//  SmartShop
//

import Foundation
import CoreLocation

/// One Smart Shop 24-7 location. Port of `StoreInfo` in `src/data/stores.ts`.
///
/// The data itself lives in `Resources/stores.json`, decoded once at startup,
/// rather than being transcribed into Swift. Keeping it as data means the file
/// can be regenerated from the web project verbatim when a store opens or
/// moves, with no code change and no chance of a typo in an address.
nonisolated struct Store: Identifiable, Hashable, Codable, Sendable {
    var slug: String
    var name: String
    /// Geocoder-friendly address, including the country.
    var address: String
    /// Two-line display address: street, then postal town.
    var displayAddress: [String]
    var phone: String
    var email: String
    var facebookUrl: String
    /// Opening hours per weekday, Monday first.
    var hours: [String]
    /// Absent means the store is open around the clock.
    var alwaysOpen: Bool?
    var lat: Double
    var lng: Double

    /// The Mobile API's own identifier.
    ///
    /// The app has always keyed a store by its slug, and deep links depend on
    /// that, so the slug stays the identity. But **favourites and my-store are
    /// addressed by this id**, not by the slug, so a store that came from the
    /// API carries both. Nil for the bundled `stores.json` records.
    var remoteID: String?
    /// Distance from the point the list was sorted against, when there was one.
    var distanceKm: Double?
    /// Whether this is one of my favourites. Nil when nobody was signed in, as
    /// distinct from `false` meaning "asked, and it is not".
    var isFavourite: Bool?
    /// Whether this is my chosen store.
    var isMyStore: Bool?

    var id: String { slug }

    /// Short label without the brand prefix, e.g. "Grimstrup".
    var shortName: String {
        name.replacingOccurrences(
            of: #"^Smart Shop 24-7\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    var isAlwaysOpen: Bool { alwaysOpen ?? true }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// `tel:` needs the number without spaces.
    var dialURL: URL? { URL(string: "tel:\(phone.filter { !$0.isWhitespace })") }

    /// Opens turn-by-turn directions. The web links to Google Maps; on iOS the
    /// Apple Maps URL opens the user's installed map app and needs no browser.
    var directionsURL: URL? {
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "daddr", value: address)]
        return components?.url
    }
}

nonisolated extension Store {
    /// Builds a store from the Mobile API's shape.
    ///
    /// The two shapes disagree about addresses and hours, so both are composed
    /// here rather than at each call site.
    init(_ dto: StoreDTO) {
        let street = dto.addressLine1 ?? ""
        let town = [dto.postalCode, dto.city].compactMap { $0 }.joined(separator: " ")
        let alwaysOpen = dto.alwaysOpen ?? dto.openingHours?.open247 ?? true

        self.init(
            slug: dto.slug,
            name: dto.name,
            // Geocoder-friendly, and the country is part of that.
            address: [street, town, dto.country ?? "DK"]
                .filter { !$0.isEmpty }
                .joined(separator: ", "),
            displayAddress: [street, town].filter { !$0.isEmpty },
            phone: dto.phone ?? "",
            email: dto.email ?? "",
            facebookUrl: dto.facebookUrl ?? "",
            hours: alwaysOpen ? [] : (dto.openingHours?.weekly ?? []),
            alwaysOpen: alwaysOpen,
            lat: dto.latitude ?? 0,
            lng: dto.longitude ?? 0,
            remoteID: dto.id,
            distanceKm: dto.distanceKm,
            isFavourite: dto.isFavourite,
            isMyStore: dto.isPreferred
        )
    }

    /// All stores, decoded once. A decode failure here is a build/packaging
    /// error, not a runtime condition, so it trips in debug rather than
    /// silently shipping an empty store list.
    static let all: [Store] = {
        guard let url = Bundle.main.url(forResource: "stores", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stores = try? JSONDecoder().decode([Store].self, from: data)
        else {
            assertionFailure("stores.json missing or malformed")
            return []
        }
        return stores
    }()

    static func named(_ slug: String) -> Store? {
        all.first { $0.slug == slug }
    }

    static var sample: Store { all.first! }
}

// MARK: - Distance (port of `src/lib/geo.ts`)

struct GeoPoint: Equatable, Sendable {
    var lat: Double
    var lng: Double
}

extension Store {
    /// Great-circle distance in kilometres.
    func distanceKm(from point: GeoPoint) -> Double {
        let r = 6371.0
        func rad(_ v: Double) -> Double { v * .pi / 180 }
        let dLat = rad(lat - point.lat)
        let dLng = rad(lng - point.lng)
        let h = pow(sin(dLat / 2), 2) + pow(sin(dLng / 2), 2) * cos(rad(point.lat)) * cos(rad(lat))
        return 2 * r * asin(sqrt(h))
    }

    /// Stores sorted by distance from `point`; without a point the bundled order.
    static func byDistance(from point: GeoPoint?) -> [(store: Store, km: Double?)] {
        guard let point else { return all.map { ($0, nil) } }
        return all.map { ($0, $0.distanceKm(from: point)) }.sorted { ($0.km ?? 0) < ($1.km ?? 0) }
    }

    /// "6,4 km" — Danish formatting, as `formatKm` on the web.
    static func formatKm(_ km: Double) -> String {
        let value = km < 10 ? String(format: "%.1f", km) : String(Int(km.rounded()))
        return "\(value.replacingOccurrences(of: ".", with: ",")) km"
    }
}
