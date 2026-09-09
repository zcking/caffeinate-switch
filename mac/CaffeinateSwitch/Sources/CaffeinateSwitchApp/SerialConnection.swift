import Darwin
import Dispatch
import Foundation

enum SerialConnectionError: Error {
    case invalidPath
    case invalidRecord
    case disconnected
}

struct SerialLineFramer {
    private static let maximumRecordBytes = 256
    private var record: [UInt8] = []
    private var discardingOversizedRecord = false

    mutating func receive<S: Sequence>(_ bytes: S) -> [String] where S.Element == UInt8 {
        var lines: [String] = []

        for byte in bytes {
            if byte == UInt8(ascii: "\n") {
                if !discardingOversizedRecord,
                   let line = String(bytes: record, encoding: .utf8) {
                    lines.append(line)
                }
                record.removeAll(keepingCapacity: true)
                discardingOversizedRecord = false
            } else if !discardingOversizedRecord {
                if record.count < Self.maximumRecordBytes {
                    record.append(byte)
                } else {
                    record.removeAll(keepingCapacity: true)
                    discardingOversizedRecord = true
                }
            }
        }

        return lines
    }
}

final class SerialConnection {
    private let ioQueue = DispatchQueue(label: "com.zachking.CaffeinateSwitch.serial")
    private let onLine: (String) -> Void
    private let onDisconnect: () -> Void
    private var descriptor: Int32
    private var readSource: DispatchSourceRead?
    private var framer = SerialLineFramer()
    private var didNotifyDisconnect = false

    init(
        path: String,
        onLine: @escaping (String) -> Void,
        onDisconnect: @escaping () -> Void
    ) throws {
        guard path.hasPrefix("/dev/cu.") else {
            throw SerialConnectionError.invalidPath
        }

        let openedDescriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard openedDescriptor >= 0 else {
            throw Self.posixError(path: path)
        }

        do {
            try Self.configure(openedDescriptor)
        } catch {
            Darwin.close(openedDescriptor)
            throw error
        }

        descriptor = openedDescriptor
        self.onLine = onLine
        self.onDisconnect = onDisconnect

        let source = DispatchSource.makeReadSource(
            fileDescriptor: openedDescriptor,
            queue: ioQueue
        )
        source.setEventHandler { [weak self] in self?.readAvailableBytes() }
        readSource = source
        source.resume()
    }

    func write(_ line: String) throws {
        guard !line.contains("\n"), !line.contains("\r"), line.utf8.count <= 256 else {
            throw SerialConnectionError.invalidRecord
        }
        let data = Data((line + "\n").utf8)

        try ioQueue.sync {
            guard descriptor >= 0 else { throw SerialConnectionError.disconnected }

            do {
                try data.withUnsafeBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.baseAddress else { return }
                    var written = 0
                    while written < rawBuffer.count {
                        let result = Darwin.write(
                            descriptor,
                            baseAddress.advanced(by: written),
                            rawBuffer.count - written
                        )
                        if result > 0 {
                            written += result
                        } else if result < 0, errno == EINTR {
                            continue
                        } else {
                            throw Self.posixError()
                        }
                    }
                }
            } catch {
                disconnectLocked(notify: true)
                throw error
            }
        }
    }

    func close() {
        ioQueue.sync { disconnectLocked(notify: false) }
    }

    private func readAvailableBytes() {
        guard descriptor >= 0 else { return }
        var bytes = [UInt8](repeating: 0, count: 512)

        while true {
            let count = Darwin.read(descriptor, &bytes, bytes.count)
            if count > 0 {
                for line in framer.receive(bytes.prefix(count)) {
                    DispatchQueue.main.async { [onLine] in onLine(line) }
                }
            } else if count == 0 {
                disconnectLocked(notify: true)
                return
            } else if errno == EINTR {
                continue
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                return
            } else {
                disconnectLocked(notify: true)
                return
            }
        }
    }

    private func disconnectLocked(notify: Bool) {
        readSource?.cancel()
        readSource = nil
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }

        if notify, !didNotifyDisconnect {
            didNotifyDisconnect = true
            DispatchQueue.main.async { [onDisconnect] in onDisconnect() }
        }
    }

    private static func configure(_ descriptor: Int32) throws {
        var settings = termios()
        guard tcgetattr(descriptor, &settings) == 0 else { throw posixError() }

        cfmakeraw(&settings)
        settings.c_cflag &= ~tcflag_t(CSIZE | PARENB | CSTOPB | CRTSCTS)
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD | CS8)
        settings.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        guard cfsetspeed(&settings, speed_t(B115200)) == 0 else { throw posixError() }
        guard tcsetattr(descriptor, TCSANOW, &settings) == 0 else { throw posixError() }
        guard tcflush(descriptor, TCIOFLUSH) == 0 else { throw posixError() }
    }

    private static func posixError(path: String? = nil) -> NSError {
        var userInfo: [String: Any] = [:]
        if let path { userInfo[NSFilePathErrorKey] = path }
        return NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: userInfo)
    }

    deinit {
        close()
    }
}
