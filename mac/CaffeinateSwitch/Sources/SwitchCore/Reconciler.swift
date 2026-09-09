/// Reconciles the serial switch's desired state with an owned child process.
///
/// Call its methods from one serialized execution context. Adapters provide
/// process ownership and scheduling; this type performs no I/O itself.
public final class Reconciler {
    public var send: (ProtocolMessage) -> Void = { _ in }

    private let process: any ChildProcessManaging
    private let scheduler: any Scheduler
    private var desiredState: (sequence: UInt64, state: SwitchState)?
    private var disconnectCleanup: (any Cancellable)?

    public init(process: any ChildProcessManaging, scheduler: any Scheduler) {
        self.process = process
        self.scheduler = scheduler
    }

    public func receive(_ message: ProtocolMessage) {
        switch message {
        case .hello(let version) where version != 1:
            send(.error(sequence: 0, code: "VERSION"))
        case .state(let sequence, let state):
            desiredState = (sequence, state)
            reconcile(sequence: sequence, desiredState: state)
        case .hello, .ping, .ack, .error:
            break
        }
    }

    public func serialConnected() {
        disconnectCleanup?.cancel()
        disconnectCleanup = nil
    }

    public func serialDisconnected() {
        disconnectCleanup?.cancel()
        disconnectCleanup = scheduler.schedule(after: 10) { [weak self] in
            self?.disconnectCleanup = nil
            self?.process.stop()
        }
    }

    /// Records an observed child-process exit. The process adapter calls this
    /// only for an actual exit event, after it has updated `isRunning`.
    public func childExited() {
        guard let desiredState, desiredState.state == .on else {
            return
        }
        send(.error(sequence: desiredState.sequence, code: "CHILD_EXIT"))
    }

    private func reconcile(sequence: UInt64, desiredState: SwitchState) {
        switch desiredState {
        case .on:
            startAndAcknowledge(sequence: sequence)
        case .off:
            process.stop()
            send(.ack(sequence: sequence, state: .off))
        }
    }

    private func startAndAcknowledge(sequence: UInt64) {
        do {
            if !process.isRunning {
                try process.start()
            }
        } catch {
            send(.error(sequence: sequence, code: "CHILD_START"))
            return
        }

        guard process.isRunning else {
            send(.error(sequence: sequence, code: "CHILD_START"))
            return
        }

        send(.ack(sequence: sequence, state: .on))
    }
}
