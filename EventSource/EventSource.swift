//
//  EventSource.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import Foundation

class EventSource: NSObject{
    
    private let urlSession: NSURLSession
    private let task : NSURLSessionTask
    private let operationQueue = NSOperationQueue()
    private let url: NSURL
    private let lastEventID: NSString?
    
    init(url: NSString, headers: [NSString : NSString]){
        self.url = NSURL(string: url)!
        
        var additionalHeaders = headers
        if let eventID = lastEventID{
            additionalHeaders["Last-Event-Id"] = eventID
        }
        
        additionalHeaders["Content-Type"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = NSTimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = NSTimeInterval(INT_MAX)
        configuration.HTTPAdditionalHeaders = additionalHeaders

        urlSession = NSURLSession(configuration: configuration, delegate: nil, delegateQueue: operationQueue)
        task = urlSession.dataTaskWithURL(self.url){(data, response, error) in
            
        }
        task.resume()
    }
    
    class func basicAuth(username: NSString, password: NSString) -> NSString{
        let authString = "\(username):\(password)"
        let authData = authString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64String = authData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding76CharacterLineLength)
        
        return "Basic \(base64String)"
    }
}