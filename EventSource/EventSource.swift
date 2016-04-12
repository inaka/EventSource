//
//  EventSource.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import Foundation

enum EventSourceState {
    case Connecting
    case Open
    case Closed
}

public class EventSource: NSObject, NSURLSessionDataDelegate {
	static let DefaultsKey = "com.inaka.eventSource.lastEventId"

    let url: NSURL
	private let lastEventIDKey: String
    private let receivedString: NSString?
    private var onOpenCallback: (Void -> Void)?
    private var onErrorCallback: (NSError? -> Void)?
    private var onMessageCallback: ((id: String?, event: String?, data: String?) -> Void)?
    private(set) var readyState: EventSourceState
    private(set) var retryTime = 3000
    private var eventListeners = Dictionary<String, (id: String?, event: String?, data: String?) -> Void>()
    private var headers: Dictionary<String, String>
    internal var urlSession: NSURLSession?
    internal var task : NSURLSessionDataTask?
    private var operationQueue: NSOperationQueue
    private var errorBeforeSetErrorCallBack: NSError?
    internal let receivedDataBuffer: NSMutableData
	private let uniqueIdentifier: String

    var event = Dictionary<String, String>()


    public init(url: String, headers: [String : String]) {

        self.url = NSURL(string: url)!
        self.headers = headers
        self.readyState = EventSourceState.Closed
        self.operationQueue = NSOperationQueue()
        self.receivedString = nil
        self.receivedDataBuffer = NSMutableData()


		let port = self.url.port?.stringValue ?? ""
		let relativePath = self.url.relativePath ?? ""
		let host = self.url.host ?? ""

		self.uniqueIdentifier = "\(self.url.scheme).\(host).\(port).\(relativePath)"
		self.lastEventIDKey = "\(EventSource.DefaultsKey).\(self.uniqueIdentifier)"

        super.init();
        self.connect()
    }

//Mark: Connect
    
    func connect() {
        var additionalHeaders = self.headers
        if let eventID = self.lastEventID {
            additionalHeaders["Last-Event-Id"] = eventID
        }
        
        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = NSTimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = NSTimeInterval(INT_MAX)
        configuration.HTTPAdditionalHeaders = additionalHeaders
        
        self.readyState = EventSourceState.Connecting
        self.urlSession = newSession(configuration)
        self.task = urlSession!.dataTaskWithURL(self.url);

        self.task!.resume()
    }

    internal func newSession(configuration: NSURLSessionConfiguration) -> NSURLSession {
        return NSURLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
    }

//Mark: Close

    public func close() {
        self.readyState = EventSourceState.Closed
        self.urlSession?.invalidateAndCancel()
    }
	
	private func receivedMessageToClose(httpResponse: NSHTTPURLResponse?) -> Bool {
		guard let response = httpResponse  else {
			return false
		}
		
		if(response.statusCode == 204) {
			self.close()
			return true
		}
		return false
	}
	
//Mark: EventListeners

    public func onOpen(onOpenCallback: Void -> Void) {
        self.onOpenCallback = onOpenCallback
    }

    public func onError(onErrorCallback: NSError? -> Void) {
        self.onErrorCallback = onErrorCallback

        if let errorBeforeSet = self.errorBeforeSetErrorCallBack {
            self.onErrorCallback!(errorBeforeSet)
            self.errorBeforeSetErrorCallBack = nil;
        }
    }

    public func onMessage(onMessageCallback: (id: String?, event: String?, data: String?) -> Void) {
        self.onMessageCallback = onMessageCallback
    }

    public func addEventListener(event: String, handler: (id: String?, event: String?, data: String?) -> Void) {
        self.eventListeners[event] = handler
    }

//MARK: NSURLSessionDataDelegate

    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
		if self.receivedMessageToClose(dataTask.response as? NSHTTPURLResponse) {
			return
		}

		if self.readyState != EventSourceState.Open {
            return
        }
        
        self.receivedDataBuffer.appendData(data)
        let eventStream = extractEventsFromBuffer()
        self.parseEventStream(eventStream)
    }

    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
        completionHandler(NSURLSessionResponseDisposition.Allow)

		if self.receivedMessageToClose(dataTask.response as? NSHTTPURLResponse) {
			return
		}
		
        self.readyState = EventSourceState.Open
        if(self.onOpenCallback != nil) {
            dispatch_async(dispatch_get_main_queue()) {
                self.onOpenCallback!()
            }
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        self.readyState = EventSourceState.Closed
		
		if self.receivedMessageToClose(task.response as? NSHTTPURLResponse) {
			return
		}

        if(error == nil || error!.code != -999) {
            let nanoseconds = Double(self.retryTime) / 1000.0 * Double(NSEC_PER_SEC)
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(nanoseconds));
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.connect()
            }
        }

        dispatch_async(dispatch_get_main_queue()) {
            if let errorCallback = self.onErrorCallback {
                errorCallback(error)
            }else {
                self.errorBeforeSetErrorCallBack = error
            }
        }
    }

