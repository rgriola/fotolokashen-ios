//
//  fotolokashenUITests.swift
//  fotolokashenUITests
//
//  Created by rgriola on 1/15/26.
//

import XCTest

final class fotolokashenUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Launch smoke test: a signed-out app must render the login screen's primary CTA.
    /// Assumes the simulator has no stored session (fresh simulators never do).
    @MainActor
    func testLaunchShowsLoginScreen() throws {
        let app = XCUIApplication()
        app.launch()

        let signInButton = app.buttons["login.signInButton"]
        XCTAssertTrue(
            signInButton.waitForExistence(timeout: 15),
            "Login screen did not render: Sign In button not found"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
