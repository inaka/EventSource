//
//  EventParserTests.swift
//  EventSourceTests
//
//  Created by Andres on 30/05/2019.
//  Copyright © 2019 inaka. All rights reserved.
//

import UIKit
import XCTest
@testable import EventSource

class EventStreamParserTests: XCTestCase {

    func testExtractingEvents() {
        let eventParser = EventStreamParser()
        let eventsString = """
        id: event-id-1
        data: event-data-first

        id: event-id-2
        data: event-data-second

        id: event-id-3
        data: event-data-third
        """

        let events = eventParser.append(data: eventsString.data(using: .utf8))
        XCTAssertEqual(events.count, 2)
    }

    func testExtractingSplittedEvents() {
        let eventParser = EventStreamParser()
        let firstEventsStringPiece = """
        id: event-id-1
        data: event-data-first

        id: event
        """

        var events = eventParser.append(data: firstEventsStringPiece.data(using: .utf8))
        XCTAssertEqual(events.count, 1)

        let secondEventsStringPiece = """
        -id-2
        data: event-data-second

        id: event-id-3
        data: event-data-third


        """

        events = eventParser.append(data: secondEventsStringPiece.data(using: .utf8))
        XCTAssertEqual(events.count, 2)
    }

    // The following test streams are the samples introduced in the https://www.w3.org/TR/eventsource/ from section 7
    func testFirstW3StreamSample() {
        let eventParser = EventStreamParser()
        let eventString = """
        data: YHOO
        data: +2
        data: 10


        """

        let events = eventParser.append(data: eventString.data(using: .utf8))
        XCTAssertEqual(events.count, 1)

        let event = events.first!
        XCTAssertEqual(event.id, nil)
        XCTAssertEqual(event.event, nil)
        XCTAssertEqual(event.retryTime, nil)
        XCTAssertEqual(event.data, "YHOO\n+2\n10")
    }

    // The first block has just a comment, and will fire nothing.
    // The second block has two fields with names "data" and "id" respectively; an event will be fired for this block.
    // The third block fires an event.
    // The last block is not fired as a new breakline is still missing to be parsed.
    func testSecondW3StreamSample() {
        let eventParser = EventStreamParser()
        let eventString = """
        : test stream

        data: first event
        id: 1

        data:second event
        id

        data:  third event

        """

        let events = eventParser.append(data: eventString.data(using: .utf8))
        XCTAssertEqual(events.count, 2)

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.id, "1")
        XCTAssertEqual(firstEvent.event, nil)
        XCTAssertEqual(firstEvent.data, "first event")
        XCTAssertEqual(firstEvent.retryTime, nil)

        let secondEvent = events[1]
        XCTAssertEqual(secondEvent.id, "")
        XCTAssertEqual(secondEvent.event, nil)
        XCTAssertEqual(secondEvent.data, "second event")
        XCTAssertEqual(secondEvent.retryTime, nil)
    }

    // The first block fires an event with the data set to the empty string.
    // The middle block fires an event with the data set to a single newline character.
    // The last block fires an event with the data set to empty string.
    func testThirdW3StreamSample() {
        let eventParser = EventStreamParser()
        let eventString = """
        data

        data
        data

        data:


        """

        let events = eventParser.append(data: eventString.data(using: .utf8))
        XCTAssertEqual(events.count, 3)

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.id, nil)
        XCTAssertEqual(firstEvent.event, nil)
        XCTAssertEqual(firstEvent.data, "")
        XCTAssertEqual(firstEvent.retryTime, nil)

        let secondEvent = events[1]
        XCTAssertEqual(secondEvent.id, nil)
        XCTAssertEqual(secondEvent.event, nil)
        XCTAssertEqual(secondEvent.data, "\n")
        XCTAssertEqual(secondEvent.retryTime, nil)

        let thirdEvent = events[2]
        XCTAssertEqual(thirdEvent.id, nil)
        XCTAssertEqual(thirdEvent.event, nil)
        XCTAssertEqual(thirdEvent.data, "")
        XCTAssertEqual(thirdEvent.retryTime, nil)
    }

    // The following stream fires two identical events:
    func testForthW3StreamSample() {
        let eventParser = EventStreamParser()
        let eventString = """
        data:test

        data: test


        """

        let events = eventParser.append(data: eventString.data(using: .utf8))
        XCTAssertEqual(events.count, 2)

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.id, nil)
        XCTAssertEqual(firstEvent.event, nil)
        XCTAssertEqual(firstEvent.data, "test")
        XCTAssertEqual(firstEvent.retryTime, nil)

        let secondEvent = events[1]
        XCTAssertEqual(secondEvent.id, nil)
        XCTAssertEqual(secondEvent.event, nil)
        XCTAssertEqual(secondEvent.data, "test")
        XCTAssertEqual(secondEvent.retryTime, nil)
    }

    func testEventAfterCommentedLine() {
        let eventParser = EventStreamParser()
        let eventString = """
            :thump
            event: update
            data: data-from-the-event


        """

        let events = eventParser.append(data: eventString.data(using: .utf8))
        XCTAssertEqual(events.count, 1)

        let firstEvent = events[0]
        XCTAssertEqual(firstEvent.id, nil)
        XCTAssertEqual(firstEvent.event, "update")
        XCTAssertEqual(firstEvent.data, "data-from-the-event")
        XCTAssertEqual(firstEvent.retryTime, nil)
    }

    func testCurrentBuffer() {
        let eventParser = EventStreamParser()
        let eventString = """
        -id-2
        data: event-data-second

        """
        _ = eventParser.append(data: eventString.data(using: .utf8))
        XCTAssertEqual(eventParser.currentBuffer, eventString)
    }
}
