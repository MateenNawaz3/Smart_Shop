//
//  APIPurchaseService.swift
//  SmartShop
//

import Foundation

/// `PurchaseService` over the Mobile API.
///
/// **Amounts are kroner throughout.** See `PurchaseSummaryDTO` — the `Minor`
/// suffix is the only signal for minor units and nothing on a receipt has it.
nonisolated struct APIPurchaseService: PurchaseService {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func purchases(limit: Int, offset: Int) async throws -> [Purchase] {
        let page: PurchaseListDTO = try await client.send(
            .get(
                "/mobile/purchases",
                query: [
                    // Capped at 100 server-side; asking for more is not an error
                    // but is not honoured either, so clamp here and be honest.
                    URLQueryItem(name: "limit", value: String(min(limit, 100))),
                    URLQueryItem(name: "offset", value: String(offset))
                ]
            )
        )
        return page.items.map(Self.map)
    }

    func purchase(id: String) async throws -> PurchaseDetail {
        let dto: PurchaseDetailDTO = try await client.send(.get("/mobile/purchases/\(id)"))
        return Self.map(dto)
    }

    func emailReceipt(id: String) async throws -> EmailReceiptOutcome {
        let request = try APIRequest.json(
            .post,
            "/mobile/purchases/\(id)/email",
            body: EmptyBody()
        )
        let result: EmailReceiptResultDTO = try await client.send(request)
        // Deliberately not thrown. `sent: false` is a 200 with an explanation —
        // "add an email address to your profile" — and turning that into an
        // error would replace usable advice with a generic failure.
        return EmailReceiptOutcome(
            sent: result.sent,
            simulated: result.simulated ?? false,
            email: result.email,
            message: result.message
        )
    }

    // MARK: - Mapping

    private static func map(_ dto: PurchaseSummaryDTO) -> Purchase {
        Purchase(
            id: dto.id,
            receiptNumber: dto.receiptNumber ?? "",
            storeName: dto.storeName ?? "",
            occurredAt: dto.occurredAt,
            total: dto.total,
            itemCount: dto.itemCount ?? 0,
            paymentMethod: dto.paymentMethod ?? "",
            // Prefer the server's flag over inferring from the sign: a void is
            // exactly zero and is not a refund, which the sign cannot express.
            isRefund: dto.isRefund ?? (dto.type == "refund")
        )
    }

    private static func map(_ dto: PurchaseDetailDTO) -> PurchaseDetail {
        let store = dto.store
        let address = [store?.addressLine1, [store?.postalCode, store?.city]
            .compactMap { $0?.nilWhenEmpty }.joined(separator: " ").nilWhenEmpty]
            .compactMap { $0 }
            .joined(separator: ", ")

        return PurchaseDetail(
            id: dto.id,
            receiptNumber: dto.receiptNumber ?? "",
            reference: dto.reference ?? "",
            occurredAt: dto.occurredAt,
            storeName: store?.name ?? "",
            storeAddress: address,
            terminal: dto.terminal ?? "",
            lines: (dto.lines ?? []).map {
                PurchaseLine(
                    name: $0.description ?? "",
                    quantity: $0.quantity ?? 1,
                    unitPrice: $0.unitPrice ?? 0,
                    lineGross: $0.lineGross ?? 0,
                    vatRate: $0.vatRate ?? 0,
                    depositAmount: $0.depositAmount ?? 0
                )
            },
            netTotal: dto.netTotal ?? 0,
            vatTotal: dto.vatTotal ?? 0,
            depositTotal: dto.depositTotal ?? 0,
            discountTotal: dto.discountTotal ?? 0,
            grossTotal: dto.grossTotal ?? 0,
            paymentMethod: dto.paymentMethod ?? ""
        )
    }

    private struct EmptyBody: Encodable, Sendable {}
}
