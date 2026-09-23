//
//  LiveAuthUITests.swift
//  SmartShopUITests
//

import XCTest

/// Proves that signing in really goes through the Mobile API, in the running
/// app, and that the two flows the switch turns off say so.
///
/// This test exists because of how module 4 went. `APIStoreService` was written,
/// tested and wired, and still never executed in the app — `AppEnvironment.live`
/// takes its demo branch, which was left pointing at the bundled list. Unit
/// tests cannot see that: they construct the service directly. Only the app can.
///
/// **The discriminator is the account.** `DemoAuthService` keeps its accounts in
/// `DemoBackend`, which `UITesting.resetPersistedState` wipes at launch — so on
/// the demo path *no* credentials work and the screen says so. Reaching the tab
/// shell therefore means a real server accepted a real password.
///
/// Skipped when `SMARTSHOP_LIVE_TESTS` is not set. **Run it on its own**, for
/// the reason given in `LiveStoresUITests`, and because repeated failed sign-ins
/// lock the probe account for fifteen minutes:
///
///     TEST_RUNNER_SMARTSHOP_LIVE_TESTS=1 xcodebuild test \
///       -scheme SmartShop -destination 'name=SmartShop-26' \
///       -only-testing:SmartShopUITests/LiveAuthUITests
final class LiveAuthUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Overridable so a throwaway account can be swapped in without a rebuild.
    private var email: String {
        ProcessInfo.processInfo.environment["SMARTSHOP_TEST_EMAIL"]
            ?? "claude.probe+auth@example.dk"
    }

    private var password: String {
        ProcessInfo.processInfo.environment["SMARTSHOP_TEST_PASSWORD"]
            ?? "TestPass123!"
    }

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
            "UITEST_LIVE_API": "1",
        ]
        app.terminate()
        app.launch()
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func testSignInGoesThroughTheMobileAPI() {
        XCTAssertTrue(
            app.buttons["Log in"].waitForExistence(timeout: 10), "welcome screen missing"
        )
        tap("Log in")

        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), "login form missing")
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.exists, "password field missing")
        passwordField.tap()
        passwordField.typeText(password)

        snap("20-login-filled")

        // The screen's own button carries the same label as the heading, so
        // take the one that is actually a button.
        app.buttons["Log in"].firstMatch.tap()

        // The brand tab bar only exists behind the auth gate. Generous timeout:
        // this is a real round trip to the dev environment.
        let homeTab = app.buttons["Home"]
        XCTAssertTrue(
            homeTab.waitForExistence(timeout: 25),
            "never reached the tab shell — sign-in did not succeed against the API"
        )
        for tab in ["Home", "Find store", "Contests", "More"] {
            XCTAssertTrue(app.buttons[tab].exists, "tab '\(tab)' missing")
        }
        snap("21-signed-in")
    }

    /// The ID sign-up wizard cannot finish on the Mobile API — it ends by
    /// exchanging a Supabase token hash, which has no equivalent. It says so up
    /// front instead of taking four steps of input and failing at the end.
    func testIdSignUpSaysItIsPaused() {
        XCTAssertTrue(
            app.buttons["Log in"].waitForExistence(timeout: 10), "welcome screen missing"
        )
        tap("Create account with Passport")

        XCTAssertTrue(
            app.staticTexts["Sign-up is paused"].waitForExistence(timeout: 10),
            "expected the paused notice in place of the details form"
        )
        // The form it replaces starts with these; none should be on screen.
        XCTAssertFalse(app.textFields["First name"].exists, "the details form is still showing")
        snap("22-signup-paused")
    }
}
