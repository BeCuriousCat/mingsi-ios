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
