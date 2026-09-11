import XCTest
@testable import MingSi

final class MentorRequestExecutorTests: XCTestCase {
    func testSuccessfulRequestDoesNotRetryAndEmitsWaitingState() async throws {
        let executor = MentorRequestExecutor(), states = Locked<[MentorRequestExecutionState]>([])
        let calls = Locked(0)
        let result = try await executor.execute({
            calls.withLock { $0 += 1 }
            try await ContinuousClock().sleep(for: .milliseconds(20))
            return Data("{}".utf8)
        }, policy: MentorRequestPolicy(deadline: .seconds(1), waitingNoticeAfter: .milliseconds(5), maxHTTPAttempts: 1, allowsFormatFallback: false)) { state in
            states.withLock { $0.append(state) }
        }
        XCTAssertEqual(result.data, Data("{}".utf8)); XCTAssertEqual(calls.value, 1)
        XCTAssertEqual(states.value, [.started, .waiting, .completed])
        XCTAssertTrue(result.waitingNoticeShown)
    }

    func testFailureIsTerminalAndNoRetryOrFallback() async {
        let executor = MentorRequestExecutor(), calls = Locked(0)
        do {
            _ = try await executor.execute({ calls.withLock { $0 += 1 }; throw URLError(.notConnectedToInternet) })
            XCTFail("Expected failure")
        } catch { XCTAssertEqual(calls.value, 1) }
    }

    func testCancellationPropagatesAndDoesNotClaimSuccess() async {
        let executor = MentorRequestExecutor()
        let operation = Task {
            try await executor.execute({
                try await ContinuousClock().sleep(for: .seconds(2)); return Data()
            })
        }
        operation.cancel()
        do { _ = try await operation.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is MentorRequestExecutionError || error is CancellationError) }
    }

    func testDeadlineReturnsWhileTransportIgnoresCancellationAndDropsLateSuccess() async throws {
        let held = MentorHeldOperation(), states = Locked<[MentorRequestExecutionState]>([])
        let returned = expectation(description: "foreground deadline returned")
        let lateSuccess = expectation(description: "late success must not be presented")
        lateSuccess.isInverted = true
        let start = ContinuousClock().now
        let caller = Task {
            defer { returned.fulfill() }
            return try await MentorRequestExecutor().execute({ try await held.run() },
                policy: MentorRequestPolicy(deadline: .milliseconds(50), waitingNoticeAfter: .milliseconds(5), maxHTTPAttempts: 1, allowsFormatFallback: false)) {
                state in
                states.withLock { $0.append(state) }
                if state == .completed { lateSuccess.fulfill() }
            }
        }
        await fulfillment(of: [returned], timeout: 1)
        // Release even on failure so a broken executor does not leave the test hanging.
        held.release(.success(Data("late response".utf8)))
        do { _ = try await caller.value; XCTFail("Deadline must fail") }
        catch { XCTAssertEqual(error as? MentorRequestExecutionError, .timedOut) }
        await fulfillment(of: [lateSuccess], timeout: 0.1)
        XCTAssertLessThan(start.duration(to: ContinuousClock().now), .seconds(1))
        XCTAssertEqual(states.value.first, .started)
        XCTAssertEqual(states.value.last, .timedOut)
        XCTAssertFalse(states.value.contains(.completed))
    }

    func testCancelReturnsBeforeUncooperativeTransportAndRejectsLateFailure() async throws {
        let held = MentorHeldOperation(), states = Locked<[MentorRequestExecutionState]>([])
        let entered = expectation(description: "transport entered")
        let returned = expectation(description: "foreground cancellation returned")
        let caller = Task {
            defer { returned.fulfill() }
            return try await MentorRequestExecutor().execute({ entered.fulfill(); return try await held.run() }) { state in
                states.withLock { $0.append(state) }
            }
        }
        await fulfillment(of: [entered], timeout: 1)
        caller.cancel()
        await fulfillment(of: [returned], timeout: 1)
        held.release(.failure(URLError(.networkConnectionLost)))
        do { _ = try await caller.value; XCTFail("Cancellation must fail") }
        catch { XCTAssertEqual(error as? MentorRequestExecutionError, .cancelled) }
        XCTAssertEqual(states.value, [.started, .cancelled])
    }

    func testPreparationTimeCountsAndExpiredRequestNeverStartsTransport() async {
        let calls = Locked(0), states = Locked<[MentorRequestExecutionState]>([])
        do {
            _ = try await MentorRequestExecutor().execute({ calls.withLock { $0 += 1 }; return Data() },
                startedAt: ContinuousClock().now.advanced(by: .seconds(-31))) { state in states.withLock { $0.append(state) } }
            XCTFail("Expired request must time out")
        } catch { XCTAssertEqual(error as? MentorRequestExecutionError, .timedOut) }
        XCTAssertEqual(calls.value, 0)
        XCTAssertEqual(states.value, [.started, .timedOut])
    }

    func testInvalidPolicyCannotDisableDeadlineOrEnableRetries() async {
        let calls = Locked(0)
        for policy in [
            MentorRequestPolicy(deadline: .zero, waitingNoticeAfter: .zero, maxHTTPAttempts: 1, allowsFormatFallback: false),
            MentorRequestPolicy(deadline: .seconds(30), waitingNoticeAfter: .seconds(10), maxHTTPAttempts: 2, allowsFormatFallback: false),
            MentorRequestPolicy(deadline: .seconds(30), waitingNoticeAfter: .seconds(10), maxHTTPAttempts: 1, allowsFormatFallback: true)
        ] {
            do { _ = try await MentorRequestExecutor().execute({ calls.withLock { $0 += 1 }; return Data() }, policy: policy); XCTFail("Invalid policy") }
            catch { XCTAssertEqual(error as? MentorRequestExecutionError, .invalidPolicy) }
        }
        XCTAssertEqual(calls.value, 0)
    }

    func testPolicyMakesNoHiddenRetryOrFormatFallback() {
        XCTAssertEqual(MentorRequestPolicy.m1.maxHTTPAttempts, 1)
        XCTAssertFalse(MentorRequestPolicy.m1.allowsFormatFallback)
        XCTAssertEqual(MentorRequestPolicy.m1.deadline, .seconds(30))
        XCTAssertEqual(MentorRequestPolicy.m1.waitingNoticeAfter, .seconds(10))
    }
}

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    var value: Value { withLock { $0 } }
    init(_ value: Value) { storage = value }
    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R { lock.lock(); defer { lock.unlock() }; return try body(&storage) }
}

/// Deliberately ignores Task cancellation, but can always be released by test cleanup.
private final class MentorHeldOperation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var result: Result<Data, Error>?
    func run() async throws -> Data {
        try await withCheckedThrowingContinuation { receiver in
            lock.lock()
            if let result { lock.unlock(); receiver.resume(with: result) }
            else { continuation = receiver; lock.unlock() }
        }
    }
    func release(_ result: Result<Data, Error>) {
        lock.lock()
        self.result = result
        let receiver = continuation; continuation = nil
        lock.unlock()
        receiver?.resume(with: result)
    }
}
