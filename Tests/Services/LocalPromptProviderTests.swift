import XCTest
@testable import MingSi

final class LocalPromptProviderTests: XCTestCase {
    private let provider = LocalPromptProvider()

    func testEveryPromptTemplate_hasCommonThinkingCoachGuardrails() {
        for promptID in PromptID.allCases {
            let template = provider.template(for: promptID, mode: .standard)
            let combined = "\(template.systemText)\n\(template.userText)"

            if promptID == .organizeCards {
                XCTAssertTrue(combined.contains("MINGSI_STREAM_V1"), "\(promptID.rawValue) must require streaming XML output")
                XCTAssertTrue(combined.contains("Do not return JSON"), "\(promptID.rawValue) must avoid JSON for streaming output")
            } else {
                XCTAssertTrue(combined.contains("Return valid JSON"), "\(promptID.rawValue) must require JSON output")
            }
            XCTAssertTrue(combined.contains("Do not decide for the user"), "\(promptID.rawValue) must not decide for the user")
            XCTAssertTrue(combined.contains("Do not replace the user's thinking"), "\(promptID.rawValue) must preserve user agency")
            XCTAssertTrue(combined.contains("confidential"), "\(promptID.rawValue) must include confidentiality guardrails")
            XCTAssertTrue(combined.contains("默认使用简体中文"), "\(promptID.rawValue) must default to Simplified Chinese output")
            XCTAssertTrue(combined.contains("follow the user's input language"), "\(promptID.rawValue) must follow the user's input language")
            XCTAssertGreaterThan(template.outputSchemaVersion, 0)
        }
    }

    func testOrganizeCardsTemplate_requiresEditableCardsAndSensitivity() {
        let template = provider.template(for: .organizeCards, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("editable thinking cards"))
        XCTAssertTrue(text.contains("Do not summarize into one article"))
        XCTAssertTrue(text.contains("<CARD>"))
        XCTAssertTrue(text.contains("<SENSITIVITY>"))
        XCTAssertTrue(text.contains("possibly_sensitive"))
    }

    func testGenerateQuestionsTemplate_requiresLensSpecificConcreteQuestions() {
        let template = provider.template(for: .generateQuestions, mode: .deep)
        let text = template.userText

        XCTAssertTrue(text.contains("lens-specific"))
        XCTAssertTrue(text.contains("Do not ask generic self-help questions"))
        XCTAssertTrue(text.contains("challenge a hidden assumption"))
        XCTAssertTrue(text.contains("\"questions\""))
        XCTAssertTrue(text.contains("\"expected_answer_type\""))
        XCTAssertTrue(text.contains("deep 4-5"))
    }

    func testGenerateQuestsTemplate_requiresOneMainQuestAndVerifiableCriteria() {
        let template = provider.template(for: .generateQuests, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("exactly one main quest"))
        XCTAssertTrue(text.contains("highest-value action"))
        XCTAssertTrue(text.contains("completion criteria"))
        XCTAssertTrue(text.contains("\"main_quest\""))
        XCTAssertTrue(text.contains("\"linked_cards\""))
        XCTAssertTrue(text.contains("rather than inventing a task"))
    }

    func testExtractPrincipleTemplate_rejectsSituationalLessonsAndRequiresBehaviorRule() {
        let template = provider.template(for: .extractPrinciple, mode: .standard)
        let text = template.userText

        XCTAssertTrue(text.contains("at most one reusable principle"))
        XCTAssertTrue(text.contains("too situational"))
        XCTAssertTrue(text.contains("behavior rule"))
        XCTAssertTrue(text.contains("\"principle_candidate\""))
        XCTAssertTrue(text.contains("\"source_card_titles\""))
    }

    func testModeGuidance_changesBySessionMode() {
        let quick = provider.template(for: .generateQuestions, mode: .quick)
        let standard = provider.template(for: .generateQuestions, mode: .standard)
        let deep = provider.template(for: .generateQuestions, mode: .deep)

        XCTAssertTrue(quick.userText.contains("quick 1-2"))
        XCTAssertTrue(standard.systemText.contains("standard is the default full loop"))
        XCTAssertTrue(deep.systemText.contains("deep uses more scrutiny"))
        XCTAssertTrue(deep.userText.contains("stronger opposing-view question"))
    }
}
