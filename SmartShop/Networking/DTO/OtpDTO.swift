//
//  OtpDTO.swift
//  SmartShop
//

// STRUCTURE ONLY — not implemented yet.
//
// Wire types for:
//
//   POST /mobile/otp/{email,phone}/send
//   POST /mobile/otp/{email,phone}/verify
//
// Verify takes ONLY the code. Sending `email` or `phone` alongside is
// rejected outright. In dev the send response carries devCode, because
// MAIL_TRANSPORT and SMS_TRANSPORT are both `log` and nothing is sent.
