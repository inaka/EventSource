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

class File: XCTestCase {
	
	var sut: EventSource?
	var session = NSURLSession()
	
	override func setUp() {
		super.setUp()
		sut = EventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
	}
	
	override class func tearDown() {
		super.tearDown()
	}
	
	func testAddEventListenerAndReceiveEvent() {
		let expectation = self.expectationWithDescription("onEvent should be called")

		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let data = "id: event-id\nevent:event-event\ndata:event-data\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: data!, statusCode: 200, headers: nil)
		}

		sut!.addEventListener("event-event") { (id, event, data) in
			XCTAssertEqual(event!, "event-event", "the event should be test")
			XCTAssertEqual(id!, "event-id", "the event id should be received")
			XCTAssertEqual(data!, "event-data", "the event data should be received")

			expectation.fulfill()
		}
		self.waitForExpectationsWithTimeout(2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
	}

	func testIgnoreCommets() {
		let expectation = self.expectationWithDescription("3 seconds passed and method was not call")

		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let commentEventData = ":coment\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: commentEventData!, statusCode: 200, headers: nil)
		}

		sut!.addEventListener("event-event",handler: { (id, event, data) in
			XCTFail("got event when server sent a comment")
		})

		sut!.onMessage { (id, event, data) in
			XCTFail("got message when server sent a comment")
		}

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
			expectation.fulfill()
		}
		self.waitForExpectationsWithTimeout(4) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
	}
}
