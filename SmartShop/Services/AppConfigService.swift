//
//  AppConfigService.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Protocol, plus its API and demo conformances.
//
// Follows the existing convention in this folder: the protocol and every
// implementation of it live together in one file.
//
// Launch gate. Read before the first screen is drawn.
//
// Decides three things the app cannot decide for itself: whether this
// build is too old to run, whether the backend is in maintenance, and
// which features exist at all. The Contests tab should be hidden by the
// feature flag rather than shown and left to 503.
