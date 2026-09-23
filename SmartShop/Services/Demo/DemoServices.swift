//
//  DemoServices.swift
//  SmartShop
//

import Foundation
import Supabase

// MARK: - Auth

/// Sign-in, sign-up and session handling against `DemoBackend`.
///
/// Validation is deliberately as strict as the real thing: a wrong password is
/// rejected, an unknown email is rejected, and the error keys are the same ones
/// `AuthErrorText` maps Supabase failures onto. What you see in demo mode is
/// what you will see in production.
struct DemoAuthService: AuthService {
    var backend: DemoBackend = .shared

    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    func currentSession() async -> AuthSession? { backend.makeSession() }

    func sessionUpdates() -> AsyncStream<AuthSession?> { backend.sessionUpdates() }

    func signIn(email: String, password: String) async throws {
        await DemoMode.pause()
        guard let account = backend.account,
              account.email.caseInsensitiveCompare(email) == .orderedSame,
              account.password == password
        else {
            // Same wording Supabase returns, so `AuthErrorText.signIn` maps it
            // to "login.errWrong" exactly as it will against the real backend.
            throw Failure(message: "Invalid login credentials")
        }
        backend.signIn()
    }

    func signUp(email: String, password: String, profile: SignUpProfile) async throws -> SignUpOutcome {
        await DemoMode.pause()
        if let existing = backend.account, existing.email.caseInsensitiveCompare(email) == .orderedSame {
            throw Failure(message: "User already registered")
        }
        backend.updateAccount { account in
            account.email = email
            account.password = password
            account.fornavn = profile.fornavn
            account.efternavn = profile.efternavn
            account.adresse = profile.adresse
            account.postnr = profile.postnr
            account.by = profile.by
            account.telefon = profile.telefon
            account.markedsforing = profile.markedsforing
        }
        backend.signIn()
        return .signedIn
    }

    func sendPasswordReset(to email: String) async throws {
        await DemoMode.pause()
        // Succeeds either way, exactly as the real one does: telling the caller
        // whether an address exists would turn this into an account oracle.
    }

    func updatePassword(_ newPassword: String) async throws {
        await DemoMode.pause()
        backend.updateAccount { $0.password = newPassword }
    }

    /// The MitID and ID sign-up flows both end here, exchanging a one-time
    /// token for a session. In demo mode the token was minted locally, so this
    /// just completes the sign-in.
    func verifyEmailToken(hash: String) async throws {
        await DemoMode.pause(0.4)
        guard hash.hasPrefix("demo-") else { throw Failure(message: "Invalid token") }
        backend.signIn()
    }

    func signOut() async throws {
        backend.signOut()
    }
}

// MARK: - ID sign-up

/// Account creation from name and address alone.
///
/// The validation below is a line-for-line port of the `inputValidator` in the
/// web's `startIdSignup`, so the demo rejects exactly what the server will.
struct DemoIdSignupService: IdSignupService {
    var backend: DemoBackend = .shared

    func start(_ details: IdSignupDetails) async throws -> String {
        await DemoMode.pause(0.9)

        let fornavn = details.fornavn.trimmingCharacters(in: .whitespacesAndNewlines)
        let efternavn = details.efternavn.trimmingCharacters(in: .whitespacesAndNewlines)
        let adresse = details.adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        let postnr = details.postnr.trimmingCharacters(in: .whitespacesAndNewlines)
        let by = details.by.trimmingCharacters(in: .whitespacesAndNewlines)

        guard (2...60).contains(fornavn.count) else { throw DemoAuthService.Failure(message: "Ugyldigt fornavn") }
        guard (1...60).contains(efternavn.count) else { throw DemoAuthService.Failure(message: "Ugyldigt efternavn") }
        guard !adresse.isEmpty, adresse.count <= 120 else { throw DemoAuthService.Failure(message: "Ugyldig adresse") }
        guard postnr.wholeMatch(of: /\d{4}/) != nil else { throw DemoAuthService.Failure(message: "Ugyldigt postnummer") }
        guard !by.isEmpty, by.count <= 80 else { throw DemoAuthService.Failure(message: "Ugyldig by") }

        // The web creates the auth user with a placeholder address and promotes
        // the real email later, at the email-code step. Same shape here.
        backend.updateAccount { account in
            account.email = "\(UUID().uuidString.lowercased())@id-konto.local"
            account.fornavn = fornavn
            account.efternavn = efternavn
            account.adresse = adresse
            account.postnr = postnr
            account.by = by
            account.markedsforing = details.markedsforing
        }
        return "demo-\(UUID().uuidString)"
    }
}

// MARK: - MitID

/// The MitID demo login. The real one resolves an identity server-side; this
/// one records the name and mints the same shape of one-time token.
struct DemoMitIDService: MitIDService {
    var backend: DemoBackend = .shared

