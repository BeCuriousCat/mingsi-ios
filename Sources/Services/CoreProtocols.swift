import Foundation
import UserNotifications

enum PromptID: String, Codable, CaseIterable, Identifiable {
    case organizeCards
    case recommendLenses
    case generateQuestions
    case generateQuests
    case verifyQuest
    case extractPrinciple
    case suggestProjectLinks
    case generateProjectInsights
    case suggestProjectMerges
    case weeklyCalibration
    case monthlyGrowth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .organizeCards: return "整理卡片"
        case .recommendLenses: return "推荐透镜"
        case .generateQuestions: return "生成追问"
        case .generateQuests: return "生成任务"
        case .verifyQuest: return "验证任务"
        case .extractPrinciple: return "沉淀原则"
        case .suggestProjectLinks: return "建议长期议题"
        case .generateProjectInsights: return "生成项目洞察"
        case .suggestProjectMerges: return "建议合并议题"
        case .weeklyCalibration: return "周校准"
        case .monthlyGrowth: return "月度成长"
        }
    }
}

struct PromptTemplate: Codable, Hashable {
    let id: PromptID
    let version: String
    var systemPolicyVersion: String = "system.v1"
    var contextPolicyVersion: String = "context.v1"
    var evalSuiteVersion: String = "eval.v1"
    var rollbackTargetVersion: String?
    var sourceKind: PromptAssetSourceKind = .builtin
    var packId: String = "mingsi.builtin.prompts"
    var packVersion: String = "builtin.v1"
    var packDisplayName: String = "MingSi Built-in Prompt Pack"
    let systemText: String
    let userText: String
    let outputSchemaVersion: Int

    func applyingPackMetadata(_ pack: PromptAssetPack) -> PromptTemplate {
        var copy = self
        copy.sourceKind = pack.sourceKind
        copy.packId = pack.id
        copy.packVersion = pack.version
        copy.packDisplayName = pack.displayName
        return copy
    }
}

struct LLMRequest: Hashable {
    let prompt: PromptTemplate
    let inputSummary: String
    var contextPayload: PromptContextPayload?
    var sourceRecordIDs: [String] = []
    var contextVersion: Int = 1
    var contextRecordIDs: [String] = []

    init(
        prompt: PromptTemplate,
        inputSummary: String,
        contextPayload: PromptContextPayload? = nil,
        sourceRecordIDs: [String] = [],
        contextVersion: Int = 1,
        contextRecordIDs: [String] = []
    ) {
        self.prompt = prompt
        self.inputSummary = inputSummary
        self.contextPayload = contextPayload
        self.sourceRecordIDs = sourceRecordIDs
        self.contextVersion = contextVersion
        self.contextRecordIDs = contextRecordIDs
    }
}

struct PromptContextPayload: Codable, Hashable {
    struct LensCatalogContext: Codable, Hashable {
        struct UIMetadata: Codable, Hashable {
            var symbolName: String
            var accentRole: LensAccentRole
            var methodIndex: Int
        }

        var localId: String
        var promptId: String
        var version: String
        var title: String
        var methodLine: String
        var promptGuidance: String
        var purpose: String
        var questionStrategy: String
        var taskSelectionRule: String
        var applicability: String
        var disableConditions: [String]
        var uiMetadata: UIMetadata
        var sourceKind: LensAssetSourceKind
        var packId: String
        var packVersion: String
        var packDisplayName: String

        init(
            localId: String,
            promptId: String,
            version: String,
            title: String,
            methodLine: String,
            promptGuidance: String,
            purpose: String,
            questionStrategy: String,
            taskSelectionRule: String,
            applicability: String,
            disableConditions: [String],
            uiMetadata: UIMetadata,
            sourceKind: LensAssetSourceKind = .localCustom,
            packId: String = "local.custom-lenses",
            packVersion: String? = nil,
            packDisplayName: String = "Local Custom Lenses"
        ) {
            self.localId = localId
            self.promptId = promptId
            self.version = version
            self.title = title
            self.methodLine = methodLine
            self.promptGuidance = promptGuidance
            self.purpose = purpose
            self.questionStrategy = questionStrategy
            self.taskSelectionRule = taskSelectionRule
            self.applicability = applicability
            self.disableConditions = disableConditions
            self.uiMetadata = uiMetadata
            self.sourceKind = sourceKind
            self.packId = packId
            self.packVersion = packVersion ?? version
            self.packDisplayName = packDisplayName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let localId = try container.decode(String.self, forKey: .localId)
            let promptId = try container.decode(String.self, forKey: .promptId)
            let version = try container.decode(String.self, forKey: .version)
            let sourceKind = try container.decodeIfPresent(LensAssetSourceKind.self, forKey: .sourceKind)
                ?? Self.defaultSourceKind(localId: localId, promptId: promptId)
            self.init(
                localId: localId,
                promptId: promptId,
                version: version,
                title: try container.decode(String.self, forKey: .title),
                methodLine: try container.decode(String.self, forKey: .methodLine),
                promptGuidance: try container.decode(String.self, forKey: .promptGuidance),
                purpose: try container.decode(String.self, forKey: .purpose),
                questionStrategy: try container.decode(String.self, forKey: .questionStrategy),
                taskSelectionRule: try container.decode(String.self, forKey: .taskSelectionRule),
                applicability: try container.decode(String.self, forKey: .applicability),
                disableConditions: try container.decode([String].self, forKey: .disableConditions),
                uiMetadata: try container.decode(UIMetadata.self, forKey: .uiMetadata),
                sourceKind: sourceKind,
                packId: try container.decodeIfPresent(String.self, forKey: .packId)
                    ?? Self.defaultPackId(sourceKind: sourceKind, localId: localId, promptId: promptId),
                packVersion: try container.decodeIfPresent(String.self, forKey: .packVersion)
                    ?? Self.defaultPackVersion(sourceKind: sourceKind, localId: localId, promptId: promptId),
                packDisplayName: try container.decodeIfPresent(String.self, forKey: .packDisplayName)
                    ?? Self.defaultPackDisplayName(sourceKind: sourceKind, localId: localId, promptId: promptId)
            )
        }

        private static func defaultSourceKind(localId: String, promptId: String) -> LensAssetSourceKind {
            builtinItem(localId: localId, promptId: promptId)?.sourceKind ?? .localCustom
        }

        private static func defaultPackId(sourceKind: LensAssetSourceKind, localId: String, promptId: String) -> String {
            if sourceKind == .builtin,
               let item = builtinItem(localId: localId, promptId: promptId) {
                return item.packId
            }
            return "local.custom-lenses"
        }

        private static func defaultPackVersion(sourceKind: LensAssetSourceKind, localId: String, promptId: String) -> String {
            if sourceKind == .builtin,
               let item = builtinItem(localId: localId, promptId: promptId) {
                return item.packVersion
            }
            return "session.v1"
        }

        private static func defaultPackDisplayName(sourceKind: LensAssetSourceKind, localId: String, promptId: String) -> String {
            if sourceKind == .builtin,
               let item = builtinItem(localId: localId, promptId: promptId) {
                return item.packDisplayName
            }
            return "Local Custom Lenses"
        }

        private static func builtinItem(localId: String, promptId: String) -> LensCatalogItem? {
            BuiltinLensCatalog.item(localId: localId) ?? BuiltinLensCatalog.item(promptId: promptId)
        }
    }

    struct CurrentInput: Codable, Hashable {
        var dailyEntryId: String?
        var rawText: String?
    }

    struct UserChoice: Codable, Hashable {
        var sessionMode: String
        var selectedLens: String?
        var lensCatalog: LensCatalogContext?
    }

