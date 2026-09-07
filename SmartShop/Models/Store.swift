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
struct Store: Identifiable, Hashable, Codable, Sendable {
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

extension Store {
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
