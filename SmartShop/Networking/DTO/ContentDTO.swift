//
//  ContentDTO.swift
//  SmartShop
//

import Foundation

// Wire types for:
//
//   GET /mobile/pages
//   GET /mobile/pages/{key}
//
// Bulletin-board posts and promotional banners belong to module 5 and are not
// implemented yet.
//
// Page CONTENT comes from here; UI LABELS come from /mobile/translations. The
// two are deliberately separate.

nonisolated struct PageDTO: Decodable, Sendable {
    var key: String
    var title: String
    var body: String
    var updatedAt: Date?
}
