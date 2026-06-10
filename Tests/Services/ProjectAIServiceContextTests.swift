import XCTest
@testable import MingSi

final class ProjectAIServiceContextTests: XCTestCase {

    func testSuggestProjectLinks_sendsTypedProjectContextAndSourceIds() async throws {
        let entryID = UUID()
        let cardID = UUID()
        let questID = UUID()
        let existingProjectID = UUID()

        let client = CapturingProjectLLMClient(response: Self.projectSuggestionsResponse(
            entryID: entryID,
            cardID: cardID,
            existingProjectID: existingProjectID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectSuggestionContext(
            dailyEntryId: entryID,
            confirmedCards: [
                .init(id: cardID.uuidString, type: "problem", title: "接口归属不清", body: "会议后仍无明确负责人。")
            ],
            quests: [
                .init(id: questID.uuidString, type: "main", title: "确认接口归属", completionCriteria: "写出负责人和验收方式")
            ],
            activeProjects: [
                .init(id: existingProjectID.uuidString, name: "接口归属确认")
            ],
            existingLinkSourceIds: []
        )

        _ = try await service.suggestProjectLinks(context: context)

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .suggestProjectLinks)
        XCTAssertTrue(request.inputSummary.contains(entryID.uuidString))

        let payload = try XCTUnwrap(request.contextPayload)
        let project = try XCTUnwrap(payload.project)
        XCTAssertEqual(project.dailyEntryId, entryID.uuidString)
        XCTAssertEqual(project.confirmedCards.map(\.id), [cardID.uuidString])
        XCTAssertEqual(project.quests.map(\.id), [questID.uuidString])
        XCTAssertEqual(project.activeProjects.map(\.id), [existingProjectID.uuidString])
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["daily_entry_id"], entryID.uuidString)
        XCTAssertEqual(legacy["confirmed_cards_count"], "1")
        XCTAssertEqual(legacy["active_projects_count"], "1")
        XCTAssertTrue(try XCTUnwrap(legacy["confirmed_cards"]).contains("接口归属不清"))
        XCTAssertTrue(try XCTUnwrap(legacy["quests"]).contains("确认接口归属"))
        XCTAssertTrue(try XCTUnwrap(legacy["active_projects"]).contains("接口归属确认"))
        XCTAssertTrue(request.sourceRecordIDs.contains(entryID.uuidString))
        XCTAssertTrue(request.sourceRecordIDs.contains(cardID.uuidString))
        XCTAssertTrue(request.sourceRecordIDs.contains(questID.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(existingProjectID.uuidString))
    }

    func testSuggestProjectLinks_usesStructuredContextAsLegacyPayloadSource() async throws {
        let entryID = UUID()
        let cardID = UUID()
        let existingProjectID = UUID()
        let client = CapturingProjectLLMClient(response: Self.projectSuggestionsResponse(
            entryID: entryID,
            cardID: cardID,
            existingProjectID: existingProjectID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        _ = try await service.suggestProjectLinks(
            context: ProjectSuggestionContext(
                dailyEntryId: entryID,
                confirmedCards: [
                    .init(id: cardID.uuidString, type: "problem", title: "接口归属不清", body: "会议后仍无明确负责人。")
                ],
                quests: [],
                activeProjects: [
                    .init(id: existingProjectID.uuidString, name: "接口归属确认")
                ],
                existingLinkSourceIds: [cardID.uuidString]
            )
        )

        let request = try XCTUnwrap(client.requests.first)
        let payload = try XCTUnwrap(request.contextPayload)
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy, payload.legacyKeyValues)
        XCTAssertEqual(legacy["existing_link_source_ids"], cardID.uuidString)
    }

    func testSuggestProjectLinks_responseContainsCandidatesWithSourceRefs() async throws {
        let entryID = UUID()
        let cardID = UUID()
        let existingProjectID = UUID()

        let client = CapturingProjectLLMClient(response: Self.projectSuggestionsResponse(
            entryID: entryID,
            cardID: cardID,
            existingProjectID: existingProjectID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectSuggestionContext(
            dailyEntryId: entryID,
            confirmedCards: [
                .init(id: cardID.uuidString, type: "problem", title: "接口归属不清", body: "负责人未明确")
            ],
            quests: [],
            activeProjects: [
                .init(id: existingProjectID.uuidString, name: "接口归属确认")
            ],
            existingLinkSourceIds: []
        )

        let result = try await service.suggestProjectLinks(context: context)

        XCTAssertEqual(result.linkCandidates.count, 1)
        XCTAssertEqual(result.linkCandidates[0].projectId, existingProjectID)
        XCTAssertEqual(result.linkCandidates[0].sourceId, cardID.uuidString)
        XCTAssertTrue(result.newProjectCandidates.isEmpty)
    }

    func testGenerateProjectInsights_sendsTypedProjectContextAndEvidenceSourceRefs() async throws {
        let projectID = UUID()
        let cardID = UUID()
        let questID = UUID()
        let verificationID = UUID()
        let principleID = UUID()

        let client = CapturingProjectLLMClient(response: Self.projectInsightsResponse(
            cardID: cardID,
            questID: questID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectInsightsContext(
            projectId: projectID,
            projectName: "接口归属确认",
            projectGoal: "明确各接口的负责人和验收标准",
            projectSuccessCriteria: "所有接口都有明确负责人和验收文档",
            confirmedEvidence: [
                .init(id: cardID.uuidString, type: "thinking_card", title: "接口归属不清", body: "会议后仍无明确负责人。"),
                .init(id: questID.uuidString, type: "quest", title: "确认接口归属", body: "写出负责人和验收方式"),
                .init(id: verificationID.uuidString, type: "verification", title: "昨天的任务完成情况", body: "任务完成，但仍需补充文档"),
                .init(id: principleID.uuidString, type: "principle", title: "会议前确认事项", body: "会前列出必须确认的问题")
            ],
            acceptedInsightCount: 0
        )

        _ = try await service.generateProjectInsights(context: context)

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .generateProjectInsights)
        XCTAssertTrue(request.inputSummary.contains(projectID.uuidString))

        let payload = try XCTUnwrap(request.contextPayload)
        let project = try XCTUnwrap(payload.project)
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["project_id"], projectID.uuidString)
        XCTAssertEqual(legacy["project_name"], "接口归属确认")
        XCTAssertEqual(legacy["project_goal"], "明确各接口的负责人和验收标准")
        XCTAssertEqual(legacy["project_success_criteria"], "所有接口都有明确负责人和验收文档")
        XCTAssertEqual(legacy["accepted_insight_count"], "0")
        XCTAssertTrue(try XCTUnwrap(legacy["confirmed_evidence"]).contains("接口归属不清"))
        XCTAssertEqual(project.confirmedCards.map(\.id), [cardID.uuidString])
        XCTAssertEqual(project.quests.map(\.id), [questID.uuidString])
        XCTAssertTrue(request.sourceRecordIDs.contains(cardID.uuidString))
        XCTAssertTrue(request.sourceRecordIDs.contains(questID.uuidString))
        XCTAssertTrue(request.sourceRecordIDs.contains(verificationID.uuidString))
        XCTAssertTrue(request.sourceRecordIDs.contains(principleID.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(projectID.uuidString))
    }

    func testGenerateProjectInsights_responseContainsInsightsWithSourceRefs() async throws {
        let projectID = UUID()
        let cardID = UUID()
        let questID = UUID()

        let client = CapturingProjectLLMClient(response: Self.projectInsightsResponse(
            cardID: cardID,
            questID: questID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectInsightsContext(
            projectId: projectID,
            projectName: "接口归属确认",
            projectGoal: "明确各接口的负责人和验收标准",
            projectSuccessCriteria: "所有接口都有明确负责人和验收文档",
            confirmedEvidence: [
                .init(id: cardID.uuidString, type: "thinking_card", title: "接口归属不清", body: "会议后仍无明确负责人。"),
                .init(id: questID.uuidString, type: "quest", title: "确认接口归属", body: "写出负责人和验收方式")
            ],
            acceptedInsightCount: 0
        )

        let result = try await service.generateProjectInsights(context: context)

        XCTAssertEqual(result.insights.count, 2)
        XCTAssertEqual(result.insights[0].insightType, .progress)
        XCTAssertEqual(result.insights[0].sourceRefs, [cardID.uuidString])
        XCTAssertEqual(result.insights[1].insightType, .thinkingChange)
        XCTAssertEqual(result.insights[1].sourceRefs, [questID.uuidString])
        XCTAssertNotNil(result.insights[1].beforeText)
        XCTAssertNotNil(result.insights[1].afterText)
    }

    func testGenerateProjectInsights_insufficientEvidenceReturnsReason() async throws {
        let projectID = UUID()

        let client = CapturingProjectLLMClient(response: Self.insufficientEvidenceResponse())
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectInsightsContext(
            projectId: projectID,
            projectName: "接口归属确认",
            projectGoal: "明确各接口的负责人和验收标准",
            projectSuccessCriteria: "所有接口都有明确负责人和验收文档",
            confirmedEvidence: [],
            acceptedInsightCount: 0
        )

        let result = try await service.generateProjectInsights(context: context)

        XCTAssertTrue(result.insights.isEmpty)
        XCTAssertEqual(result.insufficientEvidenceReason, "该项目确认的证据不足3条，无法生成可靠的洞察。")
    }

    private static func projectSuggestionsResponse(
        entryID: UUID,
        cardID: UUID,
        existingProjectID: UUID
    ) -> Data {
        Data(
            """
            {
              "project_link_candidates": [
                {
                  "project_id": "\(existingProjectID.uuidString)",
                  "source_type": "thinking_card",
                  "source_id": "\(cardID.uuidString)",
                  "link_type": "evidence",
                  "reason": "接口归属不清与项目目标直接相关",
                  "confidence": "high",
                  "requires_user_confirmation": true
                }
              ],
              "new_project_candidates": []
            }
            """.utf8
        )
    }

    private static func projectInsightsResponse(cardID: UUID, questID: UUID) -> Data {
        Data(
            """
            {
              "insights": [
                {
                  "project_id": "\(UUID().uuidString)",
                  "insight_type": "progress",
                  "title": "进展顺利",
                  "summary": "接口归属逐步明确，从模糊到具体",
                  "source_refs": ["\(cardID.uuidString)"],
                  "confidence": "0.8"
                },
                {
                  "project_id": "\(UUID().uuidString)",
                  "insight_type": "thinking_change",
                  "title": "思考方式转变",
                  "summary": "从被动等待会议到主动会前准备",
                  "before": {
                    "text": "之前依赖会议讨论决定归属",
                    "source_type": "quest",
                    "source_id": "\(questID.uuidString)"
                  },
                  "after": {
                    "text": "现在会前列出必须确认的问题",
                    "source_type": "quest",
                    "source_id": "\(questID.uuidString)"
                  },
                  "source_refs": ["\(questID.uuidString)"],
                  "confidence": "0.85"
                }
              ],
              "insufficient_evidence_reason": null
            }
            """.utf8
        )
    }

    private static func insufficientEvidenceResponse() -> Data {
        Data(
            """
            {
              "insights": [],
              "insufficient_evidence_reason": "该项目确认的证据不足3条，无法生成可靠的洞察。"
            }
            """.utf8
        )
    }

    // MARK: - Project Merge Candidates

    func testSuggestProjectMerges_sendsTypedProjectContextWithSourceAndContextRefs() async throws {
        let project1ID = UUID()
        let project2ID = UUID()
        let linkCardID = UUID()
        let linkQuestID = UUID()

        let client = CapturingProjectLLMClient(response: Self.projectMergeCandidatesResponse(
            project1ID: project1ID,
            project2ID: project2ID,
            linkCardID: linkCardID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectMergeSuggestionContext(
            activeProjects: [
                .init(
                    id: project1ID.uuidString,
                    name: "接口归属确认",
                    goal: "明确各接口的负责人和验收标准",
                    successCriteria: "所有接口都有明确负责人和验收文档",
                    status: "active"
                ),
                .init(
                    id: project2ID.uuidString,
                    name: "接口负责人问题",
                    goal: "确定每个接口的负责人",
                    successCriteria: "所有接口都有指定负责人",
                    status: "active"
                )
            ],
            confirmedProjectLinks: [
                .init(
                    projectId: project1ID.uuidString,
                    sourceId: linkCardID.uuidString,
                    sourceType: "thinking_card",
                    linkType: "evidence"
                ),
                .init(
                    projectId: project2ID.uuidString,
                    sourceId: linkQuestID.uuidString,
                    sourceType: "quest",
                    linkType: "evidence"
                )
            ]
        )

        _ = try await service.suggestProjectMerges(context: context)

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.prompt.id, .suggestProjectMerges)

        let payload = try XCTUnwrap(request.contextPayload)
        let project = try XCTUnwrap(payload.project)
        XCTAssertEqual(project.activeProjects.map(\.id), [project1ID.uuidString, project2ID.uuidString])
        let legacy = payload.legacyKeyValues
        XCTAssertEqual(legacy["active_projects_count"], "2")
        XCTAssertTrue(try XCTUnwrap(legacy["active_projects"]).contains("success_criteria: 所有接口都有明确负责人和验收文档"))
        XCTAssertTrue(try XCTUnwrap(legacy["confirmed_project_links"]).contains(linkCardID.uuidString))

        XCTAssertTrue(request.sourceRecordIDs.contains(linkCardID.uuidString))
        XCTAssertTrue(request.sourceRecordIDs.contains(linkQuestID.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(project1ID.uuidString))
        XCTAssertTrue(request.contextRecordIDs.contains(project2ID.uuidString))
    }

    func testSuggestProjectMerges_responseContainsCandidatesWithSourceRefs() async throws {
        let project1ID = UUID()
        let project2ID = UUID()
        let linkCardID = UUID()

        let client = CapturingProjectLLMClient(response: Self.projectMergeCandidatesResponse(
            project1ID: project1ID,
            project2ID: project2ID,
            linkCardID: linkCardID
        ))
        let service = ProjectAIService(
            promptProvider: LocalPromptProvider(),
            llmClient: client
        )

        let context = ProjectMergeSuggestionContext(
            activeProjects: [
                .init(id: project1ID.uuidString, name: "接口归属确认", goal: "明确负责人", successCriteria: "有负责人", status: "active"),
                .init(id: project2ID.uuidString, name: "接口负责人问题", goal: "确定负责人", successCriteria: "指定负责人", status: "active")
            ],
            confirmedProjectLinks: [
                .init(projectId: project1ID.uuidString, sourceId: linkCardID.uuidString, sourceType: "thinking_card", linkType: "evidence")
            ]
        )

        let result = try await service.suggestProjectMerges(context: context)

        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(result.candidates[0].sourceProjectId, project2ID)
        XCTAssertEqual(result.candidates[0].targetProjectId, project1ID)
        XCTAssertEqual(result.candidates[0].reason, "两个项目的目标都围绕接口负责人问题")
        XCTAssertEqual(result.candidates[0].overlappingEvidenceRefs, [linkCardID.uuidString])
    }

    private static func projectMergeCandidatesResponse(
        project1ID: UUID,
        project2ID: UUID,
        linkCardID: UUID
    ) -> Data {
        Data(
            """
            {
              "merge_candidates": [
                {
                  "source_project_id": "\(project2ID.uuidString)",
                  "target_project_id": "\(project1ID.uuidString)",
                  "reason": "两个项目的目标都围绕接口负责人问题",
                  "overlapping_evidence_refs": ["\(linkCardID.uuidString)"]
                }
              ]
            }
            """.utf8
        )
    }
}

private final class CapturingProjectLLMClient: LLMClient {
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
