//
//  APIError.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Typed failures: transport, HTTP status, envelope-reported failure (carrying
// `code` and `message`), and decoding.
//
// Two cases deserve their own treatment rather than being lumped in with the
// rest, because the UI must handle them as ordinary states:
//
//   - `.unauthorized` — drives the guest gate sheet and the sign-out path
//   - `.unavailable` (503) — the prize wheel when CONTESTS_ENABLED is false,
//     and face enrolment when FACE_COLLECTION_ID is unset. Both are the normal
//     case in most environments, not a misconfiguration.
