import Foundation

struct MentorRequestPolicy: Equatable {
    let deadline: Duration
    let waitingNoticeAfter: Duration
    let maxHTTPAttempts: Int
    let allowsFormatFallback: Bool
    static let m1 = MentorRequestPolicy(deadline: .seconds(30), waitingNoticeAfter: .seconds(10), maxHTTPAttempts: 1, allowsFormatFallback: false)
}

enum MentorRequestExecutionState: Equatable { case started, waiting, completed, timedOut, cancelled, failed }

enum MentorRequestExecutionError: Error, Equatable { case timedOut, cancelled }

struct MentorRequestExecutionResult {
    let data: Data
    let elapsed: Duration
    let waitingNoticeShown: Bool
}

/// Enforces the M1 foreground budget around one LLM operation. The base client
/// remains responsible for HTTP; this wrapper never retries or repairs JSON.
final class MentorRequestExecutor {
    private let clock: ContinuousClock
    init(clock: ContinuousClock = ContinuousClock()) { self.clock = clock }

    func execute(_ operation: @escaping @Sendable () async throws -> Data,
                 policy: MentorRequestPolicy = .m1,
                 onState: @escaping @Sendable (MentorRequestExecutionState) -> Void = { _ in }) async throws -> MentorRequestExecutionResult {
        onState(.started)
        let start = clock.now
        let task = Task { try await operation() }
        let notice = Task {
            try await clock.sleep(for: policy.waitingNoticeAfter)
            guard !Task.isCancelled else { return }
            onState(.waiting)
        }
        do {
            let data = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            notice.cancel()
            let elapsed = start.duration(to: clock.now)
            onState(.completed)
            return MentorRequestExecutionResult(data: data, elapsed: elapsed, waitingNoticeShown: elapsed >= policy.waitingNoticeAfter)
        } catch is CancellationError {
            notice.cancel(); task.cancel(); onState(.cancelled); throw MentorRequestExecutionError.cancelled
        } catch {
            notice.cancel(); onState(.failed); throw error
        }
    }
}
