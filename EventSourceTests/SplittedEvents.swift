import UIKit
import XCTest
@testable import EventSource

class SplittedEvents: XCTestCase {

    var sut: TestableEventSource!

	override func setUp() {
		sut = TestableEventSource(url: "http://test.com", headers: ["Authorization" : "basic auth"])
		super.setUp()
	}

	func testEventDataIsRemovedFromBufferWhenProcessed() {
		let expectation = self.expectation(description: "onMessage should be called")
		let eventData = "id: event-id\ndata:event-data\n\n".data(using: String.Encoding.utf8)
		sut.onMessagesReceived { (events) in
			expectation.fulfill()
		}

		sut.callDidReceiveResponse()
		sut.callDidReceiveData(eventData!)
		self.waitForExpectations(timeout: 2) { (error) in
			if let _ = error {
				XCTFail("Expectation not fulfilled")
			}
		}
		XCTAssertEqual(sut!.receivedDataBuffer.length, 0)
    }
    
    func testEventDataSplitByCariageReturnAndUnixNewline() {
        let expectation = self.expectation(description: "onMessage should be called")

        let eventData = "id: event-id\r\ndata:event-data\r\n\r\n".data(using: String.Encoding.utf8)
        sut.onMessagesReceived { (events) in
            let event = events.last
            XCTAssertNil(event!.event)
            XCTAssertEqual(event!.id!, "event-id", "the event id should be received")
            XCTAssertEqual(event!.data!, "event-data", "the event data should be received")

            expectation.fulfill()
        }

        sut.callDidReceiveResponse()
        sut.callDidReceiveData(eventData!)

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }

    func testEventDataSplitByCariageReturn() {
        let expectation = self.expectation(description: "onMessage should be called")

        let eventData = "id: event-id\rdata:event-data\r\r".data(using: String.Encoding.utf8)
        sut.onMessagesReceived { (events) in
            let event = events.last
            XCTAssertNil(event!.event)
            XCTAssertEqual(event!.id!, "event-id", "the event id should be received")
            XCTAssertEqual(event!.data!, "event-data", "the event data should be received")

            expectation.fulfill()
        }

        sut.callDidReceiveResponse()
        sut.callDidReceiveData(eventData!)

        self.waitForExpectations(timeout: 2) { (error) in
            if let _ = error {
                XCTFail("Expectation not fulfilled")
            }
        }
    }
}
