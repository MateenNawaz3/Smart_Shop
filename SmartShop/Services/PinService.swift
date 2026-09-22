//
//  PinService.swift
//  SmartShop
//

import Foundation
import CommonCrypto
import Supabase

/// Sets and checks the 4-digit app PIN.
///
/// The web does the hashing in a TanStack server function, but note *which*
/// Supabase client it uses: `context.supabase`, the user-scoped one — not the
/// admin client. Your RLS policies ("Users can view own profile" / "Users can
/// update own profile") already permit exactly this, so iOS can do the same
/// work locally without any server. The stored format is byte-for-byte the one
/// `mitid.server.ts` writes, so web and app stay interchangeable:
///
///     pbkdf2$100000$<salt hex>$<derived key hex>
nonisolated protocol PinService: Sendable {
    func setPin(_ pin: String) async throws
    func verifyPin(_ pin: String) async throws -> PinCheck
    func hasPin() async throws -> Bool
}

nonisolated enum PinCheck: Sendable, Equatable {
    case correct
    /// Wrong PIN. `attemptsLeft` is the server's count, and nil for the
    /// backends that keep no count — the screen then falls back to its own.
    case wrong(attemptsLeft: Int?)
    /// No PIN stored — the gate should let the user through.
    case notSet
    /// Too many wrong entries. The device is shut out for this many seconds,
    /// and the correct PIN will not open it until they elapse.
    case locked(forSeconds: Int)
}

nonisolated struct SupabasePinService: PinService {
    var client: SupabaseClient = .shared

    private struct PinRow: Decodable { let pin_hash: String? }

    func setPin(_ pin: String) async throws {
        let userID = try await client.auth.session.user.id
        try await client
            .from("profiles")
            .update(["pin_hash": PinHash.make(from: pin)])
            .eq("id", value: userID)
            .execute()
    }

    func verifyPin(_ pin: String) async throws -> PinCheck {
        guard let stored = try await storedHash() else { return .notSet }
        return PinHash.matches(pin, stored) ? .correct : .wrong(attemptsLeft: nil)
    }

    func hasPin() async throws -> Bool {
        try await storedHash() != nil
    }

    private func storedHash() async throws -> String? {
        let userID = try await client.auth.session.user.id
        let row: PinRow? = try await client
            .from("profiles")
            .select("pin_hash")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return row?.pin_hash
    }
}

// MARK: - Hashing

/// PBKDF2-SHA256, 100 000 iterations, 16-byte salt, 32-byte key.
///
/// Port of `hashPin` / `comparePin` in `src/lib/mitid.server.ts`.
nonisolated enum PinHash {
    static let iterations: UInt32 = 100_000
    private static let saltBytes = 16
    private static let keyBytes = 32

    static func make(from pin: String) -> String {
        var salt = [UInt8](repeating: 0, count: saltBytes)
        // SecRandomCopyBytes is the CSPRNG; never use `Int.random` for a salt.
        _ = SecRandomCopyBytes(kSecRandomDefault, saltBytes, &salt)
        let derived = derive(pin: pin, salt: salt)
        return "pbkdf2$\(iterations)$\(salt.hex)$\(derived.hex)"
    }

    static func matches(_ pin: String, _ stored: String) -> Bool {
        let parts = stored.split(separator: "$", omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "pbkdf2",
              let rounds = UInt32(parts[1]),
              let salt = [UInt8](hex: String(parts[2])),
              let expected = [UInt8](hex: String(parts[3]))
        else { return false }

        let actual = derive(pin: pin, salt: salt, iterations: rounds, length: expected.count)
        return actual.constantTimeEquals(expected)
    }

    private static func derive(
        pin: String,
        salt: [UInt8],
        iterations: UInt32 = iterations,
        length: Int = keyBytes
    ) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: length)
        let pinBytes = Array(pin.utf8)
        _ = pinBytes.withUnsafeBufferPointer { pinBuffer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                pinBuffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: pinBytes.count) { $0 },
                pinBytes.count,
                salt, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &out, length
            )
        }
        return out
    }
}

nonisolated private extension Array where Element == UInt8 {
    var hex: String { map { String(format: "%02x", $0) }.joined() }

    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = bytes
    }

    /// Compares in time independent of where the first difference is, so an
    /// attacker cannot learn the hash one byte at a time from response timing.
    func constantTimeEquals(_ other: [UInt8]) -> Bool {
        guard count == other.count else { return false }
        var diff: UInt8 = 0
        for i in indices { diff |= self[i] ^ other[i] }
        return diff == 0
    }
}
