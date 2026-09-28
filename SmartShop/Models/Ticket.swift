//
//  Ticket.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// A held seat.
//
// Needs an explicit status — confirmed / reserved / cancelled / expired — and
// expiresAt. A reserved ticket must never render as a completed purchase, or
// as something to pay for: no payment path exists, and the seat is released
// when it expires.
//
// `code` is what the door scans; render it as a barcode.
