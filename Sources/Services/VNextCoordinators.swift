import Foundation

struct TrainingCaseCoordinator {
    func materialize(
        suggestions: [TrainingCaseSuggestion],
        cards: [ThinkingCard],
        dailyEntryId: UUID
    ) -> (cases: [TrainingCase], cards: [ThinkingCard]) {
        let normalized = normalizedSuggestions(suggestions, cards: cards)
        var caseByCardId: [UUID: UUID] = [:]
        let cases = normalized.enumerated().map { index, suggestion in
            let caseId = UUID()
            for cardId in suggestion.cardIds { caseByCardId[cardId] = caseId }
            return TrainingCase(
                id: caseId,
                dailyEntryId: dailyEntryId,
                title: normalizedTitle(suggestion.title, index: index),
                status: .pendingConfirmation,
                sortOrder: index,
                createdBy: .aiSuggested
            )
        }
        let fallbackCaseId = cases.first?.id
        let assignedCards = cards.map { card -> ThinkingCard in
            var updated = card
            updated.trainingCaseId = caseByCardId[card.id] ?? fallbackCaseId
            return updated
        }
        return (cases, assignedCards)
    }

    private func normalizedSuggestions(
        _ suggestions: [TrainingCaseSuggestion],
        cards: [ThinkingCard]
    ) -> [TrainingCaseSuggestion] {
        let cardIds = Set(cards.map(\.id))
        let nonEmpty = suggestions.filter {
            !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.cardIds.isEmpty &&
                Set($0.cardIds).isSubset(of: cardIds)
        }
        let keys = nonEmpty.map { $0.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let assignedIds = nonEmpty.flatMap(\.cardIds)
        let isValid = !nonEmpty.isEmpty &&
            Set(keys).count == keys.count &&
            Set(assignedIds).count == assignedIds.count
        guard isValid else {
            return OrganizedCaptureResult.singleCase(cards: cards).caseSuggestions
        }
        return nonEmpty
    }

    func makeManualCase(dailyEntryId: UUID, title: String, sortOrder: Int) -> TrainingCase? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return TrainingCase(dailyEntryId: dailyEntryId, title: trimmed, status: .ready, sortOrder: sortOrder)
    }

    private func normalizedTitle(_ title: String, index: Int) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "事项 \(index + 1)" : String(trimmed.prefix(60))
    }
}

struct GrowthSettlementPolicy {
    func make(
        verification: Verification,
        quest: Quest,
        caseId: UUID?,
        modelEvidenceItems: [GrowthSettlementEvidenceItem]
    ) -> GrowthSettlement {
        let allowedRefs = Set([quest.id.uuidString, verification.id.uuidString])
        let evidence = modelEvidenceItems.filter { item in
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !item.sourceRefs.isEmpty &&
                Set(item.sourceRefs).isSubset(of: allowedRefs)
        }
        return GrowthSettlement(
            verificationId: verification.id,
            caseId: caseId,
            originalJudgment: quest.calibrationTarget ?? quest.whyItMatters,
            actualResult: verification.evidenceText,
            judgmentUpdate: verification.judgmentUpdate,
            evidenceItems: Array(evidence.prefix(3)),
            calibrationAssessment: verification.calibrationAssessment,
            calibrationNote: verification.calibrationNote,
            recommendation: verification.recommendation
        )
    }
}

struct GuidanceEngine {
    let catalog: [GuidanceCatalogItem]

    init(catalog: [GuidanceCatalogItem] = BuiltinGuidanceCatalog.items) {
        self.catalog = catalog
    }

    func recommendation(
        stage: GuidanceStage,
        triggerKeys: Set<String>,
        states: [UserGuidanceState],
        now: Date = .now
    ) -> GuidanceCatalogItem? {
        let statesById = Dictionary(uniqueKeysWithValues: states.map { ($0.hintId, $0) })
        return catalog.first { item in
            guard item.stage == stage, triggerKeys.contains(item.triggerKey) else { return false }
            guard let state = statesById[item.hintId] else { return true }
            if let snoozedUntil = state.snoozedUntil, snoozedUntil > now { return false }
            if state.status == .mastered && state.counterexampleCount == 0 { return false }
            if let lastShownAt = state.lastShownAt,
               let nextDate = Calendar.current.date(byAdding: .day, value: item.cooldownDays, to: lastShownAt),
               nextDate > now { return false }
            return true
        }
    }

