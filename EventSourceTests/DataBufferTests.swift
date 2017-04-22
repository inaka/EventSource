import XCTest

@testable import EventSource

class DataBufferTests: XCTestCase {
    private var subject: DataBuffer!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        subject = DataBuffer()
    }

    func test_injestingAndParsingStrings() {
        let data = "id: 0\nevent: event\ndata: {initial data}\n\nid: 1\nevent: event\ndata: {some data}\n\nid: 2\nevent: event\ndata: {some other data}\n\nid: 3\nevent: event\ndata: {the fourth data}\n\nid: 4\nevent: event\ndata: { almost the last data }\n\nid: 5\nevent: event\ndata: {the last data}\n\n".data(using: String.Encoding.utf8)

        subject.injest(data!)
        let parsedStrings = subject.extractParsedStrings()

        XCTAssertEqual(parsedStrings.count, 6)

        XCTAssertEqual(parsedStrings[0], "id: 0\nevent: event\ndata: {initial data}")
        XCTAssertEqual(parsedStrings[1], "id: 1\nevent: event\ndata: {some data}")
        XCTAssertEqual(parsedStrings[2], "id: 2\nevent: event\ndata: {some other data}")
        XCTAssertEqual(parsedStrings[3], "id: 3\nevent: event\ndata: {the fourth data}")
        XCTAssertEqual(parsedStrings[4], "id: 4\nevent: event\ndata: { almost the last data }")
        XCTAssertEqual(parsedStrings[5], "id: 5\nevent: event\ndata: {the last data}")
    }

    func test_extractingStrings_removesAlreadyParsedStringsFromBuffer() {
        let data = "id: 0\nevent: event\ndata: {initial data}\n\nid: 1\nevent: event\ndata: {some data}\n\nid: 2\nevent: event\ndata: {some other data}\n\nid: 3\nevent: event\ndata: {the fourth data}\n\nid: 4\nevent: event\ndata: { almost the last data }\n\nid: 5\nevent: event\ndata: {the last data}\n\n".data(using: String.Encoding.utf8)

        subject.injest(data!)
        let parsedStrings = subject.extractParsedStrings()

        XCTAssertEqual(parsedStrings.count, 6)

        let moreParsedStrings = subject.extractParsedStrings()
        XCTAssertEqual(moreParsedStrings.count, 0)
    }

    func test_extractingStrings_beforeInjesting_returnsAnEmptyList() {
        let parsedStrings = subject.extractParsedStrings()

        XCTAssertEqual(parsedStrings.count, 0)
    }
}
