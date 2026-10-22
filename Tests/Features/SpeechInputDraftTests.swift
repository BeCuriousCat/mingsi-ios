import XCTest
@testable import MingSi

final class SpeechInputDraftTests: XCTestCase {
    func testExitProtectionTracksRecordingAndUnacceptedRecognitionUntilExplicitResolution() {
        var draft = SpeechInputDraft()
        XCTAssertFalse(draft.hasPendingInput)
        draft.begin()
        XCTAssertTrue(draft.hasPendingInput)
        draft.receive(.recording(text: "尚未添加的闪念"))
        draft.requestStop()
        XCTAssertTrue(draft.hasPendingInput)
        draft.receive(.interrupted(text: "尚未添加的闪念"))
        XCTAssertTrue(draft.hasPendingInput, "An interrupted transcript must also protect the containing sheet")
        var text = "手写片段"
        draft.accept(into: &text)
        XCTAssertEqual(text, "手写片段\n尚未添加的闪念")
        XCTAssertFalse(draft.hasPendingInput)
        draft.begin()
        draft.receive(.final(text: "第二条"))
        XCTAssertTrue(draft.hasPendingInput)
        draft.cancel()
        XCTAssertFalse(draft.hasPendingInput)
        draft.begin()
        draft.receive(.failed("microphone_permission_denied"))
        XCTAssertFalse(draft.hasPendingInput, "An empty permission error must not trap the user in a sheet")
    }

    func testCancelPreservesDraftAndRejectsLateResults() {
        var draft = SpeechInputDraft()
        var text = "原来的记录"
        draft.begin()
        XCTAssertTrue(draft.isPreparing)
        draft.receive(.recording(text: "临时文字"))
        XCTAssertFalse(draft.isPreparing)
        draft.accept(into: &text)
        XCTAssertEqual(text, "原来的记录")
        draft.cancel()
        draft.receive(.final(text: "迟到结果"))
        draft.accept(into: &text)
        XCTAssertEqual(text, "原来的记录")
        XCTAssertEqual(draft.preview, "")
    }

    func testConfirmationAppendsEditedRecognitionToCurrentTextOnce() {
        var draft = SpeechInputDraft()
        var text = "原文"
        draft.begin()
        draft.receive(.final(text: "识别结果"))
        XCTAssertEqual(text, "原文")
        text += "以及录音期间的修改"
        draft.preview = "修正后的文字"
        draft.accept(into: &text)
        draft.accept(into: &text)
        XCTAssertEqual(text, "原文以及录音期间的修改\n修正后的文字")
    }

    func testInterruptionAndFailureRequireExplicitReview() {
        for state in [SpeechTranscriptionState.interrupted(text: "部分"), .failed("network")] {
            var draft = SpeechInputDraft()
            var text = ""
            draft.begin()
            draft.receive(.recording(text: "部分"))
            draft.receive(state)
            XCTAssertTrue(draft.isReviewing)
            XCTAssertFalse(draft.isActive)
            XCTAssertEqual(text, "")
            draft.accept(into: &text)
            XCTAssertEqual(text, "部分")
        }
    }

    func testEmptyRecognitionDoesNotChangeWhitespaceOrDraft() {
        var draft = SpeechInputDraft()
        var text = "原文\n"
        draft.begin()
        draft.receive(.final(text: " \n"))
        draft.accept(into: &text)
        XCTAssertEqual(text, "原文\n")
    }

    func testStoppingMovesToFinalizingAndCancelClearsIt() {
        var draft = SpeechInputDraft()
        draft.begin()
        draft.receive(.recording(text: "部分识别"))
        draft.requestStop()

        XCTAssertTrue(draft.isActive)
        XCTAssertFalse(draft.isPreparing)
        XCTAssertTrue(draft.isFinalizing)
        XCTAssertFalse(draft.isReviewing)

        draft.cancel()
        XCTAssertFalse(draft.isActive)
        XCTAssertFalse(draft.isFinalizing)
        XCTAssertFalse(draft.isReviewing)
        XCTAssertEqual(draft.preview, "")
    }

