//
//  APIOfferService.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// `OfferService` over the Mobile API.
//
// Covers: Campaign offers.
//
// The existing OfferService protocol returns bundled ImageResource values
// and serves both home rails. It has to change shape here: /offers and
// /banners are different endpoints answering different questions, and the
// images become remote URLs.