    struct Card: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var body: String
        var priority: String
        var sensitivity: String
        var isExcludedFromModel: Bool
    }

    struct Answer: Codable, Hashable {
        var id: String
        var question: String
        var answer: String
    }

    struct QuestContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var completionCriteria: String
    }

    struct PrincipleContext: Codable, Hashable {
        var id: String
        var title: String
        var summary: String
        var triggerContext: String
        var successCriteria: String
        var exceptions: String
        var status: PrincipleStatus
        var retrievalReason: String
        var retrievalPolicyVersion: String

        init(
            id: String,
            title: String,
            summary: String,
            triggerContext: String,
            successCriteria: String,
            exceptions: String,
            status: PrincipleStatus,
            retrievalReason: String = "",
            retrievalPolicyVersion: String = ""
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.triggerContext = triggerContext
            self.successCriteria = successCriteria
            self.exceptions = exceptions
            self.status = status
            self.retrievalReason = retrievalReason
            self.retrievalPolicyVersion = retrievalPolicyVersion
        }
    }

    struct Privacy: Codable, Hashable {
        var rules: String?
    }

    struct PromptDirectives: Codable, Hashable {
        var privacyRules: String?
        var streamProtocol: String?
        var principleUsageRule: String?
    }

    struct VerificationContext: Codable, Hashable {
        var questTitle: String
        var completionCriteria: String
        var completion: String
        var valueRating: String
    }

    struct GrowthRecordContext: Codable, Hashable {
        var dailyEntryId: String
        var date: Date
        var confirmedCardCount: Int
        var hasMainQuest: Bool
        var mainQuestTitle: String?
        var mainQuestCompletionCriteria: String?
        var verificationCompletion: String?
        var verificationValueRating: String?
        var calibrationNote: String?
        var hasLensSessionAnswers: Bool
        var principleTitles: [String]
    }

    struct GrowthSnapshotContext: Codable, Hashable {
        var clarity: Double
        var valueJudgment: Double
        var executionReliability: Double
        var calibration: Double
        var reflectionDepth: Double
    }

    struct GrowthContext: Codable, Hashable {
        var period: String
        var startDate: Date?
        var endDate: Date?
        var completeLoopCount: Int
        var records: [GrowthRecordContext]
        var previousSnapshot: GrowthSnapshotContext?
        var dismissedContributionTitles: [String]
    }

    struct ProjectCardContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var body: String
    }

    struct ProjectQuestContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var completionCriteria: String
    }

    struct ActiveProjectContext: Codable, Hashable {
        var id: String
        var name: String
        var goal: String?
        var successCriteria: String?
        var status: String?
    }

    struct ProjectEvidenceContext: Codable, Hashable {
        var id: String
        var type: String
        var title: String
        var body: String
    }

    struct ProjectLinkContext: Codable, Hashable {
        var projectId: String
        var sourceId: String
        var sourceType: String
        var linkType: String
    }

    struct ProjectContext: Codable, Hashable {
        var dailyEntryId: String
        var confirmedCards: [ProjectCardContext]
        var quests: [ProjectQuestContext]
        var activeProjects: [ActiveProjectContext]
        var existingLinkSourceIds: [String]
        var projectId: String?
        var projectName: String?
        var projectGoal: String?
        var projectSuccessCriteria: String?
        var confirmedEvidence: [ProjectEvidenceContext] = []
        var acceptedInsightCount: Int?
        var confirmedProjectLinks: [ProjectLinkContext] = []
    }

    var currentInput: CurrentInput
    var userChoice: UserChoice
    var cards: [Card]
    var answers: [Answer]
    var quests: [QuestContext]
    var principles: [PrincipleContext]
    var existingPrinciples: [PrincipleContext]
    var privacy: Privacy
    var directives: PromptDirectives
    var verification: VerificationContext?
    var growth: GrowthContext?
    var project: ProjectContext?

    var rawText: String {
        currentInput.rawText ?? ""
    }

    var sessionMode: SessionMode? {
        SessionMode(rawValue: userChoice.sessionMode)
    }

    var selectedLens: ThinkingLens? {
        userChoice.selectedLens.flatMap(ThinkingLens.init(rawValue:))
    }

    var privacyRules: String {
        privacy.rules ?? ""
    }

    var confirmedCards: [Card] {
        cards
    }

    var relevantPrinciples: [PrincipleContext] {
        principles
    }

    init(
        currentInput: CurrentInput = CurrentInput(),
        userChoice: UserChoice,
        cards: [Card] = [],
        answers: [Answer] = [],
        quests: [QuestContext] = [],
        principles: [PrincipleContext] = [],
        existingPrinciples: [PrincipleContext] = [],
        privacy: Privacy = Privacy(),
        directives: PromptDirectives = PromptDirectives(),
        verification: VerificationContext? = nil,
        growth: GrowthContext? = nil,
        project: ProjectContext? = nil
    ) {
        self.currentInput = currentInput
        self.userChoice = userChoice
        self.cards = cards
        self.answers = answers
        self.quests = quests
        self.principles = principles
        self.existingPrinciples = existingPrinciples
        self.privacy = privacy
        self.directives = directives
        self.verification = verification
        self.growth = growth
        self.project = project
    }

    func applyingDirectives(_ directives: PromptDirectives) -> PromptContextPayload {
        var copy = self
        if let privacyRules = directives.privacyRules {
            copy.privacy.rules = privacyRules
            copy.directives.privacyRules = privacyRules
        }
        if let streamProtocol = directives.streamProtocol {
            copy.directives.streamProtocol = streamProtocol
        }
        if let principleUsageRule = directives.principleUsageRule {
            copy.directives.principleUsageRule = principleUsageRule
        }
        return copy
    }

    var legacyKeyValues: [String: String] {
        var values: [String: String] = [:]
        values["sessionMode"] = userChoice.sessionMode

        if let promptId = userChoice.lensCatalog?.promptId {
            values["selectedLens"] = promptId
        } else if let selectedLens = userChoice.selectedLens {
            values["selectedLens"] = selectedLens
        }
        if let lensCatalog = userChoice.lensCatalog {
            values["lensTitle"] = lensCatalog.title
            values["lensMethodLine"] = lensCatalog.methodLine
            values["lensPromptGuidance"] = lensCatalog.promptGuidance
            values["lensPurpose"] = lensCatalog.purpose
            values["lensQuestionStrategy"] = lensCatalog.questionStrategy
            values["lensTaskSelectionRule"] = lensCatalog.taskSelectionRule
            values["lensApplicability"] = lensCatalog.applicability
            values["lensDisableConditions"] = lensCatalog.disableConditions.joined(separator: "\n")
            values["lensSourceKind"] = lensCatalog.sourceKind.rawValue
            values["lensPackId"] = lensCatalog.packId
            values["lensPackVersion"] = lensCatalog.packVersion
            values["lensPackDisplayName"] = lensCatalog.packDisplayName
        }
        if let rawText = currentInput.rawText {
            values["rawText"] = rawText
        }
        if !cards.isEmpty {
            values["confirmedCards"] = cards.map { card in
                [
                    "type": card.type,
                    "title": card.title,
                    "body": card.body,
                    "priority": card.priority,
                    "sensitivity": card.sensitivity
                ]
                .map { "\($0.key): \($0.value)" }
                .sorted()
                .joined(separator: ", ")
            }.joined(separator: "\n")
        }
        if !answers.isEmpty {
            let renderedAnswers = answers.map { answer in
                "question: \(answer.question), answer: \(answer.answer)"
            }.joined(separator: "\n")
            values["priorAnswers"] = renderedAnswers
            values["reflectionAnswers"] = renderedAnswers
        }
        if !quests.isEmpty {
            values["selectedQuest"] = quests.map { quest in
                "type: \(quest.type), title: \(quest.title), completionCriteria: \(quest.completionCriteria)"
            }.joined(separator: "\n")
        }
        if !principles.isEmpty {
            values["relevantPrinciples"] = legacyPrinciples(principles)
        }
        if !existingPrinciples.isEmpty {
            values["existingPrinciples"] = legacyPrinciples(existingPrinciples)
        }
        if let principleUsageRule = directives.principleUsageRule {
            values["principleUsageRule"] = principleUsageRule
        }
        if let streamProtocol = directives.streamProtocol {
            values["streamProtocol"] = streamProtocol
        }
        if let privacyRules = directives.privacyRules {
            values["privacyRules"] = privacyRules
        }
        if let privacyRules = privacy.rules {
            values["privacyRules"] = privacyRules
        }
        if let verification {
            values["questTitle"] = verification.questTitle
            values["completionCriteria"] = verification.completionCriteria
            values["completion"] = verification.completion
            values["valueRating"] = verification.valueRating
        }
        if let growth {
            mergeGrowthLegacyValues(growth, into: &values)
        }
        if let project {
            mergeProjectLegacyValues(project, into: &values)
        }
        return values
    }

    private func mergeGrowthLegacyValues(_ growth: GrowthContext, into values: inout [String: String]) {
        values["period"] = growth.period
        values["complete_loop_count"] = String(growth.completeLoopCount)
        values["record_count"] = String(growth.records.count)
        values["evidence_summaries"] = growth.records.map { record in
            var parts = ["entry=\(record.dailyEntryId)"]
            parts.append("cards=\(record.confirmedCardCount)")
            if let title = record.mainQuestTitle {
                parts.append("quest=\(title)")
            }
            if let completion = record.verificationCompletion {
                parts.append("completion=\(completion)")
            }
            if let rating = record.verificationValueRating {
                parts.append("value=\(rating)")
            }
            return parts.joined(separator: "; ")
        }
        .joined(separator: "\n")

        if let previous = growth.previousSnapshot {
            values["previous_clarity"] = String(format: "%.1f", previous.clarity)
            values["previous_value_judgment"] = String(format: "%.1f", previous.valueJudgment)
            values["previous_execution_reliability"] = String(format: "%.1f", previous.executionReliability)
            values["previous_calibration"] = String(format: "%.1f", previous.calibration)
            values["previous_reflection_depth"] = String(format: "%.1f", previous.reflectionDepth)
        }

        if !growth.dismissedContributionTitles.isEmpty {
            values["dismissed_contributions"] = growth.dismissedContributionTitles.joined(separator: "; ")
        }
    }

    private func mergeProjectLegacyValues(_ project: ProjectContext, into values: inout [String: String]) {
        if !project.dailyEntryId.isEmpty {
            values["daily_entry_id"] = project.dailyEntryId
            values["confirmed_cards_count"] = String(project.confirmedCards.count)
        }
        if let projectId = project.projectId {
            values["project_id"] = projectId
        }
        if let projectName = project.projectName {
            values["project_name"] = projectName
        }
        if let projectGoal = project.projectGoal {
            values["project_goal"] = projectGoal
        }
        if let projectSuccessCriteria = project.projectSuccessCriteria {
            values["project_success_criteria"] = projectSuccessCriteria
        }
        if let acceptedInsightCount = project.acceptedInsightCount {
            values["accepted_insight_count"] = String(acceptedInsightCount)
        }

        if !project.confirmedCards.isEmpty {
            values["confirmed_cards"] = project.confirmedCards.map { card in
                "id: \(card.id), type: \(card.type), title: \(card.title), body: \(card.body)"
            }.joined(separator: "\n")
        }
        if !project.quests.isEmpty {
            values["quests"] = project.quests.map { quest in
                "id: \(quest.id), type: \(quest.type), title: \(quest.title), completionCriteria: \(quest.completionCriteria)"
            }.joined(separator: "\n")
        }
        if !project.activeProjects.isEmpty {
            values["active_projects_count"] = String(project.activeProjects.count)
            values["active_projects"] = project.activeProjects.map { activeProject in
                var parts = ["id: \(activeProject.id)", "name: \(activeProject.name)"]
                if let goal = activeProject.goal {
                    parts.append("goal: \(goal)")
                }
                if let successCriteria = activeProject.successCriteria {
                    parts.append("success_criteria: \(successCriteria)")
                }
                if let status = activeProject.status {
                    parts.append("status: \(status)")
                }
                return parts.joined(separator: ", ")
            }.joined(separator: "\n")
        }
        if !project.existingLinkSourceIds.isEmpty {
            values["existing_link_source_ids"] = project.existingLinkSourceIds.joined(separator: ", ")
        }
        if !project.confirmedEvidence.isEmpty {
            values["confirmed_evidence"] = project.confirmedEvidence.map { evidence in
                "id: \(evidence.id), type: \(evidence.type), title: \(evidence.title), body: \(evidence.body)"
            }.joined(separator: "\n")
        }
        if !project.confirmedProjectLinks.isEmpty {
            values["confirmed_project_links"] = project.confirmedProjectLinks.map { link in
                "project_id: \(link.projectId), source_id: \(link.sourceId), source_type: \(link.sourceType), link_type: \(link.linkType)"
            }.joined(separator: "\n")
        }
    }

    private func legacyPrinciples(_ principles: [PrincipleContext]) -> String {
        principles.map { principle in
            [
                "id": principle.id,
                "title": principle.title,
                "summary": principle.summary,
                "triggerContext": principle.triggerContext,
                "successCriteria": principle.successCriteria,
                "exceptions": principle.exceptions,
                "status": principle.status.rawValue,
                "retrievalReason": principle.retrievalReason,
                "retrievalPolicyVersion": principle.retrievalPolicyVersion
            ]
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: ", ")
        }.joined(separator: "\n")
    }

    func renderedJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum LLMClientError: Error {
    case missingAPIKey
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int, Data)
    case encodingFailed(Error)
    case transport(Error)
}

