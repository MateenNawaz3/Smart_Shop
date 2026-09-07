//
//  GuestRoute.swift
//  SmartShop
//

import SwiftUI

/// Destinations inside guest mode. The web's `/gaest/*` routes, plus the
/// public info pages (`/om`, `/kontakt`, `/faq`, `/sprog`) the guest hub links to.
enum GuestRoute: Hashable {
    case hub
    case howToShop
    case stores
    case goodToKnow
    case about
    case contact
    case faq
    case language
}
