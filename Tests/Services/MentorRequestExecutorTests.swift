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

    func testPolicyMakesNoHiddenRetryOrFormatFallback() {
        XCTAssertEqual(MentorRequestPolicy.m1.maxHTTPAttempts, 1)
        XCTAssertFalse(MentorRequestPolicy.m1.allowsFormatFallback)
        XCTAssertEqual(MentorRequestPolicy.m1.deadline, .seconds(30))
        XCTAssertEqual(MentorRequestPolicy.m1.waitingNoticeAfter, .seconds(10))
    }
}

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock(); var value: Value
    init(_ value: Value) { self.value = value }
    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R { lock.lock(); defer { lock.unlock() }; return try body(&value) }
}
