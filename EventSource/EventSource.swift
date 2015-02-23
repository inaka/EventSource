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

class EventSource: NSObject, NSURLSessionDataDelegate{

    let url: NSURL
    private let urlSession: NSURLSession?
    private let task : NSURLSessionTask?
    private let operationQueue = NSOperationQueue()
    private let lastEventID: NSString?
    private let receivedString : NSString?
    private var onOpenCallback : (Void -> Void)?
    private var onErrorCallback : (Void -> Void)?
    private(set) var readyState = EventSourceState.Closed
    private(set) var retryTime = 3000
    
    init(url: NSString, headers: [NSString : NSString]){

        self.url = NSURL(string: url)!
        
        var additionalHeaders = headers
        if let eventID = lastEventID{
            additionalHeaders["Last-Event-Id"] = eventID
        }

        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = NSTimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = NSTimeInterval(INT_MAX)
        configuration.HTTPAdditionalHeaders = additionalHeaders

        super.init();

        readyState = EventSourceState.Connecting
        urlSession = NSURLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
        task = urlSession!.dataTaskWithURL(self.url);
        task!.resume()
    }
    
//Mark: Close
    
    func close(){
        readyState = EventSourceState.Closed
        urlSession?.invalidateAndCancel()
    }
    
//Mark: EventListeners
    
    func onOpen(onOpenCallback: Void -> Void) {
        self.onOpenCallback = onOpenCallback
    }

    func onError(onErrorCallback: Void -> Void) {
        self.onErrorCallback = onErrorCallback
    }

    
//MARK: NSURLSessionDataDelegate
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData){
        if let receivedString = NSString(data: data, encoding: NSUTF8StringEncoding){
            print(receivedString)

            parseEventStream(receivedString)

            dispatch_async(dispatch_get_main_queue()) {

            }
        }
    }

    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
        completionHandler(NSURLSessionResponseDisposition.Allow);

        readyState = EventSourceState.Open
        if(self.onOpenCallback != nil){
            dispatch_async(dispatch_get_main_queue()) {
                self.onOpenCallback!()
            }
        }
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?){
        readyState = EventSourceState.Closed
        if(self.onErrorCallback != nil){
            if(error?.domain != "NSURLErrorDomain" && error?.code != -999){
                dispatch_async(dispatch_get_main_queue()) {
                    self.onErrorCallback!()
                }
            }
        }
    }

//MARK: Helpers
    
    private func parseEventStream(events: NSString) -> [(id: String, event: String, data: String)]{
        var parsedEvents: [(id: String, event: String, data: String)] = Array()

        let events = events.componentsSeparatedByString("\n\n")
        for event in events as [String]{

            if event.isEmpty {
                continue
            }

            if event.hasPrefix(":"){
                continue
            }

            if (event as NSString).containsString("retry:"){
                if let reconnectTime = parseRetryTime(event){
                    self.retryTime = reconnectTime
                }
            }

            parsedEvents.append(parseEvent(event))
        }

        return parsedEvents
    }

    private func parseEvent(eventString: String) -> (id: String, event: String, data: String){
        autoreleasepool {
            var key: NSString?, value: NSString?
            let scanner = NSScanner(string: eventString)
            scanner.scanUpToString(":", intoString: &key)
            scanner.scanString(":",intoString: nil)
            scanner.scanUpToString("\n", intoString: &value)
        }


        return ("id", "event", "data")
    }

    private func parseRetryTime(eventString: String) -> Int?{
        var reconnectTime: Int?
        let separators = NSCharacterSet(charactersInString: ":")
        if let milli = eventString.componentsSeparatedByCharactersInSet(separators).last{
            let milliseconds = trim(milli)

            if let intMiliseconds = milliseconds.toInt() {
                reconnectTime = intMiliseconds
            }
        }
        return reconnectTime
    }

    private func trim(string: String) -> String{
        return string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    }

    class func basicAuth(username: NSString, password: NSString) -> NSString{
        let authString = "\(username):\(password)"
        let authData = authString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64String = authData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)

        return "Basic \(base64String)"
    }
}