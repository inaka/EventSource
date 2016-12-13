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