protocol PromptProvider {
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate
    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate?
}

extension PromptProvider {
    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let template = template(for: id, mode: mode)
        return template.version == version ? template : nil
    }
}

protocol LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data
}

enum LLMStreamEvent: Hashable {
    case token(String)
    case completed
}

protocol StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}

struct MissingAPIKeyLLMClient: LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data {
        throw LLMClientError.missingAPIKey
    }
}

extension MissingAPIKeyLLMClient: StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMClientError.missingAPIKey)
        }
    }
}

final class PromptTracingLLMClient: LLMClient {
    private let base: LLMClient
    private let repository: PromptRunRepository
    private let modelProvider: String
    private let modelName: String

    init(
        base: LLMClient,
        repository: PromptRunRepository,
        modelProvider: String,
        modelName: String
    ) {
        self.base = base
        self.repository = repository
        self.modelProvider = modelProvider
        self.modelName = modelName
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        do {
            let data = try await base.complete(request)
            await saveRun(for: request, responseData: data, error: nil)
            return data
        } catch {
            await saveRun(for: request, responseData: nil, error: error)
            throw error
        }
    }

    private func saveRun(for request: LLMRequest, responseData: Data?, error: Error?) async {
        let errorMessage: String?
        if let llmError = error as? LLMClientError {
            errorMessage = llmError.userFacingMessage
        } else {
            errorMessage = error?.localizedDescription
        }

        let run = PromptRun(
            promptId: request.prompt.id.rawValue,
            promptVersion: request.prompt.version,
            promptSourceKind: request.prompt.sourceKind,
            promptPackId: request.prompt.packId,
            promptPackVersion: request.prompt.packVersion,
            promptPackDisplayName: request.prompt.packDisplayName,
            systemPolicyVersion: request.prompt.systemPolicyVersion,
            contextPolicyVersion: request.prompt.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: request.prompt.outputSchemaVersion,
            evalSuiteVersion: request.prompt.evalSuiteVersion,
            rollbackTargetVersion: request.prompt.rollbackTargetVersion,
            modelProvider: modelProvider,
            modelName: modelName,
            sessionMode: sessionMode(from: request),
            sourceRecordIds: Array(Set(request.sourceRecordIDs)).sorted(),
            contextRecordIds: Array(Set(request.contextRecordIDs)).sorted(),
            requestSummary: request.inputSummary,
            responseJSON: responseData.flatMap { String(data: $0, encoding: .utf8) },
            error: errorMessage
        )

        try? await repository.savePromptRun(run)
    }

