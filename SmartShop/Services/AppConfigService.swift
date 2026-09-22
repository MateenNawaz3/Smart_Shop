//
//  AppConfigService.swift
//  SmartShop
//

import Foundation

/// Launch gate. Read before the first screen is drawn.
///
/// Decides three things the app cannot decide for itself: whether this build is
/// too old to run, whether the backend is in maintenance, and which features
/// exist at all. The Contests tab should be hidden by the feature flag rather
/// than shown and left to 503.
nonisolated protocol AppConfigService: Sendable {
    func configuration() async throws -> AppConfig
    /// Unauthenticated, and outside the `/mobile` prefix. Tells "the backend is
    /// down" apart from "my token is bad".
    func health() async throws -> HealthReport
}

/// This build's number, for comparison against `minimumBuild`.
nonisolated enum AppBuild {
    static var current: Int {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return value.flatMap(Int.init) ?? 1
    }
}

/// Stands in while the app still runs on Supabase: everything on, nothing
/// blocked. It answers rather than throwing, because a launch gate that fails
/// closed would make the app unusable offline.
nonisolated struct PermissiveAppConfigService: AppConfigService {
    func configuration() async throws -> AppConfig {
        AppConfig(
            minimumBuild: 0,
            recommendedBuild: 0,
            maintenance: false,
            message: nil,
            storeURL: nil,
            features: FeatureFlags(
                contests: true,
                events: true,
                bulletinBoard: true,
                faceEnrolment: false,
                mitID: true,
                guestMode: true
            ),
            languages: AppLanguage.allCases.map(\.rawValue),
            serverTime: nil
        )
    }

    func health() async throws -> HealthReport {
        HealthReport(status: "ok", service: "demo", databaseUp: true, redisUp: true)
    }
}
