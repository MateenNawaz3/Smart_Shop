//
//  LiveStoresUITests.swift
//  SmartShopUITests
//

import XCTest

/// Proves the store finder really reads the Mobile API, in the running app.
///
/// Every other UI test runs on bundled data and needs no network. This one
/// deliberately does not: nothing else can show that the wiring works, because
/// while every service is a stand-in the screens look identical either way.
///
/// **The discriminator is the order.** Both sources carry the same ten shops,
/// so a name proves nothing. The bundled `stores.json` is in file order and
/// starts with Grimstrup; the API returns them alphabetically, starting with
/// Bakkelandet. What is on top therefore says which one answered.
///
/// Skipped when `SMARTSHOP_LIVE_TESTS` is not set, like the other tests that
/// need the dev backend.
///
/// **Run it on its own.** UI tests run in parallel simulator clones, and this
/// one waits on the network; alongside the others it starves their ten-second
/// timeouts and a different guest test fails each run. The other fourteen pass
/// consistently without it, and this one passes consistently alone:
///
///     TEST_RUNNER_SMARTSHOP_LIVE_TESTS=1 xcodebuild test \
///       -scheme SmartShop -destination 'name=SmartShop-26' \
///       -only-testing:SmartShopUITests/LiveStoresUITests
final class LiveStoresUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SMARTSHOP_LIVE_TESTS"] == "1",
            "needs the dev backend"
        )
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment = [
            "UITEST": "1",
            "UITEST_LANGUAGE": "en",
            // Opt this one test back onto the real API.
            "UITEST_LIVE_API": "1",
        ]
        app.terminate()
        app.launch()
    }

    @discardableResult
    private func tap(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let element = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", text)
        ).firstMatch
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("no button containing '\(text)'", file: file, line: line)
            return false
        }
        element.tap()
        return true
    }

    func testStoreFinderReadsTheMobileAPI() {
        XCTAssertTrue(
            app.buttons["Log in"].waitForExistence(timeout: 10), "welcome screen missing"
        )

        // Guest mode: the store finder is readable with no account, which is
        // exactly what the API's optional auth is for.
        tap("Guest")
        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5), "language chooser missing")
        english.tap()

        XCTAssertTrue(app.staticTexts["Welcome"].waitForExistence(timeout: 5), "guest hub missing")
        tap("Find a store")

        // The bundled list shows first and is replaced in place, so wait for
        // the API's ordering rather than asserting on the first frame.
        let bakkelandet = app.staticTexts["Bakkelandet"]
        XCTAssertTrue(bakkelandet.waitForExistence(timeout: 15), "store list never appeared")

        // Take ONE snapshot of every label on screen and reason about that.
        // Querying element by element re-snapshots each time, and the list is
        // being replaced underneath — an earlier version of this test failed
        // with a snapshot error for exactly that reason.
        let shopNames: Set<String> = [
            "Bakkelandet", "Ballum", "Bolderslev", "Espe", "Faldsled",
            "Grimstrup", "Hunderup-Sejstrup", "Rarup", "Roager", "Skrydstrup",
        ]
        let visible = app.staticTexts.allElementsBoundByIndex
            .filter { shopNames.contains($0.label) }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map(\.label)

        XCTAssertGreaterThan(visible.count, 1, "expected several shops on screen, saw \(visible)")

        // Alphabetical order is the API's signature: the bundled stores.json is
        // in file order and would put Grimstrup at the top.
        XCTAssertEqual(
            visible.first,
            "Bakkelandet",
            "top of the list is \(visible.first ?? "nothing") — this looks like the bundled file, not the API"
        )
        XCTAssertEqual(visible, visible.sorted(), "the visible shops are not in alphabetical order")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "store-finder-from-api"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
