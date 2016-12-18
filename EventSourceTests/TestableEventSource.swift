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

	func callDidCompleteWithError(_ error: String) {
		let errorToReturn = NSError(domain: "Mock", code: 0, userInfo: ["mock":error])

		let delegate = self as URLSessionDataDelegate
		delegate.urlSession!(self.urlSession!, task: self.task!, didCompleteWithError: errorToReturn)

	}

	override internal func resumeSession() {
		self.readyState = EventSourceState.open
	}
}
