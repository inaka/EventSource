//
//  EventSourceTests.swift
//  EventSourceTests
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import UIKit
import XCTest
@testable import EventSource

class EventSourceTests: XCTestCase {

    let domain = "http://testdomain.com"
    var sut: TestableEventSource!

    override func setUp() {
        continueAfterFailure = false
        sut = TestableEventSource(url: domain, headers: ["Authorization" : "basic auth"])
        super.setUp()
    }

    // MARK: Testing onOpen and onError

    func testOnOpenGetsCalled() {
        let expectation = self.expectation(description: "onOpen should be called")

        sut.onOpen {
            expectation.fulfill()
        }

        sut.callDidReceiveResponse()

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    func testOnErrorGetsCalled() {
        let expectation = self.expectation(description: "onError should be called")

        sut.onError { (error) -> Void in
            expectation.fulfill()
        }

        sut.callDidCompleteWithError("error")

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    // MARK: Testing event-id behaviours

    func testCorrectlyStoringLastEventID() {
        let expectation = self.expectation(description: "onMessage and onEventDispatched should be called")

        var didCallEventHandler = false
        var didCallMessageHandler = false
        sut.onEventDispatched { event in
            XCTAssertEqual(event.lastEventId, "event-id-1", "the event id should be received")
            didCallEventHandler = true
            if didCallEventHandler && didCallMessageHandler { expectation.fulfill() }
        }

        sut.onMessage() { id, _, _ in
            XCTAssertEqual(id, "event-id-1", "the event id should be received")
            didCallMessageHandler = true
            if didCallEventHandler && didCallMessageHandler { expectation.fulfill() }
        }

        sut.callDidReceiveResponse()
        sut.callDidReceiveData("id: event-id-1\ndata:event-data-first\n\n".data(using: String.Encoding.utf8)!)

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
            XCTAssertNotNil(self.sut.lastEventID)
            XCTAssertEqual(self.sut.lastEventID!, "event-id-1", "last event id stored is different from sent")
        }
    }

    func testCorrectlyStoringLastEventIDForMultipleEventSourceInstances() {
        weak var expectation = self.expectation(description: "onMessage and onEventDispatched should be called")
        var didCallEventHandler = false
        var didCallMessageHandler = false
        sut.onEventDispatched { event in
            XCTAssertEqual(event.lastEventId, "event-id-1", "the event id should be received")
            didCallEventHandler = true
            if didCallEventHandler && didCallMessageHandler { expectation!.fulfill() }
        }
        sut.onMessage() { id, _, _ in
            XCTAssertEqual(id, "event-id-1", "the event id should be received")
            didCallMessageHandler = true
            if didCallEventHandler && didCallMessageHandler { expectation!.fulfill() }
        }
        sut.callDidReceiveData("id: event-id-1\ndata:event-data-first\n\n".data(using: String.Encoding.utf8)!)

        self.waitForExpectations(timeout: 5) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
            XCTAssertNotNil(self.sut.lastEventID)
            XCTAssertEqual(self.sut.lastEventID!, "event-id-1", "last event id stored is different from sent")
        }

        expectation = self.expectation(description: "onMessage and onEventDispatched should be called")
        let secondSut = TestableEventSource(url: "http://otherdomain.com", headers: ["Authorization" : "basic auth"])
        var didCallSecondEventHandler = false
        var didCallSecondMessageHandler = false
        secondSut.onEventDispatched { event in
            XCTAssertEqual(event.lastEventId, "event-id-99", "the event id should be received")
            didCallSecondEventHandler = true
            if didCallSecondEventHandler && didCallSecondMessageHandler { expectation!.fulfill() }
        }

        secondSut.onMessage() { id, _, _ in
            XCTAssertEqual(id, "event-id-99", "the event id should be received")
            didCallSecondMessageHandler = true
            if didCallSecondEventHandler && didCallSecondMessageHandler { expectation!.fulfill() }
        }

        secondSut.callDidReceiveData("id: event-id-99\ndata:event-data-first\n\n".data(using: String.Encoding.utf8)!)

        self.waitForExpectations(timeout: 5) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
            XCTAssertNotNil(self.sut.lastEventID)
            XCTAssertEqual(secondSut.lastEventID!, "event-id-99", "last event id stored is different from sent")
        }
    }


    // MARK: Testing multiple line data is correctly received

    func testMultilineData() {
        let expectation = self.expectation(description: "onMessage and onEventDispatched should be called")

        var didCallEventHandler = false
        var didCallMessageHandler = false
        sut.onEventDispatched { event in
            XCTAssertEqual(event.type, "message", "unknown event type received:'\(event.type)'")
            XCTAssertEqual(event.lastEventId, "event-id", "the event id should be received")
            XCTAssertEqual(event.data, "event-data-first\nevent-data-second", "the event data should be received")

            didCallEventHandler = true
            if didCallEventHandler && didCallMessageHandler { expectation.fulfill() }
        }

        sut.onMessage() { id, event, data in
            XCTAssertEqual(event, "message", "unknown event type received:'\(event)'")
            XCTAssertEqual(id, "event-id", "the event id should be received")
            XCTAssertEqual(data, "event-data-first\nevent-data-second", "the event data should be received")

            didCallMessageHandler = true
            if didCallEventHandler && didCallMessageHandler { expectation.fulfill() }
        }

        sut.callDidReceiveResponse()
        sut.callDidReceiveData("id: event-id\ndata:event-data-first\ndata:event-data-second\n\n".data(using: String.Encoding.utf8)!)

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    func testCloseConnectionIf204IsReceived() {
        let domain = "http://test.com"
        let response =  HTTPURLResponse(url: URL(string: domain)!, statusCode: 204, httpVersion: "1.1", headerFields: nil)!
        let dataTask = MockNSURLSessionDataTask(response: response)

        weak var expectation = self.expectation(description: "onMessage and onEventDispatched should be called")

        sut.onEventDispatched { event in
            XCTFail()
        }

        sut.onMessage() { _, _, _ in
            XCTFail()
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            if self.sut.readyState == .closed {
                expectation?.fulfill()
            } else {
                XCTFail()
            }
        }

        sut.callDidReceiveDataWithResponse(dataTask)

        self.waitForExpectations(timeout: 10) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    // MARK: Testing comment events
    func testAddEventListenerAndReceiveEvent() {
        let expectation = self.expectation(description: "onMessage and onEventDispatched should be called")

        var didCallObjectCallback = false
        var didCallJsCallback = false
        sut.addListenerForEvent(withType: "event-event") { event in
            XCTAssertEqual(event.type, "event-event", "the event should be test")
            XCTAssertEqual(event.lastEventId, "event-id", "the event id should be received")
            XCTAssertEqual(event.data, "event-data", "the event data should be received")

            didCallObjectCallback = true
            if didCallObjectCallback && didCallJsCallback { expectation.fulfill() }
        }

        sut.addEventListener("event-event") { id, event, data in
            XCTAssertEqual(event, "event-event", "the event should be test")
            XCTAssertEqual(id, "event-id", "the event id should be received")
            XCTAssertEqual(data, "event-data", "the event data should be received")

            didCallJsCallback = true
            if didCallObjectCallback && didCallJsCallback { expectation.fulfill() }
        }

        sut.callDidReceiveResponse()
        sut.callDidReceiveData("id: event-id\nevent:event-event\ndata:event-data\n\n".data(using: String.Encoding.utf8)!)

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    func testIgnoreComments() {
        sut.addListenerForEvent(withType: "event") { _ in
            XCTAssert(false, "Interpreted a comment as an event")
        }

        sut.addEventListener("event") { _, _, _ in
            XCTAssert(false, "Interpreted a comment as an event")
        }

        sut.onEventDispatched { _ in
            XCTAssert(false, "Interpreted a comment as an event")
        }

        sut.onMessage() { _, _, _ in
            XCTAssert(false, "Interpreted a comment as an event")
        }

        sut.callDidReceiveResponse()
        sut.callDidReceiveData(":comment\n\n".data(using: String.Encoding.utf8)!)
    }
}
