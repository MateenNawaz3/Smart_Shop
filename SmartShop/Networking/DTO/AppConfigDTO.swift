//
//  AppConfigDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/app/config
//   GET /health

nonisolated struct AppConfigDTO: Decodable, Sendable {
    var minimumBuild: Int
    var recommendedBuild: Int
    var maintenance: Bool
    var message: String?
    var storeUrl: StoreURLsDTO?
    /// Decoded as a dictionary rather than a fixed struct: the flags are a
    /// server-owned list, and a new one must not break the launch gate of a
    /// build that shipped before it existed.
    var features: [String: Bool]
    var languages: [String]?
    var serverTime: Date?
}

nonisolated struct StoreURLsDTO: Decodable, Sendable {
    var ios: String?
    var android: String?
}

nonisolated struct HealthDTO: Decodable, Sendable {
    var status: String
    var service: String
    var dependencies: DependenciesDTO?

    nonisolated struct DependenciesDTO: Decodable, Sendable {
        var database: String?
        var redis: String?
    }
}
