//
//  AppConfig.swift
//  SmartShop
//

import Foundation

/// The launch gate: minimum and recommended build, maintenance flag, feature
/// flags.
///
/// Read before the first screen is drawn. It decides three things the app
/// cannot decide for itself — whether this build is too old to run, whether the
/// backend is in maintenance, and which features exist at all.
nonisolated struct AppConfig: Sendable, Equatable {
    var minimumBuild: Int
    var recommendedBuild: Int
    var maintenance: Bool
    /// Copy to show on the maintenance screen, when the server supplies any.
    var message: String?
    var storeURL: URL?
    var features: FeatureFlags
    /// Language codes the backend considers live. Note this is *not* always the
    /// same list `/translations/languages` returns — see `TranslationService`.
    var languages: [String]
    var serverTime: Date?

    /// What the app should do about this build.
    ///
    /// Maintenance is checked before the build numbers: a backend that is down
    /// cannot serve an update any better than it can serve the app.
    func gate(forBuild build: Int) -> LaunchGate {
        if maintenance { return .maintenance(message: message) }
        if build < minimumBuild { return .blocked(storeURL: storeURL) }
        if build < recommendedBuild { return .updateAvailable(storeURL: storeURL) }
        return .open
    }
}

nonisolated enum LaunchGate: Sendable, Equatable {
    /// Carry on into the app.
    case open
    /// Nudge, but let them past.
    case updateAvailable(storeURL: URL?)
    /// Too old to run. There is no "later" button on this one.
    case blocked(storeURL: URL?)
    case maintenance(message: String?)
}

/// Which features exist at all.
///
/// The Contests tab should be hidden by its flag rather than drawn and left to
/// answer 503 when tapped.
///
/// Every flag defaults to `false`: a feature the server has not mentioned is one
/// the app should not offer. Unknown flags are kept in `others` so a backend
/// that adds one does not break decoding here.
nonisolated struct FeatureFlags: Sendable, Equatable {
    var contests = false
    var events = false
    var bulletinBoard = false
    var faceEnrolment = false
    var mitID = false
    var guestMode = false
    /// Flags this build does not know about yet.
    var others: [String: Bool] = [:]

    subscript(name: String) -> Bool {
        switch name {
        case "contests": contests
        case "events": events
        case "bulletinBoard": bulletinBoard
        case "faceEnrolment": faceEnrolment
        case "mitid": mitID
        case "guestMode": guestMode
        default: others[name] ?? false
        }
    }
}

/// `/health` — unauthenticated, and outside the `/mobile` prefix.
///
/// Its one job is telling "the backend is down" apart from "my token is bad".
/// Both otherwise look like a failed request, and they need opposite responses:
/// wait, versus sign in again.
nonisolated struct HealthReport: Sendable, Equatable {
    var status: String
    var service: String
    var databaseUp: Bool
    var redisUp: Bool

    var isHealthy: Bool { status == "ok" && databaseUp && redisUp }
}
