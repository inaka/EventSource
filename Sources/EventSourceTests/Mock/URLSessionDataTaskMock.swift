//
//  URLSessionDataTaskMock.swift
//  EventSourceTests
//
//  Created by Andres on 25/08/2019.
//  Copyright © 2019 Andres. All rights reserved.
//

import Foundation

class URLSessionDataTaskMock: URLSessionDataTask {

    let mockResponse: URLResponse?

    init(response: URLResponse?) {
        mockResponse = response
        super.init()
    }

    override var response: URLResponse? {
        return mockResponse
    }

}
