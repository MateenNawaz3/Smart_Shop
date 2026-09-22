//
//  HTTPMethod.swift
//  SmartShop
//

import Foundation

/// The verbs the Mobile API uses.
nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
