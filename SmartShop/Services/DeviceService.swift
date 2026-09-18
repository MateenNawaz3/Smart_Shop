//
//  DeviceService.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Protocol, plus its API and demo conformances.
//
// Follows the existing convention in this folder: the protocol and every
// implementation of it live together in one file.
//
// Handset registration for push, and the per-device PIN.
//
// Upserts on the device identifier, so calling it at every launch is
// correct and cheap. The PIN unlocks THIS DEVICE, not the account — five
// wrong entries lock the device for 15 minutes, so a thief cannot lock the
// owner out of their other phone.
//
// Supersedes the locally-derived hash in Services/PinService.swift.
