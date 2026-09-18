//
//  IdentityDTO.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Wire types for:
//
//   GET /mobile/identity/status
//   POST /mobile/identity/document
//   GET/POST/DELETE /mobile/identity/face
//   POST /mobile/identity/mitid/{session,result}
//
// `enrolled` means a face is actually indexed and usable at a till, not
// that a photo was uploaded. `available: false` means no Rekognition in
// this environment — expect it, eu-north-1 does not offer it.
