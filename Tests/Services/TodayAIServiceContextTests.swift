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
        let legacy = request.contextPayload?.legacyKeyValues ?? [:]
        XCTAssertNil(legacy["relevantPrinciples"])
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

    func testPromptContextPayloadEncodingOmitsUnstructuredExtraDictionary() throws {
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: "entry-structured", rawText: "typed source"),
            userChoice: .init(sessionMode: SessionMode.deep.rawValue),
            privacy: .init(rules: "typed privacy")
        )

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["extra"])
        XCTAssertEqual(object["currentInput"] as? [String: String], [
            "dailyEntryId": "entry-structured",
            "rawText": "typed source"
        ])
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
        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["streamProtocol"], "MINGSI_STREAM_V1")
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
            positiveContributionRefs: ["previous-positive"],
            completeLoopCount: 3
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
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["period"], "weekly")
        XCTAssertEqual(legacy["record_count"], "1")
        XCTAssertEqual(legacy["complete_loop_count"], "3")
        XCTAssertEqual(legacy["previous_clarity"], "3.2")
        XCTAssertEqual(legacy["previous_reflection_depth"], "3.3")
        XCTAssertEqual(legacy["dismissed_contributions"], "Overstated clarity gain")
        XCTAssertTrue(try XCTUnwrap(legacy["evidence_summaries"]).contains(entryID.uuidString))
    }

    func testGrowthAIService_usesStructuredContextAsLegacyPayloadSource() async throws {
        let entryID = UUID()
        let client = CapturingLLMClient(response: Self.growthReportResponse(entryID: entryID))
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
                previousSnapshot: nil,
                dismissedContributionTitles: ["Overstated clarity gain"]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertNotNil(payload.growth)
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["period"], "weekly")
        XCTAssertEqual(legacy["dismissed_contributions"], "Overstated clarity gain")
    }

    func testGrowthAIService_omitsPreviousScoresWhenSnapshotIsInsufficientEvidence() async throws {
        let entryID = UUID()
        let client = CapturingLLMClient(response: Self.growthReportResponse(entryID: entryID))
        let service = GrowthAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let insufficientSnapshot = MetricSnapshot(
            period: "weekly",
            clarity: 3.2,
            valueJudgment: 3.1,
            executionReliability: 3.0,
            calibration: 2.9,
            reflectionDepth: 3.3,
            summary: "not enough evidence",
            status: .insufficientEvidence,
            completeLoopCount: 1
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
                        calibrationNote: nil,
                        hasLensSessionAnswers: true,
                        principleTitles: []
                    )
                ],
                previousSnapshot: insufficientSnapshot,
                dismissedContributionTitles: []
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertNil(payload.growth?.previousSnapshot)
        XCTAssertNil(legacy["previous_clarity"])
        XCTAssertNil(legacy["previous_reflection_depth"])
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
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        let relevantPrinciples = try XCTUnwrap(legacy["relevantPrinciples"])
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
        XCTAssertEqual(payload.principles.map(\.retrievalPolicyVersion), [LocalPrincipleRetriever.policyVersion])
        XCTAssertTrue(try XCTUnwrap(payload.principles.first?.retrievalReason).contains("meeting ownership"))
        XCTAssertFalse(payload.principles.map(\.title).contains("Archived meeting checklist"))
    }

    func testStructuredContextPayload_keepsLegacyCompatibilityExportForDirectGLM() async throws {
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
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertTrue(try XCTUnwrap(legacy["confirmedCards"]).contains("Meeting ownership unclear"))
        XCTAssertEqual(legacy["selectedLens"], "evidence_check")
        XCTAssertEqual(legacy["sessionMode"], SessionMode.standard.rawValue)
        XCTAssertTrue(try XCTUnwrap(legacy["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(try XCTUnwrap(legacy["principleUsageRule"]).contains("Do not force"))
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
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["selectedLens"], "first_principles")
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
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["selectedLens"], "leverage_analysis")
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
        XCTAssertTrue(catalog.promptGuidance.contains("non-negotiable facts"))
        XCTAssertTrue(catalog.purpose.contains("不可再拆的事实"))
        XCTAssertTrue(catalog.questionStrategy.contains("硬事实"))
        XCTAssertTrue(catalog.taskSelectionRule.contains("核心前提"))
        XCTAssertTrue(catalog.applicability.contains("前提混杂"))
        XCTAssertTrue(catalog.disableConditions.contains("不要用抽象原则替代当天具体证据。"))
        XCTAssertEqual(catalog.uiMetadata.symbolName, "square.stack.3d.down.right")
        XCTAssertEqual(catalog.uiMetadata.accentRole, .principle)
        XCTAssertEqual(catalog.uiMetadata.methodIndex, 4)
        XCTAssertEqual(catalog.sourceKind, .builtin)
        XCTAssertEqual(catalog.packId, "mingsi.builtin.lenses")
        XCTAssertEqual(catalog.packVersion, "builtin.v1")
        XCTAssertEqual(catalog.packDisplayName, "MingSi Built-in Lens Pack")
    }

    func testStructuredContext_exposesRuntimeLensAssetMetadata() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )
        let lens = LensAssetPack(
            id: "marketplace.roles.coach",
            version: "2026.06",
            displayName: "Coach Role Cards",
            sourceKind: .marketplace,
            items: [
                LensCatalogItem(
                    lensId: "role-coach",
                    promptId: "role_coach",
                    version: "role.v1",
                    title: "Coach Role",
                    subtitle: "Use a coaching voice.",
                    shortLabel: "Coach",
                    methodLine: "What would a coach ask first?",
                    promptGuidance: "Ask coaching-style reflection questions.",
                    symbolName: "person.wave.2",
                    recommendedReason: "Imported role card pack.",
                    questionSeeds: ["What would a coach ask first?"],
                    accentRole: .accent,
                    methodIndex: 10
                )
            ]
        ).stampedItems[0]

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "meeting ownership was unclear",
                    sessionMode: .standard,
                    selectedCustomLensId: lens.id
                ),
                confirmedCards: [],
                selectedLensItem: lens
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let catalog = try XCTUnwrap(payload.userChoice.lensCatalog)
        XCTAssertEqual(payload.userChoice.selectedLens, "role-coach")
        XCTAssertEqual(catalog.localId, "role-coach")
        XCTAssertEqual(catalog.promptId, "role_coach")
        XCTAssertEqual(catalog.sourceKind, .marketplace)
        XCTAssertEqual(catalog.packId, "marketplace.roles.coach")
        XCTAssertEqual(catalog.packVersion, "2026.06")
        XCTAssertEqual(catalog.packDisplayName, "Coach Role Cards")
        XCTAssertEqual(payload.legacyKeyValues["lensPackId"], "marketplace.roles.coach")
    }

    func testLensCatalogContext_decodesLegacyBuiltinContextWithBuiltinPackMetadata() throws {
        let legacyJSON = """
        {
          "localId": "firstPrinciples",
          "promptId": "first_principles",
          "version": "builtin.v1",
          "title": "第一性原理",
          "methodLine": "先问：如果从零开始，这件事必须成立的条件是什么？",
          "promptGuidance": "Decompose the situation into non-negotiable facts.",
          "purpose": "拆掉默认前提。",
          "questionStrategy": "先识别硬事实。",
          "taskSelectionRule": "优先生成能验证核心前提的明日任务。",
          "applicability": "适用于前提混杂的场景。",
          "disableConditions": ["不要用抽象原则替代当天具体证据。"],
          "uiMetadata": {
            "symbolName": "square.stack.3d.down.right",
            "accentRole": "principle",
            "methodIndex": 4
          }
        }
        """.data(using: .utf8)!

        let catalog = try JSONDecoder().decode(PromptContextPayload.LensCatalogContext.self, from: legacyJSON)

        XCTAssertEqual(catalog.sourceKind, .builtin)
        XCTAssertEqual(catalog.packId, "mingsi.builtin.lenses")
        XCTAssertEqual(catalog.packVersion, "builtin.v1")
        XCTAssertEqual(catalog.packDisplayName, "MingSi Built-in Lens Pack")
    }

    func testGenerateQuestions_injectsLensPromptGuidance_fromCatalog() async throws {
        let client = CapturingLLMClient(response: Self.questionsResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.generateQuestions(
            for: TodayAIContext(
                draft: DailyEntryDraft(
                    rawText: "Which assumptions are actually necessary?",
                    selectedLens: .firstPrinciples
                )
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertEqual(legacy["selectedLens"], "first_principles")
        XCTAssertTrue(try XCTUnwrap(legacy["lensPromptGuidance"]).contains("non-negotiable facts"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensMethodLine"]).contains("从零开始"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensPurpose"]).contains("不可再拆的事实"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensQuestionStrategy"]).contains("硬事实"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensTaskSelectionRule"]).contains("核心前提"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensApplicability"]).contains("前提混杂"))
        XCTAssertTrue(try XCTUnwrap(legacy["lensDisableConditions"]).contains("抽象原则"))
        XCTAssertEqual(legacy["lensSourceKind"], "builtin")
        XCTAssertEqual(legacy["lensPackId"], "mingsi.builtin.lenses")
        XCTAssertEqual(legacy["lensPackVersion"], "builtin.v1")
        XCTAssertEqual(legacy["lensPackDisplayName"], "MingSi Built-in Lens Pack")
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
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        XCTAssertTrue(try XCTUnwrap(legacy["confirmedCards"]).contains("Prepare meeting decisions"))
        XCTAssertTrue(try XCTUnwrap(legacy["reflectionAnswers"]).contains("Confirm owner"))
        XCTAssertTrue(try XCTUnwrap(legacy["relevantPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertTrue(try XCTUnwrap(legacy["principleUsageRule"]).contains("Do not force"))
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
        let payload = try XCTUnwrap(request.contextPayload)
        XCTAssertTrue(try XCTUnwrap(payload.legacyKeyValues["existingPrinciples"]).contains("Clarify meeting ownership"))
        XCTAssertEqual(payload.existingPrinciples.map(\.title), ["Clarify meeting ownership"])
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

    func testVerifyQuest_usesStructuredContextAsLegacyPayloadSource() async throws {
        let client = CapturingLLMClient(response: Self.verificationResponse)
        let service = TodayAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.verifyQuest(
            input: VerifyQuestInput(
                sourceRecordIDs: [UUID().uuidString],
                questTitle: "Confirm owner",
                completionCriteria: "Owner acknowledged in writing.",
                completion: "done",
                valueRating: "high",
                rawText: "It reduced ambiguity."
            ),
            sessionMode: .deep
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(payload.verification?.questTitle, "Confirm owner")
        XCTAssertEqual(legacy["questTitle"], "Confirm owner")
        XCTAssertEqual(legacy["completionCriteria"], "Owner acknowledged in writing.")
        XCTAssertEqual(legacy["completion"], "done")
        XCTAssertEqual(legacy["valueRating"], "high")
        XCTAssertEqual(legacy["sessionMode"], SessionMode.deep.rawValue)
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
        let legacy = try XCTUnwrap(request.contextPayload?.legacyKeyValues)
        let relevantPrinciples = try XCTUnwrap(legacy["relevantPrinciples"])
        XCTAssertEqual(request.contextRecordIDs.filter { id in principles.map(\.id.uuidString).contains(id) }.count, 3)
        XCTAssertFalse(relevantPrinciples.contains("Meeting ownership rule 4"))
    }

    func testRelevantPrinciples_negativeRecallFeedbackDemotesMisrecalledPrinciples() async throws {
        let penalizedPrinciple = PrincipleAsset(
            title: "Meeting ownership escalation",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync"
        )
        let unchallengedPrinciple = PrincipleAsset(
            title: "Meeting ownership alignment",
            summary: "Clarify meeting ownership before execution.",
            triggerContext: "meeting ownership",
            actions: ["Write owner"],
            successCriteria: "Owner is known.",
            exceptions: "Low-stakes sync"
        )
        let context = TodayAIContext(
            draft: DailyEntryDraft(rawText: "The meeting ownership was unclear.", selectedLens: .evidenceCheck),
            confirmedCards: [
                ThinkingCard(type: .problem, title: "Meeting ownership unclear", body: "No owner was named.")
            ],
            principles: [penalizedPrinciple, unchallengedPrinciple],
            principleRecallFeedback: [
                PrincipleRecallFeedback(
                    principleId: penalizedPrinciple.id,
                    promptId: .generateQuestions,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier recall was too broad.",
                    feedback: .misrecalled,
                    createdAt: Date(timeIntervalSince1970: 200)
                ),
                PrincipleRecallFeedback(
                    principleId: penalizedPrinciple.id,
                    promptId: .generateQuests,
                    retrievalPolicyVersion: LocalPrincipleRetriever.policyVersion,
                    retrievalReason: "Earlier recall did not apply.",
                    feedback: .notApplicable,
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            ]
        )

        let retrieved = LocalPrincipleRetriever()
            .retrievePrinciples(for: context, promptID: .generateQuestions, limit: 2)

        XCTAssertEqual(retrieved.map(\.principle.id), [unchallengedPrinciple.id, penalizedPrinciple.id])
        XCTAssertLessThan(
            try XCTUnwrap(retrieved.first(where: { $0.principle.id == penalizedPrinciple.id })?.score),
            try XCTUnwrap(retrieved.first(where: { $0.principle.id == unchallengedPrinciple.id })?.score)
        )
        XCTAssertTrue(
            try XCTUnwrap(retrieved.first(where: { $0.principle.id == penalizedPrinciple.id })?.retrievalReason)
                .contains("negative recall feedback")
        )
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
