//
//  KronerTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

/// The app is kroner-only. The Mobile API is not — it sends minor units — and
/// both are `Int` on the wire, so the wrong one compiles perfectly.
@Suite("Kroner")
struct KronerTests {
    @Test("minor units convert to kroner")
    func fromMinorUnits() {
        #expect(Kroner(minorUnits: 5000) == Kroner(50))
        #expect(Kroner(minorUnits: 0) == .zero)
        #expect(Kroner(minorUnits: 12_345) == Kroner(123))
    }

    @Test("a kroner value is taken at face value")
    func fromKroner() {
        #expect(Kroner(50).amount == 50)
    }

    /// The screens interpolate straight into `"{amount} kr"`, so this has to
    /// print the number and nothing else — no "Kroner(amount: 50)".
    @Test("it prints as the bare number")
    func printing() {
        #expect("\(Kroner(50))" == "50")
        #expect("\(Kroner(minorUnits: 5000))" == "50")
    }

    /// The exact mistake this type exists to prevent: a 50 kr gift card
    /// advertised as 5000 kr.
    @Test("minor units are never shown as kroner")
    func doesNotLeakMinorUnits() {
        let giftCard = Kroner(minorUnits: 5000)
        #expect("\(giftCard)" != "5000")
        #expect("\(giftCard)" == "50")
    }

    @Test("no prize is zero kroner, not a missing value")
    func optionalIsZero() {
        let none: Kroner? = nil
        #expect(none.orZero == .zero)

        let some: Kroner? = Kroner(50)
        #expect(some.orZero == Kroner(50))

        #expect(Kroner(minorUnits: nil) == nil)
    }
}
