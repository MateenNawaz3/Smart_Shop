//
//  EmptyResponse.swift
//  SmartShop
//

import Foundation

/// For endpoints whose `data` is empty or uninteresting, so they can use the
/// same generic decode path as everything else.
///
/// Decodes from anything — `null`, `{}`, an object with fields we ignore — so a
/// server that starts returning a body does not break a caller that never
/// wanted one.
nonisolated struct EmptyResponse: Decodable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws {}
}
