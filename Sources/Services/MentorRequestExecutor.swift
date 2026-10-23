import Foundation

struct MentorRequestPolicy: Hashable {
    let deadline: Duration
    let waitingNoticeAfter: Duration
    let maxHTTPAttempts: Int
    let allowsFormatFallback: Bool
    static let m1 = MentorRequestPolicy(deadline: .seconds(30), waitingNoticeAfter: .seconds(10), maxHTTPAttempts: 1, allowsFormatFallback: false)
    // Legacy completions without a progress channel retain a finite total budget.
    // Production mentor streams use the shared content-idle budget below.
    static let responses = MentorRequestPolicy(deadline: .seconds(120), waitingNoticeAfter: .seconds(10), maxHTTPAttempts: 1, allowsFormatFallback: false)

    static func forProtocol(_ kind: GLMClientConfiguration.ProtocolKind) -> Self {
        kind == .responses ? .responses : .m1
    }

    /// Production streaming waits for content, rather than enforcing a total generation budget.
    var streamingIdleDeadline: Duration { self == .m1 || self == .responses ? .seconds(600) : deadline }

    var timeoutInterval: TimeInterval {
        let parts = deadline.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
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
final class MentorRequestExecutor: Sendable {
    private static let maximumDeadline: Duration = .seconds(120)
    private let now: @Sendable () -> ContinuousClock.Instant
    private let sleepUntil: @Sendable (ContinuousClock.Instant) async throws -> Void
    init(clock: ContinuousClock = ContinuousClock()) {
        now = { clock.now }
        sleepUntil = { try await clock.sleep(until: $0) }
    }

    /// Inject only time, retaining the production cancellation and race logic.
    init(now: @escaping @Sendable () -> ContinuousClock.Instant,
         sleepUntil: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void) {
        self.now = now
        self.sleepUntil = sleepUntil
    }

    func execute(_ operation: @escaping () async throws -> Data,
                 policy: MentorRequestPolicy = .m1,
                 startedAt: ContinuousClock.Instant? = nil,
                 progress: MentorStreamProgress? = nil,
                 isolation: isolated (any Actor)? = #isolation,
                 onState: @escaping @Sendable (MentorRequestExecutionState) -> Void = { _ in }) async throws -> MentorRequestExecutionResult {
        guard policy.deadline > .zero, policy.deadline <= Self.maximumDeadline,
              policy.waitingNoticeAfter >= .zero, policy.waitingNoticeAfter <= .seconds(10),
              policy.waitingNoticeAfter < policy.deadline, policy.maxHTTPAttempts == 1,
              !policy.allowsFormatFallback else { throw MentorRequestExecutionError.invalidPolicy }
        let start = startedAt ?? now()
        guard start <= now() else { throw MentorRequestExecutionError.invalidPolicy }
        let race = MentorRequestRace(now: now, start: start, policy: policy, progress: progress, onState: onState)
        onState(.started)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                guard race.install(continuation) else { return }
                if Task.isCancelled { race.cancel(); return }
                if now() >= race.expiresAt { race.timeout(); return }
                // Unstructured tasks are intentional: a task group waits for children which
                // ignore cancellation and would prevent the foreground deadline from returning.
                let transport = Task {
                    // Referencing the isolated actor keeps the child on the caller's executor.
                    _ = isolation
                    guard !Task.isCancelled, race.isPending else { return }
                    do { race.complete(try await operation()) }
                    catch is CancellationError { race.cancel() }
                    catch { race.fail(error) }
                }
                race.track(transport)
                let watchdog = Task {
                    do {
                        while race.isPending {
                            try await sleepUntil(race.expiresAt)
                            if now() >= race.expiresAt { race.timeout(); return }
                        }
                    }
                    catch { /* Terminal completion cancelled the watchdog. */ }
                }
                race.track(watchdog)
                let notice = Task {
                    do { try await sleepUntil(start.advanced(by: policy.waitingNoticeAfter)); race.showWaiting() }
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
    private let now: @Sendable () -> ContinuousClock.Instant
    private let start: ContinuousClock.Instant
    private let policy: MentorRequestPolicy
    private let progress: MentorStreamProgress?
    private var onState: (@Sendable (MentorRequestExecutionState) -> Void)?
    private var continuation: CheckedContinuation<MentorRequestExecutionResult, Error>?
    private var outcome: Result<MentorRequestExecutionResult, Error>?
    private var tasks: [Task<Void, Never>] = []
    private var waitingShown = false

    init(now: @escaping @Sendable () -> ContinuousClock.Instant, start: ContinuousClock.Instant, policy: MentorRequestPolicy, progress: MentorStreamProgress?,
         onState: @escaping @Sendable (MentorRequestExecutionState) -> Void) {
        self.now = now; self.start = start; self.policy = policy; self.progress = progress; self.onState = onState
    }

    var expiresAt: ContinuousClock.Instant {
        progress.map { max(start, $0.lastContentAt).advanced(by: policy.streamingIdleDeadline) }
            ?? start.advanced(by: policy.deadline)
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
        if now() >= expiresAt { timeout(); return }
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
        let elapsed = start.duration(to: now())
        let terminalState: MentorRequestExecutionState
        let result: Result<MentorRequestExecutionResult, Error>
        // The watchdog may be scheduled late. Never accept a response past the deadline.
        if state != .cancelled && now() >= expiresAt {
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

/// Per-request progress shared by the UI and nested audit/transport watchdogs.
/// Tokens and ownership never escape this request; heartbeats do not extend its idle budget.
final class MentorStreamProgress: @unchecked Sendable, Hashable {
    private let lock = NSLock()
    private var lastContent: ContinuousClock.Instant
    private var raw = ""
    private let field: String
    private let onPreview: @Sendable (String) -> Void
    private var preview = ""

    init(startedAt: ContinuousClock.Instant = .now, field: String = "body",
         onPreview: @escaping @Sendable (String) -> Void = { _ in }) {
        lastContent = startedAt; self.field = field; self.onPreview = onPreview
    }
    static func == (lhs: MentorStreamProgress, rhs: MentorStreamProgress) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    var lastContentAt: ContinuousClock.Instant { lock.lock(); defer { lock.unlock() }; return lastContent }

    func receive(_ token: String) throws {
        guard !token.isEmpty else { return }
        lock.lock()
        guard raw.utf8.count + token.utf8.count <= 128_000 else {
            lock.unlock(); throw LLMClientError.invalidResponse
        }
        lastContent = .now
        raw += token
        let next = Self.preview(in: raw, field: field)
        let changed = next != preview
        preview = next
        lock.unlock()
        if changed { onPreview(next) }
    }

    /// Decode only a top-level string field. Partial escapes and surrogate pairs
    /// wait for the next packet; JSON keys, sources and model reasoning stay hidden.
    static func preview(in json: String, field: String) -> String {
        let bytes = Array(json.utf8)
        var depth = 0, index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 123 || byte == 91 { depth += 1; index += 1; continue }
            if byte == 125 || byte == 93 { depth -= 1; index += 1; continue }
            guard byte == 34 else { index += 1; continue }
            let start = index
            index += 1
            var escaped = false
            while index < bytes.count {
                let value = bytes[index]
                if value == 34 && !escaped { break }
                if value == 92 && !escaped { escaped = true } else { escaped = false }
                index += 1
            }
            guard index < bytes.count else { return "" }
            let end = index
            index += 1
            guard depth == 1,
                  (try? JSONDecoder().decode(String.self, from: Data(bytes[start...end]))) == field else { continue }
            while index < bytes.count && [9,10,13,32].contains(bytes[index]) { index += 1 }
            guard index < bytes.count, bytes[index] == 58 else { continue }
            index += 1
            while index < bytes.count && [9,10,13,32].contains(bytes[index]) { index += 1 }
            guard index < bytes.count, bytes[index] == 34 else { return "" }
            let valueStart = index
            index += 1; escaped = false
            while index < bytes.count {
                let value = bytes[index]
                if value == 34 && !escaped {
                    return (try? JSONDecoder().decode(String.self, from: Data(bytes[valueStart...index]))) ?? ""
                }
                if value == 92 && !escaped { escaped = true } else { escaped = false }
                index += 1
            }
            for trim in 0...min(12, bytes.count - valueStart - 1) {
                var candidate = Array(bytes[valueStart..<(bytes.count - trim)])
                candidate.append(34)
                if let value = try? JSONDecoder().decode(String.self, from: Data(candidate)) { return value }
            }
            return ""
        }
        return ""
    }
}
