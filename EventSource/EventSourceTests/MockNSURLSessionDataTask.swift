//
//  MockNSURLSessionDataTask.swift
//  EventSource
//
//  Created by Andres Canal on 6/21/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

import UIKit

class MockNSURLSessionDataTask: URLSessionDataTask {

	let fakeResponse: HTTPURLResponse

	init(response: HTTPURLResponse) {
		self.fakeResponse = response
	}

	override var response: HTTPURLResponse {
		get {
			return self.fakeResponse
		}
	}
}
