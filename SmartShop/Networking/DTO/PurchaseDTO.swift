//
//  PurchaseDTO.swift
//  SmartShop
//

import Foundation

/// ⚠️ **Every amount on a receipt is in KRONER, not øre.**
///
/// `gross_total` is `numeric(12,2)` server-side, so `142.00` means 142,00 kr.
/// Dividing by 100 would show 1,42 kr. The rule is the **field name and nothing
/// else**: a field ending `Minor` is minor units, everything else is the major
/// unit. Nothing on a receipt ends `Minor`; the prize wheel's `prizeMinor`
/// does. The two are genuinely inconsistent and the suffix is the only reliable
/// signal — do not generalise from one endpoint to another.
nonisolated struct PurchaseSummaryDTO: Decodable, Sendable {
    var id: String
    var receiptNumber: String?
    var storeName: String?
    var occurredAt: Date
    /// Kroner. **Signed** — negative for a refund, exactly `0` for a void.
    var total: Double
    var currency: String?
    /// `sale` · `refund` · `void`.
    var type: String?
    var isRefund: Bool?
    /// On the summary precisely so the list can say "4 items" without fetching
    /// every receipt. Lines themselves are detail-only.
    var itemCount: Int?
    var paymentMethod: String?
}

nonisolated struct PurchaseListDTO: Decodable, Sendable {
    var items: [PurchaseSummaryDTO]
    var total: Int
    var limit: Int?
    var offset: Int?
}

nonisolated struct PurchaseLineDTO: Decodable, Sendable {
    var description: String?
    var quantity: Double?
    /// Kroner, as is everything here.
    var unitPrice: Double?
    var lineGross: Double?
    /// A **percentage** (25 means 25%), not an amount — unlike its neighbours.
    var vatRate: Double?
    var vatAmount: Double?
    var depositAmount: Double?
}

nonisolated struct PurchaseStoreDTO: Decodable, Sendable {
    var name: String?
    var addressLine1: String?
    var postalCode: String?
    var city: String?
    var cvrNumber: String?
}

nonisolated struct VatBreakdownDTO: Decodable, Sendable {
    var vatRate: Double?
    var netAmount: Double?
    var vatAmount: Double?
    var grossAmount: Double?
}

/// `GET /mobile/purchases/{id}` — the only place `lines` exist.
nonisolated struct PurchaseDetailDTO: Decodable, Sendable {
    var id: String
    /// The till's own reference, which is what a shop assistant can look up.
    var reference: String?
    var receiptNumber: String?
    var occurredAt: Date
    var store: PurchaseStoreDTO?
    var terminal: String?
    var lines: [PurchaseLineDTO]?
    var vatBreakdown: [VatBreakdownDTO]?
    var netTotal: Double?
    var vatTotal: Double?
    var depositTotal: Double?
    var discountTotal: Double?
    var grossTotal: Double?
    var currency: String?
    var paymentMethod: String?
}

/// `POST /mobile/purchases/{id}/email`
///
/// ⚠️ **A fourth `200`-that-can-mean-failure**, and it was not on the backend's
/// original list of three. An account with **no email** — the normal case after
/// a MitID sign-up — gets `200` with `sent: false`, not a `400`. Branch on
/// `sent`; `message` is already customer-ready prose.
nonisolated struct EmailReceiptResultDTO: Decodable, Sendable {
    var sent: Bool
    /// True when the log transport ran and **no mail exists**. Never say "check
    /// your inbox" on a simulated send.
    var simulated: Bool?
    var email: String?
    /// Shown to the customer as-is.
    var message: String?
}