    func recordingEvidence(
        for item: GuidanceCatalogItem,
        state: UserGuidanceState?,
        evidenceRef: String,
        isCounterexample: Bool
    ) -> UserGuidanceState {
        var updated = state ?? UserGuidanceState(hintId: item.hintId)
        guard !evidenceRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !updated.evidenceRefs.contains(evidenceRef) else { return updated }
        updated.evidenceRefs.append(evidenceRef)
        if isCounterexample {
            updated.counterexampleCount += 1
            updated.status = .practicing
        } else {
            updated.evidenceCount += 1
            // A count of reported occasions cannot establish a stable skill.
            // Only the user's explicit preference can suppress a mastered hint.
        }
        updated.updatedAt = .now
        return updated
    }

    /// Local selection is limited to objective eligibility. Which eligible hint
    /// deserves the user's attention is a model decision.
    func eligibleRecommendations(
        stage: GuidanceStage,
        triggerKeys: Set<String>,
        states: [UserGuidanceState],
        now: Date = .now
    ) -> [GuidanceCatalogItem] {
        let statesById = Dictionary(uniqueKeysWithValues: states.map { ($0.hintId, $0) })
        return catalog.filter { item in
            guard item.stage == stage, triggerKeys.contains(item.triggerKey) else { return false }
            guard let state = statesById[item.hintId] else { return true }
            if let snoozedUntil = state.snoozedUntil, snoozedUntil > now { return false }
            if state.status == .mastered && state.counterexampleCount == 0 { return false }
            if let lastShownAt = state.lastShownAt,
               let nextDate = Calendar.current.date(byAdding: .day, value: item.cooldownDays, to: lastShownAt),
               nextDate > now { return false }
            return true
        }
    }
}

struct GuidanceDecisionCandidate: Codable, Hashable {
    var hintId: String
    var copy: String
    var explanation: String
    var stage: GuidanceStage
    var triggerKey: String
}

/// User answers and model assistance have separate provenance. Model feedback
/// is context for avoiding repetition, never proof of user behavior or ability.
struct GuidanceReflectionContext: Codable, Hashable {
    var userQuestionsAndAnswers: [ReflectionQuestion]
    var modelExplanation: CoachExplanation?
    var modelReview: CoachAnswerTrainingFeedback?
}

struct GuidanceDecisionContext: Codable, Hashable {
    var stage: GuidanceStage
    var triggerKeys: [String]
    var candidates: [GuidanceDecisionCandidate]
    var states: [UserGuidanceState]
    var currentCaseId: String?
    var currentCaseTitle: String?
    var evidenceSummary: String
    var reflection: GuidanceReflectionContext? = nil
}

struct GuidanceDecision: Hashable {
    enum Action: String, Hashable { case show, hold }
    var action: Action
    var hintId: String?
    var reason: String
    var promptRunId: UUID
}

enum GuidanceEvidenceResult: String, Hashable {
    case supports
    case counterexample
    case insufficient
}

struct GuidanceEvidenceDecision: Hashable {
    var result: GuidanceEvidenceResult
    var hintId: String
    var reason: String
    var promptRunId: UUID
    var evidenceQuotes: [String] = []
}