    func testStoppingIsImmediateAndSecondTapCanCancel() {
        var draft = SpeechInputDraft()
        draft.begin()
        draft.receive(.recording(text: "部分识别"))

        draft.requestStop()

        XCTAssertTrue(draft.isActive)
        XCTAssertTrue(draft.isFinalizing)
        XCTAssertEqual(draft.message, "正在完成识别，点右下角取消")

        draft.cancel()
        XCTAssertFalse(draft.isActive)
        XCTAssertFalse(draft.isReviewing)
    }

    func testInterruptedDraftCanStartAReplacementRecording() {
        var draft = SpeechInputDraft()
        draft.begin()
        draft.receive(.recording(text: "部分识别"))
        draft.receive(.interrupted(text: "部分识别"))

        XCTAssertTrue(draft.isReviewing)
        draft.restart()

        XCTAssertTrue(draft.isActive)
        XCTAssertFalse(draft.isReviewing)
        XCTAssertEqual(draft.preview, "")
    }

    func testFailedDraftCanStartReplacementWithoutAcceptingPartialText() {
        var draft = SpeechInputDraft()
        var text = "原来的记录"
        draft.begin()
        draft.receive(.recording(text: "不完整"))
        draft.receive(.failed("speech_unavailable"))

        XCTAssertTrue(draft.isReviewing)
        XCTAssertEqual(text, "原来的记录")

        draft.restart()

        XCTAssertTrue(draft.isActive)
        XCTAssertTrue(draft.isPreparing)
        XCTAssertEqual(draft.preview, "")
        XCTAssertEqual(text, "原来的记录")
    }
}

@MainActor
final class SpeechInputControllerTests: XCTestCase {
    func testSwitchingFieldsStopsPreviousCaptureAndKeepsResultsInTheirOwnDrafts() async {
        let firstBackend = ControllerSpeechBackend()
        let secondBackend = ControllerSpeechBackend()
        let first = makeController(firstBackend)
        let second = makeController(secondBackend)
        first.toggleRecording()
        await waitForStarts(1, firstBackend)
        firstBackend.handlers[0](.transcript("第一处的部分文字", isFinal: false))
        let cancellationsBeforeSwitch = firstBackend.cancellations

        second.toggleRecording()
        XCTAssertGreaterThan(firstBackend.cancellations, cancellationsBeforeSwitch)
        XCTAssertFalse(first.draft.isActive)
        XCTAssertTrue(first.draft.isReviewing)
        XCTAssertEqual(first.draft.preview, "第一处的部分文字")
        await waitForStarts(1, secondBackend)
        firstBackend.handlers[0](.transcript("第一处迟到结果", isFinal: true))
        secondBackend.handlers[0](.transcript("第二处文字", isFinal: false))
        XCTAssertEqual(first.draft.preview, "第一处的部分文字")
        XCTAssertEqual(second.draft.preview, "第二处文字")

        // Discarding an inactive field must not revoke the current owner.
        first.discard()
        first.toggleRecording()
        await waitForStarts(2, firstBackend)
        XCTAssertFalse(second.draft.isActive)
        XCTAssertEqual(second.draft.preview, "第二处文字")
        var secondText = "第二处原文"
        second.accept(into: &secondText)
        XCTAssertEqual(secondText, "第二处原文\n第二处文字")
        XCTAssertTrue(first.draft.isActive)
        first.discard()
    }

