import Foundation

class DataBuffer {
    var receivedData = Data()
    var parsedStrings = [String]()

    func injest(_ data: Data) {
        receivedData.append(data)
        parsedStrings.append(contentsOf: extractStringsFromDataBuffer())
    }

    func extractParsedStrings() -> [String] {
        let stringsToSend = parsedStrings
        parsedStrings.removeAll()
        return stringsToSend
    }

    private func extractStringsFromDataBuffer() -> [String] {
        var events = [String]()

        var searchRange =  Range(uncheckedBounds: (lower: 0, upper: receivedData.count))
        while let foundRange = searchForEventInRange(searchRange) {
            if foundRange.lowerBound > searchRange.lowerBound {
                let dataChunk = receivedData.subdata(
                    in: Range(uncheckedBounds: (lower: searchRange.lowerBound, upper: foundRange.lowerBound))
                )

                events.append(String(data: dataChunk, encoding: String.Encoding.utf8)!)
            }

            searchRange = Range(uncheckedBounds: (lower: foundRange.upperBound, upper: receivedData.count))
        }

        receivedData.removeSubrange(Range(uncheckedBounds: (lower: 0, upper: searchRange.lowerBound)))

        return events
    }

    private func searchForEventInRange(_ searchRange: Range<Data.Index>) -> Range<Data.Index>? {
        let validNewlineCharacters = ["\r\n", "\n", "\r"]
        let delimiters = validNewlineCharacters.map { "\($0)\($0)".data(using: String.Encoding.utf8)! }

        for delimiter in delimiters {
            let foundRange = receivedData.range(of: delimiter,
                                                options: Data.SearchOptions(),
                                                in: searchRange)
            if foundRange != nil {
                return foundRange
            }
        }

        return nil
    }
}
