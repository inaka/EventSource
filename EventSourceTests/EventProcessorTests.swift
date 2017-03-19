import XCTest

@testable import EventSource

class EventProcessorTests: XCTestCase {
    fileprivate var subject: EventProcessor!
    fileprivate var dispatchedEvents: [SSEMessageEvent] = []
    fileprivate var registeredEventsDispatched: [String : SSEMessageEvent] = [:]
    fileprivate var registeredEventsDispatchedJsVersion: [String : (id: String, event: String, data: String)] = [:]
    private var retryTimeUpdates: [Int] = []

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        subject = EventProcessor()
        subject.onEventDispatched = { event in
            self.dispatchedEvents.append(event)
        }

        subject.eventListeners["event name"] = { event in
            self.registeredEventsDispatched[event.type] = event
        }

        subject.eventListenersJsVersion["event name"] = { id, event, data in
            self.registeredEventsDispatchedJsVersion[event] = (id, event, data)
        }

        subject.onRetryTimeChanged = { retryTime in
            self.retryTimeUpdates.append(retryTime)
        }
    }

    func test_processSSEStream() {
        subject.processSSEStream(["id:some id\ndata: some data\nid:\n\nsomeother field::\ndata\nid:someotherid\ndata:good data\nevent:event name\n\n"])

        XCTAssertEqual(dispatchedEvents.count, 2)
        let eventOne = dispatchedEvents[0]
        assertDispatchProperties(event: eventOne, expectedId: "some id", expectedData: "some data", expectedType: "message")
        let eventTwo = dispatchedEvents[1]
        assertDispatchProperties(event: eventTwo, expectedId: "someotherid", expectedData: "good data", expectedType: "event name")

        guard let registeredEvent = registeredEventsDispatched["event name"] else {
            XCTFail("Failed to call registered handler for the 'event name' type of event")
            return
        }

        assertDispatchProperties(event: registeredEvent, expectedId: "someotherid", expectedData: "good data", expectedType: "event name")

        guard let registeredEventJsVersionResult = registeredEventsDispatchedJsVersion["event name"] else {
            XCTFail("Failed to call registered handler (JS version) for the 'event name' type of event")
            return
        }

        XCTAssertEqual(registeredEventJsVersionResult.id, "someotherid")
        XCTAssertEqual(registeredEventJsVersionResult.data, "good data")
        XCTAssertEqual(registeredEventJsVersionResult.event, "event name")
    }

    func test_processSSEStream_whenDataSplitAcrossMultipleStreamItems() {
        subject.processSSEStream(
            ["id:",
             "someid\nd",
             "ata: some data\nevent       ",
             " :name of the event\n\n\n\n",
             "  id: shouldnotset\nevent: another event\ndata:data\n",
             "\n",
             "id:a-new-id\ndata: some long data item",
             "that spans multiple lines\nevent: yet another event\n\n"]
        )

        XCTAssertEqual(dispatchedEvents.count, 3)
        let eventOne = dispatchedEvents[0]
        assertDispatchProperties(event: eventOne, expectedId: "someid", expectedData: "some data", expectedType: "message")
        let eventTwo = dispatchedEvents[1]
        assertDispatchProperties(event: eventTwo, expectedId: "someid", expectedData: "data", expectedType: "another event")
        let eventThree = dispatchedEvents[2]
        assertDispatchProperties(event: eventThree, expectedId: "a-new-id", expectedData: "some long data itemthat spans multiple lines", expectedType: "yet another event")
    }

    func test_processSSEStream_canDispatchAtEndOfStreamEvenWithoutCompleteEmptyLine() {
        subject.processSSEStream(
            ["id:",
             "someid\nd",
             "ata: some data\nevent       ",
             " :name of the event\n\n\n\n",
             "  id: shouldnotset\nevent: another event\ndata:data\n"]
        )

        XCTAssertEqual(dispatchedEvents.count, 2)
        let eventOne = dispatchedEvents[0]
        assertDispatchProperties(event: eventOne, expectedId: "someid", expectedData: "some data", expectedType: "message")
        let eventTwo = dispatchedEvents[1]
        assertDispatchProperties(event: eventTwo, expectedId: "someid", expectedData: "data", expectedType: "another event")
    }

    func test_processSSEStream_canDispatchAtEndOfStreamEvenWhenLeftWithUnresolvedLine() {
        subject.processSSEStream(
            ["id:",
             "someid\nd",
             "ata: some data\nevent       ",
             " :name of the event\n\n\n\n",
             "  id: shouldnotset\nevent: another event\ndata:data"]
        )

        XCTAssertEqual(dispatchedEvents.count, 2)
        let eventOne = dispatchedEvents[0]
        assertDispatchProperties(event: eventOne, expectedId: "someid", expectedData: "some data", expectedType: "message")
        let eventTwo = dispatchedEvents[1]
        assertDispatchProperties(event: eventTwo, expectedId: "someid", expectedData: "data", expectedType: "another event")
    }

    func test_processSSEStream_firesRetryTimeCallbackWhenProcessingAValidRetryField() {
        subject.processSSEStream(
            ["retry: 20000\nretry: shouldfail\n\nretry:30000",
             "\n retry : 40000\n\n\nretry: 33d00\nretry: 50000",
            ]
        )

        XCTAssertEqual(retryTimeUpdates.count, 3)
        let firstUpdate = retryTimeUpdates[0]
        XCTAssertEqual(firstUpdate, 20000)
        let secondUpdate = retryTimeUpdates[1]
        XCTAssertEqual(secondUpdate, 30000)
        let thirdUpdate = retryTimeUpdates[2]
        XCTAssertEqual(thirdUpdate, 50000)
    }
}

fileprivate func assertDispatchProperties(event: SSEMessageEvent, expectedId: String, expectedData: String, expectedType: String) {
    XCTAssertEqual(event.lastEventId, expectedId)
    XCTAssertEqual(event.data, expectedData)
    XCTAssertEqual(event.type, expectedType)
}
