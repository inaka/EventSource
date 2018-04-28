//
//  TestableEventSource.swift
//  EventSource
//
//  Created by Andres Canal on 6/21/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit
@testable import EventSource

class TestableEventSource: EventSource {

	func callDidReceiveResponse() {
		let delegate = self as URLSessionDataDelegate

		delegate.urlSession!(self.urlSession!, dataTask: self.task!, didReceive: URLResponse()) { (NSURLSessionResponseDisposition) -> Void in

		}
	}

	func callDidReceiveDataWithResponse(_ dataTask: URLSessionDataTask) {
		let delegate = self as URLSessionDataDelegate
		delegate.urlSession!(self.urlSession!, dataTask: dataTask, didReceive: "".data(using: String.Encoding.utf8)!)
	}

	func callDidReceiveData(_ data: Data) {
		let delegate = self as URLSessionDataDelegate
		delegate.urlSession!(self.urlSession!, dataTask: self.task!, didReceive: data)
	}

    func callDidCompleteWithError(dataTask: URLSessionDataTask, error: NSError? = nil) {
		let delegate = self as URLSessionDataDelegate
		delegate.urlSession!(self.urlSession!, task: dataTask, didCompleteWithError: error)
	}

	override internal func resumeSession() {
		self.readyState = EventSourceState.open
	}
}
