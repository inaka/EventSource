import XCTest

@testable import EventSource

class EventProcessorIntegrationTests: XCTestCase {
    private var subject: EventProcessor!
    private var dispatchedEvents: [SSEMessageEvent] = []
    private var registeredEventsDispatched: [String : SSEMessageEvent] = [:]
    private var registeredEventsDispatchedJsVersion: [String : (id: String, event: String, data: String)] = [:]
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

    func test_processingARealWorldExample() {
        let data = "id: 0\nevent: event\ndata: {\"data\":{\"status\":\"started\",\"time\":1492401089},\"event\":\"status\",\"version\":\"1.0\"}\n\nid: 1\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbb\"}},\"event\":\"initialize-get\",\"version\":\"1.0\"}\n\nid: 2\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbb\",\"source\":\"stdout\"},\"payload\":\"using version of resource found in cache\\n\"},\"event\":\"log\",\"version\":\"5.0\"}\n\nid: 3\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbb\"},\"plan\":{\"name\":\"omgfruitapi-master\",\"resource\":\"omgfruitapi-master\",\"type\":\"git\",\"version\":{\"ref\":\"35e476dc29ca300c6a527c2b660d5334ad1b594d\"}},\"exit_status\":0,\"version\":{\"ref\":\"35e476dc29ca300c6a527c2b660d5334ad1b594d\"},\"metadata\":[{\"name\":\"commit\",\"value\":\"35e476dc29ca300c6a527c2b660d5334ad1b594d\"},{\"name\":\"author\",\"value\":\"Jared Friese\"},{\"name\":\"author_date\",\"value\":\"2016-12-06 06:04:27 -0800\"},{\"name\":\"branch\",\"value\":\"master\"},{\"name\":\"tags\",\"value\":\"1481035419,1481036805,1481054609,1481058512\"},{\"name\":\"message\",\"value\":\"Update release script\\n\"}]},\"event\":\"finish-get\",\"version\":\"4.0\"}\n\nid: 4\nevent: event\ndata: {\"data\":{\"config\":{\"platform\":\"linux\",\"image\":\"\",\"run\":{\"path\":\"go/src/github.com/jwfriese/omgfruitapi/test.sh\",\"args\":null,\"dir\":\"\"},\"inputs\":[{\"name\":\"omgfruitapi-master\",\"path\":\"go/src/github.com/jwfriese/omgfruitapi\"}]},\"origin\":{\"id\":\"58f43bbc\"}},\"event\":\"initialize-task\",\"version\":\"4.0\"}\n\nid: 5\nevent: event\ndata: {\"data\":{\"time\":1492401096,\"origin\":{\"id\":\"58f43bbc\"}},\"event\":\"start-task\",\"version\":\"4.0\"}\n\nid: 6\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"++ pwd\\n\"},\"event\":\"log\",\"version\":\"5.0\"}\n\nid: 7\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"+ export GOPATH=/tmp/build/a94a8fe5/go\\n+ GOPATH=/tmp/build/a94a8fe5/go\\n+ export PATH=/tmp/build/a94a8fe5/go/bin:/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\\n+ PATH=/tmp/build/a94a8fe5/go/bin:/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\\n+ go get github.com/onsi/ginkgo/ginkgo\\n\"},\"event\":\"log\",\"version\":\"5.0\"}\n\nid: 8\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"+ go get github.com/onsi/gomega\\n\"},\"event\":\"log\",\"version\":\"5.0\"}\n\nid: 9\nevent: event\ndata: {\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"+ go get github.com/gorilla/mux\\n\"},\"event\":\"log\",\"version\":\"5.0\"}\n\n".data(using: String.Encoding.utf8)

        subject.process(data!)

        XCTAssertEqual(dispatchedEvents.count, 10)

        let eventOne = dispatchedEvents[0]
        XCTAssertEqual(eventOne.lastEventId, "0")
        XCTAssertEqual(eventOne.data, "{\"data\":{\"status\":\"started\",\"time\":1492401089},\"event\":\"status\",\"version\":\"1.0\"}")
        XCTAssertEqual(eventOne.type, "event")

        let eventTwo = dispatchedEvents[1]
        XCTAssertEqual(eventTwo.lastEventId, "1")
        XCTAssertEqual(eventTwo.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbb\"}},\"event\":\"initialize-get\",\"version\":\"1.0\"}")
        XCTAssertEqual(eventTwo.type, "event")

        let eventThree = dispatchedEvents[2]
        XCTAssertEqual(eventThree.lastEventId, "2")
        XCTAssertEqual(eventThree.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbb\",\"source\":\"stdout\"},\"payload\":\"using version of resource found in cache\\n\"},\"event\":\"log\",\"version\":\"5.0\"}")
        XCTAssertEqual(eventThree.type, "event")

        let eventFour = dispatchedEvents[3]
        XCTAssertEqual(eventFour.lastEventId, "3")
        XCTAssertEqual(eventFour.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbb\"},\"plan\":{\"name\":\"omgfruitapi-master\",\"resource\":\"omgfruitapi-master\",\"type\":\"git\",\"version\":{\"ref\":\"35e476dc29ca300c6a527c2b660d5334ad1b594d\"}},\"exit_status\":0,\"version\":{\"ref\":\"35e476dc29ca300c6a527c2b660d5334ad1b594d\"},\"metadata\":[{\"name\":\"commit\",\"value\":\"35e476dc29ca300c6a527c2b660d5334ad1b594d\"},{\"name\":\"author\",\"value\":\"Jared Friese\"},{\"name\":\"author_date\",\"value\":\"2016-12-06 06:04:27 -0800\"},{\"name\":\"branch\",\"value\":\"master\"},{\"name\":\"tags\",\"value\":\"1481035419,1481036805,1481054609,1481058512\"},{\"name\":\"message\",\"value\":\"Update release script\\n\"}]},\"event\":\"finish-get\",\"version\":\"4.0\"}")
        XCTAssertEqual(eventFour.type, "event")

        let eventFive = dispatchedEvents[4]
        XCTAssertEqual(eventFive.lastEventId, "4")
        XCTAssertEqual(eventFive.data, "{\"data\":{\"config\":{\"platform\":\"linux\",\"image\":\"\",\"run\":{\"path\":\"go/src/github.com/jwfriese/omgfruitapi/test.sh\",\"args\":null,\"dir\":\"\"},\"inputs\":[{\"name\":\"omgfruitapi-master\",\"path\":\"go/src/github.com/jwfriese/omgfruitapi\"}]},\"origin\":{\"id\":\"58f43bbc\"}},\"event\":\"initialize-task\",\"version\":\"4.0\"}")
        XCTAssertEqual(eventFive.type, "event")

        let eventSix = dispatchedEvents[5]
        XCTAssertEqual(eventSix.lastEventId, "5")
        XCTAssertEqual(eventSix.data, "{\"data\":{\"time\":1492401096,\"origin\":{\"id\":\"58f43bbc\"}},\"event\":\"start-task\",\"version\":\"4.0\"}")
        XCTAssertEqual(eventSix.type, "event")

        let eventSeven = dispatchedEvents[6]
        XCTAssertEqual(eventSeven.lastEventId, "6")
        XCTAssertEqual(eventSeven.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"++ pwd\\n\"},\"event\":\"log\",\"version\":\"5.0\"}")
        XCTAssertEqual(eventSeven.type, "event")

        let eventEight = dispatchedEvents[7]
        XCTAssertEqual(eventEight.lastEventId, "7")
        XCTAssertEqual(eventEight.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"+ export GOPATH=/tmp/build/a94a8fe5/go\\n+ GOPATH=/tmp/build/a94a8fe5/go\\n+ export PATH=/tmp/build/a94a8fe5/go/bin:/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\\n+ PATH=/tmp/build/a94a8fe5/go/bin:/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\\n+ go get github.com/onsi/ginkgo/ginkgo\\n\"},\"event\":\"log\",\"version\":\"5.0\"}")
        XCTAssertEqual(eventEight.type, "event")

        let eventNine = dispatchedEvents[8]
        XCTAssertEqual(eventNine.lastEventId, "8")
        XCTAssertEqual(eventNine.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"+ go get github.com/onsi/gomega\\n\"},\"event\":\"log\",\"version\":\"5.0\"}")
        XCTAssertEqual(eventNine.type, "event")

        let eventTen = dispatchedEvents[9]
        XCTAssertEqual(eventTen.lastEventId, "9")
        XCTAssertEqual(eventTen.data, "{\"data\":{\"origin\":{\"id\":\"58f43bbc\",\"source\":\"stdout\"},\"payload\":\"+ go get github.com/gorilla/mux\\n\"},\"event\":\"log\",\"version\":\"5.0\"}")
        XCTAssertEqual(eventTen.type, "event")
    }

