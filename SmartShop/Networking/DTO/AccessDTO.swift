//
//  AccessDTO.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Wire types for:
//
//   GET/POST /mobile/access/credentials
//   DELETE /mobile/access/credentials/{id}
//   GET /mobile/access/history
//   POST /mobile/access/unlock
//   POST /mobile/access/help
//
// The unlock response carries a decision and one of seven refusal reasons.
// doorOpened is false when the decision was a grant but no physical door
// responded — those are different facts and the UI must not merge them.