    private func sessionMode(from request: LLMRequest) -> String {
        request.contextPayload?.userChoice.sessionMode
            ?? "unknown"
    }
}

extension PromptTracingLLMClient: StreamingLLMClient {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        guard let streamingBase = base as? StreamingLLMClient else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LLMClientError.invalidResponse)
            }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                var rawStream = ""
                do {
                    for try await event in streamingBase.stream(request) {
                        if case .token(let text) = event {
                            rawStream += text
                        }
                        continuation.yield(event)
                    }
                    await saveRun(
                        for: request,
                        responseData: Data(rawStream.utf8),
                        error: nil
                    )
                    continuation.finish()
                } catch {
                    await saveRun(
                        for: request,
                        responseData: rawStream.isEmpty ? nil : Data(rawStream.utf8),
                        error: error
                    )
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct PromptEvalRunner {
    static let currentRunnerVersion = "prompt-eval-runner.v1"

    private let promptProvider: PromptProvider
    private let parser: TodayAIResponseParser

    init(promptProvider: PromptProvider, parser: TodayAIResponseParser = TodayAIResponseParser()) {
        self.promptProvider = promptProvider
        self.parser = parser
    }

    func runFixedSuite(mode: SessionMode = .standard, createdAt: Date = .now) -> [PromptEvalRun] {
        PromptEvalCase.fixedSuite
            .groupedByPromptId()
            .map { promptId, cases in
                let template = promptProvider.template(for: promptId, mode: mode)
                let results = cases.map(runCase)
                return PromptEvalRun(
                    promptId: promptId.rawValue,
                    promptVersion: template.version,
                    promptSourceKind: template.sourceKind,
                    promptPackId: template.packId,
                    promptPackVersion: template.packVersion,
                    promptPackDisplayName: template.packDisplayName,
                    systemPolicyVersion: template.systemPolicyVersion,
                    contextPolicyVersion: template.contextPolicyVersion,
                    inputSchemaVersion: 1,
                    outputSchemaVersion: template.outputSchemaVersion,
                    evalSuiteVersion: template.evalSuiteVersion,
                    runnerVersion: Self.currentRunnerVersion,
                    caseResults: results,
                    createdAt: createdAt
                )
            }
            .sorted { $0.promptId < $1.promptId }
    }

    private func runCase(_ evalCase: PromptEvalCase) -> PromptEvalCaseResult {
        do {
            try evalCase.assertion(parser)
            return PromptEvalCaseResult(
                caseId: evalCase.caseId,
                name: evalCase.name,
                status: .passed,
                inputSummary: evalCase.inputSummary,
                expectedBehavior: evalCase.expectedBehavior,
                actualObservation: "passed: fixed-suite assertions satisfied.",
                diagnosticReason: "fixed-suite pass: \(evalCase.caseId)"
            )
        } catch {
            let reason = String(describing: error)
            return PromptEvalCaseResult(
                caseId: evalCase.caseId,
                name: evalCase.name,
                status: .failed,
                failureReason: reason,
                inputSummary: evalCase.inputSummary,
                expectedBehavior: evalCase.expectedBehavior,
                actualObservation: "failed: \(reason)",
                diagnosticReason: "fixed-suite failure: \(reason)"
            )
        }
    }
}

private struct PromptEvalFailure: Error, CustomStringConvertible {
    var description: String
}

private struct PromptEvalCase {
    var promptId: PromptID
    var caseId: String
    var name: String
    var inputSummary: String
    var expectedBehavior: String
    var assertion: (TodayAIResponseParser) throws -> Void

    static let fixedSuite: [PromptEvalCase] = [
        PromptEvalCase(
            promptId: .organizeCards,
            caseId: "cards.messy_daily_input",
            name: "Messy daily input produces typed sensitive cards",
            inputSummary: "Messy meeting coordination input with one sensitive internal-project card.",
            expectedBehavior: "Produce communication, risk, and task cards while preserving sensitivity classification."
        ) { _ in
            let assembler = XMLStreamingCardAssembler()
            _ = assembler.append(
                """
                <MINGSI_STREAM version="1">
                <CARD>
                <TYPE>communication</TYPE>
                <TITLE>会前没有明确要确认的决策</TITLE>
                <BODY>会议推进时先讨论细节，最后才发现负责人和验收标准没有写清。</BODY>
                <IMPORTANCE>high</IMPORTANCE>
                <SENSITIVITY>normal</SENSITIVITY>
                <CONFIDENCE>high</CONFIDENCE>
                <REASON>这是可复用的沟通流程问题。</REASON>
                </CARD>
                <CARD>
                <TYPE>risk</TYPE>
                <TITLE>内部项目名需要抽象化</TITLE>
                <BODY>用户提到具体内部项目和客户语境，后续模型调用应避免重复细节。</BODY>
                <IMPORTANCE>medium</IMPORTANCE>
                <SENSITIVITY>possibly_sensitive</SENSITIVITY>
                <CONFIDENCE>medium</CONFIDENCE>
                <REASON>符合隐私边界要求。</REASON>
                </CARD>
                <CARD>
                <TYPE>task</TYPE>
                <TITLE>下次会议前写出决策清单</TITLE>
                <BODY>列出本次会议要确认的事项、负责人和完成标准。</BODY>
                <IMPORTANCE>high</IMPORTANCE>
                <SENSITIVITY>normal</SENSITIVITY>
                <CONFIDENCE>high</CONFIDENCE>
                <REASON>可转化为明日任务。</REASON>
                </CARD>
                </MINGSI_STREAM>
                """
            )
            _ = assembler.finish()
            let cards = assembler.currentCards.compactMap(\.domainCard)
            try expect(cards.count == 3, "Expected three cards.")
            try expect(cards.map(\.type) == [.communication, .risk, .task], "Expected communication/risk/task cards.")
            try expect(cards.contains { $0.sensitivity == .possiblySensitive }, "Expected a possibly sensitive card.")
        },
        PromptEvalCase(
            promptId: .recommendLenses,
            caseId: "lenses.recommends_supported_default",
            name: "Lens recommendations include supported default",
            inputSummary: "Meeting reflection where facts and interpretation are mixed.",
            expectedBehavior: "Recommend at most two supported lens ids and choose a supported default lens."
        ) { _ in
            let object = try jsonObject(Self.recommendLensesFixture)
            guard let recommendations = object["recommended_lenses"] as? [[String: Any]],
                  let first = recommendations.first,
                  let defaultLens = object["default_lens"] as? String,
                  let id = first["id"] as? String else {
                throw PromptEvalFailure(description: "Expected recommended_lenses and default_lens.")
            }
            let supported = Set(BuiltinLensCatalog.library.items.map(\.promptId))
            try expect(supported.contains(id), "Expected supported lens id.")
            try expect(supported.contains(defaultLens), "Expected supported default lens.")
            try expect(recommendations.count <= 2, "Expected at most two recommendations.")
        },
        PromptEvalCase(
            promptId: .generateQuestions,
            caseId: "questions.concrete_lens_specific",
            name: "Questions are concrete and lens-specific",
            inputSummary: "First-principles and evidence-check meeting cards requiring lens-specific follow-up questions.",
            expectedBehavior: "Generate concrete, lens-specific questions including fact-vs-judgment and disconfirmation checks."
        ) { parser in
            let questions = try parser.parseQuestions(from: Data(Self.questionsFixture.utf8))
            try expect(questions.count == 3, "Expected three questions.")
            try expect(questions.contains { $0.question.contains("事实") && $0.question.contains("判断") }, "Expected fact-vs-judgment question.")
            try expect(questions.contains { $0.question.contains("最可能") && $0.question.contains("推翻") }, "Expected disconfirming evidence question.")
        },
        PromptEvalCase(
            promptId: .generateQuests,
            caseId: "quests.main_quest_verifiable",
            name: "Main quest has verifiable criteria",
            inputSummary: "Meeting preparation card and reflection answers about reducing rework.",
            expectedBehavior: "Generate one main quest with observable completion criteria and an owner signal."
        ) { parser in
            let quests = try parser.parseQuests(from: Data(Self.questsFixture.utf8))
            try expect(quests.count == 1, "Expected exactly one quest.")
            try expect(quests[0].type == .main, "Expected main quest.")
            try expect(quests[0].completionCriteria.contains("负责人"), "Expected owner in completion criteria.")
            try expect(quests[0].completionCriteria.count > quests[0].title.count, "Expected detailed completion criteria.")
        },
        PromptEvalCase(
            promptId: .verifyQuest,
            caseId: "verify.calibration_note_required",
            name: "Verification requires a calibration note",
            inputSummary: "Quest verification result where the user completed work but criteria were unclear.",
            expectedBehavior: "Return a calibration note and recommendation tied to the quest's acceptance criteria."
        ) { parser in
            let result = try parser.parseVerification(from: Data(Self.verificationFixture.utf8))
            try expect(result.calibrationNote.contains("验收标准"), "Expected calibration note to reference criteria.")
            try expect(result.recommendation?.isEmpty == false, "Expected recommendation.")
        },
        PromptEvalCase(
            promptId: .extractPrinciple,
            caseId: "principle.behavior_rule_not_slogan",
            name: "Principle is a behavior rule rather than a slogan",
            inputSummary: "Repeated meeting ownership pattern suitable for a reusable behavior rule.",
            expectedBehavior: "Extract a principle with concrete actions and success criteria rather than a vague slogan."
        ) { parser in
            let principles = try parser.parsePrinciples(from: Data(Self.principleFixture.utf8))
            try expect(principles.count == 1, "Expected one principle.")
            try expect(principles[0].actions.count >= 3, "Expected concrete actions.")
            try expect(principles[0].successCriteria.contains("负责人"), "Expected success criteria.")
        },
        PromptEvalCase(
            promptId: .suggestProjectLinks,
            caseId: "project_links.evidence_backed_candidates",
            name: "Project link suggestions keep evidence refs",
            inputSummary: "Daily project evidence containing one active-project blocker and one new long-running project candidate.",
            expectedBehavior: "Preserve evidence refs on both project link candidates and new project candidates."
        ) { parser in
            let result = try parser.parseProjectSuggestions(from: Data(Self.projectLinksFixture.utf8))
            try expect(result.projectLinks.count == 1, "Expected one link candidate.")
            try expect(result.projectLinks[0].sourceId == "card-123", "Expected source evidence id.")
            try expect(result.projectCandidates.first?.sourceRefs == ["card-456", "quest-789"], "Expected new project source refs.")
        },
        PromptEvalCase(
            promptId: .generateProjectInsights,
            caseId: "project_insights.source_refs_required",
            name: "Project insights preserve source refs",
            inputSummary: "Project insight fixture with a single quest-backed progress signal.",
            expectedBehavior: "Return only insights with valid source refs."
        ) { parser in
            let result = try parser.parseProjectInsights(from: Data(Self.projectInsightsFixture.utf8))
            try expect(result.insights.count == 1, "Expected one project insight.")
            try expect(result.insights[0].sourceRefs == ["quest-123"], "Expected source refs.")
        },
        PromptEvalCase(
            promptId: .suggestProjectMerges,
            caseId: "project_merges.overlap_evidence_required",
            name: "Project merge candidates require overlap evidence",
            inputSummary: "Two project candidates with explicit overlapping evidence links.",
            expectedBehavior: "Return merge candidates only when overlap evidence refs are present."
        ) { parser in
            let candidates = try parser.parseProjectMergeCandidates(from: Data(Self.projectMergesFixture.utf8))
            try expect(candidates.count == 1, "Expected one merge candidate.")
            try expect(candidates[0].overlappingEvidenceRefs == ["link-1", "verification-2"], "Expected overlap refs.")
        },
        PromptEvalCase(
            promptId: .weeklyCalibration,
            caseId: "growth.weekly_contributions_have_evidence",
            name: "Weekly growth contributions have evidence refs",
            inputSummary: "Weekly growth fixture with evidence-backed positive and negative metric contributions.",
            expectedBehavior: "Produce a draft-review weekly snapshot and metric contributions with source ids."
        ) { parser in
            let result = try parser.parseGrowthReport(from: Data(Self.growthFixture.utf8), period: "weekly", completeLoopCount: 5)
            try expect(result.snapshot.status == .draftReview, "Expected draft review growth snapshot.")
            try expect(result.contributions.count == 2, "Expected two metric contributions.")
            try expect(result.contributions.allSatisfy { !$0.sourceId.isEmpty }, "Expected contribution source ids.")
        },
        PromptEvalCase(
            promptId: .monthlyGrowth,
            caseId: "growth.monthly_contributions_have_evidence",
            name: "Monthly growth contributions have evidence refs",
            inputSummary: "Monthly growth fixture reusing evidence-backed metric contributions.",
            expectedBehavior: "Produce a monthly snapshot and contributions linked to source daily entries."
        ) { parser in
            let result = try parser.parseGrowthReport(from: Data(Self.growthFixture.utf8), period: "monthly", completeLoopCount: 6)
            try expect(result.snapshot.period == "monthly", "Expected monthly period.")
            try expect(result.contributions.allSatisfy { !$0.sourceDailyEntryId.uuidString.isEmpty }, "Expected source daily entry ids.")
        }
    ]

    private static let recommendLensesFixture = """
    {
      "recommended_lenses": [
        {
          "id": "evidence_check",
          "name": "证据校验",
          "why_recommended": "今天的会议判断混合了事实和解释。"
        }
      ],
      "default_lens": "evidence_check"
    }
    """

    private static let questionsFixture = """
    {
      "questions": [
        {
          "question": "这次会议中，哪些内容是事实，哪些只是你对对方意图的判断？",
          "why_this_matters": "证据校验透镜要求先分开事实和解释，避免把感觉当结论。",
          "expected_answer_type": "fact"
        },
        {
          "question": "如果你对会议低效的判断是错的，最可能被哪条证据推翻？",
          "why_this_matters": "反方问题可以阻止只证明自己原本的看法。",
          "expected_answer_type": "validation"
        },
        {
          "question": "明天只做一件事时，哪一个动作最能减少后续返工？",
          "why_this_matters": "杠杆分析必须把思考落到可执行取舍。",
          "expected_answer_type": "tradeoff"
        }
      ]
    }
    """

    private static let questsFixture = """
    {
      "main_quest": {
        "type": "main",
        "title": "会前写出决策清单并确认负责人",
        "why_it_matters": "这是减少会议返工的最高杠杆动作。",
        "completion_criteria": "会议开始前完成一页清单，包含要确认的决策、负责人、验收标准，并在会后发出确认摘要。",
        "expected_resistance": "临时事项会诱导你直接开会而不先写清楚目标。",
        "reflection_question": "这次准备是否让会议少绕了一轮？",
        "linked_cards": ["会前没有明确要确认的决策"]
      },
      "side_quests": [],
      "observation_quest": null,
      "rejected_low_value_tasks": ["先把会议纪要排版得更完整"]
    }
    """

    private static let verificationFixture = """
    {
      "calibration_note": "任务完成，但验收标准一开始还不够可观察。",
      "likely_issue": "unclear_criteria",
      "recommendation": "明天的主任务先写出可验收的完成标准。"
    }
    """

    private static let principleFixture = """
    {
      "principle_candidate": {
        "title": "会议前先定义要确认的决策",
        "summary": "重要会议前先写清要确认什么、谁负责、什么算完成。",
        "trigger_context": "跨角色会议或需要推进协作时。",
        "actions": ["写出要确认的决策", "标出负责人", "写出验收标准", "会后发送确认摘要"],
        "success_criteria": "参会者能复述下一步负责人和完成标准。",
        "exceptions": "低风险同步会可以只写一句目标。"
      }
    }
    """

    private static let projectLinksFixture = """
    {
      "project_link_candidates": [
        {
          "project_id": "11111111-1111-1111-1111-111111111111",
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

    private static let projectInsightsFixture = """
    {
      "project_insights": [
        {
          "project_id": "22222222-2222-2222-2222-222222222222",
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

    private static let projectMergesFixture = """
    {
      "merge_candidates": [
        {
          "source_project_id": "33333333-3333-3333-3333-333333333333",
          "target_project_id": "44444444-4444-4444-4444-444444444444",
          "reason": "Both projects track the same repeated ownership ambiguity.",
          "overlapping_evidence_refs": ["link-1", "verification-2"],
          "risks_if_merged": ["One narrow context may get hidden."],
          "risks_if_kept_separate": ["Evidence remains split across duplicate projects."],
          "confidence": "high"
        }
      ]
    }
    """

    private static let growthFixture = """
    {
      "insufficient_evidence": false,
      "summary": "会议目标和验收标准比上周更清晰。",
      "metrics": {
        "clarity": {"value": 3.8, "delta": 0.2, "reason": "多次任务先定义负责人和验收标准。"},
        "value_judgment": {"value": 3.4, "delta": 0.1, "reason": "开始拒绝低价值排版任务。"},
        "execution_reliability": {"value": 3.2, "delta": 0.1, "reason": "主任务完成率稳定。"},
        "calibration": {"value": 3.1, "delta": 0.1, "reason": "复盘能识别标准不清。"},
        "reflection_depth": {"value": 3.6, "delta": 0.2, "reason": "能区分事实和判断。"}
      },
      "metric_contributions": [
        {
          "metric": "clarity",
          "direction": "positive",
          "delta": 0.20,
          "title": "会议目标更清晰",
          "reason": "用户在任务中明确要求会前写出决策、负责人和验收标准。",
          "source_type": "quest",
          "source_id": "quest-001",
          "source_daily_entry_id": "55555555-5555-5555-5555-555555555555"
        },
        {
          "metric": "reflection_depth",
          "direction": "positive",
          "delta": 0.10,
          "title": "能拆分事实和判断",
          "reason": "复盘记录了哪些是事实、哪些是对方意图的解释。",
          "source_type": "thinking_card",
          "source_id": "card-002",
          "source_daily_entry_id": "55555555-5555-5555-5555-555555555555"
        }
      ],
      "next_training_focus": "继续把会议任务写成可验收标准。"
    }
    """

    private static func jsonObject(_ json: String) throws -> [String: Any] {
        guard
            let data = json.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw PromptEvalFailure(description: "Invalid JSON object fixture.")
        }
        return object
    }
}

private extension Array where Element == PromptEvalCase {
    func groupedByPromptId() -> [(PromptID, [PromptEvalCase])] {
        var grouped: [PromptID: [PromptEvalCase]] = [:]
        for evalCase in self {
            grouped[evalCase.promptId, default: []].append(evalCase)
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.caseId < $1.caseId }) }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }
}

private func expect(_ condition: Bool, _ message: String) throws {
    guard condition else {
        throw PromptEvalFailure(description: message)
    }
}

protocol ReminderService {
    func requestPermission() async throws -> ReminderPermissionStatus
    func schedule(_ request: ReminderRequest) async throws
    func cancel(id: String) async
}

enum ReminderPermissionStatus: Hashable {
    case notDetermined
    case authorized
    case denied

    var allowsScheduling: Bool {
        self == .authorized
    }
}

enum ReminderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied."
        }
    }
}

