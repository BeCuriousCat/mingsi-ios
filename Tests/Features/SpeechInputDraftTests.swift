import XCTest
@testable import MingSi

final class SpeechInputDraftTests: XCTestCase {
    func testCancelPreservesDraftAndRejectsLateResults() {
        var draft = SpeechInputDraft()
        var text = "原来的记录"
        draft.begin()
        draft.receive(.recording(text: "临时文字"))
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
}
