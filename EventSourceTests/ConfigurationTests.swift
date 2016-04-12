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

	func testURL() {
		let sut = EventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
		XCTAssertEqual("http://test.com", sut.url.absoluteString, "the URL should be the same")
	}

	func testBasicAuth() {
		// basic auth token: "Basic base64(username + ':' + password)"
		// basic auth token: "Basic base64("testUsername" + ":" + "testPassword")"
		// basic auth token: "Basic dGVzdFVzZXJuYW1lOnRlc3RQYXNzd29yZA=="

		let basicAuthToken = "Basic dGVzdFVzZXJuYW1lOnRlc3RQYXNzd29yZA=="

		let username = "testUsername"
		let password = "testPassword"
		let basicAuthString = EventSource.basicAuth(username, password: password)

		XCTAssertEqual(basicAuthString, basicAuthToken)
	}

	func testDefaultRetryTimeAndChangeRetryTime() {
		let domain = NSUUID().UUIDString
		let sut = EventSource(url: "http://\(domain).com", headers: ["Authorization" : "basic auth"])
		weak var expectation = self.expectationWithDescription("")

		XCTAssertEqual(3000, sut.retryTime, "the default retry time should be 3000")

		OHHTTPStubs.removeAllStubs()
		stub(isHost("\(domain).com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let retryEventData = "retry: 5000\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: retryEventData!, statusCode: 200, headers: nil)
		}

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
			XCTAssertEqual(5000, sut.retryTime, "the default retry time should be 3000")
			expectation?.fulfill()
			expectation = nil
		}

		self.waitForExpectationsWithTimeout(5) { (error) in
			if let _ = error{
				XCTFail("Expectation not fulfilled")
			}
		}

	}
}
