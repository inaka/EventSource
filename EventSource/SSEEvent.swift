public class SSEEvent {
    public var id: String?
    public var event: String?
    public var data: String?

    init(id: String?, event: String?, data: String?) {
        self.id = id
        self.event = event
        self.data = data
    }
 }

extension SSEEvent: Equatable {}

public func ==(lhs: SSEEvent, rhs: SSEEvent) -> Bool {
    let idsEqual = (lhs.id == rhs.id)
    let eventsEqual = (lhs.event == rhs.event)
    let dataEqual = (lhs.data == rhs.data)

    return idsEqual && eventsEqual && dataEqual
}
