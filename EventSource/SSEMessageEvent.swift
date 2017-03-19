public struct SSEMessageEvent {
    public var lastEventId: String
    public var type: String
    public var data: String

    public init(lastEventId: String, type: String, data: String) {
        self.lastEventId = lastEventId
        self.type = type
        self.data = data
    }
 }

extension SSEMessageEvent: Equatable {}

public func ==(lhs: SSEMessageEvent, rhs: SSEMessageEvent) -> Bool {
    let idsEqual = (lhs.lastEventId == rhs.lastEventId)
    let typesEqual = (lhs.type == rhs.type)
    let dataEqual = (lhs.data == rhs.data)

    return idsEqual && typesEqual && dataEqual
}
