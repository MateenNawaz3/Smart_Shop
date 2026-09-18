//
//  APIConfiguration.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Base URL and per-build environment selection.
//
// Replaces SupabaseConfig as the single place the backend address is chosen.
// Dev is http://localhost:3002; staging and production come later.
//
// Also owns the `x-localization` header value, which is read from
// LanguageStore so every request carries the language the UI is showing.
