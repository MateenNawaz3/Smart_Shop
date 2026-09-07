//
//  StoresRoute.swift
//  SmartShop
//

import Foundation

/// Destinations inside the Stores tab. The web's `/find-butik/*` routes as one value.
enum StoresRoute: Hashable {
    case store(slug: String)
    case favorites
}
