//
//  HomeUITests.swift
//  SmartShopUITests
//

import XCTest

/// Covers the signed-in home screen, reached via the `-uiTestingSignedIn`
/// launch argument (see `UITestingSupport.swift`).
final class HomeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        // The template's launch tests rotate the simulator, and that
        // orientation persists between runs. Pin it, or these tests
        // inherit a landscape device and read wrong element frames.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment = ["UITEST_SIGNED_IN": "1", "UITEST_LANGUAGE": "en"]
        // Terminate first: a still-running instance from a previous suite is
        // reused as-is, so it would keep that suite's launch arguments.
        app.terminate()
        app.launch()
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHomeScreen() {
        // Greeting uses the stubbed profile name.
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'Mateen'")
            ).firstMatch.waitForExistence(timeout: 8),
            "greeting missing"
        )
        snap("10-home-top")

        // The how-to card starts on step 1 of 5.
        XCTAssertEqual(app.staticTexts["howToShopCounter"].label, "1/4")

        // The brand tab bar is a custom view, not a system tab bar.
        for tab in ["Home", "Find store", "Contests", "More"] {
            XCTAssertTrue(app.buttons[tab].exists, "tab '\(tab)' missing")
        }

        app.swipeUp()
        XCTAssertTrue(
            app.staticTexts["This week's top offers"].waitForExistence(timeout: 5),
            "weekly offers section missing"
        )
        snap("11-home-offers")
        app.swipeUp()

        XCTAssertTrue(
            app.staticTexts["Bulletin board"].waitForExistence(timeout: 5),
            "bulletin board missing"
        )
        app.swipeUp()
        snap("12-home-bulletin")
    }

    /// Advancing the how-to card must move the counter.
    func testHowToShopStepper() {
        let counter = app.staticTexts["howToShopCounter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 8), "step counter missing")
        XCTAssertEqual(counter.label, "1/4")

        let next = app.buttons["Next step"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "next arrow missing")
        next.tap()

        let advanced = expectation(
            for: NSPredicate(format: "label == '2/4'"), evaluatedWith: counter
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [advanced], timeout: 5), .completed,
            "next arrow did not advance the step"
        )
        snap("13-home-step2")
    }
}