/// Model-backed guidance orchestration. The catalog remains versioned local
/// content, but the decision to show or credit a hint is never made by a local
/// keyword or ordering rule.
final class GuidanceAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient

    init(promptProvider: PromptProvider, llmClient: LLMClient) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
    }

    var decisionTemplate: PromptTemplate {
        promptProvider.template(for: .recommendGuidance, mode: .standard)
    }

    func choose(context: GuidanceDecisionContext) async throws -> GuidanceDecision {
        let sourceIds = Array(Set(
            context.states.flatMap(\.evidenceRefs) + [context.currentCaseId].compactMap { $0 }
        )).sorted()
        let payload = PromptContextPayload(
            currentInput: .init(
                dailyEntryId: context.currentCaseId,
                rawText: try Self.encode(context)
            ),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            privacy: .init(rules: "Use only supplied local matter evidence. Do not infer private attributes or use external data.")
        )
        let request = LLMRequest(
            prompt: decisionTemplate,
            inputSummary: "guidance_decision; stage=\(context.stage.rawValue); candidates=\(context.candidates.count)",
            contextPayload: payload,
            sourceRecordIDs: sourceIds,
            contextVersion: 1,
            contextRecordIDs: sourceIds
        )
        let decision = try Self.decode(DecisionDTO.self, from: try await llmClient.complete(request))
        guard let action = GuidanceDecision.Action(rawValue: decision.decision),
              !decision.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw TodayAIParsingError.invalidJSON }
        if action == .hold {
            return GuidanceDecision(action: .hold, hintId: nil, reason: decision.reason, promptRunId: request.traceID)
        }
        guard let hintId = decision.hintId,
              context.candidates.contains(where: { $0.hintId == hintId })
        else { throw TodayAIParsingError.qualityGateFailed(["提示选择必须来自当前候选目录。"]) }
        return GuidanceDecision(action: .show, hintId: hintId, reason: decision.reason, promptRunId: request.traceID)
    }

    func evaluateEvidence(
        item: GuidanceCatalogItem,
        quest: Quest,
        verification: Verification
    ) async throws -> GuidanceEvidenceDecision {
        let evidence = EvidenceDTO(
            hintId: item.hintId,
            hintCopy: item.copy,
            hintExplanation: item.explanation,
            questTitle: quest.title,
            completionCriteria: quest.completionCriteria,
            evidenceText: verification.evidenceText,
            targetJudgment: quest.calibrationTarget,
            completionSelfReport: verification.completion.rawValue,
            valueSelfReport: verification.valueRating.rawValue,
            judgmentSelfReport: verification.judgmentUpdate.rawValue,
            calibrationAssessment: verification.calibrationAssessment
        )
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: verification.sourceDailyEntryId.uuidString, rawText: try Self.encode(evidence)),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            privacy: .init(rules: "Use only the supplied quest and verification evidence.")
        )
        let sourceIds = [item.hintId, quest.id.uuidString, verification.id.uuidString]
        let request = LLMRequest(
            prompt: promptProvider.template(for: .evaluateGuidanceEvidence, mode: .standard),
            inputSummary: "guidance_evidence; hint=\(item.hintId)",
            contextPayload: payload,
            sourceRecordIDs: sourceIds,
            contextVersion: 1,
            contextRecordIDs: sourceIds
        )
        guard verification.questId == quest.id else {
            throw TodayAIParsingError.qualityGateFailed(["guidanceEvidenceQuestMismatch"])
        }
        let decision = try Self.decode(EvidenceDecisionDTO.self, from: try await llmClient.complete(request))
        guard let result = GuidanceEvidenceResult(rawValue: decision.result),
              decision.hintId == item.hintId,
              !decision.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw TodayAIParsingError.invalidJSON }
        let quotes = decision.evidenceQuotes ?? []
        if result == .insufficient {
            guard quotes.isEmpty else { throw TodayAIParsingError.qualityGateFailed(["invalidGuidanceEvidenceQuotes"]) }
        } else {
            guard !quotes.isEmpty, quotes.count <= 3, Set(quotes).count == quotes.count,
                  quotes.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && verification.evidenceText.contains($0) })
            else { throw TodayAIParsingError.qualityGateFailed(["invalidGuidanceEvidenceQuotes"]) }
        }
        return GuidanceEvidenceDecision(result: result, hintId: item.hintId, reason: decision.reason,
            promptRunId: request.traceID, evidenceQuotes: quotes)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = String(decoding: data, as: UTF8.self)
        let text: String
        if let envelope = try? decoder.decode(ChatEnvelope.self, from: data),
           let content = envelope.choices.first?.message?.content {
            text = content
        } else {
            text = raw
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw TodayAIParsingError.invalidJSON
        }
        return try decoder.decode(T.self, from: Data(text[start...end].utf8))
    }

    private struct ChatEnvelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { var content: String? }
            var message: Message?
        }
        var choices: [Choice]
    }

    private struct DecisionDTO: Decodable {
        var decision: String
        var hintId: String?
        var reason: String
    }

    private struct EvidenceDTO: Codable {
        var hintId: String
        var hintCopy: String
        var hintExplanation: String
        var questTitle: String
        var completionCriteria: String
        var evidenceText: String
        var targetJudgment: String?
        var completionSelfReport: String
        var valueSelfReport: String
        var judgmentSelfReport: String
        var calibrationAssessment: CalibrationAssessment?
    }

    private struct EvidenceDecisionDTO: Decodable {
        var result: String
        var hintId: String
        var reason: String
        var evidenceQuotes: [String]?
    }
}