    func testSwitchingFieldsDuringFinalizationRejectsPreviousFinalResult() async {
        let firstBackend = ControllerSpeechBackend()
        let secondBackend = ControllerSpeechBackend()
        let first = makeController(firstBackend)
        let second = makeController(secondBackend)
        first.toggleRecording()
        await waitForStarts(1, firstBackend)
        firstBackend.handlers[0](.transcript("等待收尾的文字", isFinal: false))
        first.toggleRecording()
        XCTAssertTrue(first.draft.isFinalizing)
        second.toggleRecording()
        await waitForStarts(1, secondBackend)
        firstBackend.handlers[0](.transcript("迟到的最终文字", isFinal: true))
        XCTAssertEqual(first.draft.preview, "等待收尾的文字")
        XCTAssertTrue(first.draft.isReviewing)
        XCTAssertTrue(second.draft.isActive)
        first.discard()
        second.discard()
    }

    func testSwitchingFieldsDuringPermissionRequestCannotStartOldMicrophone() async {
        let firstBackend = ControllerSpeechBackend()
        let secondBackend = ControllerSpeechBackend()
        var pending: CheckedContinuation<Bool, Never>?
        let first = SpeechInputController(speech: SpeechTranscriptionService(
            backend: firstBackend, authorizeSpeech: { .authorized },
            authorizeMicrophone: { await withCheckedContinuation { pending = $0 } }
        ))
        let second = makeController(secondBackend)
        first.toggleRecording()
        for _ in 0..<100 where pending == nil { await Task.yield() }
        XCTAssertNotNil(pending)
        second.toggleRecording()
        await waitForStarts(1, secondBackend)
        pending?.resume(returning: true)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(firstBackend.handlers.count, 0)
        XCTAssertEqual(first.draft, SpeechInputDraft())
        XCTAssertTrue(second.draft.isActive)
        second.discard()
    }

    func testSameControlCancelsFinalizationAndImmediatelyRestartsWithoutOldResults() async {
        let backend = ControllerSpeechBackend()
        let controller = makeController(backend)
        controller.toggleRecording()
        await waitForStarts(1, backend)
        backend.handlers[0](.transcript("旧部分", isFinal: false))
        controller.toggleRecording()
        XCTAssertTrue(controller.draft.isFinalizing)
        XCTAssertEqual(backend.ends, 1)
        controller.toggleRecording()
        XCTAssertEqual(controller.draft, SpeechInputDraft())
        controller.toggleRecording()
        await waitForStarts(2, backend)
        backend.handlers[0](.transcript("旧收尾", isFinal: true))
        XCTAssertTrue(controller.draft.isActive)
        XCTAssertFalse(controller.draft.isPreparing)
        backend.handlers[1](.transcript("新结果", isFinal: true))
        var text = "原文"
        controller.accept(into: &text)
        controller.accept(into: &text)
        XCTAssertEqual(text, "原文\n新结果")
        XCTAssertEqual(controller.draft, SpeechInputDraft())
    }

    func testInterruptedAndCompletedResultsRestartActualBackendWithOneTap() async {
        let backend = ControllerSpeechBackend()
        let controller = makeController(backend)
        controller.toggleRecording()
        await waitForStarts(1, backend)
        backend.handlers[0](.transcript("部分", isFinal: false))
        backend.handlers[0](.failure)
        XCTAssertTrue(controller.draft.isReviewing)
        XCTAssertEqual(controller.draft.preview, "部分")
        controller.toggleRecording()
        XCTAssertTrue(controller.draft.isPreparing)
        await waitForStarts(2, backend)
        XCTAssertTrue(controller.draft.isActive)
        XCTAssertFalse(controller.draft.isPreparing)
        XCTAssertEqual(controller.draft.preview, "")
        backend.handlers[1](.transcript("已完成", isFinal: true))
        controller.toggleRecording()
        await waitForStarts(3, backend)
        backend.handlers[1](.failure)
        XCTAssertTrue(controller.draft.isActive)
        controller.discard()
    }