    func demoLogin(name: String, birthDate: String) async throws -> MitIDLogin {
        await DemoMode.pause(1.1)
        let parts = name.split(separator: " ")
        backend.updateAccount { account in
            account.email = "\(UUID().uuidString.lowercased())@mitid.local"
            account.fornavn = parts.first.map(String.init) ?? name
            account.efternavn = parts.dropFirst().joined(separator: " ")
            account.verifikationStatus = "verificeret"
            account.verifikationMetode = "mitid"
        }
        return MitIDLogin(email: backend.account?.email ?? "", tokenHash: "demo-\(UUID().uuidString)", isNew: true)
    }
}

// MARK: - Profile

struct DemoProfileService: ProfileService {
    var backend: DemoBackend = .shared

    func firstName() async -> String? {
        let name = backend.account?.fornavn.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? nil : name
    }

    func summary() async -> ProfileSummary? {
        guard let a = backend.account else { return nil }
        return ProfileSummary(fornavn: a.fornavn, efternavn: a.efternavn, by: a.by, email: a.email)
    }

    func details() async throws -> ProfileDetails? {
        guard let a = backend.account else { return nil }
        return ProfileDetails(
            fornavn: a.fornavn, efternavn: a.efternavn, telefon: a.telefon,
            adresse: a.adresse, postnr: a.postnr, by: a.by,
            markedsforing: a.markedsforing, email: a.email
        )
    }

    func update(_ d: ProfileDetails) async throws {
        await DemoMode.pause(0.5)
        backend.updateAccount { account in
            account.fornavn = d.fornavn.trimmingCharacters(in: .whitespaces)
            account.efternavn = d.efternavn.trimmingCharacters(in: .whitespaces)
            account.telefon = d.telefon.trimmingCharacters(in: .whitespaces)
            account.adresse = d.adresse.trimmingCharacters(in: .whitespaces)
            account.postnr = d.postnr.trimmingCharacters(in: .whitespaces)
            account.by = d.by.trimmingCharacters(in: .whitespaces)
            account.markedsforing = d.markedsforing
        }
    }

    func setMarketing(_ enabled: Bool) async throws {
        await DemoMode.pause(0.35)
        backend.updateAccount { $0.markedsforing = enabled }
    }

    func storeProfile() async throws -> StoreProfile? {
        guard let a = backend.account else { return nil }
        var home: GeoPoint?
        if let lat = a.hjemLat, let lng = a.hjemLng { home = GeoPoint(lat: lat, lng: lng) }
        return StoreProfile(
            favoriteStore: a.favoritButik, adresse: a.adresse, postnr: a.postnr,
            by: a.by, home: home, onboardingDone: a.onboardingDone
        )
    }

    func setFavoriteStore(_ slug: String, home: GeoPoint?) async throws {
        await DemoMode.pause(0.35)
        backend.updateAccount { account in
            account.favoritButik = slug
            if let home {
                account.hjemLat = home.lat
                account.hjemLng = home.lng
            }
        }
    }

    func setHome(_ point: GeoPoint) async throws {
        backend.updateAccount { account in
            account.hjemLat = point.lat
            account.hjemLng = point.lng
        }
    }

    func setOnboardingDone() async throws {
        backend.updateAccount { $0.onboardingDone = true }
    }

    func saveContactDetails(
        fornavn: String, efternavn: String, email: String, telefon: String,
        adresse: String, postnr: String, by: String
    ) async throws {
        await DemoMode.pause(0.6)
        backend.updateAccount { account in
            account.fornavn = fornavn
            account.efternavn = efternavn
            account.email = email
            account.telefon = telefon
            account.adresse = adresse
            account.postnr = postnr
            account.by = by
        }
    }
}

// MARK: - PIN

/// Stores the PIN with the same PBKDF2 format the live service writes, so the
/// unlock screen exercises the real hashing and comparison code.
struct DemoPinService: PinService {
    var backend: DemoBackend = .shared

    func setPin(_ pin: String) async throws {
        await DemoMode.pause(0.4)
        backend.updateAccount { $0.pinHash = PinHash.make(from: pin) }
    }

    func verifyPin(_ pin: String) async throws -> PinCheck {
        await DemoMode.pause(0.3)
        guard let stored = backend.account?.pinHash else { return .notSet }
        return PinHash.matches(pin, stored) ? .correct : .wrong(attemptsLeft: nil)
    }

    func hasPin() async throws -> Bool { backend.account?.pinHash != nil }
}

// MARK: - Verification, NFC and tickets

struct DemoVerificationService: VerificationService {
    var backend: DemoBackend = .shared

