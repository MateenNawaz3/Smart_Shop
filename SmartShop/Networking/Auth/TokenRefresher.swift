//
//  TokenRefresher.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Single-flight refresh through POST /mobile/auth/refresh.
//
// Single-flight matters: on a cold launch the app fires several requests at
// once, and without coordination each 401 would start its own refresh and the
// losers would race. One refresh in flight; everyone else awaits it.
//
// The refresh token itself is unchanged by a refresh — keep using it. A refusal
// here is terminal: sign the user out.
