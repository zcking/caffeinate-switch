import Darwin
import Foundation
import SwitchCore
import XCTest
@testable import CaffeinateSwitchApp

final class CaffeinateProcessTests: XCTestCase {
    func testStartsReportsOwnedPIDAndStopsOnlyOwnedChild() throws {
        let fixtureURL = try makeSignalWaitingFixture()
        let unrelated = Process()
        unrelated.executableURL = fixtureURL
        try unrelated.run()
        addTeardownBlock {
            if unrelated.isRunning {
                unrelated.terminate()
                unrelated.waitUntilExit()
            }
        }

        let expectedStopDidNotNotify = expectation(description: "expected stop does not notify")
        expectedStopDidNotNotify.isInverted = true
        let process = CaffeinateProcess(executableURL: fixtureURL)
        process.onUnexpectedTermination = { expectedStopDidNotNotify.fulfill() }
        try process.start()
        let ownedPID = try XCTUnwrap(process.processIdentifier)

        XCTAssertTrue(process.isRunning)
        XCTAssertNotEqual(ownedPID, unrelated.processIdentifier)

        process.stop()

        XCTAssertFalse(process.isRunning)
        XCTAssertNil(process.processIdentifier)
        XCTAssertTrue(unrelated.isRunning)
        wait(for: [expectedStopDidNotNotify], timeout: 0.1)
    }

    func testUnexpectedTerminationNotifiesObserver() throws {
        let fixtureURL = try makeSignalWaitingFixture()
        let process = CaffeinateProcess(executableURL: fixtureURL)
        let notified = expectation(description: "unexpected child termination")
        process.onUnexpectedTermination = { notified.fulfill() }
        try process.start()
        let ownedPID = try XCTUnwrap(process.processIdentifier)

        XCTAssertEqual(kill(ownedPID, SIGTERM), 0)

        wait(for: [notified], timeout: 3)
        XCTAssertFalse(process.isRunning)
        XCTAssertNil(process.processIdentifier)
    }

    func testGraceTimerStopPublishesStoppedProcessState() throws {
        let fixtureURL = try makeSignalWaitingFixture()
        let process = CaffeinateProcess(executableURL: fixtureURL)
        let scheduler = TestScheduler()
        let reconciler = Reconciler(process: process, scheduler: scheduler)
        var observedStates: [Bool] = []
        var callbacksWereOnMainThread: [Bool] = []
        process.onStateChange = {
            observedStates.append($0)
            callbacksWereOnMainThread.append(Thread.isMainThread)
        }

        try process.start()
        reconciler.serialDisconnected()
        scheduler.advance(by: 10)

        XCTAssertEqual(observedStates, [true, false])
        XCTAssertEqual(callbacksWereOnMainThread, [true, true])
        XCTAssertFalse(process.isRunning)
    }

    func testObsoleteExitCannotOverwriteReplacementRunningState() throws {
        let fixtureURL = try makeSignalWaitingFixture()
        let delivery = QueuedMainDelivery()
        let process = CaffeinateProcess(
            executableURL: fixtureURL,
            deliverOnMain: delivery.enqueue
        )
        var observedStates: [Bool] = []
        var unexpectedExitCount = 0
        process.onStateChange = { observedStates.append($0) }
        process.onUnexpectedTermination = { unexpectedExitCount += 1 }
        defer {
            process.stop()
            delivery.runAll()
        }

        try process.start()
        XCTAssertEqual(delivery.pendingCount, 1)
        delivery.runFirst()
        let oldPID = try XCTUnwrap(process.processIdentifier)

        XCTAssertEqual(kill(oldPID, SIGTERM), 0)
        XCTAssertTrue(delivery.waitForPendingCount(1, timeout: 3))

        try process.start()
        XCTAssertEqual(delivery.pendingCount, 2)
        delivery.runLast() // replacement running
        delivery.runFirst() // obsolete child exit

        XCTAssertEqual(observedStates, [true, true])
        XCTAssertEqual(unexpectedExitCount, 1)
        XCTAssertTrue(process.isRunning)
    }

    private func makeSignalWaitingFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let fixtureURL = directory.appendingPathComponent("signal-waiter")
        let script = """
        #!/bin/sh
        trap 'exit 0' TERM INT
        while true; do
            sleep 1
        done
        """
        try Data(script.utf8).write(to: fixtureURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fixtureURL.path
        )
        return fixtureURL
    }
}

private final class QueuedMainDelivery {
    private let lock = NSLock()
    private var actions: [() -> Void] = []

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return actions.count
    }

    func enqueue(_ action: @escaping () -> Void) {
        lock.lock()
        actions.append(action)
        lock.unlock()
    }

    func waitForPendingCount(_ count: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while pendingCount < count, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        return pendingCount >= count
    }

    func runFirst() {
        lock.lock()
        let action = actions.removeFirst()
        lock.unlock()
        action()
    }

    func runLast() {
        lock.lock()
        let action = actions.removeLast()
        lock.unlock()
        action()
    }

    func runAll() {
        while pendingCount > 0 {
            runFirst()
        }
    }
}

private final class TestScheduler: Scheduler {
    private final class Token: Cancellable {
        var isCancelled = false

        func cancel() {
            isCancelled = true
        }
    }

    private struct ScheduledAction {
        let deadline: Double
        let token: Token
        let action: () -> Void
    }

    private var now: Double = 0
    private var actions: [ScheduledAction] = []

    func schedule(after delay: Double, _ action: @escaping () -> Void) -> any Cancellable {
        let token = Token()
        actions.append(ScheduledAction(deadline: now + delay, token: token, action: action))
        return token
    }

    func advance(by interval: Double) {
        now += interval
        let dueActions = actions.enumerated().filter { $0.element.deadline <= now }
        for (index, scheduled) in dueActions.reversed() {
            actions.remove(at: index)
            if !scheduled.token.isCancelled {
                scheduled.action()
            }
        }
    }
}

final class SerialLineFramerTests: XCTestCase {
    func testPreservesAFragmented256ByteRecord() {
        var framer = SerialLineFramer()
        let record = [UInt8](repeating: UInt8(ascii: "x"), count: 256)

        XCTAssertTrue(framer.receive(record.prefix(128)).isEmpty)
        XCTAssertEqual(
            framer.receive(record.suffix(128) + [UInt8(ascii: "\n")]),
            [String(repeating: "x", count: 256)]
        )
    }

    func testDropsOversizedRecordAndResynchronizesAtNewline() {
        var framer = SerialLineFramer()
        let bytes = [UInt8](repeating: UInt8(ascii: "x"), count: 257)
            + [UInt8(ascii: "\n")]
            + Array("STATE 8 ON\n".utf8)

        XCTAssertEqual(framer.receive(bytes), ["STATE 8 ON"])
    }
}
