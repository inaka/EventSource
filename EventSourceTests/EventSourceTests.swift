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
	
	var sut: EventSource?
	
	override func setUp() {
		super.setUp()
		sut = EventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
	}
	
	override class func tearDown() {
		super.tearDown()
		OHHTTPStubs.removeAllStubs()
	}
	
// MARK: Testing onOpen and onError
	
	func testOnOpenGetsCalled(){
		let expectation = self.expectationWithDescription("onOpen should be called")
		
		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let data = "".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: data!, statusCode: 200, headers: nil)
		}
		
		sut!.onOpen {
			expectation.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(2) { (error) in
			if let _ = error{
				XCTFail("Expectation not fulfilled")
			}
		}
	}
	
	func testOnErrorGetsCalled() {
		let expectation = self.expectationWithDescription("onError should be called")
		
		sut!.onError { (error) -> Void in
			expectation.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(2) { (error) in
			if let _ = error{
				XCTFail("Expectation not fulfilled")
			}
		}
	}

// MARK: Testing event-id behaviours
	
	func testCorrectlyStoringLastEventID() {
		let expectation = self.expectationWithDescription("onMessage should be called")

		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let data = "id: event-id-1\ndata:event-data-first\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: data!, statusCode: 200, headers: nil)
		}
		
		sut!.onMessage { (id, event, data) in
			XCTAssertEqual(id!, "event-id-1", "the event id should be received")
			expectation.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(5) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(self.sut!.lastEventID!, "event-id-1", "last event id stored is different from sent")
		}
	}
	
	func testLastEventIDNotUpdatedForEventWithNoID() {
		let expectation = self.expectationWithDescription("onMessage should be called")
		self.sut!.lastEventID = "event-id-1"

		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let data = "data:event-data-first\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: data!, statusCode: 200, headers: nil)
		}

		self.sut!.onMessage { (id, event, data) in
			XCTAssertEqual(id!, "event-id-1", "the event id should be received")
			expectation.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(self.sut!.lastEventID!, "event-id-1", "last event id stored is different from sent")
		}
	}

	
// MARK: Testing multiple line data is correctly received
	
	func testMultilineData() {
		let expectation = self.expectationWithDescription("onMessage should be called")
		
		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let multipleLineData = "id: event-id\ndata:event-data-first\ndata:event-data-second\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: multipleLineData!, statusCode: 200, headers: nil)
		}
		
		sut!.onMessage { (id, event, data) in
			XCTAssertEqual(event!, "message", "the event should be message")
			XCTAssertEqual(id!, "event-id", "the event id should be received")
			XCTAssertEqual(data!, "event-data-first\nevent-data-second", "the event data should be received")
			
			expectation.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(2) { (error) in
			if let _ = error{
				XCTFail("Expectation not fulfilled")
			}
		}
	}

// MARK: Testing empty data. The event should be received with no data

	func testEmptyDataValue() {
		let expectation = self.expectationWithDescription("onMessage should be called")
		
		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let emptyDataValueEvent = "event:done\ndata\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: emptyDataValueEvent!, statusCode: 200, headers: nil)
		}

		sut!.addEventListener("done") { (id, event, data) in
			XCTAssertEqual(event!, "done", "the event should be message")
			XCTAssertEqual(data!, "", "the event data should an empty string")
			
			expectation.fulfill()
		}

		self.waitForExpectationsWithTimeout(2) { (error) in
			if let _ = error{
				XCTFail("Expectation not fulfilled")
			}
		}
	}
	
	
	// MARK: Testing empty data. The event should be received with no data
	
	func testCloseConnectionIf204IsReceived() {
		let expectation = self.expectationWithDescription("onMessage should be called")
		
		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let emptyDataValueEvent = "".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: emptyDataValueEvent!, statusCode: 204, headers: nil)
		}
		
		sut!.onMessage { (id, event, data) in
			XCTFail()
		}
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
			if self.sut!.readyState == .Closed {
				expectation.fulfill()
			} else {
				XCTFail()
			}
		}
		self.waitForExpectationsWithTimeout(4) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
	}

// MARK: Testing comment events
	
	func testAddEventListenerAndReceiveEvent() {
		let expectation = self.expectationWithDescription("onEvent should be called")

		OHHTTPStubs.removeAllStubs()
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
		self.waitForExpectationsWithTimeout(4) { (error) in
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
