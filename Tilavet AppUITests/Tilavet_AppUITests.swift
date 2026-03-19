//
//  Tilavet_AppUITests.swift
//  Tilavet AppUITests
//
//  Created by Tarık ALKAN on 7.03.2026.
//

import XCTest

final class Tilavet_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testStartsInSimulationModeAndShowsDebugPanel() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tilavet-reset-defaults",
            "-tilavet-simulated-recitation",
            "-tilavet-show-debug"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Tilavet.Header"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Tilavet.StartStopButton"].exists)
        XCTAssertTrue(app.otherElements["Tilavet.DebugPanel"].exists)

        app.buttons["Tilavet.StartStopButton"].tap()
        XCTAssertTrue(app.staticTexts["Tilavet.StatusMessage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Simulasyon calisiyor"].waitForExistence(timeout: 2) || app.staticTexts["Takip sabitlendi"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCanOpenStartPointPicker() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tilavet-reset-defaults",
            "-tilavet-simulated-recitation"
        ]
        app.launch()

        app.buttons["Tilavet.MoreMenu"].tap()
        app.buttons["Ayet sec"].tap()
        XCTAssertTrue(app.otherElements["Tilavet.StartPointSheet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Tilavet.StartPointApplyButton"].exists)
    }
}
