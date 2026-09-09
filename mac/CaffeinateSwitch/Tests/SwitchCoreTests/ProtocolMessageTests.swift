import XCTest
@testable import SwitchCore

final class ProtocolMessageTests: XCTestCase {
    func testRoundTripsEveryMessage() throws {
        let messages: [ProtocolMessage] = [
            .hello(version: 1), .state(sequence: 7, state: .on),
            .ping(sequence: 7), .ack(sequence: 7, state: .off),
            .error(sequence: 7, code: "CHILD_EXIT")
        ]
        for message in messages {
            XCTAssertEqual(try ProtocolMessage.parse(message.encoded), message)
        }
    }

    func testRejectsMalformedInput() {
        XCTAssertThrowsError(try ProtocolMessage.parse("STATE nope ON"))
        XCTAssertThrowsError(try ProtocolMessage.parse(String(repeating: "x", count: 257)))
    }

    func testRejectsUnsupportedVersionsAndInvalidSequenceValues() {
        XCTAssertThrowsError(try ProtocolMessage.parse("HELLO 2"))
        XCTAssertThrowsError(try ProtocolMessage.parse("PING -1"))
        XCTAssertThrowsError(try ProtocolMessage.parse("ACK +1 ON"))
    }

    func testRejectsWhitespaceInErrorCodeAndInvalidRecordShapes() {
        XCTAssertThrowsError(try ProtocolMessage.parse("ERROR 7 CHILD EXIT"))
        XCTAssertThrowsError(try ProtocolMessage.parse("ERROR 7 CHILD\tEXIT"))
        XCTAssertThrowsError(try ProtocolMessage.parse("STATE 7 ON extra"))
        XCTAssertThrowsError(try ProtocolMessage.parse("PING 7\n"))
    }
}
