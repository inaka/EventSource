//
//  EventSourceTests.swift
//  EventSourceTests
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import UIKit
import XCTest

class EventSourceTests: XCTestCase {
    
    var sut = EventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
    var session = NSURLSession()

    override func setUp() {
        super.setUp()
    }
    
    func testURL() {
        XCTAssertEqual("http://test.com", sut.url.absoluteString!, "the URL should be the same")
    }
    
    func testDefaultRetryTimeAndChangeRetryTime(){
        let retryEventData = "retry: 5000\n\n"
        
        XCTAssertEqual(3000, sut.retryTime, "the default retry time should be 3000")
        sut.parseEventStream(retryEventData)
        XCTAssertEqual(5000, sut.retryTime, "the retry time should be changed to 5000")
    }
    
    func testParseOfIDAndData(){
        let expectation = self.expectationWithDescription("onMessage should be called")

        let retryEventData = "id: event-id\ndata:event-data"
        sut.onMessage { (id, event, data) -> Void in
            XCTAssertEqual(event!, "message", "the event should be message")
            XCTAssertEqual(id!, "event-id", "the event id should be received")
            XCTAssertEqual(data!, "event-data", "the event data should be received")
            
            expectation.fulfill()
        }
        sut.parseEventStream(retryEventData)
        
        self.waitForExpectationsWithTimeout(2, handler: { (error) -> Void in
            if let receivedError = error{
                XCTFail("Expectation not fulfilled")
            }
        })
    }
}
