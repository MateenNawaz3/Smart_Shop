//
//  MoreRoute.swift
//  SmartShop
//

import Foundation

/// Pages pushed from the More tab. The web's `/mere/*` routes plus the public
/// info pages it links to.
enum MoreRoute: Hashable {
    case receipts
    case receipt(id: String)
    case details
    case favorites
    case notifications
    case language
    case about
    case contact
    case faq
    case verification
    case access
}
