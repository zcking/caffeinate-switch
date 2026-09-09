import Foundation
import SwitchCore

final class CaffeinateProcess: ChildProcessManaging {
    private let executableURL: URL
    private let lock = NSLock()
    private var process: Process?
    private var expectedTermination: ObjectIdentifier?

    var onUnexpectedTermination: () -> Void = {}

    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/caffeinate")) {
        self.executableURL = executableURL
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true
    }

    var processIdentifier: pid_t? {
        lock.lock()
        defer { lock.unlock() }
        guard let process, process.isRunning else { return nil }
        return process.processIdentifier
    }

    func start() throws {
        lock.lock()
        if process?.isRunning == true {
            lock.unlock()
            return
        }

        let child = Process()
        child.executableURL = executableURL
        child.arguments = []
        child.terminationHandler = { [weak self, weak child] _ in
            guard let child else { return }
            self?.didTerminate(child)
        }
        process = child
        expectedTermination = nil
        lock.unlock()

        do {
            try child.run()
        } catch {
            lock.lock()
            if process === child {
                process = nil
            }
            child.terminationHandler = nil
            lock.unlock()
            throw error
        }
    }

    func stop() {
        lock.lock()
        guard let child = process else {
            lock.unlock()
            return
        }
        expectedTermination = ObjectIdentifier(child)
        lock.unlock()

        if child.isRunning {
            child.terminate()
        }
        child.waitUntilExit()

        lock.lock()
        if process === child {
            process = nil
        }
        expectedTermination = nil
        child.terminationHandler = nil
        lock.unlock()
    }

    private func didTerminate(_ child: Process) {
        lock.lock()
        let wasOwned = process === child
        let wasExpected = expectedTermination == ObjectIdentifier(child)
        if wasOwned {
            process = nil
        }
        let callback = onUnexpectedTermination
        lock.unlock()

        guard wasOwned, !wasExpected else { return }
        DispatchQueue.main.async(execute: callback)
    }

    deinit {
        stop()
    }
}
