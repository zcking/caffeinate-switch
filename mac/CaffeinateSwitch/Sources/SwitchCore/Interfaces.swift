/// A cancellable unit of scheduled work.
public protocol Cancellable: AnyObject {
    func cancel()
}

/// Schedules deferred work without coupling the reconciliation core to a
/// particular run loop or dispatch implementation.
public protocol Scheduler {
    @discardableResult
    func schedule(after delay: Double, _ action: @escaping () -> Void) -> any Cancellable
}

/// Owns the one child process managed by the application.
public protocol ChildProcessManaging: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop()
}
