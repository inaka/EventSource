import Foundation

class EventProcessor {
    var onEventDispatched: ((SSEMessageEvent) -> Void)?
    var eventListeners: [String: ((SSEMessageEvent) -> Void)] = [:]
    var eventListenersJsVersion: [String: ((String, String, String) -> Void)] = [:]
    var onRetryTimeChanged: ((Int) -> Void)?

    private var inputInProcess: String = ""
    private var lastEventId = ""
    private var dataBuffer = ""
    private var eventNameBuffer = ""

    private let validNewlineCharacters = ["\r\n", "\n", "\r"]

    func processSSEStream(_ stream: [String]) {
        for item in stream {
            processSSEItem(item)
        }

        if inputInProcess != "" {
            processLine(inputInProcess)
        }

        dispatch()
    }

    func processSSEItem(_ input: String) {
        inputInProcess += input
        let lines = inputInProcess.components(separatedBy: CharacterSet.newlines) as [String]
        let lastLineIndex = lines.count - 1
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespaces)
            if trimmedLine == "" {
                dispatch()
                continue
            }


            if index != lastLineIndex {
                processLine(line)
            }
        }

        if let lastLine = lines.last {
            if lastLine != "" {
                inputInProcess = lastLine
            } else {
                inputInProcess = ""
            }
        }
    }

    private func processLine(_ line: String) {
        let pair = parseFieldValuePair(line)
        guard let field = pair.field else { return }
        guard let value = pair.value else { return }

        if field == "event" {
            eventNameBuffer = value
        } else if field == "data" {
            dataBuffer += value
            dataBuffer += "\n"
        } else if field == "id" {
            lastEventId = value
        } else if field == "retry" {
            processRetryFieldValue(value)
        }
    }

    private func processRetryFieldValue(_ value: String) {
        if let valueAsInteger = Int(value) {
            if let retryUpdateCallback = onRetryTimeChanged {
                retryUpdateCallback(valueAsInteger)
            }
        }
    }

    private func dispatch() {
        guard let dispatchCallback = onEventDispatched else { return }

        if dataBuffer == "" {
            eventNameBuffer = ""
            return
        }

        if dataBuffer.characters.last == "\n" {
            dataBuffer = dataBuffer.substring(to: dataBuffer.index(before: dataBuffer.endIndex))
        }

        var type = "message"
        if eventNameBuffer != "" {
            type = eventNameBuffer
        }

        let event = SSEMessageEvent(
            lastEventId: lastEventId,
            type: type,
            data: dataBuffer
        )

        dataBuffer = ""
        eventNameBuffer = ""

        dispatchCallback(event)
        if let specificEventHandler = eventListeners[event.type] {
            specificEventHandler(event)
        }
        if let specificEventHandlerJsVersion = eventListenersJsVersion[event.type] {
            specificEventHandlerJsVersion(event.lastEventId, event.type, event.data)
        }
    }

    private func parseFieldValuePair(_ line: String) -> (field: String?, value: String?) {
        var nsField: NSString?, nsValue: NSString?
        let scanner = Scanner(string: line)
        scanner.charactersToBeSkipped = nil
        scanner.scanUpTo(":", into: &nsField)
        scanner.scanString(":", into: nil)

        for newline in validNewlineCharacters {
            if scanner.scanUpTo(newline, into: &nsValue) {
                break
            }
        }

        if nsField == nil || nsValue == nil { return (nil, nil) }

        let nativeField = String(describing: nsField!)
        var nativeValue = String(describing: nsValue!)
        if nativeValue.hasPrefix(" ") {
            nativeValue.remove(at: nativeValue.startIndex)
        }

        return (nativeField, nativeValue)
    }
}
