//
//  EventSourceSessionDelegate.swift
//  EventSource
//
//  Created by Andres on 21/08/2019.
//  Copyright © 2019 inaka. All rights reserved.
//

import Foundation

final class EventSourceSessionDelegate: NSObject, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//        if self.receivedMessageToClose(dataTask.response as? HTTPURLResponse) {
//            return
//        }
//
//        if self.readyState != EventSourceState.open {
//            return
//        }
//
//        let events = eventStreamParser.append(data: data)
//        parseEventStream(events)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        completionHandler(URLSession.ResponseDisposition.allow)
//
//        if self.receivedMessageToClose(dataTask.response as? HTTPURLResponse) {
//            return
//        }
//
//        self.readyState = EventSourceState.open
//        if self.onOpenCallback != nil {
//            DispatchQueue.main.async {
//                self.onOpenCallback!()
//            }
//        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        self.readyState = EventSourceState.closed
//
//        if self.receivedMessageToClose(task.response as? HTTPURLResponse) {
//            return
//        }
//
//        guard let urlResponse = task.response as? HTTPURLResponse else {
//            return
//        }
//
//        if !hasHttpError(code: urlResponse.statusCode) && (error == nil || (error! as NSError).code != -999) {
//            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(retryTime)) {
//                self.connect()
//            }
//        }
//
//        DispatchQueue.main.async {
//            var theError: NSError? = error as NSError?
//
//            if self.hasHttpError(code: urlResponse.statusCode) {
//                theError = NSError(
//                    domain: "com.inaka.eventSource.error",
//                    code: -1,
//                    userInfo: ["message": "HTTP Status Code: \(urlResponse.statusCode)"]
//                )
//                self.close()
//            }
//
//            if let errorCallback = self.onErrorCallback {
//                errorCallback(theError)
//            } else {
//                self.errorBeforeSetErrorCallBack = theError
//            }
//        }
    }

}
