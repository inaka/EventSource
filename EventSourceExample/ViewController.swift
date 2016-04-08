//
//  ViewController.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet private weak var status: UILabel!
    @IBOutlet private weak var dataLabel: UILabel!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var idLabel: UILabel!
    @IBOutlet private weak var squareConstraint: NSLayoutConstraint!
    var eventSource: EventSource?

    override func viewDidLoad() {
        super.viewDidLoad()
		
        let server = "http://127.0.0.1:8080/sse"
        let username = "fe8b0af5-1b50-467d-ac0b-b29d2d30136b"
        let password = "ae10ff39ca41dgf0a8"

        let basicAuthAuthorization = EventSource.basicAuth(username, password: password)

        self.eventSource = EventSource(url: server, headers: ["Authorization" : basicAuthAuthorization])
        
        self.eventSource?.onOpen {
            self.status.backgroundColor = UIColor(red: 166/255, green: 226/255, blue: 46/255, alpha: 1)
            self.status.text = "CONNECTED"
        }
        
        self.eventSource?.onError { (error) in
            self.status.backgroundColor = UIColor(red: 249/255, green: 38/255, blue: 114/255, alpha: 1)
            self.status.text = "DISCONNECTED"
        }

        self.eventSource?.onMessage { (id, event, data) in
            self.updateLabels(id, event: event, data: data)
        }
        
        self.eventSource?.addEventListener("user-connected") { (id, event, data) in
            self.updateLabels(id, event: event, data: data)
        }
        
//        eventSource.close()
    }
    
    func updateLabels(id: String?, event: String?, data: String?) -> Void{
        self.idLabel.text = ""
        self.idLabel.text = ""
        self.idLabel.text = ""
        
        if let eventID = id {
            self.idLabel.text = eventID
        }
        
        if let eventName = event {
            self.nameLabel.text = eventName
        }
        
        if let eventData = data {
            self.dataLabel.text = eventData
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        let finalPosition = self.view.frame.size.width - 50
        
        self.squareConstraint.constant = 0
        self.view.layoutIfNeeded()
        
        UIView.animateKeyframesWithDuration(2, delay: 0, options: [UIViewKeyframeAnimationOptions.Repeat, UIViewKeyframeAnimationOptions.Autoreverse] , animations: { () in
            self.squareConstraint.constant = finalPosition
            self.view.layoutIfNeeded()            
        }, completion: nil)
    }
}

