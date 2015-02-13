//
//  ViewController.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let basicAuthAuthorization = EventSource.basicAuth("sarasa", password: "sarasa")
        var eventSource = EventSource(url: "http://test.com", headers: ["Authorization" : basicAuthAuthorization])
    }
}

