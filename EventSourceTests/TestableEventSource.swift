//
//  TestableEventSource.swift
//  EventSource
//
//  Created by Andres Canal on 6/21/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit

class TestableEventSource: EventSource {

	func callDidReceiveResponse() {
		let delegate = self as NSURLSessionDataDelegate

		delegate.URLSession!(self.urlSession!, dataTask: self.task!, didReceiveResponse: NSURLResponse()) { (NSURLSessionResponseDisposition) -> Void in

		}
	}

	func callDidReceiveDataWithResponse(dataTask: NSURLSessionDataTask) {
		let delegate = self as NSURLSessionDataDelegate
		delegate.URLSession!(self.urlSession!, dataTask: dataTask, didReceiveData: "".dataUsingEncoding(NSUTF8StringEncoding)!)
	}

	func callDidReceiveData(data: NSData) {
		let delegate = self as NSURLSessionDataDelegate
		delegate.URLSession!(self.urlSession!, dataTask: self.task!, didReceiveData: data)
	}

	func callDidCompleteWithError(error: String) {
		let errorToReturn = NSError(domain: "Mock", code: 0, userInfo: ["mock":error])

		let delegate = self as NSURLSessionDataDelegate
		delegate.URLSession!(self.urlSession!, task: self.task!, didCompleteWithError: errorToReturn)

	}

	override internal func resumeSession(){
		self.readyState = EventSourceState.Open
	}
}