struct CoachDecisionContext: Hashable {
    var caseId: UUID?
    var caseTitle: String?
    var mode: SessionMode
    var cards: [ThinkingCard]
}

struct CoachTrainingDecision: Hashable {
    var diagnosis: CoachDiagnosis
    var prescription: TrainingPrescription
    var promptRunId: UUID
}

struct CoachAnswerReviewContext: Hashable {
    var caseId: UUID?
    var caseTitle: String?
    var mode: SessionMode
    var cards: [ThinkingCard]
    var questions: [ReflectionQuestion]
    var previousTurn: CoachTurnState?
}

struct CoachAnswerReviewDecision: Hashable {
    var turn: CoachTurnState
    var feedback: CoachAnswerTrainingFeedback
    var referenceSuggestion: CoachReferenceSuggestion?
    var promptRunId: UUID
}

/// Chooses the training focus that used to be selected by `CoachEngine` and
/// `LocalTrainingPrescriptionPolicy`. Those policies remain useful as explicit
/// test fixtures and non-model previews, but production decisions are model-led.
final class CoachDecisionAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient

    init(promptProvider: PromptProvider, llmClient: LLMClient) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
    }

    func decide(context: CoachDecisionContext) async throws -> CoachTrainingDecision {
        let cards = context.cards.filter {
            $0.isConfirmed && !$0.isExcludedFromModel &&
            (context.caseId == nil || $0.trainingCaseId == nil || $0.trainingCaseId == context.caseId)
        }
        guard !cards.isEmpty else { throw TodayAIParsingError.emptyResult }
        let sourceIds = Array(Set(cards.map(\.id.uuidString) + [context.caseId?.uuidString].compactMap { $0 })).sorted()
        let cardText = cards.map {
            "id=\($0.id.uuidString); type=\($0.type.rawValue); title=\($0.title); body=\($0.body); importance=\($0.priority.rawValue); confirmed=\($0.isConfirmed)"
        }.joined(separator: "\n")
        let payload = PromptContextPayload(
            currentInput: .init(
                dailyEntryId: context.caseId?.uuidString,
                rawText: "case_title=\(context.caseTitle ?? ""); mode=\(context.mode.rawValue)\n\(cardText)"
            ),
            currentCase: context.caseId.map {
                .init(id: $0.uuidString, title: context.caseTitle ?? "当前事项", status: "in_progress", evidenceRefs: cards.map(\.id.uuidString))
            },
            userChoice: .init(sessionMode: context.mode.rawValue),
            privacy: .init(rules: "Use only supplied confirmed matter cards. Do not infer private attributes or use external data.")
        )
        let template = promptProvider.template(for: .diagnoseTrainingCase, mode: context.mode)
        let request = LLMRequest(
            prompt: template,
            inputSummary: "coach_decision; cards=\(cards.count); case=\(context.caseId?.uuidString ?? "none")",
            contextPayload: payload,
            sourceRecordIDs: sourceIds,
            contextVersion: 1,
            contextRecordIDs: sourceIds
        )
        let data = try await llmClient.complete(request)
        let dto = try Self.decode(DecisionDTO.self, from: data)
        guard let phase = ThinkingPhase(rawValue: dto.phase),
              let readiness = ConvergenceReadiness(rawValue: dto.readiness),
              let move = NextCoachMove(rawValue: dto.recommendedMove),
              let dimension = ThinkingTrainingDimension(rawValue: dto.trainingDimension),
              let lens = BuiltinLensCatalog.item(localId: dto.recommendedLensId)
                ?? BuiltinLensCatalog.item(promptId: dto.recommendedLensId),
              !dto.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw TodayAIParsingError.qualityGateFailed(["教练决策必须返回有效的阶段、训练维度和现有透镜。"]) }

        let modelGaps: [EvidenceGapType]?
        let modelRefs: [String]?
        if template.outputSchemaVersion >= 2 {
            guard let rawGaps = dto.openEvidenceGaps, rawGaps.count <= 1,
                  let refs = dto.sourceRefs, !refs.isEmpty,
                  Set(refs).isSubset(of: Set(cards.map(\.id.uuidString))),
                  Set(refs).count == refs.count else {
                throw TodayAIParsingError.qualityGateFailed(["当前教练判断需明确至多一个材料缺口，并引用本事项已确认卡片。"])
            }
            let gaps = rawGaps.compactMap(EvidenceGapType.init(rawValue:))
            guard gaps.count == rawGaps.count, !gaps.contains(.none),
                  readiness != .ready || gaps.isEmpty else {
                throw TodayAIParsingError.qualityGateFailed(["教练材料缺口无效，或与已就绪状态冲突。"])
            }
            modelGaps = gaps
            modelRefs = refs
        } else {
            // Historical responses did not report gaps. Keep them unknown;
            // do not reconstruct missing observations from their broad phase.
            modelGaps = nil
            modelRefs = nil
        }
        let diagnosis = CoachDiagnosis(
            phase: phase,
            readiness: readiness,
            recommendedMove: move,
            reason: dto.reason,
            source: .coachRecommended,
            policyVersion: "coach-decision.llm.v\(template.outputSchemaVersion)",
            openEvidenceGaps: modelGaps,
            sourceRefs: modelRefs
        )
        let alternatives = BuiltinLensCatalog.items
            .filter { $0.lensId != lens.lensId }
            .sorted { $0.methodIndex < $1.methodIndex }
            .prefix(3)
            .map(\.lensId)
        let prescription = TrainingPrescription(
            recommendedLensId: lens.lensId,
            recommendedPromptId: lens.promptId,
            recommendationReason: dto.reason,
            confidence: min(max(dto.confidence, 0), 1),
            policyVersion: "training-prescription.llm.v1",
            alternativeLensIds: alternatives,
            baselineChecks: BaselineThinkingCheck.allCases,
            primaryTrainingDimension: dimension,
            finalLensId: lens.lensId,
            source: .coachRecommended
        )
        return CoachTrainingDecision(diagnosis: diagnosis, prescription: prescription, promptRunId: request.traceID)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = String(decoding: data, as: UTF8.self)
        let text: String
        if let envelope = try? decoder.decode(ChatEnvelope.self, from: data),
           let content = envelope.choices.first?.message?.content {
            text = content
        } else {
            text = raw
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw TodayAIParsingError.invalidJSON
        }
        return try decoder.decode(T.self, from: Data(text[start...end].utf8))
    }

    private struct ChatEnvelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { var content: String? }
            var message: Message?
        }
        var choices: [Choice]
    }

