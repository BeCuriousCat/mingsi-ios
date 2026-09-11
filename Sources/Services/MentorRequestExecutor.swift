import Foundation

struct MentorRequestPolicy: Hashable {
    let deadline: Duration
    let waitingNoticeAfter: Duration
    let maxHTTPAttempts: Int
    let allowsFormatFallback: Bool
    static let m1 = MentorRequestPolicy(deadline: .seconds(30), waitingNoticeAfter: .seconds(10), maxHTTPAttempts: 1, allowsFormatFallback: false)
}

enum MentorRequestExecutionState: Equatable { case started, waiting, completed, timedOut, cancelled, failed }
enum MentorRequestExecutionError: Error, Equatable { case timedOut, cancelled, invalidPolicy, unsupportedStreaming }

struct MentorRequestExecutionResult {
    let data: Data
    let elapsed: Duration
    let waitingNoticeShown: Bool
}

/// Foreground completion is independent of transport cooperation. Cancellation is
/// forwarded, but a late transport result cannot resume the caller or emit another state.
/// The transport must separately enforce one HTTP attempt and owned audit writes.
final class MentorRequestExecutor {
    private static let maximumDeadline: Duration = .seconds(30)
    private let clock: ContinuousClock
    init(clock: ContinuousClock = ContinuousClock()) { self.clock = clock }

    func execute(_ operation: @escaping @Sendable () async throws -> Data,
                 policy: MentorRequestPolicy = .m1,
                 startedAt: ContinuousClock.Instant? = nil,
                 onState: @escaping @Sendable (MentorRequestExecutionState) -> Void = { _ in }) async throws -> MentorRequestExecutionResult {
        guard policy.deadline > .zero, policy.deadline <= Self.maximumDeadline,
              policy.waitingNoticeAfter >= .zero, policy.waitingNoticeAfter <= .seconds(10),
              policy.waitingNoticeAfter < policy.deadline, policy.maxHTTPAttempts == 1,
              !policy.allowsFormatFallback else { throw MentorRequestExecutionError.invalidPolicy }
        let start = startedAt ?? clock.now
        guard start <= clock.now else { throw MentorRequestExecutionError.invalidPolicy }
        let race = MentorRequestRace(clock: clock, start: start, policy: policy, onState: onState)
        onState(.started)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                guard race.install(continuation) else { return }
                if Task.isCancelled { race.cancel(); return }
                if clock.now >= start.advanced(by: policy.deadline) { race.timeout(); return }
                // Unstructured tasks are intentional: a task group waits for children which
                // ignore cancellation and would prevent the foreground deadline from returning.
                let transport = Task {
                    guard !Task.isCancelled, race.isPending else { return }
                    do { race.complete(try await operation()) }
                    catch is CancellationError { race.cancel() }
                    catch { race.fail(error) }
                }
                race.track(transport)
                let watchdog = Task {
                    do { try await clock.sleep(until: start.advanced(by: policy.deadline)); race.timeout() }
                    catch { /* Terminal completion cancelled the watchdog. */ }
                }
                race.track(watchdog)
                let notice = Task {
                    do { try await clock.sleep(until: start.advanced(by: policy.waitingNoticeAfter)); race.showWaiting() }
                    catch { /* No waiting notice after a terminal result. */ }
                }
                race.track(notice)
            }
        }, onCancel: { race.cancel() })
    }
}

/// Every mutable field is protected by the lock. Observers are serialized and must
/// return promptly; recursive locking allows an observer to cancel its own caller.
private final class MentorRequestRace: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let clock: ContinuousClock
    private let start: ContinuousClock.Instant
    private let policy: MentorRequestPolicy
    private var onState: (@Sendable (MentorRequestExecutionState) -> Void)?
    private var continuation: CheckedContinuation<MentorRequestExecutionResult, Error>?
    private var outcome: Result<MentorRequestExecutionResult, Error>?
    private var tasks: [Task<Void, Never>] = []
    private var waitingShown = false

    init(clock: ContinuousClock, start: ContinuousClock.Instant, policy: MentorRequestPolicy,
         onState: @escaping @Sendable (MentorRequestExecutionState) -> Void) {
        self.clock = clock; self.start = start; self.policy = policy; self.onState = onState
    }

    var isPending: Bool { lock.lock(); defer { lock.unlock() }; return outcome == nil }

    func install(_ continuation: CheckedContinuation<MentorRequestExecutionResult, Error>) -> Bool {
        lock.lock()
        if let outcome { lock.unlock(); continuation.resume(with: outcome); return false }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func track(_ task: Task<Void, Never>) {
        lock.lock()
        let finished = outcome != nil
        if !finished { tasks.append(task) }
        lock.unlock()
        if finished { task.cancel() }
    }

    func showWaiting() {
        lock.lock()
        defer { lock.unlock() }
        guard outcome == nil, !waitingShown else { return }
        if clock.now >= start.advanced(by: policy.deadline) { timeout(); return }
        waitingShown = true
        onState?(.waiting)
    }

    func complete(_ data: Data) { finish(data: data, error: nil, state: .completed) }
    func fail(_ error: Error) { finish(data: nil, error: error, state: .failed) }
    func timeout() { finish(data: nil, error: MentorRequestExecutionError.timedOut, state: .timedOut) }
    func cancel() { finish(data: nil, error: MentorRequestExecutionError.cancelled, state: .cancelled) }

    private func finish(data: Data?, error: Error?, state: MentorRequestExecutionState) {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return }
        let elapsed = start.duration(to: clock.now)
        let terminalState: MentorRequestExecutionState
        let result: Result<MentorRequestExecutionResult, Error>
        // The watchdog may be scheduled late. Never accept a response past the deadline.
        if state != .cancelled && elapsed >= policy.deadline {
            terminalState = .timedOut
            result = .failure(MentorRequestExecutionError.timedOut)
        } else if let error {
            terminalState = state; result = .failure(error)
        } else if let data {
            terminalState = .completed
            result = .success(MentorRequestExecutionResult(data: data, elapsed: elapsed, waitingNoticeShown: waitingShown))
        } else {
            terminalState = .failed; result = .failure(MentorRequestExecutionError.invalidPolicy)
        }
        outcome = result
        let receiver = continuation; continuation = nil
        let children = tasks; tasks.removeAll()
        onState?(terminalState); onState = nil
        lock.unlock()
        children.forEach { $0.cancel() }
        receiver?.resume(with: result)
    }
}
