import Foundation
import UserNotifications

enum PromptID: String, CaseIterable, Identifiable {
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

struct PromptTemplate: Hashable {
    let id: PromptID
    let version: String
    let systemText: String
    let userText: String
    let outputSchemaVersion: Int
}

struct LLMRequest: Hashable {
    let prompt: PromptTemplate
    let inputSummary: String
    let jsonPayload: [String: String]
    var contextPayload: PromptContextPayload?
    var sourceRecordIDs: [String] = []
    var contextVersion: Int = 1
    var contextRecordIDs: [String] = []
}

struct PromptContextPayload: Codable, Hashable {
    struct CurrentInput: Codable, Hashable {
        var dailyEntryId: String?
        var rawText: String?
    }

    struct UserChoice: Codable, Hashable {
        var sessionMode: String
        var selectedLens: String?
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
    }

    struct Privacy: Codable, Hashable {
        var rules: String?
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
    }

    struct ProjectContext: Codable, Hashable {
        var dailyEntryId: String
        var confirmedCards: [ProjectCardContext]
        var quests: [ProjectQuestContext]
        var activeProjects: [ActiveProjectContext]
        var existingLinkSourceIds: [String]
    }

    var currentInput: CurrentInput
    var userChoice: UserChoice
    var cards: [Card]
    var answers: [Answer]
    var quests: [QuestContext]
    var principles: [PrincipleContext]
    var existingPrinciples: [PrincipleContext]
    var privacy: Privacy
    var growth: GrowthContext?
    var project: ProjectContext?
    var extra: [String: String]

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
        growth: GrowthContext? = nil,
        project: ProjectContext? = nil,
        extra: [String: String] = [:]
    ) {
        self.currentInput = currentInput
        self.userChoice = userChoice
        self.cards = cards
        self.answers = answers
        self.quests = quests
        self.principles = principles
        self.existingPrinciples = existingPrinciples
        self.privacy = privacy
        self.growth = growth
        self.project = project
        self.extra = extra
    }

    func mergingExtra(_ values: [String: String]) -> PromptContextPayload {
        var copy = self
        copy.extra.merge(values) { _, new in new }
        if let privacyRules = values["privacyRules"] {
            copy.privacy.rules = privacyRules
        }
        return copy
    }

    var legacyKeyValues: [String: String] {
        var values = extra
        values["sessionMode"] = userChoice.sessionMode

        if let selectedLens = userChoice.selectedLens {
            values["selectedLens"] = selectedLens
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
        if let privacyRules = privacy.rules {
            values["privacyRules"] = privacyRules
        }
        return values
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
                "status": principle.status.rawValue
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
            inputSchemaVersion: 1,
            outputSchemaVersion: request.prompt.outputSchemaVersion,
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
        request.jsonPayload["sessionMode"] ?? "unknown"
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
        let version = "1.0.0"
        return PromptTemplate(
            id: id,
            version: version,
            systemText: id == .organizeCards ? Self.streamingCardsSystemText(for: mode) : Self.systemText(for: mode),
            userText: Self.userText(for: id, mode: mode),
            outputSchemaVersion: 1
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
        Session mode: \(mode.rawValue). Quick is shortest path, standard is the default full loop, and deep uses more scrutiny.
        Return only MINGSI_STREAM_V1 XML-like tags. Do not return JSON, Markdown, comments, or explanations outside the allowed tags.
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
