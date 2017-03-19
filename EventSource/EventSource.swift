import Foundation

public enum EventSourceState {
    case connecting
    case open
    case closed
}

open class EventSource: NSObject, URLSessionDataDelegate {
    public let url: URL
    fileprivate let receivedString: NSString?
    fileprivate var onOpenCallback: ((Void) -> Void)?
    fileprivate var onErrorCallback: ((NSError?) -> Void)?
    fileprivate var onMessageCallback: ((String, String, String) -> Void)?
    fileprivate var onEventDispatchedCallback: ((SSEMessageEvent) -> ())?
    open internal(set) var readyState: EventSourceState
    open fileprivate(set) var retryTime = 3000
    fileprivate var headers: Dictionary<String, String>
    internal var urlSession: Foundation.URLSession?
    internal var task: URLSessionDataTask?
    fileprivate var operationQueue: OperationQueue
    fileprivate var errorBeforeSetErrorCallBack: NSError?
    internal let receivedDataBuffer: NSMutableData
    fileprivate let uniqueIdentifier: String
    fileprivate let validNewlineCharacters = ["\r\n", "\n", "\r"]

    public private(set) var lastEventID: String?

    var event = Dictionary<String, String>()

    fileprivate let eventProcessor = EventProcessor()

    public init(url: String, headers: [String : String] = [:]) {
        self.url = URL(string: url)!
        self.headers = headers
        self.readyState = EventSourceState.closed
        self.operationQueue = OperationQueue()
        self.receivedString = nil
        self.receivedDataBuffer = NSMutableData()

        var port = ""
        if let optionalPort = self.url.port {
            port = String(optionalPort)
        }
        let relativePath = self.url.relativePath
        let host = self.url.host ?? ""

        self.uniqueIdentifier = "\(self.url.scheme).\(host).\(port).\(relativePath)"

        super.init()

        eventProcessor.onEventDispatched = { event in
            self.lastEventID = event.lastEventId
            if let eventCallback = self.onEventDispatchedCallback {
                eventCallback(event)
            }
            if let messageCallback = self.onMessageCallback {
                messageCallback(event.lastEventId, event.type, event.data)
            }
        }

        eventProcessor.onRetryTimeChanged = { updatedTime in
            self.retryTime = updatedTime
        }

        self.connect()
    }

    //Mark: Connect

    func connect() {
        var additionalHeaders = self.headers
        if let eventID = self.lastEventID {
            additionalHeaders["Last-Event-Id"] = eventID
        }

        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        configuration.httpAdditionalHeaders = additionalHeaders

        self.readyState = EventSourceState.connecting
        self.urlSession = newSession(configuration)
        self.task = urlSession!.dataTask(with: self.url)

        self.resumeSession()
    }

    internal func resumeSession() {
        self.task!.resume()
    }

    internal func newSession(_ configuration: URLSessionConfiguration) -> Foundation.URLSession {
        return Foundation.URLSession(configuration: configuration,
                                     delegate: self,
                                     delegateQueue: operationQueue)
    }

    //Mark: Close

    open func close() {
        self.readyState = EventSourceState.closed
        self.urlSession?.invalidateAndCancel()
    }

    fileprivate func receivedMessageToClose(_ httpResponse: HTTPURLResponse?) -> Bool {
        guard let response = httpResponse  else {
            return false
        }

        if response.statusCode == 204 {
            self.close()
            return true
        }
        return false
    }

    //Mark: EventListeners

    open func onOpen(_ onOpenCallback: @escaping ((Void) -> Void)) {
        self.onOpenCallback = onOpenCallback
    }

    open func onError(_ onErrorCallback: @escaping ((NSError?) -> Void)) {
        self.onErrorCallback = onErrorCallback

        if let errorBeforeSet = self.errorBeforeSetErrorCallBack {
            self.onErrorCallback!(errorBeforeSet)
            self.errorBeforeSetErrorCallBack = nil
        }
    }

    public func onMessage(_ onMessageCallback: @escaping ((String, String, String) -> Void)) {
            self.onMessageCallback = onMessageCallback
    }

    open func onEventDispatched(_ onEventDispatched: @escaping ((SSEMessageEvent) -> Void)) {
        onEventDispatchedCallback = onEventDispatched
    }

    open func addEventListener(_ event: String, handler: @escaping ((SSEMessageEvent) -> Void)) {
        eventProcessor.eventListeners[event] = handler
    }

    open func removeEventListener(_ event: String) -> Void {
        eventProcessor.eventListeners.removeValue(forKey: event)
    }

    open func events() -> Array<String> {
        return Array(eventProcessor.eventListeners.keys)
    }

    //MARK: URLSessionDataDelegate

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if self.receivedMessageToClose(dataTask.response as? HTTPURLResponse) {
            return
        }

        if self.readyState != EventSourceState.open {
            return
        }

        self.receivedDataBuffer.append(data)
        let eventStream = extractStringsFromDataBuffer()
        eventProcessor.processSSEStream(eventStream)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)

        if self.receivedMessageToClose(dataTask.response as? HTTPURLResponse) {
            return
        }

        self.readyState = EventSourceState.open
        if self.onOpenCallback != nil {
            DispatchQueue.main.async {
                self.onOpenCallback!()
            }
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.readyState = EventSourceState.closed

        if self.receivedMessageToClose(task.response as? HTTPURLResponse) {
            return
        }

        if error == nil || (error as! NSError).code != -999 {
            let nanoseconds = Double(self.retryTime) / 1000.0 * Double(NSEC_PER_SEC)
            let delayTime = DispatchTime.now() + Double(Int64(nanoseconds)) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                self.connect()
            }
        }

        DispatchQueue.main.async {
            if let errorCallback = self.onErrorCallback {
                errorCallback(error as NSError?)
            } else {
                self.errorBeforeSetErrorCallBack = error as? NSError
            }
        }
    }

    //MARK: Helpers

    fileprivate func extractStringsFromDataBuffer() -> [String] {
        var events = [String]()

        // Find first occurrence of delimiter
        var searchRange =  NSRange(location: 0, length: receivedDataBuffer.length)
        while let foundRange = searchForEventInRange(searchRange) {
            // Append event
            if foundRange.location > searchRange.location {
                let dataChunk = receivedDataBuffer.subdata(
                    with: NSRange(location: searchRange.location, length: foundRange.location - searchRange.location)
                )
                events.append(NSString(data: dataChunk, encoding: String.Encoding.utf8.rawValue) as! String)
            }
            // Search for next occurrence of delimiter
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = receivedDataBuffer.length - searchRange.location
        }

        // Remove the found events from the buffer
        self.receivedDataBuffer.replaceBytes(in: NSRange(location: 0, length: searchRange.location), withBytes: nil, length: 0)

        return events
    }

    fileprivate func searchForEventInRange(_ searchRange: NSRange) -> NSRange? {
        let delimiters = validNewlineCharacters.map { "\($0)\($0)".data(using: String.Encoding.utf8)! }

        for delimiter in delimiters {
            let foundRange = receivedDataBuffer.range(of: delimiter,
                                                      options: NSData.SearchOptions(),
                                                      in: searchRange)
            if foundRange.location != NSNotFound {
                return foundRange
            }
        }

        return nil
    }
}
