//
//  TokenStore.swift
//  SmartShop
//

import Foundation

/// Keychain storage for the access and refresh tokens.
///
/// supabase-swift did this for us; on the Mobile API it is ours to own. This
/// reuses the existing `Keychain` helper in `Services/DeviceState.swift` rather
/// than standing up a second one, so every secret the app holds lives under one
/// service identifier with one accessibility policy.
///
/// Access tokens last 15 minutes. Refresh tokens are revoked by `/auth/logout`
/// and invalidated by a password change or reset.
nonisolated protocol TokenStoring: Sendable {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func save(accessToken: String, refreshToken: String?)
    func clear()
}

nonisolated struct KeychainTokenStore: TokenStoring {
    private enum Key {
        static let access = "ss247_access_token"
        static let refresh = "ss247_refresh_token"
    }

    var accessToken: String? { Keychain.get(Key.access) }
    var refreshToken: String? { Keychain.get(Key.refresh) }

    /// A refresh returns a new access token and *may* omit the refresh token,
    /// which means the existing one is still good. Passing `nil` therefore
    /// leaves it in place rather than wiping it — clearing it here would sign
    /// the user out on the first successful refresh.
    func save(accessToken: String, refreshToken: String?) {
        Keychain.set(accessToken, for: Key.access)
        if let refreshToken {
            Keychain.set(refreshToken, for: Key.refresh)
        }
    }

    func clear() {
        Keychain.remove(Key.access)
        Keychain.remove(Key.refresh)
    }
}
