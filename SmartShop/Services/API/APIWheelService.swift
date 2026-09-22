//
//  APIWheelService.swift
//  SmartShop
//

import Foundation

/// `WheelService` over the Mobile API.
///
/// Two things move off the device here, and both matter:
///
///   - **The draw.** The outcome is decided by the server, and a win mints a
///     real gift card in the same transaction. `SupabaseWheelService`
///     generated a barcode locally; a code the server does not know about is
///     not spendable.
///   - **"Today".** `spinDate` is the server's, not the device's. Changing the
///     phone's clock cannot buy another go.
///
/// Expect `503` as an ordinary answer: the wheel is off unless
/// `CONTESTS_ENABLED=true`, deliberately, because it issues real gift cards and
/// a recurring retailer-run prize draw may be regulated in Denmark. The tab
/// should be hidden by the `contests` feature flag from `/app/config` rather
/// than shown and left to error.
nonisolated struct APIWheelService: WheelService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    func wheelStatus() async throws -> WheelStatus {
        let dto: WheelStatusDTO = try await client.send(.get("/mobile/contests/wheel/status"))
        return WheelStatus(
            canSpin: dto.canSpin,
            spinDate: dto.spinDate,
            today: dto.today.map { SpinResult($0, alreadySpun: true) },
            segments: dto.segments.map(WheelSegment.init)
        )
    }

    func status() async throws -> SpinResult? {
        try await wheelStatus().today
    }

    func spin() async throws -> SpinResult {
        do {
            let dto: SpinDTO = try await client.send(.post("/mobile/contests/wheel/spin"))
            return SpinResult(dto, alreadySpun: false)
        } catch APIError.failure(let code, _, _) where code == "CONFLICT" {
            // "You have already spun today". Not an error to show — the screen
            // has a state for it, so report today's result instead.
            if let today = try await wheelStatus().today { return today }
            throw APIError.failure(code: "CONFLICT", message: "Already spun today", status: 409)
        }
    }

    func wins() async throws -> [WheelWin] {
        let dtos: [SpinDTO] = try await client.send(.get("/mobile/contests/wheel/wins"))
        // Wins only, so anything without a code is not something the till can
        // honour and has no business in this list.
        return dtos.compactMap { dto in
            guard let code = dto.code else { return nil }
            return WheelWin(
                id: dto.id ?? code,
                prizeAmount: Kroner(minorUnits: dto.prizeMinor).orZero,
                code: code,
                spinDate: dto.spinDate
            )
        }
    }

}

nonisolated private extension SpinResult {
    init(_ dto: SpinDTO, alreadySpun: Bool) {
        self.init(
            alreadySpun: alreadySpun,
            outcome: SpinOutcome(rawValue: dto.outcome) ?? (dto.won ? .win : .lose),
            prizeAmount: Kroner(minorUnits: dto.prizeMinor),
            code: dto.code,
            spinDate: dto.spinDate
        )
    }
}

nonisolated private extension WheelSegment {
    init(_ dto: WheelSegmentDTO) {
        self.init(
            id: dto.id,
            label: dto.label,
            outcome: SpinOutcome(rawValue: dto.outcome) ?? .lose,
            prizeAmount: Kroner(minorUnits: dto.prizeMinor).orZero
        )
    }
}
