//
//  OfferAndPostTests.swift
//  SmartShopTests
//

import Foundation
import Testing
@testable import SmartShop

@Suite("Asset URLs")
struct AssetURLTests {
    /// Dev sends bare storage keys under a field named `imageUrl`.
    @Test("a relative key with no base is no image, not a broken URL")
    func relativeKeyWithoutBase() {
        #expect(AssetURL.resolve("banners/weekly-tuborg.png", base: nil) == nil)
    }

    @Test("a relative key joins the base when there is one")
    func relativeKeyWithBase() {
        let base = URL(string: "https://cdn.example.dk/assets")!
        #expect(AssetURL.resolve("banners/a.png", base: base)?.absoluteString == "https://cdn.example.dk/assets/banners/a.png")
        #expect(AssetURL.resolve("/banners/a.png", base: base)?.absoluteString == "https://cdn.example.dk/assets/banners/a.png")
    }

    @Test("absolute values are used as they are")
    func absolute() {
        #expect(AssetURL.resolve("https://x.dk/a.png", base: nil)?.absoluteString == "https://x.dk/a.png")
        #expect(AssetURL.resolve("//x.dk/a.png", base: nil)?.absoluteString == "https://x.dk/a.png")
        #expect(AssetURL.resolve("data:image/png;base64,AA==", base: nil) != nil)
    }

    @Test("empty and null are no image")
    func empty() {
        #expect(AssetURL.resolve(nil, base: nil) == nil)
        #expect(AssetURL.resolve("  ", base: nil) == nil)
    }
}

@Suite("Offer service")
struct APIOfferServiceTests {
    private func makeService() -> (APIOfferService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore(access: "a", refresh: "r"))
        return (APIOfferService(client: client), exchange)
    }

    /// Copied from dev on 2026-09-25, `GET /mobile/banners`, plus one banner
    /// in a placement the app does not render.
    private static let liveBanners = """
    {"success":true,"message":"Success","data":[
      {"id":"89a2656e","placement":"weekly","imageUrl":"banners/weekly-tuborg.png","alt":"Ugens tilbud","linkUrl":null,"storeId":null},
      {"id":"ede888ce","placement":"weekend","imageUrl":"banners/weekend-aeg.png","alt":"Weekendtilbud","linkUrl":null,"storeId":null},
      {"id":"x1","placement":"christmas","imageUrl":"https://x.dk/jul.png","alt":null,"linkUrl":"https://x.dk","storeId":null}]}
    """

    @Test("a rail keeps only its own placement, and a bare key is a missing image")
    func weeklyRail() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: Self.liveBanners))

        let weekly = await service.weeklyOffers()
        #expect(weekly.map(\.id) == ["89a2656e"])
        #expect(weekly.first?.artwork == .missing)
        #expect(weekly.first?.altText == "Ugens tilbud")
        let url = try #require(exchange.recorded.first?.url)
        #expect(url.path == "/mobile/banners")
        #expect(url.query?.contains("placement=weekly") == true)
    }

    @Test("a rail that fails to load is empty, not an error")
    func railFailure() async {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 500, body: #"{"success":false,"message":"boom","code":null,"data":null}"#))

        #expect(await service.weekendOffers().isEmpty)
    }

    @Test("only a web link is followed")
    func links() async {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[
          {"id":"a","placement":"weekend","imageUrl":null,"alt":null,"linkUrl":"https://smartshop.dk/tilbud","storeId":null},
          {"id":"b","placement":"weekend","imageUrl":null,"alt":null,"linkUrl":"javascript:alert(1)","storeId":null}]}
        """))

        let banners = await service.weekendOffers()
        #expect(banners.first?.link?.absoluteString == "https://smartshop.dk/tilbud")
        #expect(banners.last?.link == nil)
    }

    @Test("campaign offers read both discount kinds, and a numeric string")
    func campaignOffers() async throws {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 200, body: """
        {"success":true,"data":[
          {"id":"o1","headline":"20% på kaffe","body":null,"imageUrl":null,"discountType":"percentage",
           "discountValue":20,"code":null,"validTo":"2026-10-01T21:59:59.000Z","storeId":null},
          {"id":"o2","headline":"10 kr. rabat","body":"På alt brød","imageUrl":"https://x.dk/b.png","discountType":"fixed_amount",
           "discountValue":"10.00","code":"BROED","validTo":null,"storeId":"s1"},
          {"id":"o3","headline":"2 for 1","body":null,"imageUrl":null,"discountType":"bundle",
           "discountValue":null,"code":null,"validTo":null,"storeId":null}]}
        """))

        let offers = try await service.campaignOffers()
        #expect(offers.map(\.discount) == [.percentage(20), .amount(10), .other])
        // No artwork is still an offer: the discount is the point.
        #expect(offers[0].artwork == .missing)
        #expect(offers[0].validTo != nil)
        #expect(offers[1].artwork == .remote(URL(string: "https://x.dk/b.png")!))
        #expect(offers[1].code == "BROED")
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == "Bearer a")
    }

    @Test("signed out, the offers page fails rather than showing nothing")
    func offersNeedToken() async {
        let (service, exchange) = makeService()
        exchange.queue(.init(status: 401, body: #"{"success":false,"message":"Missing or malformed bearer token","code":"UNAUTHORIZED","data":null}"#))
        exchange.queue(.init(status: 401, body: #"{"success":false,"message":"Missing or malformed bearer token","code":"UNAUTHORIZED","data":null}"#))

        await #expect(throws: (any Error).self) { _ = try await service.campaignOffers() }
    }
}

@Suite("Post service")
struct APIPostServiceTests {
    private func makeService() -> (APIPostService, StubURLProtocol.Exchange) {
        let (client, exchange) = makeStubbedClient(tokens: FakeTokenStore())
        return (APIPostService(client: client), exchange)
    }

    @Test("the live payload decodes, with categories mapped from the API's spelling")
    func liveShape() async throws {
        let (service, exchange) = makeService()
        // Copied from dev on 2026-09-25, `GET /mobile/posts`, plus two edge cases.
        exchange.queue(.init(status: 200, body: """
        {"success":true,"message":"Success","data":[
          {"id":"ce673860","date":"2026-09-12","category":"news","title":"Nyt sortiment i butikkerne","body":"Tekst.","media":null,"storeId":null},
          {"id":"bde25e0a","date":"2026-09-05","category":"opening_soon","title":"Ny Smart Shop 24-7 på vej","body":"Tekst.","media":null,"storeId":null},
          {"id":"501b98a5","date":"2026-08-21","category":"from_opening","title":"Tak for en god åbningsdag","body":null,"media":"posts/aabning.jpg","storeId":null},
          {"id":"n4","date":"2026-08-01","category":"recipe","title":"Opskrift","body":"x","media":"https://x.dk/v.mp4","storeId":null}]}
        """))

        let posts = try await service.posts(limit: 2)
        #expect(posts.map(\.categoryKey) == [.news, .openingSoon, .fromOpening, nil])
        #expect(posts[0].title(.de) == "Nyt sortiment i butikkerne")
        // A bare key is no picture yet — the card is text-only, not broken.
        #expect(posts[2].media == nil)
        #expect(posts[2].body(.da) == "")
        #expect(posts[3].media?.type == "video")
        #expect(exchange.recorded.first?.url?.query?.contains("limit=2") == true)
        #expect(exchange.recorded.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
