//
//  DemoBackend.swift
//  SmartShop
//

import Foundation
import Supabase
import Synchronization

/// The device-local stand-in for Supabase, shared by every demo service.
///
/// It holds exactly the rows the real backend would: the auth user, the
/// `profiles` row, wheel spins, event tickets and the NFC log. Everything is
/// persisted to `UserDefaults`, so signing up, force-quitting and relaunching
/// behaves the way it will in production — which is the point of a demo that is
/// meant to show what the finished flow feels like.
/// `nonisolated` because it is reached from every isolation domain the app has —
/// including an `AsyncStream.onTermination` handler, which runs wherever the
/// consumer happened to stop listening. Its mutable state lives in a `Mutex`
/// rather than behind an `@unchecked Sendable` promise, so the compiler checks
/// the locking instead of taking our word for it.
nonisolated final class DemoBackend: Sendable {
    static let shared = DemoBackend()

    /// One `profiles` row, plus the handful of `auth.users` fields the app reads.
    struct Account: Codable {
        var userID: UUID = UUID()
        var email = ""
        var password = ""

        var fornavn = ""
        var efternavn = ""
        var telefon = ""
        var adresse = ""
        var postnr = ""
        var by = ""
        var markedsforing = false

        var favoritButik: String?
        var hjemLat: Double?
        var hjemLng: Double?
        var onboardingDone = false

        var pinHash: String?
        var verifikationStatus = "ikke_verificeret"
        var verifikationMetode: String?
        var noeglebrikNummer: String?
        var telefonVerificeret = false
        var emailVerificeret = false
    }

    struct Spin: Codable {
        var id = UUID().uuidString
        var date: String
        var won: Bool
        var prizeAmount: Int?
        var code: String?
    }

    struct State: Codable {
        var account: Account?
        var signedIn = false
        var spins: [Spin] = []
        var tickets: [String] = []
        var nfcLog: [NfcEntry] = []
    }

    struct NfcEntry: Codable {
        var id = UUID().uuidString
        var point: String
        var approved: Bool
        var at: Date
    }

    /// Everything mutable, under one lock. Keeping the listener list in here
    /// alongside the state means a broadcast cannot observe a half-applied write.
    private struct Storage {
        var state: State
        var continuations: [UUID: AsyncStream<Session?>.Continuation] = [:]
    }

    private let key = "smartshop.demo.state"
    private let storage: Mutex<Storage>

    private init() {
        let restored: State
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            restored = decoded
        } else {
            restored = State()
        }
        storage = Mutex(Storage(state: restored))
    }

    // MARK: Reading and writing

    func read<T>(_ body: (State) -> T) -> T {
        storage.withLock { body($0.state) }
    }

    func write(_ body: (inout State) -> Void) {
        storage.withLock { storage in
            body(&storage.state)
            if let data = try? JSONEncoder().encode(storage.state) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    var account: Account? { read { $0.account } }
    var isSignedIn: Bool { read { $0.signedIn && $0.account != nil } }

    /// Mutates the stored account, creating a blank one if sign-up has not run.
    func updateAccount(_ body: (inout Account) -> Void) {
        write { state in
            var account = state.account ?? Account()
            body(&account)
            state.account = account
        }
    }

    // MARK: Session

    /// A syntactically valid `Session` so `AuthSessionStore` behaves normally.
    /// Nothing reads its contents — the app only ever checks it for nil.
    func makeSession() -> Session? {
        guard let account = read({ $0.account }), read({ $0.signedIn }) else { return nil }
        let user = User(
            id: account.userID,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            email: account.email,
            createdAt: .now,
            updatedAt: .now
        )
        return Session(
            accessToken: "demo-access-token",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date.now.addingTimeInterval(3600).timeIntervalSince1970,
            refreshToken: "demo-refresh-token",
            user: user
        )
    }

    func signIn() {
        write { $0.signedIn = true }
        broadcast()
    }

    func signOut() {
        write { $0.signedIn = false }
        broadcast()
    }

    /// Wipes everything — used by the UI-test reset and available for a manual reset.
    func reset() {
        write { $0 = State() }
        UserDefaults.standard.removeObject(forKey: key)
        broadcast()
    }

    func sessionUpdates() -> AsyncStream<Session?> {
        AsyncStream { continuation in
            let id = UUID()
            storage.withLock { $0.continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.storage.withLock { $0.continuations[id] = nil }
            }
        }
    }

    private func broadcast() {
        // `makeSession()` takes the lock itself, and `yield` runs arbitrary
        // consumer code — so both stay outside `withLock`, which only copies
        // the listener list.
        let session = makeSession()
        let targets = storage.withLock { Array($0.continuations.values) }
        for continuation in targets { continuation.yield(session) }
    }
}
