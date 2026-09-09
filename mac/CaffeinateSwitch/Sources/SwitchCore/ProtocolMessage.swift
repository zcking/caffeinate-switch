public enum SwitchState: Equatable {
    case on
    case off
}

public enum ProtocolMessage: Equatable {
    case hello(version: Int)
    case state(sequence: UInt64, state: SwitchState)
    case ping(sequence: UInt64)
    case ack(sequence: UInt64, state: SwitchState)
    case error(sequence: UInt64, code: String)

    public enum ParseError: Error, Equatable {
        case lineTooLong
        case malformedRecord
        case unsupportedVersion
    }

    public static func parse(_ line: String) throws -> ProtocolMessage {
        guard line.utf8.count <= 256 else {
            throw ParseError.lineTooLong
        }

        guard !line.contains("\n"), !line.contains("\r") else {
            throw ParseError.malformedRecord
        }

        let fields = line.split(separator: " ", omittingEmptySubsequences: false)
        guard !fields.contains(where: { $0.isEmpty }) else {
            throw ParseError.malformedRecord
        }

        guard let record = fields.first else {
            throw ParseError.malformedRecord
        }

        switch record {
        case "HELLO":
            guard fields.count == 2 else {
                throw ParseError.malformedRecord
            }
            guard fields[1] == "1" else {
                throw ParseError.unsupportedVersion
            }
            return .hello(version: 1)
        case "STATE":
            guard fields.count == 3 else { throw ParseError.malformedRecord }
            return .state(
                sequence: try parseSequence(String(fields[1])),
                state: try parseState(String(fields[2]))
            )
        case "PING":
            guard fields.count == 2 else { throw ParseError.malformedRecord }
            return .ping(sequence: try parseSequence(String(fields[1])))
        case "ACK":
            guard fields.count == 3 else { throw ParseError.malformedRecord }
            return .ack(
                sequence: try parseSequence(String(fields[1])),
                state: try parseState(String(fields[2]))
            )
        case "ERROR":
            guard fields.count == 3 else { throw ParseError.malformedRecord }
            let code = String(fields[2])
            guard !code.isEmpty, !code.contains(where: { $0.isWhitespace }) else {
                throw ParseError.malformedRecord
            }
            return .error(sequence: try parseSequence(String(fields[1])), code: code)
        default:
            throw ParseError.malformedRecord
        }
    }

    public var encoded: String {
        switch self {
        case .hello:
            return "HELLO 1"
        case .state(let sequence, let state):
            return "STATE \(sequence) \(state.encoded)"
        case .ping(let sequence):
            return "PING \(sequence)"
        case .ack(let sequence, let state):
            return "ACK \(sequence) \(state.encoded)"
        case .error(let sequence, let code):
            let prefix = "ERROR \(sequence) "
            return prefix + Self.safeErrorCode(code, maximumByteCount: 256 - prefix.utf8.count)
        }
    }

    private static func safeErrorCode(_ code: String, maximumByteCount: Int) -> String {
        let normalized = code.map { $0.isWhitespace ? "_" : String($0) }.joined()
        let nonemptyCode = normalized.isEmpty ? "INVALID" : normalized
        var result = ""

        for character in nonemptyCode {
            let characterString = String(character)
            guard result.utf8.count + characterString.utf8.count <= maximumByteCount else {
                break
            }
            result.append(character)
        }

        return result.isEmpty ? "INVALID" : result
    }

    private static func parseSequence(_ value: String) throws -> UInt64 {
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }), let sequence = UInt64(value) else {
            throw ParseError.malformedRecord
        }
        return sequence
    }

    private static func parseState(_ value: String) throws -> SwitchState {
        switch value {
        case "ON": return .on
        case "OFF": return .off
        default: throw ParseError.malformedRecord
        }
    }
}

private extension SwitchState {
    var encoded: String {
        switch self {
        case .on: return "ON"
        case .off: return "OFF"
        }
    }
}