private struct DecisionDTO: Decodable {
        var phase: String
        var readiness: String
        var recommendedMove: String
        var trainingDimension: String
        var recommendedLensId: String
        var reason: String
        var confidence: Double
        var openEvidenceGaps: [String]?
        var sourceRefs: [String]?
    }
}

/// The model reviews the user's actual answer. Local code retains only
/// cancellation, source isolation, UI timing, and explicit user overrides.
final class CoachAnswerReviewAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient
    private let coachPromptTurnRepository: CoachPromptTurnRepository?

    init(
        promptProvider: PromptProvider,
        llmClient: LLMClient,
        coachPromptTurnRepository: CoachPromptTurnRepository? = nil
    ) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
        self.coachPromptTurnRepository = coachPromptTurnRepository
    }

    func review(context: CoachAnswerReviewContext) async throws -> CoachAnswerReviewDecision {
        let cards = context.cards.filter { $0.isConfirmed && !$0.isExcludedFromModel }
        let answered = context.questions.filter { !trimmed($0.answer).isEmpty }
        guard !answered.isEmpty else { throw TodayAIParsingError.emptyResult }

        let evidenceIds = Set(cards.map(\.id.uuidString) + answered.map { $0.id.uuidString })
        let sourceIds = Array(evidenceIds.union([context.caseId?.uuidString].compactMap { $0 })).sorted()
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: context.caseId?.uuidString, rawText: renderedContext(context, cards: cards, answered: answered)),
            currentCase: context.caseId.map { .init(id: $0.uuidString, title: context.caseTitle ?? "当前事项", status: "in_progress", evidenceRefs: evidenceIds.sorted()) },
            userChoice: .init(sessionMode: context.mode.rawValue),
            privacy: .init(rules: "Use only supplied cards and answered questions from the current matter. Do not infer private attributes or use other matters.")
        )
        let request = LLMRequest(
            prompt: promptProvider.template(for: .reviewCoachAnswer, mode: context.mode),
            inputSummary: "coach_answer_review; case=\(context.caseId?.uuidString ?? "none"); answers=\(answered.count)",
            contextPayload: payload,
            sourceRecordIDs: sourceIds,
            contextVersion: 1,
            contextRecordIDs: sourceIds
        )
        let data = try await llmClient.complete(request)
        if let repository = coachPromptTurnRepository {
            try? await repository.recordOutcome(
                promptRunId: request.traceID,
                promptId: .reviewCoachAnswer,
                outcome: .responseReceived,
                detail: nil
            )
        }
        let dto = try decode(DecisionDTO.self, from: data)
        guard let readiness = ConvergenceReadiness(rawValue: dto.readiness),
              let move = NextCoachMove(rawValue: dto.recommendedMove),
              !trimmed(dto.reason).isEmpty,
              !trimmed(dto.coachCritique).isEmpty,
              !trimmed(dto.missingMaterial).isEmpty else {
            throw TodayAIParsingError.qualityGateFailed(["回答复盘必须返回有效的准备度、下一步和证据化反馈。"])
        }
        let userBoundary: CoachAnswerReviewUserBoundary
        if let rawBoundary = dto.userBoundary {
            guard let parsedBoundary = CoachAnswerReviewUserBoundary(rawValue: rawBoundary) else {
                throw TodayAIParsingError.qualityGateFailed(["回答复盘的用户收束状态无效。"])
            }
            userBoundary = parsedBoundary
        } else {
            // Older recorded responses predate this field. Preserve replay
            // compatibility and treat them as ordinary answerable turns.
            userBoundary = .continueAnswering
        }
        let nextRepairQuestion = trimmed(dto.nextRepairQuestion)
        guard userBoundary != .stopHere || nextRepairQuestion.isEmpty else {
            throw TodayAIParsingError.qualityGateFailed(["用户已停止回答时不得制造额外追问。"])
        }
        if userBoundary == .stopHere {
            let alternateAssignments = [dto.experienceReplayPrompt, dto.judgmentSentencePrompt,
                                        dto.referenceSuggestion, dto.referenceExample]
            guard alternateAssignments.allSatisfy({ trimmed($0).isEmpty }) else {
                throw TodayAIParsingError.qualityGateFailed(["用户已停止回答时不得通过其他提示继续安排练习。"])
            }
        }
        let repairQuestionContractIsValid: Bool = {
            switch readiness {
            case .ready:
                // Once the evidence is sufficient, the model must stop. An
                // extra question here would turn a completed turn back into
                // an unnecessary repair loop.
                return nextRepairQuestion.isEmpty
            case .notReady, .partiallyReady:
                return true // A factual gap may remain without a useful, answerable follow-up.
            }
        }()
        guard repairQuestionContractIsValid else {
            throw TodayAIParsingError.qualityGateFailed(["回答复盘已就绪时不得制造额外追问。"])
        }
        guard move != .askClarifyingQuestion || !nextRepairQuestion.isEmpty else {
            throw TodayAIParsingError.qualityGateFailed(["澄清建议需要实际可回答的问题；仅保留未知时应说明证据边界。"])
        }
        let gaps = Array(Set(dto.openEvidenceGaps.compactMap(EvidenceGapType.init(aiRawValue:)).filter { $0 != .none }))
        guard gaps.count <= 1 else {
            throw TodayAIParsingError.qualityGateFailed(["回答复盘只能保留一个最重要的证据缺口。"])
        }
        guard !(readiness == ConvergenceReadiness.ready && !gaps.isEmpty),
              !(readiness != ConvergenceReadiness.ready && move == NextCoachMove.generateQuest && userBoundary != .stopHere) else {
            throw TodayAIParsingError.qualityGateFailed(["回答复盘的准备度、缺口与下一步互相矛盾。"])
        }
        let cited = Set(dto.sourceRefs.map(trimmed).filter { !$0.isEmpty })
        guard !cited.isEmpty, cited.isSubset(of: evidenceIds) else {
            throw TodayAIParsingError.qualityGateFailed(["回答复盘只能引用当前事项的卡片和回答。"])
        }

        let turn = CoachTurnState(
            phase: readiness == ConvergenceReadiness.ready ? .formAction : (context.previousTurn?.phase ?? .fillEvidenceGap),
            readiness: readiness,
            recommendedMove: move,
            reason: trimmed(dto.reason),
            openEvidenceGaps: gaps,
            baselineChecks: context.previousTurn?.baselineChecks ?? [],
            decisionSource: context.previousTurn?.decisionSource ?? .coachRecommended,
            policyVersion: "coach-answer-review.llm.v1",
            turnSummary: fallback(dto.turnSummary, to: trimmed(dto.reason))
        )
        let canProceed = readiness == ConvergenceReadiness.ready && gaps.isEmpty
        let plan = CoachTeachingPlan(
            policyVersion: "coach-answer-review.llm.v1",
            missingMoveTitle: fallback(dto.missingMaterial, to: "已根据当前回答完成复盘。"),
            trainingTargetTitle: trimmed(dto.trainingTarget),
            whyNotAnswer: fallback(dto.coachCritique, to: "保持判断与证据之间的可回链关系。"),
            proceedStandard: trimmed(dto.trainingOutput),
            repairQuestion: nextRepairQuestion,
            experienceReplayPrompt: trimmed(dto.experienceReplayPrompt),
            routeSteps: [
                fallback(dto.turnSummary, to: "复盘当前回答"),
                fallback(dto.proceedLine, to: "根据当前证据决定下一步")
            ],
            auditNote: "模型基于当前事项的证据引用完成复盘。"
        )
        let feedback = CoachAnswerTrainingFeedback(
            readiness: readiness,
            canProceedToValidation: canProceed,
            coachCritiqueLine: trimmed(dto.coachCritique),
            repairedLine: trimmed(dto.repairedMaterial),
            missingLine: trimmed(dto.missingMaterial),
            proceedLine: fallback(dto.proceedLine, to: "可以保存当前回顾，返回今日。"),
            abilityGapLine: trimmed(dto.abilityGap),
            trainingOutputLine: trimmed(dto.trainingOutput),
            selfCheckLine: trimmed(dto.selfCheck),
            trainingTargetLine: trimmed(dto.trainingTarget),
            nextRepairQuestion: nextRepairQuestion,
            experienceReplayDecisionLine: trimmed(dto.experienceReplayDecision),
            experienceReplayPrompt: trimmed(dto.experienceReplayPrompt),
            judgmentSentencePrompt: trimmed(dto.judgmentSentencePrompt),
            teachingPlan: plan,
            userBoundary: userBoundary
        )
        let suggestion = trimmed(dto.referenceSuggestion)
        let reference: CoachReferenceSuggestion? = suggestion.isEmpty ? nil : {
            CoachReferenceSuggestion(
                guidance: suggestion,
                workedExample: trimmed(dto.referenceExample),
                caveat: "这是基于当前事项材料的参考，不替代你的事实结论。"
            )
        }()
        return CoachAnswerReviewDecision(turn: turn, feedback: feedback, referenceSuggestion: reference, promptRunId: request.traceID)
    }

    private func renderedContext(_ context: CoachAnswerReviewContext, cards: [ThinkingCard], answered: [ReflectionQuestion]) -> String {
        let cardText = cards.map { "card_id=\($0.id.uuidString); type=\($0.type.rawValue); title=\($0.title); body=\($0.body)" }.joined(separator: "\n")
        let latestAnswerID = answered.last?.id.uuidString ?? "none"
        let answerText = answered.enumerated().map { index, question in
            "answer_index=\(index + 1); answer_id=\(question.id.uuidString); is_latest_answer=\(question.id.uuidString == latestAnswerID); question=\(question.question); calibration_target=\(question.calibrationTarget ?? ""); answer=\(question.answer)"
        }.joined(separator: "\n")
        return "case_title=\(context.caseTitle ?? "")\nprevious_assessment_available=\(context.previousTurn != nil)\nprevious_reason=\(context.previousTurn?.reason ?? "No prior model assessment is available; assess the supplied answers directly.")\nprevious_open_gaps=\(context.previousTurn?.openEvidenceGaps.map(\.rawValue).joined(separator: ",") ?? "")\nlatest_answer_id=\(latestAnswerID)\nReview the ordered answers below. The row marked is_latest_answer=true is the current turn; earlier rows are context and must not be asked again.\nCARDS:\n\(cardText)\nANSWERS:\n\(answerText)"
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallback(_ value: String, to fallback: String) -> String {
        let value = trimmed(value)
        return value.isEmpty ? fallback : value
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = String(decoding: data, as: UTF8.self)
        let text: String
        if let envelope = try? decoder.decode(ChatEnvelope.self, from: data), let content = envelope.choices.first?.message?.content { text = content } else { text = raw }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { throw TodayAIParsingError.invalidJSON }
        return try decoder.decode(T.self, from: Data(text[start...end].utf8))
    }

    private struct ChatEnvelope: Decodable {
        struct Choice: Decodable { struct Message: Decodable { var content: String? }; var message: Message? }
        var choices: [Choice]
    }

    private struct DecisionDTO: Decodable {
        var readiness, recommendedMove: String
        var openEvidenceGaps: [String]
        var reason, turnSummary, coachCritique, repairedMaterial, missingMaterial, proceedLine: String
        var abilityGap, trainingOutput, selfCheck, trainingTarget, nextRepairQuestion: String
        var userBoundary: String?
        var experienceReplayDecision, experienceReplayPrompt, judgmentSentencePrompt: String
        var referenceSuggestion, referenceExample: String
        var sourceRefs: [String]
    }
}

