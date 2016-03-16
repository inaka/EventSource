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

class ConfigurationTests: XCTestCase {
	
	var sut: EventSource?
	var session = NSURLSession()
	
	override func setUp() {
		super.setUp()
		sut = EventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
	}
	
	override class func tearDown() {
		super.tearDown()
	}
	
	func testURL() {
		XCTAssertEqual("http://test.com", sut!.url.absoluteString, "the URL should be the same")
	}
	
	func testDefaultRetryTimeAndChangeRetryTime() {
		let expectation = self.expectationWithDescription("onEvent should be called")

		XCTAssertEqual(3000, sut!.retryTime, "the default retry time should be 3000")
		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let retryEventData = "retry: 5000\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: retryEventData!, statusCode: 200, headers: nil)
		}

		OHHTTPStubs.onStubActivation { (_, _) -> Void in
			expectation.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(3) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
			XCTAssertEqual(5000, self.sut!.retryTime, "the retry time should be changed to 5000")
		}
	}
}
