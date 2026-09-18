//
//  APIClient.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// The protocol every API service talks through, plus the URLSession-backed
// implementation.
//
// Responsibilities:
//   - build a URLRequest from an APIRequest
//   - attach the bearer token and x-localization header
//   - decode the envelope and hand back `.data`
//   - map a failure into APIError
//   - on 401, ask TokenRefresher for a new access token and retry ONCE
//
// Everything above this line is generic; nothing in here knows about any
// particular endpoint.
