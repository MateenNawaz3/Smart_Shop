//
//  FormErrorUITests.swift
//  SmartShopUITests
//

import XCTest

/// Checks that invalid input is reported: message under the field and a red
/// border on the field itself.
final class FormErrorUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
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

    func testLoginShowsInvalidEmail() {
        let entry = app.buttons["Log in"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "welcome screen missing")
        entry.tap()

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5), "email field missing")
        email.tap()
        email.typeText("dsds")

        app.buttons.matching(
            NSPredicate(format: "label == 'Log in'")
        ).element(boundBy: 0).tap()

        XCTAssertTrue(
            app.staticTexts["Invalid email"].waitForExistence(timeout: 5),
            "email error not shown"
        )
        snap("20-login-invalid-email")
    }

    func testSignUpShowsFieldErrors() {
        let entry = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Create account with'")
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "welcome screen missing")
        entry.tap()
        let firstName = app.textFields.firstMatch
        XCTAssertTrue(firstName.waitForExistence(timeout: 5), "signup form missing")

        // The wizard greys out OK until the terms are accepted, as on the web.
        app.descendants(matching: .any)["signupTerms"].firstMatch.tap()
        app.buttons["OK"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts["Enter your first name"].waitForExistence(timeout: 5),
            "signup errors not shown"
        )
        snap("21-signup-errors")
    }
}
