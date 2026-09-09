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

    func testEncodingCanonicalizesInvalidConstructibleValues() throws {
        let unsupportedHello = ProtocolMessage.hello(version: 2).encoded
        XCTAssertEqual(unsupportedHello, "HELLO 1")
        XCTAssertEqual(try ProtocolMessage.parse(unsupportedHello), .hello(version: 1))

        let whitespaceCode = ProtocolMessage.error(sequence: 7, code: "BAD CODE").encoded
        XCTAssertEqual(whitespaceCode, "ERROR 7 BAD_CODE")
        XCTAssertEqual(
            try ProtocolMessage.parse(whitespaceCode),
            .error(sequence: 7, code: "BAD_CODE")
        )
    }

    func testEncodingLimitsConstructibleErrorRecordsTo256Bytes() throws {
        let encoded = ProtocolMessage.error(
            sequence: UInt64.max,
            code: String(repeating: "x", count: 300)
        ).encoded

        XCTAssertLessThanOrEqual(encoded.utf8.count, 256)
        XCTAssertNoThrow(try ProtocolMessage.parse(encoded))
    }
}
