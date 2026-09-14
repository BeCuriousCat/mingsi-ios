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
