//
//  Kroner.swift
//  SmartShop
//

import Foundation

/// An amount of money, in Danish kroner.
///
/// **The app is kroner-only.** Smart Shop 24-7 trades in Denmark, prices are
/// quoted in kroner, and every screen that prints money prints kroner.
///
/// This exists because the Mobile API does not agree about the unit. It sends
/// **minor units** — `prizeMinor: 5000` is a 50 kr gift card, the way Stripe
/// counts cents. Both are `Int` on the wire, so the wrong one compiles
/// perfectly and shows a customer a 5000 kr prize. Making the unit part of the
/// *type* is what stops that: a minor-unit integer cannot become a `Kroner`
/// without going through `init(minorUnits:)` and saying so.
///
/// Printing works unchanged — `"\(amount)"` gives `"50"` — so the screens that
/// interpolate straight into `"{amount} kr"` keep working.
nonisolated struct Kroner: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// Whole kroner. Deliberately `Int`: nothing in this app prices in øre, and
    /// a gift card is never 49.50.
    var amount: Int

    init(_ amount: Int) {
        self.amount = amount
    }

    /// Converts from the API's minor units. 5000 øre becomes 50 kr.
    init(minorUnits: Int) {
        amount = minorUnits / 100
    }

    static let zero = Kroner(0)

    var description: String { "\(amount)" }
}

nonisolated extension Kroner {
    /// Convenience for an optional wire value.
    init?(minorUnits: Int?) {
        guard let minorUnits else { return nil }
        self.init(minorUnits: minorUnits)
    }
}

nonisolated extension Optional where Wrapped == Kroner {
    /// `nil` means no prize, which is zero kroner — not a missing value the
    /// screen has to decide about.
    var orZero: Kroner { self ?? .zero }
}
