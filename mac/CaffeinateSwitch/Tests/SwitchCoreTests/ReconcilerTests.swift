import XCTest
@testable import SwitchCore

final class ReconcilerTests: XCTestCase {
    func testOnStartsChildBeforeAcknowledging() {
        let process = FakeProcess()
        let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        var childWasRunningAtAcknowledgement = false
        reconciler.send = { message in
            childWasRunningAtAcknowledgement = process.isRunning
            sent.append(message)
        }

        reconciler.receive(.state(sequence: 9, state: .on))

        XCTAssertTrue(process.isRunning)
        XCTAssertTrue(childWasRunningAtAcknowledgement)
        XCTAssertEqual(sent, [.ack(sequence: 9, state: .on)])
    }

    func testOffStopsChildBeforeAcknowledging() {
        let process = FakeProcess(running: true)
        let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        var childWasStoppedAtAcknowledgement = false
        reconciler.send = { message in
            childWasStoppedAtAcknowledgement = !process.isRunning
            sent.append(message)
        }

        reconciler.receive(.state(sequence: 10, state: .off))

        XCTAssertEqual(process.stopCallCount, 1)
        XCTAssertTrue(childWasStoppedAtAcknowledgement)
        XCTAssertEqual(sent, [.ack(sequence: 10, state: .off)])
    }

    func testDisconnectStopsAfterTenSecondsOnly() {
        let scheduler = FakeScheduler()
        let process = FakeProcess(running: true)
        let reconciler = Reconciler(process: process, scheduler: scheduler)

        reconciler.serialDisconnected()
        scheduler.advance(by: 9.9)
        XCTAssertTrue(process.isRunning)

        scheduler.advance(by: 0.1)
        XCTAssertFalse(process.isRunning)
    }

    func testReconnectCancelsPendingDisconnectCleanup() {
        let scheduler = FakeScheduler()
        let process = FakeProcess(running: true)
        let reconciler = Reconciler(process: process, scheduler: scheduler)

        reconciler.serialDisconnected()
        reconciler.serialConnected()
        scheduler.advance(by: 10)

        XCTAssertTrue(process.isRunning)
    }

    func testUnsupportedHelloVersionReturnsVersionError() {
        let reconciler = Reconciler(process: FakeProcess(), scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        reconciler.send = { sent.append($0) }

        reconciler.receive(.hello(version: 2))

        XCTAssertEqual(sent, [.error(sequence: 0, code: "VERSION")])
    }

    func testStartFailureReturnsChildStartErrorInsteadOfAcknowledgement() {
        let process = FakeProcess(startError: FakeProcessError.failedToStart)
        let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        reconciler.send = { sent.append($0) }

        reconciler.receive(.state(sequence: 11, state: .on))

        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(sent, [.error(sequence: 11, code: "CHILD_START")])
    }

    func testImmediatelyExitedChildReturnsChildStartErrorInsteadOfAcknowledgement() {
        let process = FakeProcess(startsRunning: false)
        let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        reconciler.send = { sent.append($0) }

        reconciler.receive(.state(sequence: 14, state: .on))

        XCTAssertEqual(process.startCallCount, 1)
        XCTAssertEqual(sent, [.error(sequence: 14, code: "CHILD_START")])
    }

    func testUnexpectedExitForDesiredOnReportsChildExit() {
        let process = FakeProcess(running: true)
        let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        reconciler.send = { sent.append($0) }
        reconciler.receive(.state(sequence: 12, state: .on))
        sent.removeAll()
        process.isRunning = false

        reconciler.childExited()

        XCTAssertEqual(sent, [.error(sequence: 12, code: "CHILD_EXIT")])
    }

    func testExpectedExitForDesiredOffIsIgnored() {
        let process = FakeProcess(running: true)
        let reconciler = Reconciler(process: process, scheduler: FakeScheduler())
        var sent: [ProtocolMessage] = []
        reconciler.send = { sent.append($0) }
        reconciler.receive(.state(sequence: 13, state: .off))
        sent.removeAll()

        reconciler.childExited()

        XCTAssertTrue(sent.isEmpty)
    }
}

private enum FakeProcessError: Error {
    case failedToStart
}

private final class FakeProcess: ChildProcessManaging {
    var isRunning: Bool
    var startError: Error?
    var startsRunning: Bool
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(running: Bool = false, startError: Error? = nil, startsRunning: Bool = true) {
        isRunning = running
        self.startError = startError
        self.startsRunning = startsRunning
    }

    func start() throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        isRunning = startsRunning
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}

private final class FakeScheduler: Scheduler {
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