//MARK: Helpers
    
    private func extractEventsFromBuffer() -> [String] {
        let delimiter = "\n\n".dataUsingEncoding(NSUTF8StringEncoding)!
        var events = [String]()
        
        // Find first occurrence of delimiter
        var searchRange = NSMakeRange(0, receivedDataBuffer.length)
        var foundRange = receivedDataBuffer.rangeOfData(delimiter, options: NSDataSearchOptions(), range: searchRange)
        while foundRange.location != NSNotFound {
            // Append event
            if foundRange.location > searchRange.location {
                let dataChunk = receivedDataBuffer.subdataWithRange(
                    NSMakeRange(searchRange.location, foundRange.location - searchRange.location)
                )
                events.append(NSString(data: dataChunk, encoding: NSUTF8StringEncoding) as! String)
            }
            // Search for next occurrence of delimiter
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = receivedDataBuffer.length - searchRange.location
            foundRange = receivedDataBuffer.rangeOfData(delimiter, options: NSDataSearchOptions(), range: searchRange)
        }
        
        // Remove the found events from the buffer
        self.receivedDataBuffer.replaceBytesInRange(NSMakeRange(0,searchRange.location), withBytes: nil, length: 0)
        
        return events
    }
    
    private func parseEventStream(events: [String]) {
        var parsedEvents: [(id: String?, event: String?, data: String?)] = Array()

        for event in events {
            if event.isEmpty {
                continue
            }

            if event.hasPrefix(":") {
                continue
            }

            if (event as NSString).containsString("retry:") {
                if let reconnectTime = parseRetryTime(event) {
                    self.retryTime = reconnectTime
                }
                continue
            }

            parsedEvents.append(parseEvent(event))
        }

        for parsedEvent in parsedEvents {
            self.lastEventID = parsedEvent.id

            if parsedEvent.event == nil {
                if let data = parsedEvent.data, onMessage = self.onMessageCallback {
                    dispatch_async(dispatch_get_main_queue()) {
                        onMessage(id: self.lastEventID, event: "message", data: data)
                    }
                }
            }

            if let event = parsedEvent.event, data = parsedEvent.data, eventHandler = self.eventListeners[event] {
                dispatch_async(dispatch_get_main_queue()) {
                    eventHandler(id: self.lastEventID, event: event, data: data)
                }
            }
        }
    }

    internal var lastEventID: String? {
        set {
            if let lastEventID = newValue {
                let defaults = NSUserDefaults.standardUserDefaults()
                defaults.setObject(lastEventID, forKey: lastEventIDKey)
                defaults.synchronize()
            }
        }

        get {
            let defaults = NSUserDefaults.standardUserDefaults()

            if let lastEventID = defaults.stringForKey(lastEventIDKey) {
                return lastEventID
            }
            return nil
        }
    }

    private func parseEvent(eventString: String) -> (id: String?, event: String?, data: String?) {
        var event = Dictionary<String, String>()

        for line in eventString.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()) as [String] {
            autoreleasepool {
                var key: NSString?, value: NSString?
                let scanner = NSScanner(string: line)
                scanner.scanUpToString(":", intoString: &key)
                scanner.scanString(":",intoString: nil)
                scanner.scanUpToString("\n", intoString: &value)

                if (key != nil && value != nil) {
                    if (event[key as! String] != nil) {
                        event[key as! String] = "\(event[key as! String]!)\n\(value!)"
                    } else {
                        event[key as! String] = value! as String
                    }
                } else if (key != nil && value == nil) {
                    event[key as! String] = ""
                }
            }
        }

        return (event["id"], event["event"], event["data"])
    }

    private func parseRetryTime(eventString: String) -> Int? {
        var reconnectTime: Int?
        let separators = NSCharacterSet(charactersInString: ":")
        if let milli = eventString.componentsSeparatedByCharactersInSet(separators).last {
            let milliseconds = trim(milli)

            if let intMiliseconds = Int(milliseconds) {
                reconnectTime = intMiliseconds
            }
        }
        return reconnectTime
    }

    private func trim(string: String) -> String {
        return string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    }

    class public func basicAuth(username: String, password: String) -> String {
        let authString = "\(username):\(password)"
        let authData = authString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64String = authData!.base64EncodedStringWithOptions([])

        return "Basic \(base64String)"
    }
}