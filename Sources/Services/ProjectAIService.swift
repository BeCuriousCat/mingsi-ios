import Foundation

struct ProjectSuggestionCardContext: Hashable {
    var id: String
    var type: String
    var title: String
    var body: String
}

struct ProjectSuggestionQuestContext: Hashable {
    var id: String
    var type: String
    var title: String
    var completionCriteria: String
}

struct ProjectSuggestionProjectContext: Hashable {
    var id: String
    var name: String
}

struct ProjectSuggestionContext: Hashable {
    var dailyEntryId: UUID
    var confirmedCards: [ProjectSuggestionCardContext]
    var quests: [ProjectSuggestionQuestContext]
    var activeProjects: [ProjectSuggestionProjectContext]
    var existingLinkSourceIds: [String]
}

struct ProjectInsightEvidenceContext: Hashable {
    var id: String
    var type: String
    var title: String
    var body: String
}

struct ProjectInsightsContext: Hashable {
    var projectId: UUID
    var projectName: String
    var projectGoal: String
    var projectSuccessCriteria: String
    var confirmedEvidence: [ProjectInsightEvidenceContext]
    var acceptedInsightCount: Int
}

struct ProjectClosureReviewAIResult: Hashable {
    var summary: String
    var principleCandidates: [ProjectClosurePrincipleCandidate]
    var insufficientEvidenceReason: String?
}

struct ProjectMergeSuggestionProjectContext: Hashable {
    var id: String
    var name: String
    var goal: String
    var successCriteria: String
    var status: String
}

struct ProjectMergeSuggestionLinkContext: Hashable {
    var projectId: String
    var sourceId: String
    var sourceType: String
    var linkType: String
}

struct ProjectMergeSuggestionContext: Hashable {
    var activeProjects: [ProjectMergeSuggestionProjectContext]
    var confirmedProjectLinks: [ProjectMergeSuggestionLinkContext]
}

struct ProjectMergeSuggestionResult: Hashable {
    var candidates: [ProjectMergeCandidate]
}

