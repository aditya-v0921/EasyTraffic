//
//  EasyTrafficTests.swift
//  EasyTrafficTests
//
//  Created by Aditya Vaswani on 6/30/24.
//

import XCTest
import CoreLocation
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

    @MainActor
    func testInitialStationaryReadingStartsStopTimer() {
        let detector = MotionDetector()
        XCTAssertNil(detector.stopDuration)

        detector.handleStateChange(isStopped: true)

        XCTAssertFalse(detector.isMoving)
        XCTAssertNotNil(detector.stopDuration)
        XCTAssertFalse(detector.didFullStop)
    }

    @MainActor
    func testStationaryReadingsPreserveTimerAndMovementClearsIt() {
        let detector = MotionDetector()
        detector.handleStateChange(isStopped: true)
        let initialDuration = detector.stopDuration!

        detector.handleStateChange(isStopped: true)
        XCTAssertGreaterThanOrEqual(detector.stopDuration!, initialDuration)

        detector.handleStateChange(isStopped: false)
        XCTAssertTrue(detector.isMoving)
        XCTAssertNil(detector.stopDuration)
        XCTAssertFalse(detector.didFullStop)
    }

    @MainActor
    func testStoppingMonitoringClearsStationaryTimer() {
        let detector = MotionDetector()
        detector.handleStateChange(isStopped: true)
        XCTAssertNotNil(detector.stopDuration)

        detector.stopMonitoring()

        XCTAssertNil(detector.stopDuration)
        XCTAssertFalse(detector.didFullStop)
        XCTAssertFalse(detector.isMoving)
    }

    @MainActor
    func testStoppingMonitoringClearsMovementAndSpeed() {
        let detector = MotionDetector()
        detector.currentSpeed = 5
        detector.handleStateChange(isStopped: false)

        detector.stopMonitoring()

        XCTAssertFalse(detector.isMoving)
        XCTAssertEqual(detector.currentSpeed, 0)
        XCTAssertNil(detector.stopDuration)
    }

    func testDeduperUsesAnnouncementCategoryInsteadOfModelLabel() {
        let deduper = Deduper()
        let detection = DetectedObject(
            bbox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3),
            confidence: 0.9, label: "3", timestamp: Date()
        )

        XCTAssertTrue(deduper.isNewObject(detection, label: "stop_sign"))
        XCTAssertFalse(deduper.isNewObject(detection, label: "stop_sign"))
        XCTAssertTrue(deduper.isNewObject(detection, label: "other_sign"))
        XCTAssertFalse(deduper.isNewObject(detection, label: "other_sign"))
    }

    func testDeduperRemembersCategoryAfterSpatiallyNewDetection() {
        let deduper = Deduper()
        let first = DetectedObject(
            bbox: CGRect(x: 0, y: 0, width: 0.2, height: 0.2),
            confidence: 0.9, label: "3", timestamp: Date()
        )
        let second = DetectedObject(
            bbox: CGRect(x: 0.7, y: 0.7, width: 0.2, height: 0.2),
            confidence: 0.9, label: "3", timestamp: Date()
        )

        XCTAssertTrue(deduper.isNewObject(first, label: "stop_sign"))
        XCTAssertTrue(deduper.isNewObject(second, label: "stop_sign"))
        XCTAssertFalse(deduper.isNewObject(second, label: "stop_sign"))
    }

    @MainActor
    func testStoppingMonitoringCancelsPendingStopCheck() async {
        let detector = MotionDetector()
        let staleCheck = expectation(description: "Ended drive must not receive a stop result")
        staleCheck.isInverted = true
        detector.checkIfStoppedAtStopSign { _, _ in
            staleCheck.fulfill()
        }

        detector.stopMonitoring()

        await fulfillment(of: [staleCheck], timeout: 3)
        XCTAssertNil(detector.stopDuration)
    }

    @MainActor
    func testNewStopCheckCompletesAfterReset() async {
        let detector = MotionDetector()
        detector.reset()
        detector.handleStateChange(isStopped: true)
        let completed = expectation(description: "Current stop check completes")
        detector.checkIfStoppedAtStopSign { didStop, duration in
            XCTAssertTrue(didStop)
            XCTAssertGreaterThanOrEqual(duration ?? 0, 2)
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 4)
        XCTAssertTrue(detector.didFullStop)
    }

    @MainActor
    func testResetRejectsQueuedLocationUpdate() async {
        let detector = MotionDetector()
        let manager = CLLocationManager()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 34.4, longitude: -119.8),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: 8, timestamp: Date()
        )
        detector.locationManager(manager, didUpdateLocations: [location])
        detector.reset()
        let drained = expectation(description: "Queued location update processed")
        DispatchQueue.main.async { drained.fulfill() }

        await fulfillment(of: [drained], timeout: 1)
        XCTAssertEqual(detector.currentSpeed, 0)
        XCTAssertNil(detector.currentLocation)
    }

    @MainActor
    func testLocationUpdateAfterResetIsAccepted() async {
        let detector = MotionDetector()
        detector.reset()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 34.4, longitude: -119.8),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: 8, timestamp: Date()
        )
        detector.locationManager(CLLocationManager(), didUpdateLocations: [location])
        let drained = expectation(description: "Current location update processed")
        DispatchQueue.main.async { drained.fulfill() }

        await fulfillment(of: [drained], timeout: 1)
        XCTAssertEqual(detector.currentSpeed, 8)
        XCTAssertEqual(detector.currentLocation?.latitude, 34.4)
        XCTAssertEqual(detector.currentLocation?.longitude, -119.8)
    }

    func testExample() throws {
  
    }

    func testPerformanceExample() throws {
        self.measure {
        }
    }

}
