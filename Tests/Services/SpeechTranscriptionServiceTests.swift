import XCTest
import Speech
@testable import MingSi

@MainActor
final class SpeechTranscriptionServiceTests: XCTestCase {
    func testReleaseDuringSpeechPermissionCannotStartMicrophone() async {
        var pending: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>?
        var microphoneCalls = 0
        let service = SpeechTranscriptionService(authorizeSpeech: {
            await withCheckedContinuation { pending = $0 }
        }, authorizeMicrophone: { microphoneCalls += 1; return false })
        let start = Task { await service.start() }
        while pending == nil { await Task.yield() }
        service.stop()
        pending?.resume(returning: .authorized)
        await start.value
        XCTAssertEqual(service.state, .idle)
        XCTAssertEqual(microphoneCalls, 0)
    }

    func testOldPermissionCannotOverwriteNewAttempt() async {
        var pending: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>?
        var calls = 0
        let service = SpeechTranscriptionService(authorizeSpeech: {
            calls += 1
            if calls == 1 { return await withCheckedContinuation { pending = $0 } }
            return .denied
        }, authorizeMicrophone: { XCTFail("Must not request microphone"); return false })
        let first = Task { await service.start() }
        while pending == nil { await Task.yield() }
        service.cancel()
        await service.start()
        pending?.resume(returning: .authorized)
        await first.value
        XCTAssertEqual(service.state, .failed("speech_permission_denied"))
        XCTAssertEqual(calls, 2)
    }

    func testCancelDuringMicrophonePermissionPreservesIdle() async {
        var pending: CheckedContinuation<Bool, Never>?
        let service = SpeechTranscriptionService(authorizeSpeech: { .authorized }, authorizeMicrophone: {
            await withCheckedContinuation { pending = $0 }
        })
        let start = Task { await service.start() }
        while pending == nil { await Task.yield() }
        service.cancel()
        pending?.resume(returning: true)
        await start.value
        XCTAssertEqual(service.state, .idle)
    }

    func testDeniedPermissionCanBeRetriedWithoutReset() async {
        var calls = 0
        let service = SpeechTranscriptionService(authorizeSpeech: { calls += 1; return .denied }, authorizeMicrophone: { false })
        await service.start()
        await service.start()
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(service.state, .failed("speech_permission_denied"))
    }
}

extension SpeechTranscriptionServiceTests {
    func testReleaseWaitsForFinalResultAndStopsAudioOnce() async {
        let backend = TestSpeechBackend()
        let service = SpeechTranscriptionService(backend: backend, authorizeSpeech: { .authorized }, authorizeMicrophone: { true })
        await service.start()
        backend.handlers[0](.transcript("部分", isFinal: false))
        let cancellations = backend.cancellations
        service.stop()
        service.stop()
        XCTAssertEqual(service.state, .finalizing(text: "部分"))
        XCTAssertEqual(backend.ends, 1)
        XCTAssertEqual(backend.cancellations, cancellations, "Must not cancel recognition before final result")
        backend.handlers[0](.transcript("完整的一句话。", isFinal: true))
        XCTAssertEqual(service.state, .final(text: "完整的一句话。"))
        backend.handlers[0](.failure)
        XCTAssertEqual(service.state, .final(text: "完整的一句话。"))
    }

    func testFinalizationTimeoutPreservesPartialAndIgnoresLateFinal() async throws {
        let backend = TestSpeechBackend()
        let service = SpeechTranscriptionService(backend: backend, finalizationTimeout: .milliseconds(20), authorizeSpeech: { .authorized }, authorizeMicrophone: { true })
        await service.start()
        backend.handlers[0](.transcript("已有文字", isFinal: false))
        service.stop()
        for _ in 0..<100 {
            if case .interrupted = service.state { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(service.state, .interrupted(text: "已有文字"))
        backend.handlers[0](.transcript("迟到全文", isFinal: true))
        XCTAssertEqual(service.state, .interrupted(text: "已有文字"))
    }

    func testCancelledFinalizationCannotWriteIntoNextRecording() async {
        let backend = TestSpeechBackend()
        let service = SpeechTranscriptionService(backend: backend, authorizeSpeech: { .authorized }, authorizeMicrophone: { true })
        await service.start()
        service.stop()
        service.cancel()
        await service.start()
        backend.handlers[0](.transcript("旧录音", isFinal: true))
        XCTAssertEqual(service.state, .recording(text: ""))
        backend.handlers[1](.transcript("新录音", isFinal: false))
        XCTAssertEqual(service.state, .recording(text: "新录音"))
        service.cancel()
    }

    func testRecognitionErrorAfterReleasePreservesLastPartial() async {
        let backend = TestSpeechBackend()
        let service = SpeechTranscriptionService(backend: backend, authorizeSpeech: { .authorized }, authorizeMicrophone: { true })
        await service.start()
        service.stop()
        backend.handlers[0](.transcript("收尾的部分结果", isFinal: false))
        backend.handlers[0](.failure)
        XCTAssertEqual(service.state, .interrupted(text: "收尾的部分结果"))
    }
}

@MainActor
private final class TestSpeechBackend: SpeechRecognitionBackend {
    var isAvailable = true
    var handlers: [@MainActor (SpeechRecognitionEvent) -> Void] = []
    var ends = 0
    var cancellations = 0
    func start(_ receive: @escaping @MainActor (SpeechRecognitionEvent) -> Void) throws { handlers.append(receive) }
    func endAudio() { ends += 1 }
    func cancel() { cancellations += 1 }
}
