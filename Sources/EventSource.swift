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
	static let DefaultsKey = "com.inaka.eventSource.lastEventId"
    static let DefaultRetryTime = 3000

    let url: URL
    let lastEventIDKey: String

    private(set) var retryTime = EventSource.DefaultRetryTime

    private var onOpenCallback: (() -> Void)?
    private var onErrorCallback: ((NSError?) -> Void)?
    private var onMessageCallback: ((_ id: String?, _ event: String?, _ data: String?) -> Void)?
    private var eventListeners = Dictionary<String, (_ id: String?, _ event: String?, _ data: String?) -> Void>()
    private var headers: Dictionary<String, String>
    private var operationQueue: OperationQueue
    private var errorBeforeSetErrorCallBack: NSError?
    private let uniqueIdentifier: String
    private let eventStreamParser: EventStreamParser

    var urlSession: Foundation.URLSession?
    var task: URLSessionDataTask?
    var readyState: EventSourceState

    public init(url: String, headers: [String: String] = [:], resetLastEventID: Bool = false) {
        self.url = URL(string: url)!
        self.headers = headers
        self.readyState = EventSourceState.closed
        self.operationQueue = OperationQueue()
        self.eventStreamParser = EventStreamParser()

        let port = String(self.url.port ?? 80)
		let relativePath = self.url.relativePath
		let host = self.url.host ?? ""
        let scheme = self.url.scheme ?? ""

        self.uniqueIdentifier = "\(scheme).\(host).\(port).\(relativePath)"
		self.lastEventIDKey = "\(EventSource.DefaultsKey).\(self.uniqueIdentifier)"

        super.init()

        if resetLastEventID {
            self.resetLastEventID()
        }
        connect()
    }

    private(set) var lastEventID: String? {
        set {
            guard let lastEventID = newValue else { return }
            UserDefaults.standard.set(lastEventID, forKey: lastEventIDKey)
        }

        get {
            return UserDefaults.standard.string(forKey: lastEventIDKey)
        }
    }

    func connect() {
        var additionalHeaders = self.headers
        if let eventID = self.lastEventID {
            additionalHeaders["Last-Event-Id"] = eventID
        }

        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        configuration.httpAdditionalHeaders = additionalHeaders

        self.readyState = EventSourceState.connecting
        self.urlSession = newSession(configuration)
        self.task = urlSession!.dataTask(with: self.url)

		self.resumeSession()
    }

	internal func resumeSession() {
		self.task!.resume()
	}

    internal func newSession(_ configuration: URLSessionConfiguration) -> URLSession {
        return URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
    }

    func close() {
        self.readyState = EventSourceState.closed
        self.urlSession?.invalidateAndCancel()
    }

    func onOpen(_ onOpenCallback: @escaping (() -> Void)) {
        self.onOpenCallback = onOpenCallback
    }

    func onError(_ onErrorCallback: @escaping ((NSError?) -> Void)) {
        self.onErrorCallback = onErrorCallback

        if let errorBeforeSet = self.errorBeforeSetErrorCallBack {
            self.onErrorCallback!(errorBeforeSet)
            self.errorBeforeSetErrorCallBack = nil
        }
    }

    func onMessage(_ onMessageCallback: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        self.onMessageCallback = onMessageCallback
    }

    func addEventListener(_ event: String, handler: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> Void)) {
        self.eventListeners[event] = handler
    }

	func removeEventListener(_ event: String) {
		self.eventListeners.removeValue(forKey: event)
	}

	func events() -> Array<String> {
		return Array(self.eventListeners.keys)
	}

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		if receivedMessageToClose(dataTask.response as? HTTPURLResponse) {
			return
		}

		if self.readyState != EventSourceState.open {
            return
        }

        let events = eventStreamParser.append(data: data)
        parseEventStream(events)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)

		if receivedMessageToClose(dataTask.response as? HTTPURLResponse) {
			return
		}

        self.readyState = EventSourceState.open
        DispatchQueue.main.async {
            self.onOpenCallback?()
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.readyState = EventSourceState.closed

		if self.receivedMessageToClose(task.response as? HTTPURLResponse) {
            return
        }

        guard let urlResponse = task.response as? HTTPURLResponse else {
            return
        }

        if !hasHttpError(code: urlResponse.statusCode) && (error == nil || (error! as NSError).code != -999) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(retryTime)) { [weak self] in
                self?.connect()
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var theError: NSError? = error as NSError?

            if self.hasHttpError(code: urlResponse.statusCode) {
                theError = NSError(
                    domain: "com.inaka.eventSource.error",
                    code: -1,
                    userInfo: ["message": "HTTP Status Code: \(urlResponse.statusCode)"]
                )
                self.close()
            }

            if let errorCallback = self.onErrorCallback {
                errorCallback(theError)
            } else {
                self.errorBeforeSetErrorCallBack = theError
            }
        }
    }

    class func basicAuth(_ username: String, password: String) -> String {
        let authString = "\(username):\(password)"
        let authData = authString.data(using: String.Encoding.utf8)
        let base64String = authData!.base64EncodedString(options: [])

        return "Basic \(base64String)"
    }
}

private extension EventSource {

    func parseEventStream(_ events: [Event]) {

        for event in events {
            lastEventID = event.id
            retryTime = event.retryTime ?? EventSource.DefaultRetryTime

            if event.onlyRetryEvent == true {
                continue
            }

            if event.event == nil || event.event == "message" {
                onMessageCallback?(event.id, "message", event.data)
            }

            if let eventName = event.event, let eventHandler = self.eventListeners[eventName] {
                eventHandler(event.id, event.event, event.data)
            }
        }
    }

    func resetLastEventID() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: lastEventIDKey)
        defaults.synchronize()
    }

    func hasHttpError(code: Int) -> Bool {
        return code >= 400
    }

    func receivedMessageToClose(_ httpResponse: HTTPURLResponse?) -> Bool {
        guard httpResponse?.statusCode == 204 else { return false }

        close()
        return true
    }
}
