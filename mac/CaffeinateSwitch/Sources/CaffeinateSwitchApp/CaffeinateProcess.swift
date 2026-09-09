import Foundation
import SwitchCore

final class CaffeinateProcess: ChildProcessManaging {
    private let executableURL: URL
    private let deliverOnMain: (@escaping () -> Void) -> Void
    private let lock = NSLock()
    private var process: Process?
    private var latestGeneration: UInt64 = 0
    private var processGeneration: UInt64?
    private var expectedTerminationGenerations: Set<UInt64> = []

    var onUnexpectedTermination: () -> Void = {}
    /// Runs on the main thread after a process transition is verified.
    var onStateChange: (Bool) -> Void = { _ in }

    init(
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/caffeinate"),
        deliverOnMain: @escaping (@escaping () -> Void) -> Void = CaffeinateProcess.defaultMainDelivery
    ) {
        self.executableURL = executableURL
        self.deliverOnMain = deliverOnMain
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
        latestGeneration &+= 1
        let generation = latestGeneration
        child.executableURL = executableURL
        child.arguments = []
        child.terminationHandler = { [weak self, weak child] _ in
            guard let child else { return }
            self?.didTerminate(child, generation: generation)
        }
        process = child
        processGeneration = generation
        lock.unlock()

        do {
            try child.run()
            if child.isRunning {
                notifyStateChange(true, for: child, generation: generation)
            }
        } catch {
            lock.lock()
            if process === child, processGeneration == generation {
                process = nil
                processGeneration = nil
            }
            child.terminationHandler = nil
            lock.unlock()
            notifyStateChange(false, for: nil, generation: generation)
            throw error
        }
    }

    func stop() {
        lock.lock()
        guard let child = process, let generation = processGeneration else {
            lock.unlock()
            return
        }
        expectedTerminationGenerations.insert(generation)
        lock.unlock()

        if child.isRunning {
            child.terminate()
        }
        child.waitUntilExit()

        lock.lock()
        if process === child, processGeneration == generation {
            process = nil
            processGeneration = nil
        }
        lock.unlock()
        notifyStateChange(false, for: nil, generation: generation)
    }

    private func didTerminate(_ child: Process, generation: UInt64) {
        lock.lock()
        let wasExpected = expectedTerminationGenerations.remove(generation) != nil
        if process === child, processGeneration == generation {
            process = nil
            processGeneration = nil
        }
        lock.unlock()

        guard !wasExpected else { return }
        deliverOnMain { [weak self] in
            self?.publishUnexpectedTermination(generation: generation)
        }
    }

    private func publishUnexpectedTermination(generation: UInt64) {
        lock.lock()
        let isCurrentExit = latestGeneration == generation
            && processGeneration == nil
            && process == nil
        let stateChangeCallback = onStateChange
        lock.unlock()

        guard isCurrentExit else { return }
        stateChangeCallback(false)

        // The state observer is allowed to initiate a replacement. Recheck
        // after it runs so an old exit can never be published for that child.
        lock.lock()
        let stillCurrentExit = latestGeneration == generation
            && processGeneration == nil
            && process == nil
        let unexpectedTerminationCallback = onUnexpectedTermination
        lock.unlock()

        if stillCurrentExit {
            unexpectedTerminationCallback()
        }
    }

    private func notifyStateChange(
        _ isRunning: Bool,
        for child: Process?,
        generation: UInt64
    ) {
        deliverOnMain { [weak self, weak child] in
            self?.publishStateChange(isRunning, for: child, generation: generation)
        }
    }

    private func publishStateChange(
        _ isRunning: Bool,
        for child: Process?,
        generation: UInt64
    ) {
        lock.lock()
        let isCurrent: Bool
        if isRunning {
            isCurrent = latestGeneration == generation
                && processGeneration == generation
                && process === child
                && child?.isRunning == true
        } else {
            isCurrent = latestGeneration == generation && process == nil
        }
        let callback = onStateChange
        lock.unlock()

        if isCurrent {
            callback(isRunning)
        }
    }

    private static func defaultMainDelivery(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    deinit {
        stop()
    }
}