struct ReminderRequest: Hashable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

final class LocalPromptProvider: PromptProvider {
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        let asset = Self.assetMetadata(for: id)
        return PromptTemplate(
            id: id,
            version: asset.promptVersion,
            systemPolicyVersion: asset.systemPolicyVersion,
            contextPolicyVersion: asset.contextPolicyVersion,
            evalSuiteVersion: asset.evalSuiteVersion,
            rollbackTargetVersion: asset.rollbackTargetVersion,
            systemText: id == .organizeCards ? Self.streamingCardsSystemText(for: mode) : Self.systemText(for: mode),
            userText: Self.userText(for: id, mode: mode),
            outputSchemaVersion: asset.outputSchemaVersion
        )
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let current = template(for: id, mode: mode)
        if current.version == version {
            return current
        }
        return Self.historicalTemplate(for: id, mode: mode, version: version, current: current)
    }

    private struct PromptAssetMetadata {
        var promptVersion: String
        var systemPolicyVersion: String
        var contextPolicyVersion: String
        var outputSchemaVersion: Int
        var evalSuiteVersion: String
        var rollbackTargetVersion: String?
    }

    private static func assetMetadata(for id: PromptID) -> PromptAssetMetadata {
        let rollbackTargetVersion: String?
        switch id {
        case .generateQuestions:
            rollbackTargetVersion = "0.9.0"
        default:
            rollbackTargetVersion = nil
        }

        return PromptAssetMetadata(
            promptVersion: "1.0.0",
            systemPolicyVersion: "system.v1",
            contextPolicyVersion: "context.\(id.rawValue).v1",
            outputSchemaVersion: 1,
            evalSuiteVersion: "\(id.rawValue).eval.v1",
            rollbackTargetVersion: rollbackTargetVersion
        )
    }

    private static func historicalTemplate(
        for id: PromptID,
        mode: SessionMode,
        version: String,
        current: PromptTemplate
    ) -> PromptTemplate? {
        guard id == .generateQuestions, version == "0.9.0" else {
            return nil
        }

        return PromptTemplate(
            id: id,
            version: version,
            systemPolicyVersion: current.systemPolicyVersion,
            contextPolicyVersion: current.contextPolicyVersion,
            evalSuiteVersion: current.evalSuiteVersion,
            rollbackTargetVersion: nil,
            systemText: current.systemText,
            userText: Self.generateQuestionsV090UserText(for: mode),
            outputSchemaVersion: current.outputSchemaVersion
        )
    }

    private static func systemText(for mode: SessionMode) -> String {
        """
        You are 明思, a thinking coach for a busy knowledge worker.
        Help the user clarify problems, challenge assumptions, choose high-value actions, and calibrate judgment.
        Do not decide for the user.
        Do not replace the user's thinking.
        Separate facts, interpretations, assumptions, risks, and validation needs.
        Do not encourage the user to share confidential company information, code, customer data, or internal documents.
        Be concise, concrete, and non-performative.
        Language: 默认使用简体中文回答；if the user clearly writes in another language, follow the user's input language.
        Session mode: \(mode.rawValue). Quick is shortest path, standard is the default full loop, and deep uses more scrutiny.
        Return valid JSON only, matching the requested schema.
        """
    }

    private static func streamingCardsSystemText(for mode: SessionMode) -> String {
        """
        You are 明思, a thinking coach for a busy knowledge worker.
        Convert raw daily input into editable thinking cards.
        Do not decide for the user.
        Do not replace the user's thinking.
        Do not encourage the user to share confidential company information, code, customer data, or internal documents.
        Language: 默认使用简体中文回答；if the user clearly writes in another language, follow the user's input language.
        Session mode: \(mode.rawValue). Quick is shortest path, standard is the default full loop, and deep uses more scrutiny.
        Return only MINGSI_STREAM_V1 XML-like tags. Do not return JSON, Markdown, comments, or explanations outside the allowed tags.
        """
    }

    private static func generateQuestionsV090UserText(for mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        return """
        Generate concrete reflection questions from the confirmed cards.
        Questions must be specific to the user's actual situation.
        Do not ask generic self-help questions.
        Include at least one question that tests an assumption or missing fact.
        \(modeGuidance)

        Question count: quick 1-2, standard 3, deep 4-5.
        Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
        Return JSON:
        {
          "questions": [
            {
              "question": "string",
              "why_this_matters": "string",
              "expected_answer_type": "fact | judgment | tradeoff | validation"
            }
          ]
        }
        """
    }

    private static func userText(for id: PromptID, mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        switch id {
        case .organizeCards:
            return """
            Organize the user's raw daily input into editable thinking cards.
            Do not summarize into one article.
            Extract concrete facts, problems, decisions, risks, ideas, communications, and tasks.
            Preserve uncertainty. If boundaries are unclear, infer likely cards and mark lower confidence.
            If content may contain confidential company details, mark it possibly_sensitive or sensitive and avoid repeating unnecessary specifics.
            \(modeGuidance)

            Input will include rawText, optional projectContext, privacyRules, and sessionMode.
            Return only this controlled XML-like streaming format:
            <MINGSI_STREAM version="1">
            <CARD>
            <TYPE>fact | problem | decision | risk | idea | communication | task</TYPE>
            <TITLE>string</TITLE>
            <BODY>string</BODY>
            <IMPORTANCE>low | medium | high</IMPORTANCE>
            <SENSITIVITY>normal | possibly_sensitive | sensitive</SENSITIVITY>
            <CONFIDENCE>low | medium | high</CONFIDENCE>
            <REASON>string</REASON>
            </CARD>
            </MINGSI_STREAM>

            Rules:
            - Output no Markdown and no text outside the tags.
            - Start a CARD as soon as a candidate is clear enough; do not wait to plan every card first.
            - Every CARD must close with </CARD>.
            - BODY must not contain XML control tags. Rewrite angle brackets as plain words.
            - Prefer quick 1-3 cards, standard 2-6 cards, deep 3-8 cards.

            Example:
            <MINGSI_STREAM version="1">
            <CARD>
            <TYPE>problem</TYPE>
            <TITLE>会议前没有定义确认事项</TITLE>
            <BODY>今天的会议讨论了接口归属，但会前没有先列出必须确认的问题。</BODY>
            <IMPORTANCE>high</IMPORTANCE>
            <SENSITIVITY>normal</SENSITIVITY>
            <CONFIDENCE>high</CONFIDENCE>
            <REASON>这是影响会议效率和结论质量的流程问题。</REASON>
            </CARD>
            </MINGSI_STREAM>
            """

        case .recommendLenses:
            return """
            Review the confirmed cards and recommend up to two thinking lenses.
            Choose lenses that improve the user's thinking quality today.
            Prefer lenses that expose unclear goals, weak evidence, opportunity cost, hidden assumptions, or low-leverage execution.
            Explain briefly why each lens is useful.
            \(modeGuidance)

            Input will include confirmedCards, excludedCardTitles, and sessionMode.
            Return JSON:
            {
              "recommended_lenses": [
                {
                  "id": "first_principles | occams_razor | opposing_view | opportunity_cost | leverage_analysis | evidence_check | execution_bias_check",
                  "name": "string",
                  "why_recommended": "string"
                }
              ],
              "default_lens": "string"
            }
            """

        case .generateQuestions:
            return """
            Generate lens-specific reflection questions from the confirmed cards.
            Questions must be specific to the user's content.
            Do not ask generic self-help questions.
            At least one question should challenge a hidden assumption.
            At least one question should connect to tomorrow's action.
            \(modeGuidance)

            Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
            Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
            Return JSON:
            {
              "questions": [
                {
                  "question": "string",
                  "why_this_matters": "string",
                  "expected_answer_type": "fact | judgment | tradeoff | validation"
                }
              ]
            }
            """

        case .generateQuests:
            return """
            Generate tomorrow's quests from confirmed cards and user answers.
            Create exactly one main quest unless information is insufficient.
            Create at most two side quests and at most one observation quest.
            The main quest should target the highest-value action, not the easiest task.
            Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
            If information is insufficient, ask for clarification rather than inventing a task.
            \(modeGuidance)

            Input will include confirmedCards, reflectionAnswers, selectedLens, and sessionMode.
            Return JSON:
            {
              "main_quest": {
                "type": "main",
                "title": "string",
                "why_it_matters": "string",
                "completion_criteria": "string",
                "expected_resistance": "string",
                "reflection_question": "string",
                "linked_cards": ["string"]
              },
              "side_quests": [],
              "observation_quest": null,
              "rejected_low_value_tasks": ["string"]
            }
            """

        case .verifyQuest:
            return """
            Review yesterday's quest, completion status, and actual value.
            Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
            Do not blame the user.
            Return a concise calibration note and one recommendation for today's quest design.
            \(modeGuidance)

            Input will include yesterdayQuest, userVerification, completionEvidence, and actualValue.
            Return JSON:
            {
              "calibration_note": "string",
              "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
              "recommendation": "string"
            }
            """

        case .extractPrinciple:
            return """
            From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
            Do not create a principle if the lesson is too situational.
            The principle must be concrete enough to apply later.
            Frame it as a behavior rule, not a slogan.
            \(modeGuidance)

            Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
            Return JSON:
            {
              "principle_candidate": {
                "title": "string",
                "summary": "string",
                "trigger_context": "string",
                "actions": ["string"],
                "success_criteria": "string",
                "exceptions": "string",
                "source_card_titles": ["string"]
              }
            }
            If no reusable rule is justified, return:
            {
              "principle_candidate": null
            }
            """

        case .weeklyCalibration:
            return """
            Analyze confirmed daily records and quest verifications for the week.
            Produce a strict Growth attribution report.

            Rules:
            - Growth is an attribution ledger, not a personality test.
            - Fewer than 3 complete loops: return insufficient_evidence=true.
            - Every score delta must be explained by positive or negative metric_contributions.
            - Every contribution MUST include source_type, source_id, and source_daily_entry_id (UUID of the daily entry).
            - A contribution without source evidence must be omitted.
            - Delta per contribution must be between 0.01 and 0.30.
            - Avoid vague praise. Use evidence snippets.
            - Include dismissed contributions from prior rounds as context only.
            \(modeGuidance)

            Input includes: period, complete_loop_count, evidence_summaries (one per daily entry with id, card count, quest, verification), optional previous scores, optional dismissed_contributions.

            Return JSON:
            {
              "insufficient_evidence": false,
              "summary": "string: one-sentence attribution summary",
              "metrics": {
                "clarity": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "value_judgment": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "execution_reliability": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "calibration": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "reflection_depth": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"}
              },
              "metric_contributions": [
                {
                  "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
                  "direction": "positive | negative",
                  "delta": 0.01-0.30,
                  "title": "string",
                  "reason": "string",
                  "source_type": "daily_entry | thinking_card | quest | verification | principle",
                  "source_id": "UUID or string id of the source record",
                  "source_daily_entry_id": "UUID of the daily entry"
                }
              ],
              "next_training_focus": "string"
            }

            If insufficient evidence:
            {
              "insufficient_evidence": true,
              "summary": "string: explain what is missing",
              "metrics": {},
              "metric_contributions": [],
              "next_training_focus": "string"
            }
            """

        case .monthlyGrowth:
            return """
            Compare this month's records against baseline and early-month examples.
            Produce a strict Growth attribution report.

            Rules:
            - Growth is an attribution ledger, not a personality test.
            - Fewer than 3 complete loops: return insufficient_evidence=true.
            - Every score delta must be explained by positive or negative metric_contributions.
            - Every contribution MUST include source_type, source_id, and source_daily_entry_id (UUID of the daily entry).
            - A contribution without source evidence must be omitted.
            - Delta per contribution must be between 0.01 and 0.30.
            - Do not present scores as objective intelligence measures; present them as personal trend indicators.
            - Use before/after evidence.
            \(modeGuidance)

            Input includes: period, complete_loop_count, evidence_summaries, optional previous scores, optional dismissed_contributions.

            Return JSON:
            {
              "insufficient_evidence": false,
              "summary": "string",
              "metrics": {
                "clarity": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "value_judgment": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "execution_reliability": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "calibration": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"},
                "reflection_depth": {"value": 1.0-5.0, "delta": -1.0 to 1.0, "reason": "string"}
              },
              "metric_contributions": [
                {
                  "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
                  "direction": "positive | negative",
                  "delta": 0.01-0.30,
                  "title": "string",
                  "reason": "string",
                  "source_type": "daily_entry | thinking_card | quest | verification | principle",
                  "source_id": "UUID or string id of the source record",
                  "source_daily_entry_id": "UUID of the daily entry"
                }
              ],
              "next_training_focus": "string"
            }

            If insufficient evidence:
            {
              "insufficient_evidence": true,
              "summary": "string",
              "metrics": {},
              "metric_contributions": [],
              "next_training_focus": "string"
            }
            """

        case .suggestProjectLinks:
            return """
            Review confirmed cards, quests, verifications, principles, and existing active projects.
            Suggest at most two project link candidates to existing projects.
            If no existing project fits and the evidence suggests a recurring long-running topic, propose at most one new project candidate.
            Do not use company-sensitive names.
            Only link confirmed evidence.
            Do not create or merge projects automatically.
            Return candidates that require user confirmation.
            Do not treat repeated keywords as a project unless there is a recurring goal, blocker, decision pattern, or action standard.

            Rules:
            - Every candidate must include source_ids referencing real evidence IDs.
            - A candidate without source evidence must be omitted.
            - A link candidate must reference an existing project_id or a candidate_project_name.
            - Limit: at most 2 link candidates and 1 new project candidate per request.
            - Do not suggest a link if the source_id already has a confirmed project link.

            Input includes: confirmed_cards, quests, active_projects, existing_link_source_ids.
            Return JSON:
            {
              "project_link_candidates": [
                {
                  "project_id": "UUID of existing project (optional if candidate_project_name is set)",
                  "candidate_project_name": "string (optional, used when matching by name)",
                  "source_type": "thinking_card | quest | verification | principle",
                  "source_id": "UUID of the source record",
                  "link_type": "evidence | blocker | decision | task | principle | risk",
                  "reason": "string: why this evidence belongs to this project",
                  "confidence": "high | medium | low",
                  "requires_user_confirmation": true
                }
              ],
              "new_project_candidates": [
                {
                  "name": "string: abstract, non-sensitive project name",
                  "goal": "string",
                  "success_criteria": "string",
                  "current_bottleneck": "string",
                  "why_this_is_long_running": "string: must explain recurring goal, blocker, decision pattern, or action standard",
                  "reason": "string: why this topic deserves a dedicated long-running project",
                  "source_ids": ["UUID of source evidence"],
                  "source_refs": [],
                  "privacy_safe_name_required": false,
                  "confidence": "high | medium | low"
                }
              ]
            }
            """

        case .generateProjectInsights:
            return """
            Review a project's confirmed evidence and generate evidence-backed insights.
            Identify progress, blocker changes, thinking changes, open questions closed, principles practiced, and next bets.
            Every insight must be grounded in specific evidence with source references.
            Do not invent insights without evidence.
            If fewer than 3 confirmed evidence items exist, return insufficient_evidence_reason with a clear explanation.

            Rules:
            - Every insight must include source_refs referencing real evidence IDs (cards, quests, verifications, principles).
            - A thinking_change insight must include before_text and after_text.
            - A blocker_change insight must include before_text and after_text.
            - Limit: at most 5 insights per request.
            - Do not repeat insights already accepted by the user.
            - Focus on patterns and changes visible across multiple evidence items.

            Input includes: project_id, project_name, project_goal, project_success_criteria, confirmed_evidence (array with id, type, title, body), accepted_insight_count.
            Return JSON:
            {
              "project_insights": [
                {
                  "project_id": "UUID of the project",
                  "insight_type": "progress | blocker_change | thinking_change | open_question_closed | principle_practiced | next_bet",
                  "title": "string: concise user-facing title",
                  "summary": "string: concise insight",
                  "before": {
                    "text": "string (required for thinking_change and blocker_change)",
                    "source_type": "thinking_card | quest | verification | principle | daily_entry",
                    "source_id": "source evidence id"
                  },
                  "after": {
                    "text": "string (required for thinking_change and blocker_change)",
                    "source_type": "thinking_card | quest | verification | principle | daily_entry",
                    "source_id": "source evidence id"
                  },
                  "source_refs": ["UUID or string id of the source evidence"]
                }
              ],
              "insufficient_evidence_reason": "string (null if evidence is sufficient)"
            }

            If insufficient evidence:
            {
              "insights": [],
              "insufficient_evidence_reason": "string: explain what evidence is missing and why it's insufficient"
            }
            """

        case .suggestProjectMerges:
            return """
            Review active projects and their confirmed evidence links to identify potential merge candidates.
            Two active projects should be merged only if they share confirmed evidence and have overlapping goals, blockers, or success criteria.
            Do not suggest merges based solely on name similarity.
            Every overlapping evidence reference must correspond to a confirmed project link for either project.

            Rules:
            - A merge candidate must have both source_project_id and target_project_id referencing existing active projects.
            - overlapping_evidence_refs must be a subset of confirmed project link source IDs for both projects.
            - Source project and target project must be different projects.
            - Limit: at most 3 merge candidates per request.
            - Require user confirmation for all merge candidates.
            - Do not automatically merge projects.

            Input includes: active_projects (array with id, name, goal, success_criteria, status), confirmed_project_links (array with project_id, source_id, source_type, link_type).
            Return JSON:
            {
              "merge_candidates": [
                {
                  "source_project_id": "UUID of the project to merge from",
                  "target_project_id": "UUID of the project to merge into",
                  "reason": "string: explain why these projects should merge (overlapping goals, blockers, success criteria, or evidence patterns)",
                  "overlapping_evidence_refs": ["UUID or string id of overlapping evidence from confirmed links"]
                }
              ]
            }
            """
        }
    }

    private static func modeGuidance(for mode: SessionMode) -> String {
        switch mode {
        case .quick:
            return "Use the shortest useful path. Prefer fewer cards, fewer questions, and one main quest."
        case .standard:
            return "Use the default full loop: clear cards, one recommended lens, three questions, quests, and a principle candidate when justified."
        case .deep:
            return "Use higher scrutiny. Include stronger opposing views, more explicit assumptions, and deeper validation needs."
        }
    }
}

final class LocalNotificationReminder: ReminderService {
    func requestPermission() async throws -> ReminderPermissionStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        @unknown default:
            return .denied
        }
    }

    func schedule(_ request: ReminderRequest) async throws {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notification = UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        try await center.add(notification)
    }

    func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
