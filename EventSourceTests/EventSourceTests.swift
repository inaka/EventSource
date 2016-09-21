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
		let expectation = self.expectation(description: "onMessage should be called")

		sut.onMessage { (id, event, data) in
			XCTAssertEqual(id!, "event-id-1", "the event id should be received")
			expectation.fulfill()
		}

		sut.callDidReceiveResponse()
		sut.callDidReceiveData("id: event-id-1\ndata:event-data-first\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(self.sut.lastEventID!, "event-id-1", "last event id stored is different from sent")
		}
	}

	func testLastEventIDNotUpdatedForEventWithNoID() {
		self.sut.lastEventID = "event-id-1"

		let expectation = self.expectation(description: "onMessage should be called")
		self.sut.onMessage { (id, event, data) in
			XCTAssertEqual(id!, "event-id-1", "the event id should be received")
			expectation.fulfill()
		}

		self.sut.callDidReceiveResponse()
		self.sut.callDidReceiveData("data:event-data-first\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(self.sut.lastEventID!, "event-id-1", "last event id stored is different from sent")
		}
	}

	func testCorrectlyStoringLastEventIDForMultipleEventSourceInstances() {
		weak var expectation = self.expectation(description: "onMessage should be called")
		sut.onMessage { (id, event, data) in
			XCTAssertEqual(id!, "event-id-1", "the event id should be received")
			expectation!.fulfill()
		}
		sut.callDidReceiveData("id: event-id-1\ndata:event-data-first\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 5) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(self.sut.lastEventID!, "event-id-1", "last event id stored is different from sent")
		}

		expectation = self.expectation(description: "onMessage should be called")
		let secondSut = TestableEventSource(url: "http://otherdomain.com", headers: ["Authorization" : "basic auth"])
		secondSut.onMessage { (id, event, data) in
			XCTAssertEqual(id!, "event-id-99", "the event id should be received")
			expectation!.fulfill()
		}
		secondSut.callDidReceiveData("id: event-id-99\ndata:event-data-first\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 5) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(secondSut.lastEventID!, "event-id-99", "last event id stored is different from sent")
		}
	}


// MARK: Testing multiple line data is correctly received

	func testMultilineData() {
		let expectation = self.expectation(description: "onMessage should be called")

		sut.onMessage { (id, event, data) in
			XCTAssertEqual(event!, "message", "the event should be message")
			XCTAssertEqual(id!, "event-id", "the event id should be received")
			XCTAssertEqual(data!, "event-data-first\nevent-data-second", "the event data should be received")

			expectation.fulfill()
		}

		sut.callDidReceiveResponse()
		sut.callDidReceiveData("id: event-id\ndata:event-data-first\ndata:event-data-second\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
	}

// MARK: Testing empty data. The event should be received with no data

	func testEmptyDataValue() {
		let expectation = self.expectation(description: "onMessage should be called")

		sut.addEventListener("done") { (id, event, data) in
			XCTAssertEqual(event!, "done", "the event should be message")
			XCTAssertEqual(data!, "", "the event data should an empty string")

			expectation.fulfill()
		}

		sut.callDidReceiveResponse()
		sut.callDidReceiveData("event:done\ndata\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
	}


	// MARK: Testing empty data. The event should be received with no data

	func testCloseConnectionIf204IsReceived() {
		let domain = "http://test.com"
		let response =  HTTPURLResponse(url: URL(string: domain)!, statusCode: 204, httpVersion: "1.1", headerFields: nil)!
		let dataTask = MockNSURLSessionDataTask(response: response)

		weak var expectation = self.expectation(description: "onMessage should be called")

		sut.onMessage { (id, event, data) in
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
		let expectation = self.expectation(description: "onEvent should be called")

		sut.addEventListener("event-event") { (id, event, data) in
			XCTAssertEqual(event!, "event-event", "the event should be test")
			XCTAssertEqual(id!, "event-id", "the event id should be received")
			XCTAssertEqual(data!, "event-data", "the event data should be received")

			expectation.fulfill()
		}

		sut.callDidReceiveResponse()
		sut.callDidReceiveData("id: event-id\nevent:event-event\ndata:event-data\n\n".data(using: String.Encoding.utf8)!)

		self.waitForExpectations(timeout: 2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
	}

	func testIgnoreCommets() {
		sut.addEventListener("event") { (id, event, data) in
			XCTAssert(false, "got event in comment")
		}

		sut.onMessage { (id, event, data) in
			XCTAssert(false, "got event in comment")
		}

		sut.callDidReceiveResponse()
		sut.callDidReceiveData(":coment\n\n".data(using: String.Encoding.utf8)!)
	}
}
