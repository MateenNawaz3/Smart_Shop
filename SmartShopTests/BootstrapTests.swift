//
//  BootstrapTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("Launch gate")
struct LaunchGateTests {
    private func config(
        minimum: Int = 1,
        recommended: Int = 1,
        maintenance: Bool = false,
        message: String? = nil
    ) -> AppConfig {
        AppConfig(
            minimumBuild: minimum,
            recommendedBuild: recommended,
            maintenance: maintenance,
            message: message,
            storeURL: URL(string: "https://apps.apple.com/app/id1"),
            features: FeatureFlags(),
            languages: ["da"],
            serverTime: nil
        )
    }

    @Test("a current build is let through")
    func open() {
        #expect(config(minimum: 3, recommended: 5).gate(forBuild: 5) == .open)
    }

    @Test("a build below the recommendation is nudged, not stopped")
    func nudged() {
        let gate = config(minimum: 3, recommended: 5).gate(forBuild: 4)
        guard case .updateAvailable = gate else {
            Issue.record("expected .updateAvailable, got \(gate)")
            return
        }
    }

    @Test("a build below the minimum is blocked")
    func blocked() {
        let gate = config(minimum: 3, recommended: 5).gate(forBuild: 2)
        guard case .blocked(let url) = gate else {
            Issue.record("expected .blocked, got \(gate)")
            return
        }
        // Blocking without somewhere to go leaves the user stuck.
        #expect(url != nil)
    }

    /// Maintenance wins over the build numbers: a backend that is down cannot
    /// serve an update any better than it can serve the app, so telling someone
    /// to go and update would be a dead end.
    @Test("maintenance outranks an out-of-date build")
    func maintenanceFirst() {
        let gate = config(minimum: 9, maintenance: true, message: "Back at 14:00")
            .gate(forBuild: 1)
        guard case .maintenance(let message) = gate else {
            Issue.record("expected .maintenance, got \(gate)")
            return
        }
        #expect(message == "Back at 14:00")
    }
}

@Suite("App config service")
struct APIAppConfigServiceTests {
    private func makeService() -> (APIAppConfigService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        return (APIAppConfigService(client: client), exchange)
    }

    private static let configBody = """
    {"success":true,"data":{"minimumBuild":3,"recommendedBuild":7,"maintenance":false,
      "message":null,"storeUrl":{"ios":"https://apps.apple.com/app/id1","android":null},
      "features":{"contests":true,"events":true,"bulletinBoard":true,
        "faceEnrolment":false,"mitid":true,"guestMode":true},
      "languages":["da","en","de"],"serverTime":"2026-09-22T06:19:40.628Z"}}
    """

    @Test("the config decodes, including its fractional-second timestamp")
    func decodes() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: Self.configBody))

        let config = try await service.configuration()
        #expect(config.minimumBuild == 3)
        #expect(config.recommendedBuild == 7)
        #expect(config.features.contests)
        #expect(!config.features.faceEnrolment)
        #expect(config.languages == ["da", "en", "de"])
        #expect(config.serverTime != nil)
        #expect(config.storeURL?.host() == "apps.apple.com")
    }

    /// The launch gate has to answer before anyone has signed in.
    @Test("the config is fetched without a token")
    func unauthenticated() async throws {
        let (client, exchange) = makeStubbedClient(
            tokens: FakeTokenStore(access: "a", refresh: "r")
        )
        exchange.queue(.init(status: 200, body: Self.configBody))

        _ = try await APIAppConfigService(client: client).configuration()
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    /// A flag added server-side must not break the launch gate of a build that
    /// shipped before it existed.
    @Test("an unknown feature flag is kept, not fatal")
    func unknownFlag() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"minimumBuild":1,"recommendedBuild":1,"maintenance":false,
          "features":{"contests":true,"somethingNew":true},"languages":["da"]}}
        """))

        let config = try await service.configuration()
        #expect(config.features.contests)
        #expect(config.features["somethingNew"])
        // Absent means off: a feature the server has not mentioned is one the
        // app should not offer.
        #expect(!config.features.events)
        #expect(!config.features["neverHeardOfIt"])
    }

    @Test("health reports its dependencies")
    func health() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"status":"ok","service":"mobile-api",
          "dependencies":{"database":"up","redis":"up"}}}
        """))

        let report = try await service.health()
        #expect(report.isHealthy)
        #expect(report.service == "mobile-api")
    }

    @Test("a degraded dependency is not healthy")
    func degraded() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"status":"ok","service":"mobile-api",
          "dependencies":{"database":"up","redis":"down"}}}
        """))

        #expect(try await service.health().isHealthy == false)
    }
}

@Suite("Translation service")
struct APITranslationServiceTests {
    private func makeService() -> (APITranslationService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        return (APITranslationService(client: client), exchange)
    }

    @Test("the language list decodes")
    func languages() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[
          {"id":1,"name":"Dansk","shortCode":"da","countryIso2":"DK"},
          {"id":2,"name":"English","shortCode":"en","countryIso2":"US"}]}
        """))

        #expect(try await service.languages() == [.da, .en])
    }

    /// The app can only render a language it ships strings and a flag for, so a
    /// code it does not know is dropped rather than guessed at.
    @Test("an unknown language code is dropped")
    func unknownLanguage() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[
          {"id":1,"name":"Dansk","shortCode":"da","countryIso2":"DK"},
          {"id":9,"name":"Français","shortCode":"fr","countryIso2":"FR"}]}
        """))

        #expect(try await service.languages() == [.da])
    }

    @Test("a bundle decodes its strings")
    func bundle() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"language":{"id":2,"name":"English","shortCode":"en",
          "countryIso2":"US"},"platform":"mobile","isActive":true,
          "translation":{"door_granted":"Door open — come on in."}}}
        """))

        let bundle = try await service.bundle(for: .en)
        #expect(bundle.language == .en)
        #expect(bundle["door_granted"] == "Door open — come on in.")
        #expect(!bundle.isFallback(from: .en))
    }

    /// The dev backend answers `/translations/de` with Danish rather than
    /// failing. A caller that trusted its own request would show Danish door
    /// messages to a German speaker and never know, so the bundle reports the
    /// language it actually came back as.
    @Test("a silent language fallback is detectable")
    func fallbackIsVisible() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":{"language":{"id":1,"name":"Dansk","shortCode":"da",
          "countryIso2":"DK"},"platform":"mobile","isActive":true,
          "translation":{"door_granted":"Døren er åben — kom indenfor."}}}
        """))

        let bundle = try await service.bundle(for: .de)
        #expect(bundle.language == .da)
        #expect(bundle.isFallback(from: .de))
    }
}
