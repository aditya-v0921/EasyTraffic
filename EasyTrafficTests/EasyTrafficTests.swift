//
//  EasyTrafficTests.swift
//  EasyTrafficTests
//
//  Created by Aditya Vaswani on 6/30/24.
//

import XCTest
@testable import EasyTraffic

final class EasyTrafficTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testAverageStopDurationUsesRecordedDurations() {
        var drive = Drive(userId: UUID(), familyId: nil)
        drive.events = [
            StopSignEvent(didFullStop: true, stopDuration: 4, confidence: 0.9),
            StopSignEvent(didFullStop: false, stopDuration: nil, confidence: 0.9),
            StopSignEvent(didFullStop: true, stopDuration: 2, confidence: 0.9)
        ]

        XCTAssertEqual(drive.summary.averageStopDuration, 3, accuracy: 0.001)
        XCTAssertEqual(drive.summary.totalStopSigns, 3)
        XCTAssertEqual(drive.summary.rollingStops, 1)
    }

    func testAverageStopDurationWithoutMeasurementsIsZero() {
        var drive = Drive(userId: UUID(), familyId: nil)
        XCTAssertEqual(drive.summary.averageStopDuration, 0)

        drive.events = [
            StopSignEvent(didFullStop: false, stopDuration: nil, confidence: 0.9)
        ]
        XCTAssertEqual(drive.summary.averageStopDuration, 0)
    }

    func testExample() throws {
  
    }

    func testPerformanceExample() throws {
        self.measure {
        }
    }

}
