//
//  Receipt.swift
//  SmartShop
//

import Foundation

/// A purchase receipt. Port of `Receipt` in `src/data/receipts.ts`.
///
/// Demo data in `Resources/receipts.json` until the checkout integration
/// exists; the shape is what the till will eventually send.
struct Receipt: Identifiable, Codable, Hashable, Sendable {
    struct Line: Codable, Hashable, Sendable {
        /// Product group, e.g. "ENERGIDRIK, DÅSE".
        var group: String
        var name: String
        /// Price in kroner.
        var price: Double
    }

    var id: String
    var store: String
    var address: String
    /// ISO date (YYYY-MM-DD).
    var date: String
    /// "HH:mm".
    var time: String
    /// Payment method shown at the bottom of the receipt.
    var payment: String
    var barcode: String
    var lines: [Line]

    var total: Double { lines.reduce(0) { $0 + $1.price } }

    var purchasedAt: Date? {
        try? Date("\(date)T\(time):00", strategy: .iso8601.year().month().day()
            .dateSeparator(.dash).dateTimeSeparator(.standard).time(includingFractionalSeconds: false))
    }

    /// "36,95" — the web's `formatKr`.
    static func kr(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}

extension Receipt {
    /// Newest first.
    static let all: [Receipt] = {
        guard let url = Bundle.main.url(forResource: "receipts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let receipts = try? JSONDecoder().decode([Receipt].self, from: data)
        else {
            assertionFailure("receipts.json missing or malformed")
            return []
        }
        return receipts.sorted { $0.date > $1.date }
    }()

    static func named(_ id: String) -> Receipt? {
        all.first { $0.id == id }
    }
}