    func testReviewUsesEditedRecognitionAndCurrentUserText() async {
        let backend = ControllerSpeechBackend()
        let controller = makeController(backend)
        controller.toggleRecording()
        await waitForStarts(1, backend)
        backend.handlers[0](.transcript("识别原稿", isFinal: true))
        controller.draft.preview = "修正后的文字"
        var text = "录音期间编辑过的原文"
        controller.accept(into: &text)
        XCTAssertEqual(text, "录音期间编辑过的原文\n修正后的文字")
        controller.toggleRecording()
        await waitForStarts(2, backend)
        controller.discard()
        backend.handlers[1](.transcript("离开后的结果", isFinal: true))
        XCTAssertEqual(controller.draft, SpeechInputDraft())
        XCTAssertEqual(text, "录音期间编辑过的原文\n修正后的文字")
    }

    func testPermissionCancellationAndRetryCannotBeOverwrittenByOldPermission() async {
        let backend = ControllerSpeechBackend()
        var pending: CheckedContinuation<Bool, Never>?
        var requests = 0
        let service = SpeechTranscriptionService(backend: backend, authorizeSpeech: { .authorized }, authorizeMicrophone: {
            requests += 1
            if requests == 1 { return await withCheckedContinuation { pending = $0 } }
            return true
        })
        let controller = SpeechInputController(speech: service)
        controller.toggleRecording()
        for _ in 0..<100 where pending == nil { await Task.yield() }
        XCTAssertNotNil(pending)
        controller.toggleRecording()
        XCTAssertEqual(controller.draft, SpeechInputDraft())
        controller.toggleRecording()
        await waitForStarts(1, backend)
        pending?.resume(returning: true)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(backend.handlers.count, 1)
        XCTAssertTrue(controller.draft.isActive)
        XCTAssertFalse(controller.draft.isPreparing)
        controller.discard()
    }

    private func makeController(_ backend: ControllerSpeechBackend) -> SpeechInputController {
        SpeechInputController(speech: SpeechTranscriptionService(
            backend: backend, authorizeSpeech: { .authorized }, authorizeMicrophone: { true }
        ))
    }

    private func waitForStarts(_ count: Int, _ backend: ControllerSpeechBackend) async {
        for _ in 0..<100 where backend.handlers.count < count { await Task.yield() }
        XCTAssertEqual(backend.handlers.count, count)
    }
}

@MainActor
private final class ControllerSpeechBackend: SpeechRecognitionBackend {
    let isAvailable = true
    var handlers: [@MainActor (SpeechRecognitionEvent) -> Void] = []
    var ends = 0
    var cancellations = 0
    func start(_ receive: @escaping @MainActor (SpeechRecognitionEvent) -> Void) throws { handlers.append(receive) }
    func endAudio() { ends += 1 }
    func cancel() { cancellations += 1 }
}

extension SpeechInputDraftTests {
    func testRestoredSpeechRequiresReviewAndAppendsOnlyOnce() {
        var draft = SpeechInputDraft()
        draft.restorePreview("重启后保留的识别")
        XCTAssertTrue(draft.isReviewing)
        XCTAssertFalse(draft.isActive)
        var body = "原手写正文"
        draft.receive(.final(text: "旧录音的迟到回调"))
        draft.accept(into: &body)
        draft.accept(into: &body)
        XCTAssertEqual(body, "原手写正文\n重启后保留的识别")
    }

    @MainActor
    func testBackgroundSuspensionPreservesReviewAndRejectsLateResults() {
        let controller = SpeechInputController(speech: SpeechTranscriptionService.inputService())
        controller.draft.begin()
        controller.draft.receive(.recording(text: "退后台前的部分识别"))
        controller.suspend()
        XCTAssertFalse(controller.draft.isActive)
        XCTAssertTrue(controller.draft.isReviewing)
        XCTAssertEqual(controller.draft.preview, "退后台前的部分识别")
        controller.draft.receive(.final(text: "迟到"))
        XCTAssertEqual(controller.draft.preview, "退后台前的部分识别")
        controller.suspend()
        XCTAssertEqual(controller.draft.preview, "退后台前的部分识别")
    }
}
