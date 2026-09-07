//
//  WheelService.swift
//  SmartShop
//

import Foundation
import Supabase

enum SpinOutcome: String, Sendable { case win, retry, lose }

/// Port of `SpinResult` in `wheel.functions.ts`.
struct SpinResult: Sendable, Equatable {
    var alreadySpun: Bool
    var outcome: SpinOutcome
    var prizeAmount: Int?
    var code: String?
    var spinDate: String
    var won: Bool { outcome == .win }
}

struct WheelWin: Identifiable, Sendable, Hashable {
    var id: String
    var prizeAmount: Int
    var code: String
    var spinDate: String
}

/// The daily prize wheel. Reading is allowed under the user's own row policy;
/// the draw and the insert live server-side, so a real spin calls the
/// `wheel-spin` Edge Function. While `devAlwaysWin` is on (as `DEV_ALWAYS_WIN`
/// on the web) every spin wins locally and nothing is stored.
protocol WheelService: Sendable {
    func status() async throws -> SpinResult?
    func wins() async throws -> [WheelWin]
    func spin() async throws -> SpinResult
}

struct SupabaseWheelService: WheelService {
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
        return SpinResult(alreadySpun: true, outcome: r.won ? .win : .lose, prizeAmount: r.prize_amount, code: r.code, spinDate: r.spin_date)
    }

    func wins() async throws -> [WheelWin] {
        let user = try await client.auth.session.user
        let rows: [Row] = try await client.from("wheel_spins")
            .select("id, prize_amount, code, spin_date")
            .eq("user_id", value: user.id).eq("won", value: true)
            .order("spin_date", ascending: false).execute().value
        return rows.compactMap { r in
            guard let id = r.id, let amount = r.prize_amount, let code = r.code else { return nil }
            return WheelWin(id: id, prizeAmount: amount, code: code, spinDate: r.spin_date)
        }
    }

    func spin() async throws -> SpinResult {
        if devAlwaysWin {
            return SpinResult(alreadySpun: false, outcome: .win, prizeAmount: 50, code: Self.generateBarcode(), spinDate: Self.copenhagenToday())
        }
        struct Response: Decodable { var alreadySpun: Bool; var outcome: String; var prizeAmount: Int?; var code: String?; var spinDate: String }
        let r: Response = try await client.functions.invoke("wheel-spin")
        return SpinResult(alreadySpun: r.alreadySpun, outcome: SpinOutcome(rawValue: r.outcome) ?? .lose, prizeAmount: r.prizeAmount, code: r.code, spinDate: r.spinDate)
    }
}
