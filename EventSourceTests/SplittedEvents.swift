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

class SplittedEvents: XCTestCase {
    
    var sut: EventSource?

	override func setUp() {
		super.setUp()
		sut = EventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
	}
	
	override class func tearDown() {
		super.tearDown()
		OHHTTPStubs.removeAllStubs()
	}
	
    func testEventDataIsRemovedFromBufferWhenProcessed() {
        let expectation = self.expectationWithDescription("onMessage should be called")

		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let data = "id: event-id\ndata:event-data\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: data!, statusCode: 200, headers: nil)
		}

        sut!.onMessage { (id, event, data) in
            expectation.fulfill()
        }
		
        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
        XCTAssertEqual(sut!.receivedDataBuffer.length, 0)
    }
	
	
/*
    func testEventDataSplitOverMultiplePackets() {
        let expectation = self.expectationWithDescription("onMessage should be called")

		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let dataPacket2 = "ta:event-data\n\n".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: dataPacket2!, statusCode: 200, headers: nil)
		}
		
		stub(isHost("test.com")) { (request: NSURLRequest) -> OHHTTPStubsResponse in
			let dataPacket1 = "id: event-id\nda".dataUsingEncoding(NSUTF8StringEncoding)
			return OHHTTPStubsResponse(data: dataPacket1!, statusCode: 200, headers: nil)
		}
		
		sut!.onMessage { (id, event, data) in
            XCTAssertEqual(event!, "message", "the event should be message")
            XCTAssertEqual(id!, "event-id", "the event id should be received")
            XCTAssertEqual(data!, "event-data", "the event data should be received")
            
            expectation.fulfill()
        }

        self.waitForExpectationsWithTimeout(5) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
    }

*/
}
