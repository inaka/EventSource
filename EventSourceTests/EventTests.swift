//
//  EventTests.swift
//  EventSourceTests
//
//  Created by Andres on 01/06/2019.
//  Copyright © 2019 inaka. All rights reserved.
//

import UIKit
import XCTest
@testable import EventSource

class EventTests: XCTestCase {
    let newLineCharacters = ["\r\n", "\n", "\r"]

    func testIgnoreComment() {
        var event = Event(eventString: ":retry", newLineCharacters: newLineCharacters)
        XCTAssertNil(event)

        event = Event(eventString: ": retry", newLineCharacters: newLineCharacters)
        XCTAssertNil(event)
    }

    func testRetryEvent() {
        let eventsString = """
        retry: 5000
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.retryTime, 5000)
    }

    func testRetryEventWrongTime() {
        let eventsString = """
        retry: this is a wrong value
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.retryTime, nil)
    }

    func testFullBasicEvent() {
        let eventsString = """
        id: event-id-1
        data: event-data-first
        event: testing event name
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.id, "event-id-1")
        XCTAssertEqual(event?.data, "event-data-first")
        XCTAssertEqual(event?.event, "testing event name")
    }

    func testFullBasicEventWithSpaces() {
        let eventsString = """
        id:              event-id-1
        data:            event-data-first
        event:           testing event name
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.id, "event-id-1")
        XCTAssertEqual(event?.data, "event-data-first")
        XCTAssertEqual(event?.event, "testing event name")
    }

    func testEventWithMultipleLinesOfData() {
        let eventsString = """
        id: event-id-1
        data: first line
        data: second line
        data: third line
        event: testing event name
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.id, "event-id-1")
        XCTAssertEqual(event?.data, "first line\nsecond line\nthird line")
        XCTAssertEqual(event?.event, "testing event name")
    }

    func testEventWithNoId() {
        let eventsString = """
        event: test-event
        data: first line
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.id, nil)
        XCTAssertEqual(event?.data, "first line")
        XCTAssertEqual(event?.event, "test-event")
    }

    func testEventWithEmptyId() {
        let eventsString = """
        id
        data: first line
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.id, "")
        XCTAssertEqual(event?.data, "first line")
    }

    func testEventWithEmptyData() {
        let eventsString = "data"
        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.data, "")
    }

    func testEventDobleEmptyData() {
        let eventsString = """
        data
        data
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.data, "\n")
    }

    func testEventWithRetryTime() {
        let eventsString = """
        id
        data
        data
        retry: 1000
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.id, "")
        XCTAssertEqual(event?.data, "\n")
        XCTAssertEqual(event?.retryTime, 1000)
    }

    func testOnlyRetryTime() {
        let eventsString = """
        retry: 1000
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.onlyRetryEvent, true)
    }

    func testOnlyRetryTimeWithEventInfo() {
        let eventsString = """
        retry: 1000
        id
        """

        let event = Event(eventString: eventsString, newLineCharacters: newLineCharacters)
        XCTAssertEqual(event?.onlyRetryEvent, false)
    }
}
