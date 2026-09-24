//
//  PurchaseService.swift
//  SmartShop
//

import Foundation

/// Till receipts.
///
/// Replaces the bundled `receipts.json` demo data and the visible `DemoNote`
/// in `ReceiptsView`.
nonisolated protocol PurchaseService: Sendable {
    /// Newest first. `limit` is capped at 100 server-side; there is no cursor,
    /// so paging is offset-based or not at all.
    func purchases(limit: Int, offset: Int) async throws -> [Purchase]
    /// The only call that carries line items.
    func purchase(id: String) async throws -> PurchaseDetail
    /// Emails a receipt **to the address on the account**, never one supplied
    /// here. See `EmailReceiptOutcome` — a refusal arrives as a success.
    @discardableResult
    func emailReceipt(id: String) async throws -> EmailReceiptOutcome
}

nonisolated extension PurchaseService {
    func purchases() async throws -> [Purchase] {
        try await purchases(limit: 50, offset: 0)
    }
}

/// A receipt as the list shows it. **Amounts are kroner.**
nonisolated struct Purchase: Identifiable, Sendable, Equatable {
    var id: String
    var receiptNumber: String
    var storeName: String
    var occurredAt: Date
    /// Signed: negative for a refund, exactly zero for a void.
    var total: Double
    var itemCount: Int
    var paymentMethod: String
    var isRefund: Bool
}

nonisolated struct PurchaseDetail: Sendable, Equatable {
    var id: String
    var receiptNumber: String
    /// The till's reference, which is what a shop assistant can look up.
    var reference: String
    var occurredAt: Date
    var storeName: String
    var storeAddress: String
    var terminal: String
    var lines: [PurchaseLine]
    var netTotal: Double
    var vatTotal: Double
    var depositTotal: Double
    var discountTotal: Double
    var grossTotal: Double
    var paymentMethod: String
}

nonisolated struct PurchaseLine: Identifiable, Sendable, Equatable {
    var id = UUID()
    var name: String
    var quantity: Double
    var unitPrice: Double
    var lineGross: Double
    /// A percentage, not an amount.
    var vatRate: Double
    var depositAmount: Double
}

/// The result of asking for a receipt by email.
///
/// `sent == false` is **not** an error and does not throw: an account with no
/// email address — the normal case after a MitID sign-up — gets a `200` saying
/// so, with prose meant for the customer.
nonisolated struct EmailReceiptOutcome: Sendable, Equatable {
    var sent: Bool
    /// The log transport ran and no mail exists. Do not say "check your inbox".
    var simulated: Bool
    var email: String?
    /// Customer-ready, from the server. Show it rather than inventing copy.
    var message: String?
}