    func info() async throws -> VerificationInfo {
        guard let a = backend.account else { return VerificationInfo() }
        let email = a.email.hasSuffix("@mitid.local") || a.email.hasSuffix("@id-konto.local") ? "" : a.email
        return VerificationInfo(
            status: VerificationStatus(rawValue: a.verifikationStatus) ?? .none,
            method: a.verifikationMetode.flatMap(VerificationMethod.init(rawValue:)),
            keyFob: a.noeglebrikNummer ?? "",
            phone: a.telefon,
            phoneVerified: a.telefonVerificeret,
            email: email,
            emailVerified: a.emailVerificeret
        )
    }

    /// The web auto-approves uploads while `DEMO_AUTO_APPROVE` is on. Same here.
    func submit(method: VerificationMethod, front: Data, back: Data?) async throws -> VerificationStatus {
        await DemoMode.pause(1.2)
        backend.updateAccount { account in
            account.verifikationStatus = "verificeret"
            account.verifikationMetode = method.rawValue
        }
        return .verified
    }

    func saveKeyFob(_ number: String?) async throws {
        await DemoMode.pause(0.4)
        backend.updateAccount { $0.noeglebrikNummer = number }
    }

    func logNfcAccess(point: String, storeSlug: String?) async throws -> Bool {
        let verified = backend.account?.verifikationStatus == "verificeret"
        backend.write { $0.nfcLog.insert(.init(point: point, approved: verified, at: .now), at: 0) }
        return verified
    }

    func recentNfcAccess() async throws -> [NfcAccessEntry] {
        backend.read { state in
            state.nfcLog.prefix(5).map {
                NfcAccessEntry(id: $0.id, point: $0.point, approved: $0.approved, at: $0.at)
            }
        }
    }

    func boughtTicketEventIds() async throws -> [String] { backend.read { $0.tickets } }

    func buyTicket(for event: AppEvent) async throws {
        await DemoMode.pause(0.8)
        backend.write { $0.tickets.append(event.id) }
    }
}

// MARK: - Prize wheel

/// One spin a day, drawn locally. `alwaysWin` mirrors the web's
/// `DEV_ALWAYS_WIN`; set it to `false` to exercise the real odds and the
/// once-a-day limit.
struct DemoWheelService: WheelService {
    var backend: DemoBackend = .shared
    var alwaysWin = true

    private var today: String { SupabaseWheelService.copenhagenToday() }

    func status() async throws -> SpinResult? {
        if alwaysWin { return nil }
        guard let spin = backend.read({ $0.spins.first { $0.date == today } }) else { return nil }
        return SpinResult(alreadySpun: true, outcome: spin.won ? .win : .lose,
                          prizeAmount: spin.prizeAmount.map { Kroner($0) }, code: spin.code, spinDate: spin.date)
    }

    func wins() async throws -> [WheelWin] {
        backend.read { state in
            state.spins.filter(\.won).sorted { $0.date > $1.date }.compactMap { spin in
                guard let amount = spin.prizeAmount, let code = spin.code else { return nil }
                return WheelWin(id: spin.id, prizeAmount: Kroner(amount), code: code, spinDate: spin.date)
            }
        }
    }

    func spin() async throws -> SpinResult {
        await DemoMode.pause(0.5)

        if alwaysWin {
            let result = SpinResult(alreadySpun: false, outcome: .win, prizeAmount: Kroner(50),
                                    code: SupabaseWheelService.generateBarcode(), spinDate: today)
            backend.write { $0.spins.insert(.init(date: today, won: true, prizeAmount: 50, code: result.code), at: 0) }
            return result
        }

        if let existing = backend.read({ $0.spins.first { $0.date == today } }) {
            return SpinResult(alreadySpun: true, outcome: existing.won ? .win : .lose,
                              prizeAmount: existing.prizeAmount.map { Kroner($0) }, code: existing.code, spinDate: existing.date)
        }

        // The web's odds: 15% win, 45% try again, the rest a loss.
        let roll = Double.random(in: 0..<1)
        if roll < 0.15 {
            let code = SupabaseWheelService.generateBarcode()
            backend.write { $0.spins.insert(.init(date: today, won: true, prizeAmount: 50, code: code), at: 0) }
            return SpinResult(alreadySpun: false, outcome: .win, prizeAmount: Kroner(50), code: code, spinDate: today)
        }
        if roll < 0.60 {
            // "Try again" does not use up the day's spin.
            return SpinResult(alreadySpun: false, outcome: .retry, prizeAmount: nil, code: nil, spinDate: today)
        }
        backend.write { $0.spins.insert(.init(date: today, won: false, prizeAmount: nil, code: nil), at: 0) }
        return SpinResult(alreadySpun: false, outcome: .lose, prizeAmount: nil, code: nil, spinDate: today)
    }
}
