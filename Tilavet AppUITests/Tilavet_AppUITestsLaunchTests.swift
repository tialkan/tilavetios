//
//  Tilavet_AppUITestsLaunchTests.swift
//  Tilavet AppUITests
//
//  Created by Tarık ALKAN on 7.03.2026.
//

import XCTest

final class Tilavet_AppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tilavet-reset-defaults",
            "-tilavet-simulated-recitation",
            "-tilavet-show-debug"
        ]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