final class ProjectAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient
    private let parser: TodayAIResponseParser

    init(
        promptProvider: PromptProvider,
        llmClient: LLMClient,
        parser: TodayAIResponseParser = TodayAIResponseParser()
    ) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
        self.parser = parser
    }

    func suggestProjectLinks(context: ProjectSuggestionContext) async throws -> ProjectSuggestionResult {
        let template = promptProvider.template(for: .suggestProjectLinks, mode: .standard)
        let contextPayload = buildContextPayload(from: context)
        let sourceRecordIDs = buildSourceRecordIDs(from: context)
        let contextRecordIDs = buildContextRecordIDs(from: context)

        let request = LLMRequest(
            prompt: template,
            inputSummary: "entry=\(context.dailyEntryId.uuidString); cards=\(context.confirmedCards.count); projects=\(context.activeProjects.count)",
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: contextRecordIDs
        )

        let data = try await llmClient.complete(request)
        var result = try parser.parseProjectSuggestions(from: data)

        let existingSourceIds = Set(context.existingLinkSourceIds)
        result.linkCandidates = result.linkCandidates.filter { !existingSourceIds.contains($0.sourceId) }
        result.newProjectCandidates = result.newProjectCandidates.filter { candidate in
            !candidate.sourceRefs.allSatisfy { existingSourceIds.contains($0) }
        }

        return result
    }

    private func buildContextPayload(from context: ProjectSuggestionContext) -> PromptContextPayload {
        PromptContextPayload(
            currentInput: .init(dailyEntryId: context.dailyEntryId.uuidString),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            cards: context.confirmedCards.map { card in
                .init(id: card.id, type: card.type, title: card.title, body: card.body, priority: "medium", sensitivity: "normal", isExcludedFromModel: false)
            },
            quests: context.quests.map { quest in
                .init(id: quest.id, type: quest.type, title: quest.title, completionCriteria: quest.completionCriteria)
            },
            privacy: .init(rules: "Do not use company-sensitive names. Use abstract, non-sensitive project names."),
            project: .init(
                dailyEntryId: context.dailyEntryId.uuidString,
                confirmedCards: context.confirmedCards.map { card in
                    .init(id: card.id, type: card.type, title: card.title, body: card.body)
                },
                quests: context.quests.map { quest in
                    .init(id: quest.id, type: quest.type, title: quest.title, completionCriteria: quest.completionCriteria)
                },
                activeProjects: context.activeProjects.map { project in
                    .init(id: project.id, name: project.name)
                },
                existingLinkSourceIds: context.existingLinkSourceIds
            )
        )
    }

    private func buildSourceRecordIDs(from context: ProjectSuggestionContext) -> [String] {
        var ids = [context.dailyEntryId.uuidString]
        ids.append(contentsOf: context.confirmedCards.map(\.id))
        ids.append(contentsOf: context.quests.map(\.id))
        return Array(Set(ids)).sorted()
    }

    private func buildContextRecordIDs(from context: ProjectSuggestionContext) -> [String] {
        var ids = buildSourceRecordIDs(from: context)
        ids.append(contentsOf: context.activeProjects.map(\.id))
        return Array(Set(ids)).sorted()
    }

    func generateProjectInsights(context: ProjectInsightsContext) async throws -> ProjectInsightsResult {
        let template = promptProvider.template(for: .generateProjectInsights, mode: .standard)
        let contextPayload = buildContextPayload(from: context)
        let sourceRecordIDs = buildSourceRecordIDs(from: context)
        let contextRecordIDs = [context.projectId.uuidString]

        let request = LLMRequest(
            prompt: template,
            inputSummary: "project=\(context.projectId.uuidString); evidence=\(context.confirmedEvidence.count)",
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: contextRecordIDs
        )

        let data = try await llmClient.complete(request)
        return try parser.parseProjectInsights(from: data)
    }

    func generateClosureReview(
        project: Project,
        closure: ProjectClosureReview,
        confirmedEvidence: [ProjectInsightEvidenceContext]
    ) async throws -> ProjectClosureReviewAIResult {
        guard confirmedEvidence.count >= 2 else {
            return ProjectClosureReviewAIResult(
                summary: "",
                principleCandidates: [],
                insufficientEvidenceReason: "至少需要两条已确认项目证据，才能生成结束总结或原则候选。"
            )
        }
        let base = promptProvider.template(for: .generateProjectInsights, mode: .standard)
        let template = PromptTemplate(
            id: base.id,
            version: base.version,
            systemPolicyVersion: base.systemPolicyVersion,
            contextPolicyVersion: base.contextPolicyVersion,
            evalSuiteVersion: base.evalSuiteVersion,
            rollbackTargetVersion: base.rollbackTargetVersion,
            systemText: base.systemText,
            userText: Self.closureReviewPrompt,
            outputSchemaVersion: 1
        )
        var payload = buildContextPayload(from: ProjectInsightsContext(
            projectId: project.id,
            projectName: project.name,
            projectGoal: project.goal,
            projectSuccessCriteria: project.successCriteria,
            confirmedEvidence: confirmedEvidence,
            acceptedInsightCount: 0
        ))
        payload.currentInput = .init(
            dailyEntryId: nil,
            rawText: "结束原因：\(closure.reason.title)\n实际结果：\(closure.outcome)\n补充复盘：\(closure.reviewNote ?? "")"
        )
        let refs = Set(confirmedEvidence.map(\.id))
        let request = LLMRequest(
            prompt: template,
            inputSummary: "project=\(project.id.uuidString); closure_evidence=\(refs.count)",
            contextPayload: payload,
            sourceRecordIDs: refs.sorted(),
            contextVersion: 1,
            contextRecordIDs: [project.id.uuidString]
        )
        let data = try await llmClient.complete(request)
        let result = try Self.parseClosureReview(data)
        guard result.insufficientEvidenceReason == nil else { return result }
        guard result.principleCandidates.allSatisfy({
            $0.evidenceRefs.count >= 2 && Set($0.evidenceRefs).isSubset(of: refs)
        }) else {
            throw TodayAIParsingError.qualityGateFailed(["项目结束原则候选缺少可回链证据。"])
        }
        return result
    }

    private static let closureReviewPrompt = """
    Summarize a closed project using only confirmed project evidence and the user's closure review.
    Do not infer hidden causes, traits, or conclusions. If the evidence cannot support a reusable rule, return an insufficient_evidence_reason and no candidates.
    Every principle candidate must cite two or more real source_refs from the supplied evidence. The user will confirm each candidate manually; never state that a candidate has been accepted.
    Return JSON only:
    {
      "summary": "short evidence-backed project summary",
      "insufficient_evidence_reason": "optional string",
      "principle_candidates": [{
        "title": "string", "summary": "string", "trigger_context": "string",
        "actions": ["string"], "success_criteria": "string", "exceptions": "string",
        "evidence_refs": ["real evidence id"]
      }]
    }
    """

    private static func parseClosureReview(_ data: Data) throws -> ProjectClosureReviewAIResult {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let text = String(decoding: data, as: UTF8.self)
        let payload: Data
        if let envelope = try? decoder.decode(ClosureEnvelope.self, from: data),
           let content = envelope.choices.first?.message?.content,
           let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}") {
            payload = Data(content[start...end].utf8)
        } else if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            payload = Data(text[start...end].utf8)
        } else {
            throw TodayAIParsingError.invalidJSON
        }
        let response = try decoder.decode(ClosureReviewDTO.self, from: payload)
        let reason = response.insufficientEvidenceReason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = response.principleCandidates.compactMap { item -> ProjectClosurePrincipleCandidate? in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            let actions = item.actions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let refs = Array(Set(item.evidenceRefs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).sorted()
            guard !title.isEmpty, !summary.isEmpty, !actions.isEmpty,
                  !item.triggerContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !item.successCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !refs.isEmpty else { return nil }
            return ProjectClosurePrincipleCandidate(
                title: title, summary: summary, triggerContext: item.triggerContext,
                actions: actions, successCriteria: item.successCriteria,
                exceptions: item.exceptions, evidenceRefs: refs
            )
        }
        if reason?.isEmpty == false { return .init(summary: "", principleCandidates: [], insufficientEvidenceReason: reason) }
        guard !response.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TodayAIParsingError.emptyResult
        }
        return .init(summary: response.summary.trimmingCharacters(in: .whitespacesAndNewlines), principleCandidates: candidates, insufficientEvidenceReason: nil)
    }

    private struct ClosureReviewDTO: Decodable {
        var summary: String
        var insufficientEvidenceReason: String?
        var principleCandidates: [ClosurePrincipleDTO]
    }

    private struct ClosurePrincipleDTO: Decodable {
        var title: String
        var summary: String
        var triggerContext: String
        var actions: [String]
        var successCriteria: String
        var exceptions: String
        var evidenceRefs: [String]
    }

    private struct ClosureEnvelope: Decodable {
        struct Choice: Decodable { struct Message: Decodable { var content: String? }; var message: Message? }
        var choices: [Choice]
    }

    private func buildContextPayload(from context: ProjectInsightsContext) -> PromptContextPayload {
        var cards: [PromptContextPayload.Card] = []
        var quests: [PromptContextPayload.QuestContext] = []

        for evidence in context.confirmedEvidence {
            switch evidence.type {
            case "thinking_card":
                cards.append(.init(
                    id: evidence.id,
                    type: evidence.type,
                    title: evidence.title,
                    body: evidence.body,
                    priority: "medium",
                    sensitivity: "normal",
                    isExcludedFromModel: false
                ))
            case "quest":
                quests.append(.init(
                    id: evidence.id,
                    type: evidence.type,
                    title: evidence.title,
                    completionCriteria: evidence.body
                ))
            default:
                break
            }
        }

        return PromptContextPayload(
            currentInput: .init(dailyEntryId: nil),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            cards: cards,
            quests: quests,
            privacy: .init(rules: "Do not use company-sensitive information."),
            project: .init(
                dailyEntryId: context.projectId.uuidString,
                confirmedCards: cards.map { card in
                    .init(id: card.id, type: card.type, title: card.title, body: card.body)
                },
                quests: quests.map { quest in
                    .init(id: quest.id, type: quest.type, title: quest.title, completionCriteria: quest.completionCriteria)
                },
                activeProjects: [],
                existingLinkSourceIds: [],
                projectId: context.projectId.uuidString,
                projectName: context.projectName,
                projectGoal: context.projectGoal,
                projectSuccessCriteria: context.projectSuccessCriteria,
                confirmedEvidence: context.confirmedEvidence.map { evidence in
                    .init(id: evidence.id, type: evidence.type, title: evidence.title, body: evidence.body)
                },
                acceptedInsightCount: context.acceptedInsightCount
            )
        )
    }

    private func buildSourceRecordIDs(from context: ProjectInsightsContext) -> [String] {
        context.confirmedEvidence.map(\.id).sorted()
    }

    func suggestProjectMerges(context: ProjectMergeSuggestionContext) async throws -> ProjectMergeSuggestionResult {
        let template = promptProvider.template(for: .suggestProjectMerges, mode: .standard)
        let contextPayload = buildContextPayload(from: context)
        let sourceRecordIDs = buildSourceRecordIDs(from: context)
        let contextRecordIDs = buildContextRecordIDs(from: context)

        let request = LLMRequest(
            prompt: template,
            inputSummary: "projects=\(context.activeProjects.count); links=\(context.confirmedProjectLinks.count)",
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: contextRecordIDs
        )

        let data = try await llmClient.complete(request)
        let candidates = try parser.parseProjectMergeCandidates(from: data)

        return ProjectMergeSuggestionResult(candidates: candidates)
    }

    private func buildContextPayload(from context: ProjectMergeSuggestionContext) -> PromptContextPayload {
        PromptContextPayload(
            currentInput: .init(dailyEntryId: nil),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            project: .init(
                dailyEntryId: "",
                confirmedCards: [],
                quests: [],
                activeProjects: context.activeProjects.map { project in
                    .init(
                        id: project.id,
                        name: project.name,
                        goal: project.goal,
                        successCriteria: project.successCriteria,
                        status: project.status
                    )
                },
                existingLinkSourceIds: [],
                confirmedProjectLinks: context.confirmedProjectLinks.map { link in
                    .init(
                        projectId: link.projectId,
                        sourceId: link.sourceId,
                        sourceType: link.sourceType,
                        linkType: link.linkType
                    )
                }
            )
        )
    }

    private func buildSourceRecordIDs(from context: ProjectMergeSuggestionContext) -> [String] {
        context.confirmedProjectLinks.map(\.sourceId).sorted()
    }

    private func buildContextRecordIDs(from context: ProjectMergeSuggestionContext) -> [String] {
        context.activeProjects.map(\.id).sorted()
    }
}
