//
//  WheelService.swift
//  SmartShop
//

import Foundation
import Supabase

nonisolated enum SpinOutcome: String, Sendable { case win, retry, lose }

/// Port of `SpinResult` in `wheel.functions.ts`.
nonisolated struct SpinResult: Sendable, Equatable {
    var alreadySpun: Bool
    var outcome: SpinOutcome
    /// Nil for anything that is not a win.
    var prizeAmount: Kroner?
    var code: String?
    var spinDate: String
    var won: Bool { outcome == .win }
}

nonisolated struct WheelWin: Identifiable, Sendable, Hashable {
    var id: String
    var prizeAmount: Kroner
    var code: String
    var spinDate: String
}

/// The daily prize wheel. Reading is allowed under the user's own row policy;
/// the draw and the insert live server-side, so a real spin calls the
/// `wheel-spin` Edge Function. While `devAlwaysWin` is on (as `DEV_ALWAYS_WIN`
/// on the web) every spin wins locally and nothing is stored.
nonisolated protocol WheelService: Sendable {
    func status() async throws -> SpinResult?
    func wins() async throws -> [WheelWin]
    func spin() async throws -> SpinResult

    /// The fuller picture the Mobile API gives: whether a spin is still
    /// available, the server's idea of today, and the segments to render.
    ///
    /// Defaulted so the Supabase and demo backends, which know none of this,
    /// do not have to grow it.
    func wheelStatus() async throws -> WheelStatus
}

/// What `/contests/wheel/status` answers.
nonisolated struct WheelStatus: Sendable, Equatable {
    var canSpin: Bool
    /// The **server's** today, `yyyy-MM-dd`. The device clock is not a source
    /// of truth for "one spin per day".
    var spinDate: String
    var today: SpinResult?
    /// The wheel's faces, in the order to render them. Empty for a backend
    /// that does not describe its wheel.
    var segments: [WheelSegment]
}

nonisolated struct WheelSegment: Identifiable, Sendable, Equatable {
    var id: String
    var label: String
    var outcome: SpinOutcome
    var prizeAmount: Kroner
}

nonisolated extension WheelService {
    func wheelStatus() async throws -> WheelStatus {
        let today = try await status()
        return WheelStatus(
            canSpin: today == nil,
            spinDate: today?.spinDate ?? SupabaseWheelService.copenhagenToday(),
            today: today,
            segments: []
        )
    }
}

nonisolated struct SupabaseWheelService: WheelService {
    var client: SupabaseClient = .shared
    var devAlwaysWin = true

    private struct Row: Decodable {
        var id: String?
        var won: Bool
        var prize_amount: Int?
        var code: String?
        var spin_date: String
    }

    static func copenhagenToday() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        let c = cal.dateComponents([.year, .month, .day], from: .now)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// EAN-like 13-digit code the till can scan. Port of `generateBarcode`.
    static func generateBarcode() -> String {
        let base = "29" + (0..<10).map { _ in String(Int.random(in: 0...9)) }.joined()
        var sum = 0
        for (i, ch) in base.enumerated() { sum += Int(String(ch))! * (i % 2 == 0 ? 1 : 3) }
        return base + String((10 - sum % 10) % 10)
    }

    func status() async throws -> SpinResult? {
        if devAlwaysWin { return nil }
        let user = try await client.auth.session.user
        let rows: [Row] = try await client.from("wheel_spins")
            .select("won, prize_amount, code, spin_date")
            .eq("user_id", value: user.id).eq("spin_date", value: Self.copenhagenToday())
            .limit(1).execute().value
        guard let r = rows.first else { return nil }
        return SpinResult(alreadySpun: true, outcome: r.won ? .win : .lose, prizeAmount: r.prize_amount.map { Kroner($0) }, code: r.code, spinDate: r.spin_date)
    }

    func wins() async throws -> [WheelWin] {
        let user = try await client.auth.session.user
        let rows: [Row] = try await client.from("wheel_spins")
            .select("id, prize_amount, code, spin_date")
            .eq("user_id", value: user.id).eq("won", value: true)
            .order("spin_date", ascending: false).execute().value
        return rows.compactMap { r in
            guard let id = r.id, let amount = r.prize_amount, let code = r.code else { return nil }
            return WheelWin(id: id, prizeAmount: Kroner(amount), code: code, spinDate: r.spin_date)
        }
    }

    func spin() async throws -> SpinResult {
        if devAlwaysWin {
            return SpinResult(alreadySpun: false, outcome: .win, prizeAmount: Kroner(50), code: Self.generateBarcode(), spinDate: Self.copenhagenToday())
        }
        struct Response: Decodable { var alreadySpun: Bool; var outcome: String; var prizeAmount: Int?; var code: String?; var spinDate: String }
        let r: Response = try await client.functions.invoke("wheel-spin")
        return SpinResult(alreadySpun: r.alreadySpun, outcome: SpinOutcome(rawValue: r.outcome) ?? .lose, prizeAmount: r.prizeAmount.map { Kroner($0) }, code: r.code, spinDate: r.spinDate)
    }
}
