import XCTest
@testable import MingSi

final class TodayAIServiceContextTests: XCTestCase {

    func testOrganizeCards_doesNotInjectPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let principle = PrincipleAsset(
            title: "Clarify before meetings",
            summary: "Write decisions before meeting.",
            triggerContext: "meeting",
            actions: ["Write decision list"],
            successCriteria: "People know next actions.",
            exceptions: "Casual sync"
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "meeting ownership was unclear"),
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertNil(request.jsonPayload["relevantPrinciples"])
        XCTAssertFalse(request.contextRecordIDs.contains(principle.id.uuidString))
        XCTAssertEqual(request.contextVersion, 1)
    }

    func testOrganizeCards_exposesStructuredContextPayloadWithoutPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.cardsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let principle = PrincipleAsset(
            title: "Clarify before meetings",
            summary: "Write decisions before meeting.",
            triggerContext: "meeting",
            actions: ["Write decision list"],
            successCriteria: "People know next actions.",
            exceptions: "Casual sync"
        )

        _ = try await service.organizeCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "meeting ownership was unclear",
                    sessionMode: .quick
                ),
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.currentInput.rawText, "meeting ownership was unclear")
        XCTAssertEqual(payload.userChoice.sessionMode, SessionMode.quick.rawValue)
        XCTAssertTrue(try XCTUnwrap(payload.privacy.rules).contains("confidential"))
        XCTAssertTrue(payload.principles.isEmpty)
    }

    func testStreamOrganizedCards_yieldsDraftUpdatesAndReturnsDomainCards() async throws {
        let client = StreamingCapturingLLMClient(tokens: [
            "<MINGSI_STREAM version=\"1\"><CARD><TYPE>problem</TYPE><TITLE>",
            "会议目标不清楚</TITLE><BODY>会前没有列出必须确认的问题。</BODY>",
            "<IMPORTANCE>high</IMPORTANCE><SENSITIVITY>normal</SENSITIVITY><CONFIDENCE>high</CONFIDENCE><REASON>影响结论质量</REASON></CARD></MINGSI_STREAM>"
        ])
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        var updates: [[StreamingCardDraft]] = []

        let cards = try await service.streamOrganizedCards(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "今天开会但目标不清楚。",
                    sessionMode: .standard,
                    hasSelectedSessionMode: true
                )
            ),
            onUpdate: { drafts in updates.append(drafts) }
        )

        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].title, "会议目标不清楚")
        XCTAssertEqual(cards[0].priority, .high)
        XCTAssertFalse(updates.isEmpty)
        XCTAssertEqual(client.requests.first?.jsonPayload["streamProtocol"], "MINGSI_STREAM_V1")
    }

    func testOrganizeCardsPrompt_usesStreamingXMLInstructions() {
        let template = LocalPromptProvider().template(for: .organizeCards, mode: .standard)

        XCTAssertTrue(template.systemText.contains("MINGSI_STREAM_V1"))
        XCTAssertFalse(template.systemText.contains("Return valid JSON only"))
        XCTAssertTrue(template.userText.contains("<CARD>"))
        XCTAssertTrue(template.userText.contains("</CARD>"))
    }

    func testGrowthAIService_exposesStructuredGrowthContextPayload() async throws {
        let entryID = UUID()
        let client = CapturingLLMClient(response: Self.growthReportResponse(entryID: entryID))
        let previousSnapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.2,
            valueJudgment: 3.1,
            executionReliability: 3.0,
            calibration: 2.9,
            reflectionDepth: 3.3,
            summary: "previous",
            positiveContributionRefs: ["previous-positive"]
        )
        let service = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateWeeklyReport(
            context: GrowthReportContext(
                period: "weekly",
                startDate: nil,
                endDate: nil,
                completeLoopCount: 3,
                historyRecords: [
                    GrowthRecordSummary(
                        dailyEntryId: entryID,
                        date: Date(timeIntervalSince1970: 0),
                        confirmedCardCount: 2,
                        hasMainQuest: true,
                        mainQuestTitle: "Prepare meeting decision list",
                        mainQuestCompletionCriteria: "Decision list sent before meeting",
                        verificationCompletion: "done",
                        verificationValueRating: "high",
                        calibrationNote: "Prepared agenda reduced meeting drift.",
                        hasLensSessionAnswers: true,
                        principleTitles: ["Clarify before meeting"]
                    )
                ],
                previousSnapshot: previousSnapshot,
                dismissedContributionTitles: ["Overstated clarity gain"]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let growth = try XCTUnwrap(payload.growth)
        XCTAssertEqual(growth.period, "weekly")
        XCTAssertEqual(growth.completeLoopCount, 3)
        XCTAssertEqual(growth.records.map(\.dailyEntryId), [entryID.uuidString])
        XCTAssertEqual(growth.records.map(\.mainQuestTitle), ["Prepare meeting decision list"])
        XCTAssertEqual(growth.records.map(\.principleTitles), [["Clarify before meeting"]])
        XCTAssertEqual(growth.previousSnapshot?.clarity, 3.2)
        XCTAssertEqual(growth.dismissedContributionTitles, ["Overstated clarity gain"])
        XCTAssertEqual(request.jsonPayload["record_count"], "1")
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["evidence_summaries"]).contains(entryID.uuidString))
    }

    func testGenerateQuestions_injectsRelevantPrinciplesAndContextIds() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let relevantPrinciple = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )
        let unrelatedPrinciple = PrincipleAsset(
            title: "Protect deep work",
            summary: "Batch shallow notifications.",
            triggerContext: "focus time",
            actions: ["Mute notifications"],
            successCriteria: "One uninterrupted block.",
            exceptions: "Urgent incident"
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [relevantPrinciple, unrelatedPrinciple]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let relevantPrinciples = try XCTUnwrap(request.jsonPayload["relevantPrinciples"])
        XCTAssertTrue(relevantPrinciples.contains("Clarify meeting ownership"))
        XCTAssertFalse(relevantPrinciples.contains("Protect deep work"))
        XCTAssertTrue(request.contextRecordIDs.contains(relevantPrinciple.id.uuidString))
        XCTAssertFalse(request.contextRecordIDs.contains(unrelatedPrinciple.id.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(card.id.uuidString))
        XCTAssertTrue(request.inputSummary.contains("principles=Clarify meeting ownership"))
    }

    func testGenerateQuestions_exposesStructuredContextPayloadWithCardsLensModeAndPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let relevantPrinciple = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )
        let inactivePrinciple = PrincipleAsset(
            title: "Archived meeting checklist",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync",
            status: .archived
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    sessionMode: .deep,
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [relevantPrinciple, inactivePrinciple]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.cards.map(\.title), ["Meeting ownership unclear"])
        XCTAssertEqual(payload.cards.map(\.body), ["The meeting ended without owner and acceptance criteria."])
        XCTAssertEqual(payload.userChoice.selectedLens, ThinkingLens.evidenceCheck.rawValue)
        XCTAssertEqual(payload.userChoice.sessionMode, SessionMode.deep.rawValue)
        XCTAssertEqual(payload.principles.map(\.title), ["Clarify meeting ownership"])
        XCTAssertFalse(payload.principles.map(\.title).contains("Archived meeting checklist"))
    }

    func testStructuredContextPayload_keepsLegacyJSONPayloadForDirectGLMCompatibility() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .problem,
            title: "Meeting ownership unclear",
            body: "The meeting ended without owner and acceptance criteria.",
            isConfirmed: true
        )
        let principle = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "The meeting did not clarify ownership.",
                    sessionMode: .standard,
                    selectedLens: .evidenceCheck
                ),
                confirmedCards: [card],
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        _ = try XCTUnwrap(request.contextPayload)
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["confirmedCards"]).contains("Meeting ownership unclear"))
        XCTAssertEqual(request.jsonPayload["selectedLens"], "evidence_check")
        XCTAssertEqual(request.jsonPayload["sessionMode"], SessionMode.standard.rawValue)
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["principleUsageRule"]).contains("Do not force"))
    }

    // MARK: - Subtask 042: Lens Prompt Context Wiring

    func testGenerateQuestions_sendsPromptFacingLensId_forFirstPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What are the fundamentals?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.jsonPayload["selectedLens"], "first_principles")
    }

    func testGenerateQuests_sendsPromptFacingLensId_forLeverageAnalysis() async throws {
        let client = CapturingLLMClient(response: Self.questsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What is the leverage point?",
                    selectedLens: .leverageAnalysis
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.jsonPayload["selectedLens"], "leverage_analysis")
    }

    func testStructuredContext_exposesLocalSelectedLens_forFirstPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What are the fundamentals?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertEqual(payload.selectedLens, .firstPrinciples)
    }

    func testStructuredContext_exposesLensCatalogMetadata_forFirstPrinciples() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "What are the fundamentals?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let catalog = try XCTUnwrap(payload.userChoice.lensCatalog)
        XCTAssertEqual(catalog.localId, "firstPrinciples")
        XCTAssertEqual(catalog.promptId, "first_principles")
        XCTAssertEqual(catalog.version, "builtin.v1")
        XCTAssertEqual(catalog.title, "第一性原理")
    }

    func testGenerateQuests_injectsRelevantPrinciplesAndGroundingPayload() async throws {
        let client = CapturingLLMClient(response: Self.questsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let card = ThinkingCard(
            type: .task,
            title: "Prepare meeting decisions",
            body: "The next meeting needs clear owner and acceptance criteria.",
            isConfirmed: true
        )
        let question = ReflectionQuestion(
            question: "Which decision matters most?",
            whyItMatters: "It turns the lens into a concrete action.",
            answer: "Confirm owner before implementation."
        )
        let principle = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Before discussion ends, write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner", "Write acceptance criteria"],
            successCriteria: "Everyone knows who owns the next action.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.generateQuests(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "Tomorrow I need to make meeting ownership explicit.",
                    selectedLens: .leverageAnalysis
                ),
                confirmedCards: [card],
                questions: [question],
                principles: [principle]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .generateQuests)
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["confirmedCards"]).contains("Prepare meeting decisions"))
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["reflectionAnswers"]).contains("Confirm owner"))
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["principleUsageRule"]).contains("Do not force"))
        XCTAssertTrue(request.contextRecordIDs.contains(card.id.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(question.id.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(principle.id.uuidString))
    }

    func testExtractPrinciple_includesExistingPrinciplesForDedupe() async throws {
        let client = CapturingLLMClient(response: Self.principlesResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let existing = PrincipleAsset(
            title: "Clarify meeting ownership",
            summary: "Write owner and acceptance criteria.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync"
        )

        _ = try await service.extractPrinciple(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "Meeting ownership should be explicit."),
                principles: [existing]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .extractPrinciple)
        XCTAssertTrue(try XCTUnwrap(request.jsonPayload["existingPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertEqual(request.contextPayload?.existingPrinciples.map(\.title), ["Clarify meeting ownership"])
        XCTAssertTrue(request.contextRecordIDs.contains(existing.id.uuidString))
    }

    func testVerifyQuest_recordsSourceIdsAsRequestAndContextIds() async throws {
        let client = CapturingLLMClient(response: Self.verificationResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let sourceIds = [UUID().uuidString, UUID().uuidString]

        _ = try await service.verifyQuest(
            input: VerifyQuestInput(
                sourceRecordIDs: sourceIds,
                questTitle: "Confirm owner",
                completionCriteria: "Owner acknowledged in writing.",
                completion: "done",
                valueRating: "high",
                rawText: "It reduced ambiguity."
            ),
            sessionMode: .standard
        )

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .verifyQuest)
        XCTAssertEqual(request.sourceRecordIDs, sourceIds)
        XCTAssertEqual(request.contextRecordIDs, sourceIds)
    }

    func testRelevantPrinciples_areCappedAtThreeAndExcludeInactive() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let principles = (0..<5).map { index in
            PrincipleAsset(
                title: "Meeting ownership rule \(index)",
                summary: "Clarify meeting ownership before execution.",
                triggerContext: "meeting ownership",
                actions: ["Write owner"],
                successCriteria: "Owner is known.",
                exceptions: "Low-stakes sync",
                status: index == 4 ? .archived : .active
            )
        }

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(rawText: "The meeting ownership was unclear.", selectedLens: .evidenceCheck),
                confirmedCards: [
                    ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named.")
                ],
                principles: principles
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let relevantPrinciples = try XCTUnwrap(request.jsonPayload["relevantPrinciples"])
        XCTAssertEqual(request.contextRecordIDs.filter { id in principles.map(\.id.uuidString).contains(id) }.count, 3)
        XCTAssertFalse(relevantPrinciples.contains("Meeting ownership rule 4"))
    }

    private static let cardsResponse = Data(
        """
        {
          "cards": [
            {
              "type": "problem",
              "title": "Meeting ownership unclear",
              "body": "The owner was not explicit.",
              "importance": "high",
              "sensitivity": "normal",
              "confidence": "high",
              "reason": "The input names ownership ambiguity."
            }
          ]
        }
        """.utf8
    )

    private static let questionsResponse = Data(
        """
        {
          "questions": [
            {
              "question": "What evidence shows ownership was unclear?",
              "why_this_matters": "It separates fact from interpretation.",
              "expected_answer_type": "fact"
            }
          ]
        }
        """.utf8
    )

    private static let questsResponse = Data(
        """
        {
          "main_quest": {
            "type": "main",
            "title": "Confirm meeting owner",
            "why_it_matters": "It reduces ambiguity.",
            "completion_criteria": "Owner and acceptance criteria are written.",
            "expected_resistance": "People may assume it is obvious.",
            "reflection_question": "Did ambiguity reduce?"
          },
          "side_quests": [],
          "observation_quest": null
        }
        """.utf8
    )

    private static let principlesResponse = Data(
        """
        {
          "principle_candidate": {
            "title": "Clarify ownership before execution",
            "summary": "Make owner and done criteria explicit.",
            "trigger_context": "Cross-role work.",
            "actions": ["Write owner"],
            "success_criteria": "Owner is known.",
            "exceptions": "Low-stakes sync."
          }
        }
        """.utf8
    )

    private static let verificationResponse = Data(
        """
        {
          "calibration_note": "The quest was useful and verifiable.",
          "likely_issue": "none",
          "recommendation": "Keep criteria explicit."
        }
        """.utf8
    )

    private static func growthReportResponse(entryID: UUID) -> Data {
        Data(
            """
            {
              "insufficient_evidence": false,
              "summary": "Weekly growth has evidence.",
              "metrics": {
                "clarity": {"value": 3.5, "delta": 0.2, "reason": "More explicit meeting goals."}
              },
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.12,
                  "title": "Prepared meeting decisions",
                  "reason": "The record shows a concrete pre-meeting decision list.",
                  "source_type": "daily_entry",
                  "source_id": "\(entryID.uuidString)",
                  "source_daily_entry_id": "\(entryID.uuidString)"
                }
              ],
              "next_training_focus": "Keep writing meeting decisions before discussions."
            }
            """.utf8
        )
    }
}

private final class CapturingLLMClient: LLMClient {
    private let response: Data
    private(set) var requests: [LLMRequest] = []

    init(response: Data) {
        self.response = response
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        requests.append(request)
        return response
    }
}

private final class StreamingCapturingLLMClient: LLMClient, StreamingLLMClient {
    private let tokens: [String]
    private(set) var requests: [LLMRequest] = []

    init(tokens: [String]) {
        self.tokens = tokens
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.invalidResponse
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        requests.append(request)
        return AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(.token(token))
            }
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}