struct VerificationCoordinator {
    func dueQuests(
        from quests: [Quest],
        verifications: [Verification],
        now: Date = .now
    ) -> [Quest] {
        let verifiedIds = Set(verifications.map(\.questId))
        return quests.filter { quest in
            guard quest.status == .active, !verifiedIds.contains(quest.id) else { return false }
            if let deferred = quest.verificationDeferredUntil, deferred > now { return false }
            return quest.verificationDueAt.map { $0 <= now } ?? true
        }
    }
}

struct ProjectClosureCoordinator {
    func makeReview(
        project: Project,
        existing: ProjectClosureReview?,
        reason: ProjectClosureReason,
        outcome: String,
        evidenceRefs: [String],
        transferredItems: String?,
        reviewNote: String?
    ) throws -> ProjectClosureReview {
        let trimmedOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutcome.isEmpty else {
            throw PersistenceError.validationFailed("Project closure requires an actual outcome")
        }
        return ProjectClosureReview(
            id: existing?.id ?? UUID(),
            projectId: project.id,
            reason: reason,
            outcome: trimmedOutcome,
            evidenceRefs: Array(Set(evidenceRefs.filter { !$0.isEmpty })).sorted(),
            transferredItems: transferredItems?.trimmingCharacters(in: .whitespacesAndNewlines),
            reviewNote: reviewNote?.trimmingCharacters(in: .whitespacesAndNewlines),
            aiSummary: existing?.aiSummary,
            previousStatus: project.status == .archived
                ? (existing?.previousStatus ?? .active)
                : project.status,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
    }
}
