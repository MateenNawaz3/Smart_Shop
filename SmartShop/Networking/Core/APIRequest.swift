//
//  APIRequest.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// One value describing a call: method, path, query items, body, and whether it
// needs a bearer token.
//
// Auth is a three-state choice, not a Bool — the API has endpoints that are
// required (most), optional (`/stores`, `/stores/{slug}` — they work signed out
// and say more signed in) and forbidden (`/app/config`, `/health`, `/pages`).
// Guest mode depends on the forbidden case sending no Authorization header at
// all, rather than an empty one.
