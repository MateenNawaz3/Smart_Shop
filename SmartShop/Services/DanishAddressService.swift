//
//  DanishAddressService.swift
//  SmartShop
//

import Foundation

/// Danish address lookup against DAWA (Danmarks Adressers Web API).
/// Port of `AddressAutocomplete.tsx` and `usePostalCitySync.ts`.
struct DanishAddressService: Sendable {
    struct Suggestion: Identifiable, Hashable, Sendable {
        var id: String { text }
        var text: String
        /// Street and number, e.g. "Egedalvej 11".
        var street: String
        var postalCode: String
        var city: String
    }

    private static let base = "https://api.dataforsyningen.dk"

    /// Up to eight fuzzy matches for a partial address (three characters or more).
    func suggestions(for query: String) async -> [Suggestion] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else { return [] }
        var components = URLComponents(string: Self.base + "/adgangsadresser/autocomplete")!
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "per_side", value: "8"),
            URLQueryItem(name: "fuzzy", value: ""),
        ]
        struct Row: Decodable {
            struct Access: Decodable { var vejnavn: String?; var husnr: String?; var postnr: String?; var postnrnavn: String? }
            var tekst: String?
            var adgangsadresse: Access?
        }
        guard let rows: [Row] = await get(components.url) else { return [] }
        return rows.compactMap { row in
            let a = row.adgangsadresse
            let street = [a?.vejnavn, a?.husnr].compactMap { $0 }.joined(separator: " ")
            guard !street.isEmpty, let postnr = a?.postnr, !postnr.isEmpty else { return nil }
            return Suggestion(text: row.tekst ?? street, street: street, postalCode: postnr, city: a?.postnrnavn ?? "")
        }
    }

    /// Town for a four-digit postcode.
    func city(forPostalCode code: String) async -> String? {
        guard code.count == 4, code.allSatisfy(\.isNumber) else { return nil }
        struct Row: Decodable { var navn: String? }
        let row: Row? = await get(URL(string: Self.base + "/postnumre/\(code)"))
        return row?.navn
    }

    /// Postcode for a town name, only when the match is unambiguous.
    func postalCode(forCity name: String) async -> (code: String, city: String)? {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard n.count >= 3 else { return nil }
        var components = URLComponents(string: Self.base + "/postnumre")!
        components.queryItems = [URLQueryItem(name: "navn", value: n)]
        struct Row: Decodable { var nr: String?; var navn: String? }
        guard let rows: [Row] = await get(components.url), rows.count == 1, let nr = rows[0].nr else { return nil }
        return (nr, rows[0].navn ?? n)
    }

    /// Coordinates for an address, falling back to the postcode/town centre.
    /// Port of `geocodeDanishAddress`.
    func geocode(address: String, postalCode: String?, city: String?) async -> GeoPoint? {
        struct Row: Decodable { var x: Double?; var y: Double? }
        func lookup(_ parts: [String?]) async -> GeoPoint? {
            let q = parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            guard !q.isEmpty else { return nil }
            var components = URLComponents(string: Self.base + "/adgangsadresser")!
            components.queryItems = [
                URLQueryItem(name: "q", value: q),
                URLQueryItem(name: "struktur", value: "mini"),
                URLQueryItem(name: "per_side", value: "1"),
            ]
            guard let rows: [Row] = await get(components.url), let hit = rows.first,
                  let x = hit.x, let y = hit.y else { return nil }
            return GeoPoint(lat: y, lng: x)
        }
        if let point = await lookup([address, postalCode, city]) { return point }
        return await lookup([postalCode, city])
    }

    private func get<T: Decodable>(_ url: URL?) async -> T? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
