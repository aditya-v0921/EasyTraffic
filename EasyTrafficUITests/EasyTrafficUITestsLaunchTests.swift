//
//  EasyTrafficUITestsLaunchTests.swift
//  EasyTrafficUITests
//
//  Created by Aditya Vaswani on 6/30/24.
//

import XCTest

final class EasyTrafficUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
