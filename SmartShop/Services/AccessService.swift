//
//  AccessService.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Protocol, plus its API and demo conformances.
//
// Follows the existing convention in this folder: the protocol and every
// implementation of it live together in one file.
//
// Door credentials, door history, unlocking, and asking for help.
//
// The decision moves to the server. Today the app decides the outcome in
// VerificationService.logNfcAccess and then writes its own verdict, which
// is not a defensible place for it.
//
// POST /access/help must always have somewhere to send someone: a refusal
// a customer cannot act on, at three in the morning outside an unmanned
// shop, is the one outcome this flow must not produce.
