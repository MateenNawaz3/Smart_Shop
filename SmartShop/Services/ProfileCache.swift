//
//  ProfileCache.swift
//  SmartShop
//

import Foundation
import Observation

/// The signed-in user's first name, loaded once per session for the greeting
/// header on every inner page. The web re-queries it in `useProfileName` on
/// each page; caching it keeps the header stable while pages push and pop.
@MainActor
@Observable
final class ProfileCache {
    private(set) var firstName: String?

    func load(from profiles: any ProfileService) async {
        firstName = await profiles.firstName()
    }

    func set(firstName: String?) {
        self.firstName = firstName
    }

    func clear() { firstName = nil }
}
