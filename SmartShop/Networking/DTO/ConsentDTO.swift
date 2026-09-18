//
//  ConsentDTO.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Wire types for:
//
//   GET/PUT /mobile/me/consents
//   POST /mobile/me/deletion-request
//
// Append-only. Withdrawing writes a new record rather than erasing the
// grant, because "consented then withdrew" and "never consented" are
// different facts (GDPR art. 7(1)).
