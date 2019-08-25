//
//  ViewController.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import UIKit
class ViewController: UIViewController {

    @IBOutlet fileprivate weak var status: UILabel!
    @IBOutlet fileprivate weak var dataLabel: UILabel!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet fileprivate weak var idLabel: UILabel!
    @IBOutlet fileprivate weak var squareConstraint: NSLayoutConstraint!
    var eventSource: EventSource?

    override func viewDidLoad() {
        super.viewDidLoad()

        let serverURL = URL(string: "http://127.0.0.1:8080/sse")!
        eventSource = EventSource(url: serverURL, headers: ["Authorization": "Bearer basic-auth-token"])

        eventSource?.onOpen {
            self.status.backgroundColor = UIColor(red: 166/255, green: 226/255, blue: 46/255, alpha: 1)
            self.status.text = "CONNECTED"
        }

        eventSource?.onComplete { _, _, _ in
            self.status.backgroundColor = UIColor(red: 249/255, green: 38/255, blue: 114/255, alpha: 1)
            self.status.text = "DISCONNECTED"
        }

        eventSource?.onMessage { (id, event, data) in
            self.updateLabels(id, event: event, data: data)
        }

        eventSource?.addEventListener("user-connected") { (id, event, data) in
            self.updateLabels(id, event: event, data: data)
        }
    }

    func updateLabels(_ id: String?, event: String?, data: String?) {
        idLabel.text = id
        nameLabel.text = event
        dataLabel.text = data
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let finalPosition = view.frame.size.width - 50

        squareConstraint.constant = 0
        view.layoutIfNeeded()

        let animationOptions: UIView.KeyframeAnimationOptions = [
            UIView.KeyframeAnimationOptions.repeat, UIView.KeyframeAnimationOptions.autoreverse
        ]

        UIView.animateKeyframes(withDuration: 2,
                                delay: 0,
                                options: animationOptions,
                                animations: { () in
            self.squareConstraint.constant = finalPosition
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func disconnect(_ sender: Any) {
        eventSource?.disconnect()
    }

    @IBAction func connect(_ sender: Any) {
        eventSource?.connect()
    }
}
