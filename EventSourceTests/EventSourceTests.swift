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
    
    var sut: TestableEventSource?
    var session = NSURLSession()

    class TestableEventSource: EventSource {

        func callDidReceiveResponse() {
            let delegate = self as NSURLSessionDataDelegate

            delegate.URLSession!(self.urlSession!, dataTask: self.task!, didReceiveResponse: NSURLResponse()) { (NSURLSessionResponseDisposition) -> Void in

            }
        }

        func callDidReceiveData(data: NSData) {
            let delegate = self as NSURLSessionDataDelegate
            delegate.URLSession!(self.urlSession!, dataTask: self.task!, didReceiveData: data)
        }

        func callDidCompleteWithError(error: String) {
            let errorToReturn = NSError(domain: "Mock", code: 0, userInfo: ["mock":error])

            let delegate = self as NSURLSessionDataDelegate
            delegate.URLSession!(self.urlSession!, task: self.task!, didCompleteWithError: errorToReturn)
        }
    }

    override func setUp() {
        super.setUp()
        sut = TestableEventSource(url: "http://127.0.0.1", headers: ["Authorization" : "basic auth"])
    }

    override class func tearDown() {
        super.tearDown()
    }

    func testURL() {
        XCTAssertEqual("http://127.0.0.1", sut!.url.absoluteString, "the URL should be the same")
    }

    func testDefaultRetryTimeAndChangeRetryTime() {
        let retryEventData = "retry: 5000\n\n".dataUsingEncoding(NSUTF8StringEncoding)

        XCTAssertEqual(3000, sut!.retryTime, "the default retry time should be 3000")

        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(retryEventData!)

        XCTAssertEqual(5000, sut!.retryTime, "the retry time should be changed to 5000")
    }

    func testIgnoreCommets() {
        let commentEventData = ":coment\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        sut!.addEventListener("event",handler: { (id, event, data) in
            XCTAssert(false, "got event in comment")
        })

        sut!.onMessage { (id, event, data) in
            XCTAssert(false, "got event in comment")
        }

        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(commentEventData!)
    }

    func testAddEventListenerAndReceiveEvent() {
        let expectation = self.expectationWithDescription("onEvent should be called")

        let eventListenerAndReceiveEventData = "id: event-id\nevent:event-event\ndata:event-data\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        sut!.addEventListener("event-event") { (id, event, data) in
            XCTAssertEqual(event!, "event-event", "the event should be test")
            XCTAssertEqual(id!, "event-id", "the event id should be received")
            XCTAssertEqual(data!, "event-data", "the event data should be received")

            expectation.fulfill()
        }

        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(eventListenerAndReceiveEventData!)

        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    func testMultilineData() {
        let expectation = self.expectationWithDescription("onMessage should be called")

        let retryEventData = "id: event-id\ndata:event-data-first\ndata:event-data-second\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        sut!.onMessage { (id, event, data) in
            XCTAssertEqual(event!, "message", "the event should be message")
            XCTAssertEqual(id!, "event-id", "the event id should be received")
            XCTAssertEqual(data!, "event-data-first\nevent-data-second", "the event data should be received")

            expectation.fulfill()
        }

        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(retryEventData!)

        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
    }
    
    func testEmptyDataValue() {
        let expectation = self.expectationWithDescription("onMessage should be called")
        
        let emptyDataValueEvent = "event:done\ndata\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        sut!.addEventListener("done") { (id, event, data) in
            XCTAssertEqual(event!, "done", "the event should be message")
            XCTAssertEqual(data!, "", "the event data should an empty string")
            
            expectation.fulfill()
        }
        
        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(emptyDataValueEvent!)
        
        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
    }
    
    func testEventDataIsRemovedFromBufferWhenProcessed() {
        let expectation = self.expectationWithDescription("onMessage should be called")
        
        let eventData = "id: event-id\ndata:event-data\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        
        sut!.onMessage { (id, event, data) in
            expectation.fulfill()
        }
        
        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(eventData!)
        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
        XCTAssertEqual(sut!.receivedDataBuffer.length, 0)
    }
    
    func testEventDataSplitOverMultiplePackets() {
        let expectation = self.expectationWithDescription("onMessage should be called")
        
        let dataPacket1 = "id: event-id\nda".dataUsingEncoding(NSUTF8StringEncoding)
        let dataPacket2 = "ta:event-data\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        sut!.onMessage { (id, event, data) in
            XCTAssertEqual(event!, "message", "the event should be message")
            XCTAssertEqual(id!, "event-id", "the event id should be received")
            XCTAssertEqual(data!, "event-data", "the event data should be received")
            
            expectation.fulfill()
        }
        
        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(dataPacket1!)
        sut?.callDidReceiveData(dataPacket2!)
        
        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    func testCorrectlyStoringLastEventID() {
        let expectation = self.expectationWithDescription("onMessage should be called")
        
        let retryEventData = "id: event-id-1\ndata:event-data-first\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        sut!.onMessage { (id, event, data) in
            XCTAssertEqual(id!, "event-id-1", "the event id should be received")
            expectation.fulfill()
        }

        sut?.callDidReceiveResponse()
        sut?.callDidReceiveData(retryEventData!)

        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
            XCTAssertEqual(self.sut!.lastEventID!, "event-id-1", "last event id stored is different from sent")
        }
    }
    
    func testLastEventIDNotUpdatedForEventWithNoID() {
        self.sut!.lastEventID = "event-id-1"
        
        let expectation = self.expectationWithDescription("onMessage should be called")
        let retryEventData = "data:event-data-first\n\n".dataUsingEncoding(NSUTF8StringEncoding)
        self.sut!.onMessage { (id, event, data) in
            XCTAssertEqual(id!, "event-id-1", "the event id should be received")
            expectation.fulfill()
        }
        
        self.sut?.callDidReceiveResponse()
        self.sut?.callDidReceiveData(retryEventData!)
        
        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
            XCTAssertEqual(self.sut!.lastEventID!, "event-id-1", "last event id stored is different from sent")
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

    func testOnOpenGetsCalled(){
        let expectation = self.expectationWithDescription("onOpen should be called")

        sut!.onOpen {
            expectation.fulfill()
        }

        sut!.callDidReceiveResponse()
        self.waitForExpectationsWithTimeout(2) { (error) in
            if let _ = error{
                XCTFail("Expectation not fulfilled")
            }
        }
    }
}
