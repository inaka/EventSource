//
//  MockNSURLSessionDataTask.swift
//  EventSource
//
//  Created by Andres Canal on 6/21/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit

class MockNSURLSessionDataTask: NSURLSessionDataTask {

	let fakeResponse: NSHTTPURLResponse

	init(response: NSHTTPURLResponse) {
		self.fakeResponse = response
	}

	override var response: NSHTTPURLResponse {
		get {
			return self.fakeResponse
		}
	}
}
