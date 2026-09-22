//
//  MitIDCallbackTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("MitID deep link")
struct MitIDCallbackTests {
    private func callback(_ string: String) -> MitIDCallback? {
        URL(string: string).flatMap(MitIDCallback.init(url:))
    }

    @Test("a success carries the one-time reference and the state")
    func success() throws {
        let parsed = try #require(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=xyz")
        )
        #expect(parsed.outcome == .success(reference: "abc123def456ghi7"))
        #expect(parsed.state == "xyz")
    }

    /// Verified live: the server's callback answers a cancelled sign-in with
    /// `302 smartshop://mitid?status=error&reason=session_expired&state=…`.
    @Test("an error carries its reason and still echoes the state")
    func failure() throws {
        let parsed = try #require(
            callback("smartshop://mitid?status=error&reason=session_expired&state=abc123xyz")
        )
        #expect(parsed.outcome == .failure(reason: "session_expired"))
        #expect(parsed.state == "abc123xyz")
    }

    @Test("an error with no state still parses")
    func failureWithoutState() throws {
        let parsed = try #require(callback("smartshop://mitid?status=error&reason=session_expired"))
        #expect(parsed.outcome == .failure(reason: "session_expired"))
        #expect(parsed.state == nil)
    }

    @Test("the trailing-slash form the server sends also parses")
    func trailingSlash() throws {
        let parsed = try #require(
            callback("smartshop://mitid/?status=error&reason=session_expired&state=abc")
        )
        #expect(parsed.state == "abc")
    }

    @Test("other smartshop links are not MitID callbacks")
    func otherRoutes() {
        #expect(callback("smartshop://auth-callback?type=recovery") == nil)
        #expect(callback("https://example.com/mitid?reference=abc") == nil)
    }

    /// `status=error` wins even if a reference somehow rides along, rather than
    /// redeeming something the server has already called a failure.
    @Test("an error with a reference is still an error")
    func errorBeatsReference() throws {
        let parsed = try #require(
            callback("smartshop://mitid?status=error&reason=access_denied&reference=abc123def456ghi7")
        )
        #expect(parsed.outcome == .failure(reason: "access_denied"))
    }

    // MARK: - State checking

    /// The reference is single-use server-side, but that protects the server.
    /// Without this check a deep link injected from anywhere hands the app a
    /// reference it never asked for, and it signs the user in as whoever
    /// minted it.
    @Test("a callback from a different attempt does not match")
    func mismatchedState() throws {
        let parsed = try #require(
            callback("smartshop://mitid?status=success&reference=abc123def456ghi7&state=attacker")
        )
        #expect(!parsed.matches(state: "ours"))
        #expect(parsed.matches(state: "attacker"))
    }

    /// Accepting a missing state would defeat the whole check — an injected
    /// link simply omits it.
    @Test("a callback with no state never matches")
    func missingStateNeverMatches() throws {
        let parsed = try #require(callback("smartshop://mitid?status=success&reference=abc123def456ghi7"))
        #expect(parsed.state == nil)
        #expect(!parsed.matches(state: "ours"))
    }
}
