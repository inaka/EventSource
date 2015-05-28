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

    let url: NSURL
    private let lastEventIDKey = "com.inaka.eventSource.lastEventId"
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

    var event = Dictionary<String, String>()

    
    public init(url: String, headers: [String : String]) {

        self.url = NSURL(string: url)!
        self.headers = headers
        self.readyState = EventSourceState.Closed
        self.operationQueue = NSOperationQueue()
        self.receivedString = nil

        super.init();
        self.connect()
    }

//Mark: Connect
    
    func connect() {
        var additionalHeaders = self.headers
        if let eventID = lastEventID {
            additionalHeaders["Last-Event-Id"] = eventID
        }
        
        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = NSTimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = NSTimeInterval(INT_MAX)
        configuration.HTTPAdditionalHeaders = additionalHeaders
        
        readyState = EventSourceState.Connecting
        urlSession = newSession(configuration)
        task = urlSession!.dataTaskWithURL(self.url);

        task!.resume()
    }

    internal func newSession(configuration: NSURLSessionConfiguration) -> NSURLSession {
        return NSURLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
    }

//Mark: Close

    public func close() {
        readyState = EventSourceState.Closed
        urlSession?.invalidateAndCancel()
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

        if readyState != EventSourceState.Open {
            return
        }

        var buffer = [UInt8](count: data.length, repeatedValue: 0)
        data.getBytes(&buffer, length: data.length)
        
        if let receivedString = String(bytes: buffer, encoding: NSUTF8StringEncoding) {
            parseEventStream(receivedString)
        }
    }

    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
        completionHandler(NSURLSessionResponseDisposition.Allow)

        readyState = EventSourceState.Open
        if(self.onOpenCallback != nil) {
            dispatch_async(dispatch_get_main_queue()) {
                self.onOpenCallback!()
            }
        }
    }

    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        readyState = EventSourceState.Closed

        if(error == nil || error!.code != -999) {
            let nanoseconds = Double(self.retryTime) / 1000.0 * Double(NSEC_PER_SEC)
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(nanoseconds));
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.connect()
            }
        }

        dispatch_async(dispatch_get_main_queue()) {
            if let errorCallback = self.onErrorCallback {
                self.onErrorCallback!(error)
            }else {
                self.errorBeforeSetErrorCallBack = error
            }
        }
    }

//MARK: Helpers

    private func parseEventStream(events: String) {
        var parsedEvents: [(id: String?, event: String?, data: String?)] = Array()

        let events = events.componentsSeparatedByString("\n\n")
        for event in events as [String] {

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

        for parsedEvent in parsedEvents as [(id: String?, event: String?, data: String?)] {
            self.lastEventID = parsedEvent.id

            if parsedEvent.event == nil && parsedEvent.data != nil {
                if(self.onMessageCallback != nil) {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.onMessageCallback!(id:self.lastEventID,event: "message",data: parsedEvent.data)
                    }
                }
            }

            if parsedEvent.event != nil && parsedEvent.data != nil {
                if (self.eventListeners[parsedEvent.event!] != nil) {
                    dispatch_async(dispatch_get_main_queue()) {
                        let eventHandler = self.eventListeners[parsedEvent.event!]
                        eventHandler!(id:self.lastEventID,event:parsedEvent.event!, data: parsedEvent.data!)
                    }
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

            if let intMiliseconds = milliseconds.toInt() {
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
        let base64String = authData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)

        return "Basic \(base64String)"
    }
}