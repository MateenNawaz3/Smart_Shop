//
//  TokenStore.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Keychain storage for the access and refresh tokens.
//
// supabase-swift did this for us; on the Mobile API it is ours to own. Reuse
// the existing `Keychain` helper in Services/DeviceState.swift rather than
// writing a second one.
//
// Access tokens last 15 minutes. Refresh tokens are revoked by /auth/logout and
// invalidated by a password change or reset.
