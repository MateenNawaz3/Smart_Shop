//
//  APIEnvelope.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// The response shape every mobile endpoint returns, on success and on failure
// alike:
//
//     { success, message, code, data }
//
// Read `.data` when success is true and `.message` when it is false; tell them
// apart by `success`. `code` is the stable identifier to translate against —
// never the message text, which is prose and may change.
//
// (admin-api is NOT enveloped. kiosk-api is. This type is for /mobile only.)
