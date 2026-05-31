import XCTest
@testable import MingSi

final class TodayAIResponseParserTests: XCTestCase {

    private var parser: TodayAIResponseParser!

    override func setUp() {
        super.setUp()
        parser = TodayAIResponseParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - parseCards

    func testParseCards_validJSON_returnsCards() throws {
        let json = """
        {
          "cards": [
            {
              "type": "problem",
              "title": "Meeting goal unclear",
              "body": "Discussion moved across several topics.",
              "importance": "high",
              "sensitivity": "normal",
              "confidence": "high",
              "reason": "Unclear alignment."
            },
            {
              "type": "task",
              "title": "Clarify ownership",
              "body": "Confirm owner and acceptance criteria.",
              "importance": "medium",
              "sensitivity": "normal",
              "confidence": "medium",
              "reason": "Concrete next action."
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].type, .problem)
        XCTAssertEqual(cards[0].title, "Meeting goal unclear")
        XCTAssertEqual(cards[0].priority, .high)
        XCTAssertEqual(cards[0].isConfirmed, false)
        XCTAssertEqual(cards[1].type, .task)
        XCTAssertEqual(cards[1].priority, .medium)
    }

    func testParseCards_wrappedInChatEnvelope_extractsContent() throws {
        let json = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"cards\\": [{\\"type\\": \\"fact\\", \\"title\\": \\"Test\\", \\"body\\": \\"Body\\", \\"importance\\": \\"low\\", \\"sensitivity\\": \\"normal\\", \\"confidence\\": \\"low\\", \\"reason\\": \\"\\"}]}"
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].type, .fact)
    }

    func testParseCards_wrappedInCodeBlocks_extractsJSON() throws {
        let json = """
        ```json
        {
          "cards": [
            {
              "type": "idea",
              "title": "New approach",
              "body": "Try a different method.",
              "importance": "medium",
              "sensitivity": "normal",
              "confidence": "medium",
              "reason": "Worth exploring."
            }
          ]
        }
        ```
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].type, .idea)
    }

    func testParseCards_missingOptionalFields_usesDefaults() throws {
        let json = """
        {
          "cards": [
            {
              "type": "risk",
              "title": "Technical debt",
              "body": "Accumulating without plan.",
              "importance": "high",
              "sensitivity": "sensitive",
              "confidence": "medium",
              "reason": "Pattern observed."
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sensitivity, .sensitive)
        XCTAssertEqual(cards[0].confidence, 0.72)
    }

    func testParseCards_emptyTitleBody_filtersOutCard() throws {
        let json = """
        {
          "cards": [
            {
              "type": "decision",
              "title": "",
              "body": "",
              "importance": "low",
              "sensitivity": "normal",
              "confidence": "high",
              "reason": "Important observation"
            }
          ]
        }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try parser.parseCards(from: data)) { error in
            if let parsingError = error as? TodayAIParsingError {
                XCTAssertEqual(parsingError, .emptyResult)
            }
        }
    }

    func testParseCards_emptyTitleOnly_usesFallbackTitle() throws {
        let json = """
        {
          "cards": [
            {
              "type": "decision",
              "title": "",
              "body": "Has body content",
              "importance": "low",
              "sensitivity": "normal",
              "confidence": "high",
              "reason": "Important observation"
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "未命名卡片")
        XCTAssertEqual(cards[0].body, "Has body content")
    }

    func testParseCards_allEmptyCards_throwsEmptyResult() {
        let json = """
        { "cards": [] }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try parser.parseCards(from: data)) { error in
            XCTAssertTrue(error is TodayAIParsingError)
            if let parsingError = error as? TodayAIParsingError {
                XCTAssertEqual(parsingError, .emptyResult)
            }
        }
    }

    func testParseCards_invalidJSON_throwsInvalidJSON() {
        let data = Data("not json at all".utf8)

        XCTAssertThrowsError(try parser.parseCards(from: data)) { error in
            XCTAssertTrue(error is TodayAIParsingError)
        }
    }

    func testParseCards_unknownCardType_fallsBackToIdea() throws {
        let json = """
        {
          "cards": [
            {
              "type": "unknown_type",
              "title": "Something",
              "body": "Details here.",
              "importance": "medium",
              "sensitivity": "normal",
              "confidence": "high",
              "reason": ""
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards[0].type, .idea)
    }

    func testParseCards_hyphenatedEnumValues_normalizesCorrectly() throws {
        let json = """
        {
          "cards": [
            {
              "type": "communication",
              "title": "Team sync",
              "body": "Discussed priorities.",
              "importance": "medium",
              "sensitivity": "possibly_sensitive",
              "confidence": "medium",
              "reason": ""
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards[0].type, .communication)
        XCTAssertEqual(cards[0].sensitivity, .possiblySensitive)
    }

    // MARK: - parseQuestions

    func testParseQuestions_validJSON_returnsQuestions() throws {
        let json = """
        {
          "questions": [
            {
              "question": "What is the highest-value action?",
              "why_this_matters": "Forces prioritization."
            },
            {
              "question": "What evidence supports this?",
              "why_this_matters": "Checks assumptions."
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let questions = try parser.parseQuestions(from: data)

        XCTAssertEqual(questions.count, 2)
        XCTAssertEqual(questions[0].question, "What is the highest-value action?")
        XCTAssertEqual(questions[0].whyItMatters, "Forces prioritization.")
    }

    func testParseQuestions_missingWhyThisMatters_usesFallback() throws {
        let json = """
        {
          "questions": [
            {
              "question": "What should change?",
              "why_this_matters": ""
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let questions = try parser.parseQuestions(from: data)

        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions[0].whyItMatters, "帮助把今天的判断转成可验证行动。")
    }

    func testParseQuestions_emptyQuestionArray_throwsEmptyResult() {
        let json = """
        { "questions": [] }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try parser.parseQuestions(from: data)) { error in
            if let parsingError = error as? TodayAIParsingError {
                XCTAssertEqual(parsingError, .emptyResult)
            }
        }
    }

    // MARK: - parseQuests

    func testParseQuests_validJSON_returnsMainAndSideQuests() throws {
        let json = """
        {
          "main_quest": {
            "type": "main",
            "title": "Confirm interface ownership",
            "why_it_matters": "Reduces rework risk.",
            "completion_criteria": "Owner and acceptance criteria confirmed.",
            "expected_resistance": "Cross-role discussion needed.",
            "reflection_question": "Which rework risk is lower?"
          },
          "side_quests": [
            {
              "type": "side",
              "title": "Send decision summary",
              "why_it_matters": "Keeps decision visible.",
              "completion_criteria": "Summary sent.",
              "expected_resistance": "Easy to expand.",
              "reflection_question": "Was it useful?"
            }
          ],
          "observation_quest": {
            "type": "observation",
            "title": "Watch for ambiguity",
            "why_it_matters": "Trains detection.",
            "completion_criteria": "One note written.",
            "expected_resistance": "Easy to miss.",
            "reflection_question": "What signal revealed it?"
          }
        }
        """
        let data = Data(json.utf8)

        let quests = try parser.parseQuests(from: data)

        XCTAssertEqual(quests.count, 3)
        XCTAssertEqual(quests[0].type, .main)
        XCTAssertEqual(quests[0].status, .draft)
        XCTAssertEqual(quests[1].type, .side)
        XCTAssertEqual(quests[2].type, .observation)
    }

    func testParseQuests_missingMainQuest_throwsEmptyResult() {
        let json = """
        {
          "main_quest": null,
          "side_quests": [],
          "observation_quest": null
        }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try parser.parseQuests(from: data)) { error in
            if let parsingError = error as? TodayAIParsingError {
                XCTAssertEqual(parsingError, .emptyResult)
            }
        }
    }

    func testParseQuests_emptyCompletionCriteria_skipsQuest() throws {
        let json = """
        {
          "main_quest": {
            "type": "main",
            "title": "Do something",
            "why_it_matters": "Important.",
            "completion_criteria": "",
            "expected_resistance": "None",
            "reflection_question": "What changed?"
          }
        }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try parser.parseQuests(from: data)) { error in
            if let parsingError = error as? TodayAIParsingError {
                XCTAssertEqual(parsingError, .emptyResult)
            }
        }
    }

    func testParseQuests_missingOptionalFields_usesFallbacks() throws {
        let json = """
        {
          "main_quest": {
            "type": "main",
            "title": "Valid quest",
            "why_it_matters": "Important",
            "completion_criteria": "Done when verified."
          }
        }
        """
        let data = Data(json.utf8)

        let quests = try parser.parseQuests(from: data)

        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests[0].expectedResistance, "容易被临时事务打断。")
        XCTAssertEqual(quests[0].reflectionQuestion, "完成后，哪个关键判断被验证了？")
    }

    // MARK: - parsePrinciples

    func testParsePrinciples_validPrinciple_returnsPrinciple() throws {
        let json = """
        {
          "principle_candidate": {
            "title": "Clarify before execution",
            "summary": "Make ownership explicit before proceeding.",
            "trigger_context": "Cross-functional work.",
            "actions": ["Name the decision.", "Write owner and criteria."],
            "success_criteria": "People know who owns what.",
            "exceptions": "Low-stakes sync."
          }
        }
        """
        let data = Data(json.utf8)

        let principles = try parser.parsePrinciples(from: data)

        XCTAssertEqual(principles.count, 1)
        XCTAssertEqual(principles[0].title, "Clarify before execution")
        XCTAssertEqual(principles[0].actions.count, 2)
    }

    func testParsePrinciples_nullCandidate_returnsEmpty() throws {
        let json = """
        { "principle_candidate": null }
        """
        let data = Data(json.utf8)

        let principles = try parser.parsePrinciples(from: data)

        XCTAssertTrue(principles.isEmpty)
    }

    func testParsePrinciples_emptyActions_returnsEmpty() throws {
        let json = """
        {
          "principle_candidate": {
            "title": "Some title",
            "summary": "Some summary",
            "trigger_context": "Context",
            "actions": [],
            "success_criteria": "Criteria",
            "exceptions": "None"
          }
        }
        """
        let data = Data(json.utf8)

        let principles = try parser.parsePrinciples(from: data)

        XCTAssertTrue(principles.isEmpty)
    }

    func testParsePrinciples_missingOptionalFields_usesFallbacks() throws {
        let json = """
        {
          "principle_candidate": {
            "title": "Valid",
            "summary": "Summary text",
            "trigger_context": "",
            "actions": ["Do something"],
            "success_criteria": "",
            "exceptions": ""
          }
        }
        """
        let data = Data(json.utf8)

        let principles = try parser.parsePrinciples(from: data)

        XCTAssertEqual(principles.count, 1)
        XCTAssertEqual(principles[0].triggerContext, "适用于类似的复盘场景。")
        XCTAssertEqual(principles[0].successCriteria, "行动结果可被检查。")
        XCTAssertEqual(principles[0].exceptions, "低风险场景可简化。")
    }

    // MARK: - Confidence mapping

    func testParseCards_confidenceHigh_returns086() throws {
        let cards = try parseSingleCard(confidence: "high")
        XCTAssertEqual(cards.confidence, 0.86, accuracy: 0.01)
    }

    func testParseCards_confidenceMedium_returns072() throws {
        let cards = try parseSingleCard(confidence: "medium")
        XCTAssertEqual(cards.confidence, 0.72, accuracy: 0.01)
    }

    func testParseCards_confidenceLow_returns048() throws {
        let cards = try parseSingleCard(confidence: "low")
        XCTAssertEqual(cards.confidence, 0.48, accuracy: 0.01)
    }

    func testParseCards_confidenceNumeric0to1_returnsDirectly() throws {
        let cards = try parseSingleCard(confidence: "0.65")
        XCTAssertEqual(cards.confidence, 0.65, accuracy: 0.01)
    }

    func testParseCards_confidenceNumericPercentage_convertsTo0to1() throws {
        let cards = try parseSingleCard(confidence: "75")
        XCTAssertEqual(cards.confidence, 0.75, accuracy: 0.01)
    }

    func testParseCards_confidenceUnknown_returns064() throws {
        let cards = try parseSingleCard(confidence: "very_high")
        XCTAssertEqual(cards.confidence, 0.64, accuracy: 0.01)
    }

    // MARK: - Helper

    private func parseSingleCard(confidence: String) throws -> ThinkingCard {
        let json = """
        {
          "cards": [
            {
              "type": "fact",
              "title": "Test",
              "body": "Body",
              "importance": "medium",
              "sensitivity": "normal",
              "confidence": "\(confidence)",
              "reason": ""
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let cards = try parser.parseCards(from: data)
        return cards[0]
    }
}
