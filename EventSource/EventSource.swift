//
//  EventSource.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import Foundation

public enum EventSourceState {
    case connecting
    case open
    case closed
}

public class EventSource: NSObject, URLSessionDataDelegate {
    static let DefaultRetryTime = 3000

    let url: URL
    var lastEventId: String?

    private(set) var retryTime = EventSource.DefaultRetryTime
    private(set) var headers: [String: String]

    private var onOpenCallback: (() -> Void)?
    private var onComplete: ((Int?, Bool?, NSError?) -> Void)?

    private var onMessageCallback: ((_ id: String?, _ event: String?, _ data: String?) -> Void)?
    private var eventListeners: [String: (_ id: String?, _ event: String?, _ data: String?) -> Void] = [:]

    private var eventStreamParser: EventStreamParser?

    var urlSession: URLSession?
    var readyState: EventSourceState

    private var operationQueue: OperationQueue
    private var mainQueue = DispatchQueue.main

    public init(
        url: URL,
        headers: [String: String] = [:]
    ) {
        self.url = url
        self.headers = headers

        readyState = EventSourceState.closed
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        super.init()
    }

    public func connect(lastEventId: String? = nil) {
        eventStreamParser = EventStreamParser()
        readyState = .connecting

        let configuration = sessionConfiguration(lastEventId: lastEventId)
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
        urlSession?.dataTask(with: url).resume()
    }

    public func disconnect() {
        readyState = .closed
        urlSession?.invalidateAndCancel()
    }

    func onOpen(_ onOpenCallback: @escaping (() -> Void)) {
        self.onOpenCallback = onOpenCallback
    }

    func onComplete(_ onComplete: @escaping ((Int?, Bool?, NSError?) -> Void)) {
        self.onComplete = onComplete
    }

    func onMessage(_ onMessageCallback: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        self.onMessageCallback = onMessageCallback
    }

    func addEventListener(_ event: String,
                          handler: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        eventListeners[event] = handler
    }

	func removeEventListener(_ event: String) {
		eventListeners.removeValue(forKey: event)
	}

	func events() -> [String] {
		return Array(eventListeners.keys)
	}

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

		if readyState != .open {
            return
        }

        if let events = eventStreamParser?.append(data: data) {
            notifyReceivedEvents(events)
        }
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        completionHandler(URLSession.ResponseDisposition.allow)

        readyState = .open
        mainQueue.async { [weak self] in self?.onOpenCallback?() }
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {

        guard let responseStatusCode = (task.response as? HTTPURLResponse)?.statusCode else {
            mainQueue.async { [weak self] in self?.onComplete?(nil, nil, error as NSError?) }
            return
        }

        let reconnect = shouldReconnect(statusCode: responseStatusCode)
        mainQueue.async { [weak self] in self?.onComplete?(responseStatusCode, reconnect, nil) }
    }

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {

        var newRequest = request
        self.headers.forEach { newRequest.setValue($1, forHTTPHeaderField: $0) }
        completionHandler(newRequest)
    }
}

internal extension EventSource {

    func sessionConfiguration(lastEventId: String?) -> URLSessionConfiguration {

        var additionalHeaders = headers
        if let eventID = lastEventId {
            additionalHeaders["Last-Event-Id"] = eventID
        }

        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        sessionConfiguration.httpAdditionalHeaders = additionalHeaders

        return sessionConfiguration
    }

    func readyStateOpen() {
        readyState = .open
    }
}

private extension EventSource {

    func notifyReceivedEvents(_ events: [Event]) {

        for event in events {
            lastEventId = event.id
            retryTime = event.retryTime ?? EventSource.DefaultRetryTime

            if event.onlyRetryEvent == true {
                continue
            }

            if event.event == nil || event.event == "message" {
                mainQueue.async { [weak self] in self?.onMessageCallback?(event.id, "message", event.data) }
            }

            if let eventName = event.event, let eventHandler = eventListeners[eventName] {
                mainQueue.async { eventHandler(event.id, event.event, event.data) }
            }
        }
    }

    // Following "5 Processing model" from:
    // https://www.w3.org/TR/2009/WD-eventsource-20090421/#handler-eventsource-onerror
    func shouldReconnect(statusCode: Int) -> Bool {
        switch statusCode {
        case 200:
            return false
        case _ where statusCode > 200 && statusCode < 300:
            return true
        default:
            return false
        }
    }
}