    func test_processing_whenDataSplitAcrossMultipleStreamItems() {
        subject.process("id:".data(using: String.Encoding.utf8)!)
        subject.process("someid\nd".data(using: String.Encoding.utf8)!)
        subject.process("ata: some data\nevent       ".data(using: String.Encoding.utf8)!)
        subject.process(" :name of the event\n\n\n\n".data(using: String.Encoding.utf8)!)
        subject.process("  id: shouldnotset\nevent: another event\ndata:data\n".data(using: String.Encoding.utf8)!)
        subject.process("\n".data(using: String.Encoding.utf8)!)
        subject.process("id:a-new-id\ndata: some long data item".data(using: String.Encoding.utf8)!)
        subject.process("that spans multiple lines\nevent: yet another event\n\n".data(using: String.Encoding.utf8)!)

        XCTAssertEqual(dispatchedEvents.count, 3)

        let eventOne = dispatchedEvents[0]
        XCTAssertEqual(eventOne.lastEventId, "someid")
        XCTAssertEqual(eventOne.data, "some data")
        XCTAssertEqual(eventOne.type, "message")

        let eventTwo = dispatchedEvents[1]
        XCTAssertEqual(eventTwo.lastEventId, "someid")
        XCTAssertEqual(eventTwo.data, "data")
        XCTAssertEqual(eventTwo.type, "another event")

        let eventThree = dispatchedEvents[2]
        XCTAssertEqual(eventThree.lastEventId, "a-new-id")
        XCTAssertEqual(eventThree.data, "some long data itemthat spans multiple lines")
        XCTAssertEqual(eventThree.type, "yet another event")
    }

    func test_processing_firesRetryTimeCallbackWhenProcessingAValidRetryField() {
        subject.process("retry: 20000\nretry: shouldfail\n\nretry:30000".data(using: String.Encoding.utf8)!)
        subject.process("\n retry : 40000\n\n\nretry: 33d00\nretry: 50000\n\n".data(using: String.Encoding.utf8)!)

        XCTAssertEqual(retryTimeUpdates.count, 3)

        let firstUpdate = retryTimeUpdates[0]
        XCTAssertEqual(firstUpdate, 20000)
        let secondUpdate = retryTimeUpdates[1]
        XCTAssertEqual(secondUpdate, 30000)
        let thirdUpdate = retryTimeUpdates[2]
        XCTAssertEqual(thirdUpdate, 50000)
    }
}
