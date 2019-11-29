//
//  EventSourceTests.swift
//  EventSourceTests
//
//  Created by Andres on 22/08/2019.
//  Copyright © 2019 Andres. All rights reserved.
//

import XCTest
@testable import EventSource

class EventSourceTests: XCTestCase {

    var eventSource: EventSource!
    let url = URL(string: "https://localhost")!

    override func setUp() {
        eventSource = EventSource(url: url, headers: ["header": "value"])
    }

    func testCreation() {
        XCTAssertEqual(url, eventSource.url)
        XCTAssertEqual(eventSource.headers, ["header": "value"])
        XCTAssertEqual(eventSource.readyState, EventSourceState.closed)
    }

    func testDisconnect() {
        XCTAssertEqual(eventSource.readyState, EventSourceState.closed)
    }

    func testSessionConfiguration() {
        let configuration = eventSource.sessionConfiguration(lastEventId: "event-id")

        XCTAssertEqual(configuration.timeoutIntervalForRequest, TimeInterval(INT_MAX))
        XCTAssertEqual(configuration.timeoutIntervalForResource, TimeInterval(INT_MAX))
        XCTAssertEqual(configuration.httpAdditionalHeaders as? [String: String], [
            "Last-Event-Id": "event-id", "Accept": "text/event-stream", "Cache-Control": "no-cache", "header": "value"]
        )
    }

    func testAddEventListener() {
        eventSource.addEventListener("event-name") { _, _, _ in }
        XCTAssertEqual(eventSource.events(), ["event-name"])
    }

    func testRemoveEventListener() {
        eventSource.addEventListener("event-name") { _, _, _ in }
        eventSource.removeEventListener("event-name")

        XCTAssertEqual(eventSource.events(), [])
    }

    func testRetryTime() {
        eventSource.connect()
        eventSource.readyStateOpen()

        let aSession = URLSession(configuration: URLSessionConfiguration.default)
        let aSessionDataTask = URLSessionDataTask()

        let event = """
        id: event-id-1
        data: event-data-first
        retry: 1000

        id: event
        """

        let data = event.data(using: .utf8)!
        eventSource.urlSession(aSession, dataTask: aSessionDataTask, didReceive: data)
        XCTAssertEqual(eventSource.retryTime, 1000)
    }

    func testOnOpen() {
        let expectation = XCTestExpectation(description: "onOpen gets called")

        eventSource.onOpen {
            XCTAssertEqual(self.eventSource.readyState, EventSourceState.open)
            expectation.fulfill()
        }

        let aSession = URLSession(configuration: URLSessionConfiguration.default)
        let aSessionDataTask = URLSessionDataTask()
        let urlResponse = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        eventSource.urlSession(aSession, dataTask: aSessionDataTask, didReceive: urlResponse) { _ in }
        wait(for: [expectation], timeout: 2.0)
    }

    func testOnCompleteRetryTrue() {
        let expectation = XCTestExpectation(description: "onComplete gets called")
        eventSource.onComplete { statusCode, retry, _ in
            XCTAssertEqual(statusCode, 200)
            XCTAssertEqual(retry, false)
            expectation.fulfill()
        }

        let aSession = URLSession(configuration: URLSessionConfiguration.default)
        let response =  HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])
        let dataTask = URLSessionDataTaskMock(response: response)
        eventSource.urlSession(aSession, task: dataTask, didCompleteWithError: nil)
        wait(for: [expectation], timeout: 2.0)
    }

    func testOnCompleteRetryFalse() {
        let expectation = XCTestExpectation(description: "onComplete gets called")
        eventSource.onComplete { statusCode, retry, _ in
            XCTAssertEqual(statusCode, 250)
            XCTAssertEqual(retry, true)
            expectation.fulfill()
        }

        let aSession = URLSession(configuration: URLSessionConfiguration.default)
        let response =  HTTPURLResponse(url: url, statusCode: 250, httpVersion: nil, headerFields: [:])
        let dataTask = URLSessionDataTaskMock(response: response)
        eventSource.urlSession(aSession, task: dataTask, didCompleteWithError: nil)
        wait(for: [expectation], timeout: 2.0)
    }

    func testOnCompleteError() {
        let expectation = XCTestExpectation(description: "onComplete gets called")
        eventSource.onComplete { statusCode, retry, error in
            XCTAssertNotNil(error)
            XCTAssertNil(retry)
            XCTAssertNil(statusCode)
            expectation.fulfill()
        }

        let aSession = URLSession(configuration: URLSessionConfiguration.default)
        let dataTask = URLSessionDataTaskMock(response: nil)
        let error = NSError(domain: "", code: -1, userInfo: [:])
        eventSource.urlSession(aSession, task: dataTask, didCompleteWithError: error)
        wait(for: [expectation], timeout: 2.0)
    }

    func testSmallEventStream() {
        eventSource.connect()
        eventSource.readyStateOpen()

        var eventsIds: [String] = []
        var eventNames: [String] = []
        var eventDatas: [String] = []

        let exp = self.expectation(description: "onMessage gets called")
        eventSource.onMessage { eventId, eventName, eventData in
            eventsIds.append(eventId ?? "")
            eventNames.append(eventName ?? "")
            eventDatas.append(eventData ?? "")

            if(eventsIds.count == 3) {
                exp.fulfill()
            }
        }

        let eventsString = """
        id: event-id-1
        data: event-data-first

        id: event-id-2
        data: event-data-second

        id: event-id-3
        data: event-data-third


        """

        let aSession = URLSession(configuration: URLSessionConfiguration.default)
        let aSessionDataTask = URLSessionDataTask()
        let data = eventsString.data(using: .utf8)!
        eventSource.urlSession(aSession, dataTask: aSessionDataTask, didReceive: data)

        waitForExpectations(timeout: 2) { _ in
            XCTAssertEqual(eventsIds, ["event-id-1", "event-id-2", "event-id-3"])
            XCTAssertEqual(eventNames, ["message", "message", "message"])
            XCTAssertEqual(eventsIds, ["event-id-1", "event-id-2", "event-id-3"])
        }
    }

    func testDisconnet() {
        eventSource.readyStateOpen()
        eventSource.disconnect()

        XCTAssertEqual(eventSource.readyState, .closed)
    }
}
