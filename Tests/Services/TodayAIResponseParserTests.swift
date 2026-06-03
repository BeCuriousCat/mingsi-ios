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

    // MARK: - parseVerification

    func testParseVerification_validJSON_returnsCalibrationResult() throws {
        let json = """
        {
          "calibration_note": "The quest was useful but the completion evidence was weak.",
          "likely_issue": "unclear_criteria",
          "recommendation": "Define one visible artifact before starting tomorrow."
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseVerification(from: data)

        XCTAssertEqual(result.calibrationNote, "The quest was useful but the completion evidence was weak.")
        XCTAssertEqual(result.likelyIssue, "unclear_criteria")
        XCTAssertEqual(result.recommendation, "Define one visible artifact before starting tomorrow.")
    }

    func testParseVerification_emptyNote_throwsEmptyResult() {
        let json = """
        {
          "calibration_note": "",
          "likely_issue": "none",
          "recommendation": "Keep going."
        }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try parser.parseVerification(from: data)) { error in
            XCTAssertEqual(error as? TodayAIParsingError, .emptyResult)
        }
    }

    // MARK: - parseProjectSuggestions

    func testParseProjectSuggestions_existingLinkAndNewCandidate_returnsEvidenceBackedResults() throws {
        let projectId = UUID()
        let json = """
        {
          "project_link_candidates": [
            {
              "project_id": "\(projectId.uuidString)",
              "candidate_project_name": null,
              "link_type": "blocker",
              "source_type": "thinking_card",
              "source_id": "card-123",
              "reason": "The blocker matches an active project.",
              "confidence": "high",
              "requires_user_confirmation": true
            }
          ],
          "new_project_candidates": [
            {
              "candidate_project_name": "Cross-team ownership clarity",
              "goal": "Make ownership explicit before implementation work starts.",
              "current_bottleneck": "Responsibility boundaries keep surfacing after meetings.",
              "success_criteria": "Every cross-team decision has one owner and visible acceptance criteria.",
              "why_this_is_long_running": "The same ownership ambiguity appears across multiple planning loops.",
              "source_refs": [
                {
                  "source_type": "thinking_card",
                  "source_id": "card-456"
                },
                {
                  "source_type": "quest",
                  "source_id": "quest-789"
                }
              ],
              "privacy_safe_name_required": true,
              "confidence": "medium"
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseProjectSuggestions(from: data)

        XCTAssertEqual(result.projectLinks.count, 1)
        XCTAssertEqual(result.projectLinks[0].projectId, projectId)
        XCTAssertEqual(result.projectLinks[0].sourceType, .thinkingCard)
        XCTAssertEqual(result.projectLinks[0].sourceId, "card-123")
        XCTAssertEqual(result.projectLinks[0].linkType, .blocker)
        XCTAssertEqual(result.projectLinks[0].confidence, 0.86, accuracy: 0.01)
        XCTAssertFalse(result.projectLinks[0].isUserConfirmed)

        XCTAssertEqual(result.projectCandidates.count, 1)
        XCTAssertEqual(result.projectCandidates[0].suggestedName, "Cross-team ownership clarity")
        XCTAssertEqual(result.projectCandidates[0].suggestedGoal, "Make ownership explicit before implementation work starts.")
        XCTAssertEqual(result.projectCandidates[0].suggestedBottleneck, "Responsibility boundaries keep surfacing after meetings.")
        XCTAssertEqual(result.projectCandidates[0].suggestedSuccessCriteria, "Every cross-team decision has one owner and visible acceptance criteria.")
        XCTAssertEqual(result.projectCandidates[0].reason, "The same ownership ambiguity appears across multiple planning loops.")
        XCTAssertEqual(result.projectCandidates[0].sourceRefs, ["card-456", "quest-789"])
        XCTAssertEqual(result.projectCandidates[0].status, .pending)
        XCTAssertEqual(result.projectCandidates[0].createdBy, .aiSuggested)
        XCTAssertEqual(result.projectCandidates[0].confidence, 0.72, accuracy: 0.01)
    }

    func testParseProjectSuggestions_missingEvidence_skipsProjectOutputs() throws {
        let projectId = UUID()
        let json = """
        {
          "project_link_candidates": [
            {
              "project_id": "\(projectId.uuidString)",
              "candidate_project_name": null,
              "link_type": "evidence",
              "source_type": "thinking_card",
              "source_id": "",
              "reason": "No source id should make this unusable.",
              "confidence": "high",
              "requires_user_confirmation": true
            },
            {
              "project_id": "\(projectId.uuidString)",
              "candidate_project_name": null,
              "link_type": "decision",
              "source_type": "quest",
              "source_id": "quest-valid",
              "reason": "A concrete source exists.",
              "confidence": "medium",
              "requires_user_confirmation": true
            }
          ],
          "new_project_candidates": [
            {
              "candidate_project_name": "No evidence project",
              "goal": "Should not be created.",
              "current_bottleneck": "Missing evidence.",
              "success_criteria": "N/A",
              "why_this_is_long_running": "Claimed but unsupported.",
              "source_refs": [],
              "privacy_safe_name_required": true,
              "confidence": "high"
            },
            {
              "candidate_project_name": "Supported recurring topic",
              "goal": "Reduce repeated ambiguity.",
              "current_bottleneck": "The same question keeps returning.",
              "success_criteria": "A visible owner is named before handoff.",
              "why_this_is_long_running": "Multiple confirmed sources point to the same pattern.",
              "source_refs": [
                {
                  "source_type": "daily_entry",
                  "source_id": "entry-valid"
                }
              ],
              "privacy_safe_name_required": true,
              "confidence": "low"
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseProjectSuggestions(from: data)

        XCTAssertEqual(result.projectLinks.map(\.sourceId), ["quest-valid"])
        XCTAssertEqual(result.projectCandidates.map(\.suggestedName), ["Supported recurring topic"])
        XCTAssertEqual(result.projectCandidates[0].sourceRefs, ["entry-valid"])
    }

    // MARK: - parseProjectInsights

    func testParseProjectInsights_progressInsight_returnsEvidenceBackedInsight() throws {
        let projectId = UUID()
        let json = """
        {
          "project_insights": [
            {
              "project_id": "\(projectId.uuidString)",
              "insight_type": "progress",
              "title": "Decision owner is now explicit",
              "summary": "The latest quest names the owner before implementation starts.",
              "before": null,
              "after": null,
              "source_refs": ["quest-123"],
              "confidence": "high"
            }
          ],
          "insufficient_evidence_reason": null
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseProjectInsights(from: data)

        XCTAssertNil(result.insufficientEvidenceReason)
        XCTAssertEqual(result.insights.count, 1)
        XCTAssertEqual(result.insights[0].projectId, projectId)
        XCTAssertEqual(result.insights[0].insightType, .progress)
        XCTAssertEqual(result.insights[0].title, "Decision owner is now explicit")
        XCTAssertEqual(result.insights[0].summary, "The latest quest names the owner before implementation starts.")
        XCTAssertEqual(result.insights[0].sourceRefs, ["quest-123"])
        XCTAssertEqual(result.insights[0].confidence, 0.86, accuracy: 0.01)
    }

    func testParseProjectInsights_thinkingChangeMissingBeforeOrAfter_skipsInvalidInsights() throws {
        let projectId = UUID()
        let json = """
        {
          "project_insights": [
            {
              "project_id": "\(projectId.uuidString)",
              "insight_type": "thinking_change",
              "title": "Missing before",
              "summary": "Should be rejected.",
              "after": {
                "text": "Now the concern is ownership.",
                "source_type": "thinking_card",
                "source_id": "card-after"
              },
              "source_refs": ["card-after"],
              "confidence": "medium"
            },
            {
              "project_id": "\(projectId.uuidString)",
              "insight_type": "thinking_change",
              "title": "Missing after",
              "summary": "Should also be rejected.",
              "before": {
                "text": "Earlier concern was general speed.",
                "source_type": "thinking_card",
                "source_id": "card-before"
              },
              "source_refs": ["card-before"],
              "confidence": "medium"
            },
            {
              "project_id": "\(projectId.uuidString)",
              "insight_type": "thinking_change",
              "title": "Problem framing changed",
              "summary": "The project shifted from generic speed to explicit ownership.",
              "before": {
                "text": "We need to move faster.",
                "source_type": "thinking_card",
                "source_id": "card-before-valid"
              },
              "after": {
                "text": "We need one owner before implementation starts.",
                "source_type": "quest",
                "source_id": "quest-after-valid"
              },
              "source_refs": ["card-before-valid", "quest-after-valid"],
              "confidence": "medium"
            }
          ],
          "insufficient_evidence_reason": null
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseProjectInsights(from: data)

        XCTAssertEqual(result.insights.count, 1)
        XCTAssertEqual(result.insights[0].insightType, .thinkingChange)
        XCTAssertEqual(result.insights[0].title, "Problem framing changed")
        XCTAssertEqual(result.insights[0].beforeText, "We need to move faster.")
        XCTAssertEqual(result.insights[0].afterText, "We need one owner before implementation starts.")
        XCTAssertEqual(result.insights[0].sourceRefs, ["card-before-valid", "quest-after-valid"])
    }

    func testParseProjectInsights_blockerChangeMissingBeforeOrAfter_skipsInvalidInsights() throws {
        let projectId = UUID()
        let json = """
        {
          "project_insights": [
            {
              "project_id": "\(projectId.uuidString)",
              "insight_type": "blocker_change",
              "title": "Missing transition evidence",
              "summary": "Should be rejected because blocker changes require before and after.",
              "source_refs": ["card-blocker"],
              "confidence": "medium"
            },
            {
              "project_id": "\(projectId.uuidString)",
              "insight_type": "blocker_change",
              "title": "Blocker became explicit",
              "summary": "The bottleneck moved from vague delay to a concrete owner gap.",
              "before": {
                "text": "Progress feels slow.",
                "source_type": "thinking_card",
                "source_id": "card-before-blocker"
              },
              "after": {
                "text": "The missing owner blocks the next decision.",
                "source_type": "quest",
                "source_id": "quest-after-blocker"
              },
              "source_refs": ["card-before-blocker", "quest-after-blocker"],
              "confidence": "medium"
            }
          ],
          "insufficient_evidence_reason": null
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseProjectInsights(from: data)

        XCTAssertEqual(result.insights.count, 1)
        XCTAssertEqual(result.insights[0].insightType, .blockerChange)
        XCTAssertEqual(result.insights[0].beforeText, "Progress feels slow.")
        XCTAssertEqual(result.insights[0].afterText, "The missing owner blocks the next decision.")
        XCTAssertEqual(result.insights[0].sourceRefs, ["card-before-blocker", "quest-after-blocker"])
    }

    func testParseProjectInsights_onlyInsufficientEvidenceReason_returnsEmptyInsightsAndReason() throws {
        let json = """
        {
          "project_insights": [],
          "insufficient_evidence_reason": "Need at least two confirmed project links from different days."
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseProjectInsights(from: data)

        XCTAssertTrue(result.insights.isEmpty)
        XCTAssertEqual(result.insufficientEvidenceReason, "Need at least two confirmed project links from different days.")
    }

    // MARK: - parseProjectMergeCandidates

    func testParseProjectMergeCandidates_validUUIDsAndEvidenceRefs_returnsMergeCandidate() throws {
        let sourceProjectId = UUID()
        let targetProjectId = UUID()
        let json = """
        {
          "merge_candidates": [
            {
              "source_project_id": "\(sourceProjectId.uuidString)",
              "target_project_id": "\(targetProjectId.uuidString)",
              "reason": "Both projects track the same repeated ownership ambiguity.",
              "overlapping_evidence_refs": ["link-1", "verification-2"],
              "risks_if_merged": ["One narrow context may get hidden."],
              "risks_if_kept_separate": ["Evidence remains split across duplicate projects."],
              "confidence": "high"
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let candidates = try parser.parseProjectMergeCandidates(from: data)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].sourceProjectId, sourceProjectId)
        XCTAssertEqual(candidates[0].targetProjectId, targetProjectId)
        XCTAssertEqual(candidates[0].reason, "Both projects track the same repeated ownership ambiguity.")
        XCTAssertEqual(candidates[0].overlappingEvidenceRefs, ["link-1", "verification-2"])
        XCTAssertEqual(candidates[0].status, .pending)
    }

    func testParseProjectMergeCandidates_missingEvidenceRefsOrInvalidUUID_skipsInvalidCandidates() throws {
        let sourceProjectId = UUID()
        let targetProjectId = UUID()
        let json = """
        {
          "merge_candidates": [
            {
              "source_project_id": "\(sourceProjectId.uuidString)",
              "target_project_id": "\(targetProjectId.uuidString)",
              "reason": "No overlap evidence should reject this.",
              "overlapping_evidence_refs": [],
              "risks_if_merged": [],
              "risks_if_kept_separate": [],
              "confidence": "medium"
            },
            {
              "source_project_id": "not-a-uuid",
              "target_project_id": "\(targetProjectId.uuidString)",
              "reason": "Invalid UUID should reject this.",
              "overlapping_evidence_refs": ["link-invalid"],
              "risks_if_merged": [],
              "risks_if_kept_separate": [],
              "confidence": "medium"
            },
            {
              "source_project_id": "\(sourceProjectId.uuidString)",
              "target_project_id": "\(targetProjectId.uuidString)",
              "reason": "This one has valid project ids and evidence.",
              "overlapping_evidence_refs": ["link-valid"],
              "risks_if_merged": [],
              "risks_if_kept_separate": [],
              "confidence": "medium"
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let candidates = try parser.parseProjectMergeCandidates(from: data)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].sourceProjectId, sourceProjectId)
        XCTAssertEqual(candidates[0].targetProjectId, targetProjectId)
        XCTAssertEqual(candidates[0].overlappingEvidenceRefs, ["link-valid"])
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

    // MARK: - parseGrowthReport

    func testParseGrowthReport_validWeeklyReport_returnsSnapshotAndContributions() throws {
        let entryId1 = UUID()
        let entryId2 = UUID()
        let cardId1 = UUID()
        let questId1 = UUID()
        let verificationId1 = UUID()
        let json = """
        {
          "insufficient_evidence": false,
          "summary": "本周对会议类问题的定义更清楚，执行可靠性有提升。",
          "metrics": {
            "clarity": {"value": 3.8, "delta": 0.3, "reason": "多次任务完成标准更具体"},
            "value_judgment": {"value": 3.5, "delta": 0.2, "reason": "高价值任务占比提升"},
            "execution_reliability": {"value": 3.4, "delta": 0.4, "reason": "主线任务完成率提升"},
            "calibration": {"value": 3.0, "delta": 0.0, "reason": "校准证据不足"},
            "reflection_depth": {"value": 3.6, "delta": 0.3, "reason": "透镜追问回答更深入"}
          },
          "metric_contributions": [
            {
              "metric": "clarity",
              "direction": "positive",
              "delta": 0.15,
              "title": "任务完成标准更具体",
              "reason": "主线任务包含可验证的完成标准。",
              "source_type": "quest",
              "source_id": "\(questId1.uuidString)",
              "source_daily_entry_id": "\(entryId1.uuidString)"
            },
            {
              "metric": "execution_reliability",
              "direction": "positive",
              "delta": 0.14,
              "title": "主线任务完成",
              "reason": "次日验证显示主线任务已完成。",
              "source_type": "verification",
              "source_id": "\(verificationId1.uuidString)",
              "source_daily_entry_id": "\(entryId2.uuidString)"
            }
          ],
          "next_training_focus": "继续把明日任务写成可验证结果，并在第二天做价值校准。"
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseGrowthReport(from: data, period: "weekly", completeLoopCount: 5)

        XCTAssertFalse(result.snapshot.hasInsufficientEvidence)
        XCTAssertTrue(result.snapshot.canDisplayScores)
        XCTAssertEqual(result.snapshot.period, "weekly")
        XCTAssertEqual(result.snapshot.clarity, 3.8, accuracy: 0.01)
        XCTAssertEqual(result.snapshot.valueJudgment, 3.5, accuracy: 0.01)
        XCTAssertEqual(result.snapshot.completeLoopCount, 5)
        XCTAssertEqual(result.snapshot.nextTrainingFocus, "继续把明日任务写成可验证结果，并在第二天做价值校准。")
        XCTAssertEqual(result.snapshot.status, .draftReview)
        XCTAssertEqual(result.contributions.count, 2)
        XCTAssertEqual(result.contributions[0].metric, .clarity)
        XCTAssertEqual(result.contributions[0].direction, .positive)
        XCTAssertEqual(result.contributions[0].sourceDailyEntryId, entryId1)
        XCTAssertEqual(result.contributions[1].metric, .executionReliability)
        XCTAssertEqual(result.contributions[1].sourceDailyEntryId, entryId2)
        XCTAssertEqual(result.contributions[0].snapshotId, result.snapshot.id)
        XCTAssertEqual(result.contributions[1].snapshotId, result.snapshot.id)
    }

    func testParseGrowthReport_insufficientEvidence_returnsInsufficientStatusAndNoContributions() throws {
        let json = """
        {
          "insufficient_evidence": true,
          "summary": "完成 2 次完整复盘，需要至少 3 次才能生成可解释的成长趋势。",
          "metrics": {},
          "metric_contributions": [],
          "next_training_focus": "先稳定完成输入、卡片确认、明日任务和次日验证。"
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseGrowthReport(from: data, period: "weekly", completeLoopCount: 2)

        XCTAssertTrue(result.snapshot.hasInsufficientEvidence)
        XCTAssertFalse(result.snapshot.canDisplayScores)
        XCTAssertEqual(result.snapshot.status, .insufficientEvidence)
        XCTAssertEqual(result.snapshot.completeLoopCount, 2)
        XCTAssertTrue(result.contributions.isEmpty)
    }

    func testParseGrowthReport_contributionMissingSourceFields_rejected() throws {
        let entryId = UUID()
        let json = """
        {
          "insufficient_evidence": false,
          "summary": "Valid summary.",
          "metrics": {
            "clarity": {"value": 3.5, "delta": 0.2, "reason": "test"}
          },
          "metric_contributions": [
            {
              "metric": "clarity",
              "direction": "positive",
              "delta": 0.15,
              "title": "No source entry",
              "reason": "Missing sourceDailyEntryId.",
              "source_type": "quest",
              "source_id": "some-id",
              "source_daily_entry_id": ""
            },
            {
              "metric": "clarity",
              "direction": "positive",
              "delta": 0.10,
              "title": "No source type",
              "reason": "Missing sourceType.",
              "source_type": "",
              "source_id": "some-id",
              "source_daily_entry_id": "\(entryId.uuidString)"
            },
            {
              "metric": "clarity",
              "direction": "positive",
              "delta": 0.12,
              "title": "Valid contribution",
              "reason": "All fields present.",
              "source_type": "quest",
              "source_id": "quest-123",
              "source_daily_entry_id": "\(entryId.uuidString)"
            }
          ],
          "next_training_focus": "test"
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseGrowthReport(from: data, period: "weekly", completeLoopCount: 4)

        XCTAssertEqual(result.contributions.count, 1)
        XCTAssertEqual(result.contributions[0].title, "Valid contribution")
        XCTAssertEqual(result.contributions[0].sourceDailyEntryId, entryId)
    }

    func testParseGrowthReport_deltaClamped_remainsExplainable() throws {
        let entryId = UUID()
        let json = """
        {
          "insufficient_evidence": false,
          "summary": "Large delta test.",
          "metrics": {
            "clarity": {"value": 4.5, "delta": 0.8, "reason": "test"}
          },
          "metric_contributions": [
            {
              "metric": "clarity",
              "direction": "positive",
              "delta": 0.99,
              "title": "Excessive delta",
              "reason": "Should be clamped to 0.30.",
              "source_type": "quest",
              "source_id": "quest-1",
              "source_daily_entry_id": "\(entryId.uuidString)"
            }
          ],
          "next_training_focus": "test"
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseGrowthReport(from: data, period: "weekly", completeLoopCount: 5)

        XCTAssertEqual(result.contributions.count, 1)
        XCTAssertLessThanOrEqual(result.contributions[0].delta, 0.30)
        XCTAssertGreaterThanOrEqual(result.contributions[0].delta, 0.01)
    }

    func testParseGrowthReport_missingInsufficientFlag_defaultsToDraft() throws {
        let json = """
        {
          "summary": "No insufficient flag.",
          "metrics": {
            "clarity": {"value": 3.5, "delta": 0.2, "reason": "test"}
          },
          "metric_contributions": [],
          "next_training_focus": "test"
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseGrowthReport(from: data, period: "monthly", completeLoopCount: 6)

        XCTAssertEqual(result.snapshot.status, .draftReview)
        XCTAssertEqual(result.snapshot.period, "monthly")
    }

    func testParseGrowthReport_emptyMetrics_usesBaselineScores() throws {
        let json = """
        {
          "insufficient_evidence": false,
          "summary": "Empty metrics.",
          "metrics": {},
          "metric_contributions": [],
          "next_training_focus": "test"
        }
        """
        let data = Data(json.utf8)

        let result = try parser.parseGrowthReport(from: data, period: "weekly", completeLoopCount: 5)

        XCTAssertEqual(result.snapshot.clarity, 3.0, accuracy: 0.01)
        XCTAssertEqual(result.snapshot.valueJudgment, 3.0, accuracy: 0.01)
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
