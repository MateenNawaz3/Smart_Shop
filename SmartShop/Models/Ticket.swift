//
//  Ticket.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// A held seat.
//
// Needs an explicit status — confirmed / reserved / cancelled — plus
// awaitingPayment and expiresAt. A reserved ticket must never render as a
// completed purchase: there is no in-app payment path, and the seat is
// released when it expires.
//
// `code` is what the door scans; render it as a barcode.
