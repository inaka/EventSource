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

            dispatch_async(dispatch_get_main_queue()) {
                print(NSThread.isMainThread())
            }
        }
    }

    func URLSession(session: NSURLSession!, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: ((NSURLSessionResponseDisposition) -> Void)) {
        completionHandler(NSURLSessionResponseDisposition.Allow);
        
        readyState = EventSourceState.Open
        if(self.onOpenCallback != nil){
           self.onOpenCallback!()
        }
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?){
        readyState = EventSourceState.Closed
        if(self.onErrorCallback != nil){
            if(error?.domain != "NSURLErrorDomain" && error?.code != -999){
                self.onErrorCallback!()
            }
        }
    }

//MARK: Helpers
    
    class func basicAuth(username: NSString, password: NSString) -> NSString{
        let authString = "\(username):\(password)"
        let authData = authString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64String = authData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)
        
        return "Basic \(base64String)"
    }
}