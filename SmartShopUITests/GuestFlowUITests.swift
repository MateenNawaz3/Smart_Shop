//
//  GuestFlowUITests.swift
//  SmartShopUITests
//

import XCTest

/// Walks the guest (tourist) flow end to end and captures a screenshot of each
/// screen, so the port can be checked against the reference design.
final class GuestFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        // The template's launch tests rotate the simulator, and that
        // orientation persists between runs. Pin it, or these tests
        // inherit a landscape device and read wrong element frames.
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment = ["UITEST": "1", "UITEST_LANGUAGE": "en"]
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

    /// Taps the first button whose label contains `text`.
    ///
    /// Deliberately does not gate on `isHittable`: SwiftUI reports it
    /// unreliably for controls inside scroll views. Screens are settled by
    /// waiting for a known element before calling this instead.
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

    private func awaitHub(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.staticTexts["Welcome"].waitForExistence(timeout: 5),
            "guest hub did not appear", file: file, line: line
        )
    }

    func testGuestFlow() {
        // Wait for the welcome screen to finish its launch transition before
        // touching anything.
        XCTAssertTrue(
            app.buttons["Log in"].waitForExistence(timeout: 10), "welcome screen missing"
        )
        snap("01-welcome")

        tap("Guest")
        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5), "language chooser missing")
        snap("02-language")
        english.tap()

        awaitHub()
        snap("03-hub")

        // Stores — the real data from stores.json should be on screen.
        tap("Find a store")
        XCTAssertTrue(app.staticTexts["Grimstrup"].waitForExistence(timeout: 5), "store list empty")
        XCTAssertTrue(app.staticTexts["Roager"].exists)
        snap("04-stores")
        tap("Back to start")
        awaitHub()

        // How to shop. Each page is one combined element labelled
        // "<n>. <title>. <body>"; a bug in the string-catalog list lookup once
        // produced twenty pages here instead of five.
        tap("How to shop")
        let firstStep = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '1. Find the store.'")
        ).firstMatch
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5), "how-to carousel empty")
        let pages = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '^[0-9]+\\. [^.]+\\. .+'")
        )
        XCTAssertLessThanOrEqual(pages.count, 5, "carousel ran past the end of the step list")
        snap("05-howto")
        tap("Back to start")
        awaitHub()

        // Good to know
        tap("Good to know")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'pay'")).firstMatch
                .waitForExistence(timeout: 5),
            "good-to-know content missing"
        )
        snap("06-goodtoknow")
    }

    /// The language bar must switch the whole UI, not just the screen it is on.
    func testLanguageSwitchOnLogin() {
        tap("Log in")

        XCTAssertTrue(app.buttons["Deutsch"].waitForExistence(timeout: 5), "language bar missing on login")
        snap("07-login-default")

        app.buttons["Deutsch"].tap()
        XCTAssertTrue(
            app.staticTexts["Anmelden"].waitForExistence(timeout: 5),
            "switching to German did not retranslate the login screen"
        )
        snap("08-login-de")

        app.buttons["Dansk"].tap()
        XCTAssertTrue(
            app.staticTexts["Log ind"].waitForExistence(timeout: 5),
            "switching to Danish did not retranslate the login screen"
        )
        snap("09-login-da")
    }
}
