import Foundation

struct VerifyQuestInput: Hashable {
    var verificationId: UUID = UUID()
    var sourceRecordIDs: [String] = []
    var currentTrainingCase: TrainingCase? = nil
    var questTitle: String
    var completionCriteria: String
    var targetJudgment: String? = nil
    var trainingPrinciple: PromptContextPayload.VerificationTrainingPrincipleContext? = nil
    var completion: String
    var valueRating: String
    var judgmentUpdate: String
    var rawText: String
}


struct VerifyQuestResult: Hashable {
    var calibrationNote: String
    var likelyIssue: String?
    var recommendation: String?
    var expectedPrinciplePracticeAssessment: String? = nil
    /// Model-authored evidence that may be shown in the one-time settlement.
    /// It is deliberately separate from metric contributions and scores.
    var growthEvidenceItems: [GrowthSettlementEvidenceItem] = []
    var calibrationAssessment: CalibrationAssessment? = nil
    var principlePracticeAssessment: PrinciplePracticeAssessment? = nil
}

struct TodayAIContext: Hashable {
    var draft: DailyEntryDraft
    var currentTrainingCase: TrainingCase? = nil
    var confirmedCards: [ThinkingCard] = []
    var questions: [ReflectionQuestion] = []
    var quests: [Quest] = []
    var principles: [PrincipleAsset] = []
    var principleRecallFeedback: [PrincipleRecallFeedback] = []
    var selectedLensItem: LensCatalogItem?
    var lensFeedback: [PromptContextPayload.LensFeedbackContext] = []
    var trainingPrescription: TrainingPrescription? = nil
    var coachDiagnosis: CoachDiagnosis? = nil
    var coachTurnState: CoachTurnState? = nil
    var coachPatternSummary: CoachPatternSummary? = nil
}

struct CoachGenerated<Value> {
    var value: Value
    var promptRunId: UUID?
}

final class TodayAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient
    private let parser: TodayAIResponseParser
    private let contextAssembler: ContextAssembler
    private let coachPromptTurnRepository: CoachPromptTurnRepository?

    init(
        promptProvider: PromptProvider,
        llmClient: LLMClient,
        parser: TodayAIResponseParser = TodayAIResponseParser(),
        contextAssembler: ContextAssembler = DefaultContextAssembler(),
        coachPromptTurnRepository: CoachPromptTurnRepository? = nil
    ) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
        self.parser = parser
        self.contextAssembler = contextAssembler
        self.coachPromptTurnRepository = coachPromptTurnRepository
    }

    func generateSingleNudge(for context: TodayAIContext) async throws -> CoachGenerated<String> {
        // Kept for source compatibility; callers should pass the dedicated nudge input overload.
        try await generateSingleNudge(input: context.draft.rawText, sessionMode: context.draft.sessionMode)
    }

    /// Single-nudge requests intentionally bypass the daily context assembler.
    /// A continuation may include only the root concern and its direct parent
    /// round; cards, quests, principles, and other Today state never enter it.
    func generateSingleNudge(
        input: String,
        sessionMode: SessionMode,
        sourceRecordIDs: [String] = [],
        alternateAngle: Bool = false,
        continuationKind: SingleNudgeContinuationKind = .initial,
        previousRound: SingleNudgeSession? = nil
    ) async throws -> CoachGenerated<String> {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw TodayAIParsingError.emptyResult }
        let continuation = alternateAngle ? SingleNudgeContinuationKind.alternateAngle : continuationKind
        let priorMaterial: String
        if let previousRound {
            priorMaterial = [
                "原卡点：\(value)",
                previousRound.question.map { "上一问：\($0)" },
                previousRound.after.map { "上一轮表达：\($0)" },
                previousRound.diagnosis.map { "上一轮点拨：\($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        } else {
            priorMaterial = value
        }
        let base = promptProvider.template(for: .singleNudge, mode: sessionMode)
        let request = LLMRequest(
            prompt: base,
            inputSummary: "单次点拨输入",
            contextPayload: PromptContextPayload(
                currentInput: .init(rawText: priorMaterial),
                userChoice: .init(sessionMode: sessionMode.rawValue),
                directives: .init(
                    privacyRules: "只处理本条点拨链材料；continuation_mode=\(continuation.rawValue)。" +
                        (continuation == .alternateAngle ? "避开上一轮的切入点。" : "") +
                        (continuation == .deeper ? "基于用户刚才的表达进一步追问。" : "")
                )
            ),
            sourceRecordIDs: sourceRecordIDs
        )
        do {
            try Task.checkCancellation()
            let data = try await llmClient.complete(request)
            try Task.checkCancellation()
            let question = try parser.parseSingleNudge(from: data)
            await recordCoachTurnOutcome(request, outcome: .responseReceived, detail: nil)
            return CoachGenerated(value: question, promptRunId: request.traceID)
        } catch {
            await recordCoachTurnFailure(for: request, error: error)
            throw error
        }
    }

    func reviewSingleNudge(
        input: String,
        question: String,
        answer: String,
        before: String? = nil,
        sessionMode: SessionMode,
        sourceRecordIDs: [String] = []
    ) async throws -> CoachGenerated<SingleNudgeReview> {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty, !cleanQuestion.isEmpty, !cleanAnswer.isEmpty else {
            throw TodayAIParsingError.emptyResult
        }
        let base = promptProvider.template(for: .singleNudge, mode: sessionMode)
        let reviewPrompt = PromptTemplate(
            id: .singleNudge,
            version: "\(base.version)-review",
            systemPolicyVersion: base.systemPolicyVersion,
            contextPolicyVersion: base.contextPolicyVersion,
            evalSuiteVersion: base.evalSuiteVersion,
            rollbackTargetVersion: base.rollbackTargetVersion,
            sourceKind: base.sourceKind,
            packId: base.packId,
            packVersion: base.packVersion,
            packDisplayName: base.packDisplayName,
            systemText: base.systemText,
            userText: """
            Give a short, in-the-moment MingSi response to only this nudge round. Return strict JSON with exactly diagnosis, cognitive_shift, thinking_action, unresolved_uncertainty, transition_to_verification; the first four are strings or null and the last is a boolean.
            diagnosis is a brief point-out of the thinking move, not a diagnosis of the person. Set cognitive_shift only when the before/after material shows a real change in judgment criterion, assumption, or causal explanation; otherwise null. thinking_action may only be a thinking move the user can do now, never an automatic task or plan. Set transition_to_verification true only when the material contains a judgment, prediction, or action that future facts could test. Do not create any asset, quest, verification, principle, metric, or task.
            """,
            outputSchemaVersion: 2
        )
        let beforeText = (before ?? cleanInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = "原始输入:\n\(cleanInput)\n\n回答前想法:\n\(beforeText)\n\n点拨问题:\n\(cleanQuestion)\n\n用户回答:\n\(cleanAnswer)"
        let request = LLMRequest(
            prompt: reviewPrompt,
            inputSummary: "单次点拨回答",
            contextPayload: PromptContextPayload(
                currentInput: .init(rawText: raw),
                userChoice: .init(sessionMode: sessionMode.rawValue),
                directives: .init(privacyRules: "只分析这次点拨的输入、问题和回答。")
            ),
            sourceRecordIDs: sourceRecordIDs
        )
        do {
            try Task.checkCancellation()
            let data = try await llmClient.complete(request)
            try Task.checkCancellation()
            var review = try parser.parseSingleNudgeReview(from: data)
            // A shift is only defensible when both sides contain distinct material.
            let normalizedBefore = beforeText.lowercased()
            let normalizedAfter = cleanAnswer.lowercased()
            if normalizedBefore.count < 4 || normalizedAfter.count < 4 || normalizedBefore == normalizedAfter {
                review.cognitiveShift = nil
            }
            await recordCoachTurnOutcome(request, outcome: .responseReceived, detail: nil)
            return CoachGenerated(value: review, promptRunId: request.traceID)
        } catch {
            await recordCoachTurnFailure(for: request, error: error)
            throw error
        }
    }

    func organizeCards(for context: TodayAIContext) async throws -> [ThinkingCard] {
        try await organizeCapture(for: context).cards
    }

    func organizeCapture(for context: TodayAIContext) async throws -> OrganizedCaptureResult {
        let request = request(
            promptID: .organizeCards,
            context: context,
            directives: organizeCardsDirectives()
        )
        try Task.checkCancellation()
        let data = try await llmClient.complete(request)
        // Some clients finish after cancellation; never parse a late response.
        try Task.checkCancellation()
        return try parser.parseOrganizedCapture(from: data)
    }

    func streamOrganizedCards(
        for context: TodayAIContext,
        onUpdate: @escaping ([StreamingCardDraft]) async -> Void,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> [ThinkingCard] {
        try await streamOrganizedCapture(for: context, onUpdate: onUpdate, onProgress: onProgress).cards
    }

    func streamOrganizedCapture(
        for context: TodayAIContext,
        onUpdate: @escaping ([StreamingCardDraft]) async -> Void,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> OrganizedCaptureResult {
        guard let streamingClient = llmClient as? StreamingLLMClient else {
            return try await organizeCapture(for: context)
        }

        let request = request(
            promptID: .organizeCards,
            context: context,
            directives: organizeCardsDirectives(streamProtocol: "MINGSI_STREAM_V2")
        )
        let assembler = XMLStreamingCardAssembler()

        try Task.checkCancellation()
        for try await event in streamingClient.stream(request) {
            try Task.checkCancellation()
            await onProgress(event)
            switch event {
            case .token(let text):
                let events = assembler.append(text)
                for event in events {
                    if case .updated(let cards) = event {
                        await onUpdate(cards)
                    }
                }
            case .requestStarted, .connected, .receivedEvent, .completed:
                break
            }
        }

        for event in assembler.finish() {
            if case .updated(let cards) = event {
                await onUpdate(cards)
            }
        }
        // A stream can close a card without emitting another incremental update.
        // Always publish the assembler's final state before domain cards are returned.
        await onUpdate(assembler.currentCards)
        try Task.checkCancellation()

        let values = assembler.currentCards.compactMap { draft -> (ThinkingCard, String, String)? in
            guard let card = draft.domainCard else { return nil }
            return (card, draft.caseKey, draft.caseTitle)
        }
        let cards = values.map(\.0)
        guard !cards.isEmpty else { throw TodayAIParsingError.emptyResult }
        var order: [String] = []
        var groups: [String: (title: String, ids: [UUID])] = [:]
        for value in values {
            let key = value.1.isEmpty ? "default" : String(value.1.prefix(64))
            if groups[key] == nil { order.append(key) }
            let title = value.2.isEmpty ? value.0.title : value.2
            groups[key, default: (title, [])].ids.append(value.0.id)
        }
        let suggestions = order.compactMap { key -> TrainingCaseSuggestion? in
            guard let group = groups[key] else { return nil }
            return TrainingCaseSuggestion(key: key, title: group.title.isEmpty ? "今天要想清楚的事" : group.title, cardIds: group.ids)
        }
        return OrganizedCaptureResult(cards: cards, caseSuggestions: suggestions)
    }

    func generateQuestions(
        for context: TodayAIContext,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> [ReflectionQuestion] {
        try await generateQuestionsWithTrace(for: context, onProgress: onProgress).value
    }

    func generateQuestionsWithTrace(
        for context: TodayAIContext,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> CoachGenerated<[ReflectionQuestion]> {
        let generated = try await generateQuestionTurnWithTrace(for: context, onProgress: onProgress)
        return CoachGenerated(value: generated.value.questions, promptRunId: generated.promptRunId)
    }

    func generateQuestionTurnWithTrace(
        for context: TodayAIContext,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> CoachGenerated<CoachQuestionTurn> {
        let request = request(
            promptID: .generateQuestions,
            context: context
        )
        let data: Data
        do {
            try Task.checkCancellation()
            data = try await completePossiblyStreaming(request, onProgress: onProgress)
            try Task.checkCancellation()
        } catch {
            await recordCoachTurnFailure(for: request, error: error)
            throw error
        }
        await recordCoachTurnOutcome(
            request,
            outcome: .responseReceived,
            detail: nil
        )

        do {
            let turn = try parser.parseQuestionTurn(from: data)
            let questions = turn.questions
            let visiblePayload = request.contextPayload
            if let explanation = turn.explanation {
                let allowed = Set(visiblePayload?.cards.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) } ?? [])
                guard explanation.sourceCardTitles.allSatisfy(allowed.contains) else {
                    throw TodayAIParsingError.qualityGateFailed(["invalid_explanation_source_grounding"])
                }
            }
            try validateCoachingQuality(
                PromptCoachingQualityPolicy.evaluateQuestions(
                    questions,
                    selectedLens: effectiveTrainingLens(forPromptPayload: visiblePayload, fallback: context),
                    lensFeedback: visiblePayload?.lensFeedback ?? [],
                    primaryTrainingDimension: visiblePayload?.trainingPrescription?.primaryTrainingDimension,
                    baselineTrainingDimensions: visiblePayload?.trainingPrescription?.baselineTrainingDimensions ?? [],
                    coachTurnState: coachTurnState(from: visiblePayload),
                    relevantPrinciples: visiblePayload?.principles ?? [],
                    coachObservation: visiblePayload?.coachObservation,
                    // The current 1.23 question contract treats local coach
                    // plans as hypotheses. Keep structural checks for the
                    // response, but do not reject an evidence-grounded move
                    // solely because it diverges from a stale plan.
                    enforceCoachAlignment: false,
                    // Today is turn based. The model may decide that no
                    // question is needed, but it must never send a batch of
                    // future questions for the UI to reveal at once.
                    maxQuestionsPerTurn: 1,
                    // Retrieved principles are optional context. Only a
                    // deliberately principle-comparison turn should require
                    // the question to replay one; keyword retrieval alone
                    // must not turn history into a hidden assignment.
                    requirePrincipleReplay: false,
                    allowedSourceCardTitles: Set(visiblePayload?.cards.map(\.title) ?? [])
                )
            )
            return CoachGenerated(
                value: turn,
                promptRunId: coachPromptTurnRepository == nil ? nil : request.traceID
            )
        } catch {
            await recordCoachTurnOutcome(
                request,
                outcome: coachOutcome(for: error),
                detail: coachOutcomeDetail(for: error)
            )
            throw error
        }
    }

    private func completePossiblyStreaming(
        _ request: LLMRequest,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> Data {
        guard let streamingClient = llmClient as? StreamingLLMClient else {
            try Task.checkCancellation()
            let data = try await llmClient.complete(request)
            try Task.checkCancellation()
            return data
        }

        var rawText = ""
        try Task.checkCancellation()
        for try await event in streamingClient.stream(request) {
            try Task.checkCancellation()
            await onProgress(event)
            switch event {
            case .token(let text):
                rawText += text
            case .requestStarted, .connected, .receivedEvent, .completed:
                break
            }
        }

        try Task.checkCancellation()
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TodayAIParsingError.emptyResult }
        return Data(trimmed.utf8)
    }

    func generateQuests(
        for context: TodayAIContext,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> [Quest] {
        try await generateQuestsWithTrace(for: context, onProgress: onProgress).value
    }

    func generateQuestsWithTrace(
        for context: TodayAIContext,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> CoachGenerated<[Quest]> {
        let request = request(
            promptID: .generateQuests,
            context: context
        )
        let data: Data
        do {
            try Task.checkCancellation()
            data = try await completePossiblyStreaming(request, onProgress: onProgress)
            try Task.checkCancellation()
        } catch {
            await recordCoachTurnFailure(for: request, error: error)
            throw error
        }
        await recordCoachTurnOutcome(
            request,
            outcome: .responseReceived,
            detail: nil
        )

        do {
            let quests = try parser.parseQuests(from: data, enforceSingleValidationAction: true)
            if quests.isEmpty {
                return CoachGenerated(value: [], promptRunId: coachPromptTurnRepository == nil ? nil : request.traceID)
            }
            let visiblePayload = request.contextPayload
            try validateCoachingQuality(
                PromptCoachingQualityPolicy.evaluateQuests(
                    quests,
                    selectedLens: effectiveTrainingLens(forPromptPayload: visiblePayload, fallback: context),
                    coachTurnState: coachTurnState(from: visiblePayload),
                    // The current single-action contract uses the lens only
                    // when it fits. A useful comparison must not be rejected
                    // solely because its method label differs from that lens.
                    requireSelectedLensMove: false,
                    allowedSourceCardTitles: Set(visiblePayload?.cards.map(\.title) ?? [])
                )
            )
            return CoachGenerated(
                value: quests,
                promptRunId: coachPromptTurnRepository == nil ? nil : request.traceID
            )
        } catch {
            await recordCoachTurnOutcome(
                request,
                outcome: coachOutcome(for: error),
                detail: coachOutcomeDetail(for: error)
            )
            throw error
        }
    }

    func extractPrinciple(
        for context: TodayAIContext,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> [PrincipleAsset] {
        let request = request(
            promptID: .extractPrinciple,
            context: context
        )
        let data = try await completePossiblyStreaming(request, onProgress: onProgress)
        let principles = try parser.parsePrinciples(from: data)
        try validateCoachingQuality(
            PromptCoachingQualityPolicy.evaluatePrinciples(
                principles,
                allowedSourceCardTitles: Set(request.contextPayload?.cards.map(\.title) ?? [])
            )
        )
        return principles
    }

    func verifyQuest(
        input: VerifyQuestInput,
        sessionMode: SessionMode,
        onProgress: @escaping (LLMStreamEvent) async -> Void = { _ in }
    ) async throws -> VerifyQuestResult {
        let template = promptProvider.template(for: .verifyQuest, mode: sessionMode)
        let contextPayload = PromptContextPayload(
            currentInput: .init(rawText: input.rawText),
            currentCase: input.currentTrainingCase.map {
                .init(
                    id: $0.id.uuidString,
                    title: $0.title,
                    status: $0.status.rawValue,
                    evidenceRefs: input.sourceRecordIDs
                )
            },
            userChoice: .init(sessionMode: sessionMode.rawValue),
            verification: .init(
                questTitle: input.questTitle,
                completionCriteria: input.completionCriteria,
                targetJudgment: input.targetJudgment,
                trainingPrinciple: input.trainingPrinciple,
                completion: input.completion,
                valueRating: input.valueRating,
                judgmentUpdate: input.judgmentUpdate
            )
        )
        let request = LLMRequest(
            prompt: template,
            inputSummary: "quest=\(input.questTitle); completion=\(input.completion); rating=\(input.valueRating); judgmentUpdate=\(input.judgmentUpdate)",
            contextPayload: contextPayload,
            sourceRecordIDs: input.sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: input.sourceRecordIDs
        )
        let data = try await completePossiblyStreaming(request, onProgress: onProgress)
        let result = try parser.parseVerification(
            from: data,
            allowedGrowthEvidenceRefs: Set([input.sourceRecordIDs.first ?? "", input.verificationId.uuidString])
                .filter { !$0.isEmpty }
        )
        if template.outputSchemaVersion >= 4 {
            guard let assessment = result.calibrationAssessment,
                  assessment.isGrounded(in: input.rawText, hasGrowthEvidence: !result.growthEvidenceItems.isEmpty) else {
                throw TodayAIParsingError.qualityGateFailed(["invalidCalibrationAssessment"])
            }
        }
        try validateCoachingQuality(
            PromptCoachingQualityPolicy.evaluateVerification(
                result,
                targetJudgment: input.targetJudgment,
                hasTrainingPrinciple: input.trainingPrinciple != nil
            )
        )
        if let assessment = result.principlePracticeAssessment {
            guard assessment.isGrounded(in: input.rawText,
                expectedPrincipleID: input.trainingPrinciple.flatMap { UUID(uuidString: $0.principleId) }) else {
                throw TodayAIParsingError.qualityGateFailed(["invalidPrinciplePracticeAssessment"])
            }
            if assessment.status != .notAssessable {
                guard let principle = input.trainingPrinciple,
                      principle.triggerContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                      principle.actions?.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) == true else {
                    throw TodayAIParsingError.qualityGateFailed(["missingPrincipleBehaviorContext"])
                }
            }
        } else if template.outputSchemaVersion >= 5, input.trainingPrinciple != nil {
            throw TodayAIParsingError.qualityGateFailed(["missingPrinciplePracticeAssessment"])
        }
        return result
    }

    private func validateCoachingQuality(_ issues: [PromptCoachingQualityIssue]) throws {
        guard !issues.isEmpty else { return }
        let reasons = Array(Set(issues.map { $0.reason.rawValue })).sorted()
        throw TodayAIParsingError.qualityGateFailed(reasons)
    }

    private func recordCoachTurnFailure(for request: LLMRequest, error: Error) async {
        await recordCoachTurnOutcome(
            request,
            outcome: coachOutcome(for: error),
            detail: coachOutcomeDetail(for: error)
        )
    }

    private func recordCoachTurnOutcome(
        _ request: LLMRequest,
        outcome: CoachPromptTurnOutcome,
        detail: String?
    ) async {
        guard let coachPromptTurnRepository,
              request.prompt.id == .generateQuestions || request.prompt.id == .generateQuests || request.prompt.id == .reviewCoachAnswer || request.prompt.id == .singleNudge
        else { return }
        try? await coachPromptTurnRepository.recordOutcome(
            promptRunId: request.traceID,
            promptId: request.prompt.id,
            outcome: outcome,
            detail: detail
        )
    }

    private func coachOutcome(for error: Error) -> CoachPromptTurnOutcome {
        if Task.isCancelled || error is CancellationError {
            return .cancelled
        }
        if let parsingError = error as? TodayAIParsingError {
            if case .qualityGateFailed = parsingError {
                return .qualityRejected
            }
            return .parseRejected
        }
        return .transportFailed
    }

    private func coachOutcomeDetail(for error: Error) -> String {
        if Task.isCancelled || error is CancellationError {
            return "cancelled"
        }
        if let parsingError = error as? TodayAIParsingError {
            switch parsingError {
            case .missingResponseContent:
                return "missing_response_content"
            case .invalidJSON:
                return "invalid_json"
            case .emptyResult:
                return "empty_result"
            case .qualityGateFailed(let reasons):
                return "quality_gate:\(reasons.sorted().joined(separator: ","))"
            case .invalidSingleNudgeQuestion:
                return "invalid_single_nudge_question"
            }
        }
        if let clientError = error as? LLMClientError {
            switch clientError {
            case .missingAPIKey:
                return "missing_api_key"
            case .invalidEndpoint:
                return "invalid_endpoint"
            case .invalidResponse:
                return "invalid_response"
            case .incompleteResponse:
                return "incomplete_response"
            case .providerResponseFailed:
                return "provider_response_failed"
            case .providerStreamFailure(let failure):
                return failure.diagnosticCode
            case .httpStatus(let status, _):
                return "http_\(status)"
            case .encodingFailed:
                return "encoding_failed"
            case .transport:
                return "transport"
            }
        }
        return String(describing: type(of: error))
    }

    private func effectiveTrainingLens(for context: TodayAIContext) -> ThinkingLens? {
        if let finalLensId = context.trainingPrescription?.finalLensId,
           let prescribedLens = ThinkingLens(rawValue: finalLensId) {
            return prescribedLens
        }
        return context.draft.selectedLens
    }

    private func effectiveTrainingLens(
        forPromptPayload payload: PromptContextPayload?,
        fallback context: TodayAIContext
    ) -> ThinkingLens? {
        guard let payload else { return effectiveTrainingLens(for: context) }
        if let finalLensId = payload.trainingPrescription?.finalLensId,
           let prescribedLens = ThinkingLens(rawValue: finalLensId) {
            return prescribedLens
        }
        return payload.selectedLens
    }

    private func coachTurnState(from payload: PromptContextPayload?) -> CoachTurnState? {
        guard let turn = payload?.coachTurnState else { return nil }
        return CoachTurnState(
            phase: turn.phase,
            readiness: turn.readiness,
            recommendedMove: turn.recommendedMove,
            reason: turn.reason,
            openEvidenceGaps: turn.openEvidenceGaps,
            baselineChecks: turn.baselineChecks,
            decisionSource: turn.decisionSource,
            policyVersion: turn.policyVersion,
            turnSummary: turn.turnSummary
        )
    }

    private func request(
        promptID: PromptID,
        context: TodayAIContext,
        directives: PromptContextPayload.PromptDirectives = .init()
    ) -> LLMRequest {
        let promptContext = contextAssembler.assemble(promptID: promptID, context: context)
        let contextPayload = promptContext.contextPayload.applyingDirectives(directives)
        return LLMRequest(
            prompt: promptProvider.template(for: promptID, mode: context.draft.sessionMode),
            inputSummary: promptContext.inputSummary,
            contextPayload: contextPayload,
            sourceRecordIDs: promptContext.sourceRecordIDs,
            contextVersion: promptContext.version,
            contextRecordIDs: promptContext.contextRecordIDs
        )
    }

    private func organizeCardsDirectives(streamProtocol: String? = nil) -> PromptContextPayload.PromptDirectives {
        .init(
            privacyRules: "Avoid repeating unnecessary confidential specifics. Mark sensitive content defensively.",
            streamProtocol: streamProtocol
        )
    }
}

struct PromptContext: Hashable {
    var version: Int = 1
    var inputSummary: String
    var contextPayload: PromptContextPayload
    var sourceRecordIDs: [String]
    var contextRecordIDs: [String]
}

protocol ContextAssembler {
    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext
}

protocol PrincipleRetriever {
    func retrievePrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [RetrievedPrinciple]
    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [PrincipleAsset]
}

struct RetrievedPrinciple: Hashable {
    var principle: PrincipleAsset
    var score: Int
    var retrievalReason: String
    var retrievalSignal: String
    var policyVersion: String
}

extension PrincipleRetriever {
    func relevantPrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int) -> [PrincipleAsset] {
        retrievePrinciples(for: context, promptID: promptID, limit: limit).map(\.principle)
    }
}

struct LocalPrincipleRetriever: PrincipleRetriever {
    static let policyVersion = "principle-retrieval.local-keyword-feedback.v3"

    private let minimumScore = 2
    private let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "before", "by", "did", "do", "does", "for", "from",
        "has", "have", "if", "in", "is", "it", "its", "not", "of", "on", "one", "or", "our", "the",
        "their", "then", "this", "to", "was", "were", "what", "when", "where", "which", "who", "why",
        "will", "with", "write", "action", "actions", "criteria", "discussion", "ended", "next",
        "明日", "任务", "今天", "昨天", "问题", "行动", "标准", "完成", "需要", "进行", "一个", "这个"
    ]

    func retrievePrinciples(for context: TodayAIContext, promptID: PromptID, limit: Int = 3) -> [RetrievedPrinciple] {
        guard promptID != .organizeCards else { return [] }

        let terms = searchTerms(from: context)
        let scored = context.principles
            .filter { $0.status == .active }
            .map { principle in
                let baseScore = score(principle: principle, terms: terms)
                let retrievalSignal = retrievalSignal(for: principle, terms: terms)
                let penalty = recallFeedbackPenalty(
                    for: principle.id,
                    retrievalSignal: retrievalSignal,
                    feedback: context.principleRecallFeedback
                )
                return (principle, retrievalSignal, baseScore, max(0, baseScore - penalty), penalty)
            }
            .filter { $0.3 >= minimumScore }
            .sorted { lhs, rhs in
                if lhs.3 == rhs.3 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.3 > rhs.3
            }
            .prefix(limit)
            .map { principle, retrievalSignal, baseScore, adjustedScore, penalty in
                return RetrievedPrinciple(
                    principle: principle,
                    score: adjustedScore,
                    retrievalReason: retrievalReason(
                        for: principle,
                        terms: terms,
                        baseScore: baseScore,
                        adjustedScore: adjustedScore,
                        feedbackPenalty: penalty
                    ),
                    retrievalSignal: retrievalSignal,
                    policyVersion: Self.policyVersion
                )
            }

        return Array(scored)
    }

    private func searchTerms(from context: TodayAIContext) -> [String] {
        let text = [
            context.draft.rawText,
            context.draft.selectedLens?.title ?? "",
            context.confirmedCards.map { "\($0.title) \($0.body)" }.joined(separator: " "),
            context.questions.map { "\($0.question) \($0.answer)" }.joined(separator: " "),
            context.quests.map { "\($0.title) \($0.whyItMatters) \($0.completionCriteria)" }.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        return text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { term in
                term.count >= 3 && !stopWords.contains(term)
            }
    }

    private func score(principle: PrincipleAsset, terms: [String]) -> Int {
        guard !terms.isEmpty else { return 0 }
        let uniqueTerms = Set(terms)
        let highSignalText = [
            principle.title,
            principle.triggerContext
        ].joined(separator: " ").lowercased()
        let fullText = [
            highSignalText,
            principle.summary,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ].joined(separator: " ").lowercased()

        return uniqueTerms.reduce(0) { partial, term in
            if highSignalText.contains(term) {
                return partial + 2
            }
            if fullText.contains(term) {
                return partial + 1
            }
            return partial
        }
    }

    private func recallFeedbackPenalty(
        for principleId: UUID,
        retrievalSignal: String,
        feedback: [PrincipleRecallFeedback]
    ) -> Int {
        let normalizedRetrievalSignal = normalizedSignal(retrievalSignal)
        return feedback
            .filter { $0.principleId == principleId }
            .reduce(0) { partial, event in
                guard event.feedback.isNegativeRecall else {
                    return partial
                }
                let eventSignal = normalizedSignal(event.retrievalSignal)
                guard eventSignal.isEmpty || eventSignal == normalizedRetrievalSignal else {
                    return partial
                }
                return partial + 1
            }
    }

    private func normalizedSignal(_ signal: String) -> String {
        signal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func retrievalReason(
        for principle: PrincipleAsset,
        terms: [String],
        baseScore: Int,
        adjustedScore: Int,
        feedbackPenalty: Int
    ) -> String {
        let principleText = [
            principle.title,
            principle.summary,
            principle.triggerContext,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ].joined(separator: " ").lowercased()
        let matchedTerms = Array(Set(terms))
            .sorted()
            .filter { principleText.contains($0) }
            .prefix(4)
        let matchedText = matchedTerms.isEmpty ? "keyword overlap" : matchedTerms.joined(separator: ", ")
        var reason = "Matched \(matchedText) with \(principle.title) using local keyword policy; score=\(adjustedScore)."
        if feedbackPenalty > 0 {
            reason += " Applied negative recall feedback penalty=\(feedbackPenalty) from base score=\(baseScore)."
        }
        return reason
    }

    private func retrievalSignal(for principle: PrincipleAsset, terms: [String]) -> String {
        let termSet = Set(terms)
        let candidateFields = [
            principle.triggerContext,
            principle.title,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ]

        for field in candidateFields {
            let signal = field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let signalTerms = signal
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
            guard !signal.isEmpty, !signalTerms.isEmpty else { continue }
            if signalTerms.allSatisfy({ termSet.contains($0) }) {
                return signal
            }
        }

        let principleText = [
            principle.title,
            principle.summary,
            principle.triggerContext,
            principle.actions.joined(separator: " "),
            principle.successCriteria
        ].joined(separator: " ").lowercased()
        let matchedTerms = Array(Set(terms))
            .sorted()
            .filter { principleText.contains($0) }
            .prefix(4)
        return matchedTerms.isEmpty ? "keyword overlap" : matchedTerms.joined(separator: " ")
    }
}

struct CoachContextMemorySelection: Hashable {
    var retrievedPrinciples: [RetrievedPrinciple] = []
    var existingPrinciples: [PrincipleAsset] = []
    var lensFeedback: [PromptContextPayload.LensFeedbackContext] = []
    var trainingPrescription: TrainingPrescription?
    var coachDiagnosis: CoachDiagnosis?
    var coachTurnState: CoachTurnState?
    var coachTeachingPlan: CoachTeachingPlan?
    var coachObservation: CoachObservation?
    var coachPatternSummary: CoachPatternSummary?

    var relevantPrinciples: [PrincipleAsset] {
        retrievedPrinciples.map(\.principle)
    }
}

struct CoachContextMemoryPolicy {
    static let policyVersion = "coach-context-memory.local-v1"

    var principleLimit = 3
    var lensFeedbackLimit = 2

    func selectMemory(
        promptID: PromptID,
        context: TodayAIContext,
        principleRetriever: PrincipleRetriever
    ) -> CoachContextMemorySelection {
        guard allowsCoachMemory(promptID) else {
            return CoachContextMemorySelection()
        }

        let retrievedPrinciples = allowsPrincipleReferences(promptID)
            ? principleRetriever.retrievePrinciples(
                for: context,
                promptID: promptID,
                limit: principleLimit
            )
            : []
        let existingPrinciples = promptID == .extractPrinciple ? context.principles : []

        return CoachContextMemorySelection(
            retrievedPrinciples: retrievedPrinciples,
            existingPrinciples: existingPrinciples,
            lensFeedback: lensFeedback(
                for: promptID,
                context: context
            ),
            trainingPrescription: allowsTrainingPrescription(promptID) ? context.trainingPrescription : nil,
            coachDiagnosis: allowsCoachTurn(promptID) ? context.coachDiagnosis : nil,
            coachTurnState: allowsCoachTurn(promptID) ? context.coachTurnState : nil,
            coachTeachingPlan: coachTeachingPlan(
                for: promptID,
                context: context
            ),
            coachObservation: coachObservation(
                for: promptID,
                context: context
            ),
            coachPatternSummary: allowsCoachPatternSummary(promptID) ? context.coachPatternSummary : nil
        )
    }

    private func coachObservation(
        for promptID: PromptID,
        context: TodayAIContext
    ) -> CoachObservation? {
        guard allowsCoachObservation(promptID),
              !context.confirmedCards.isEmpty else {
            return nil
        }
        return CoachObservationPolicy().observe(cards: context.confirmedCards)
    }

    private func coachTeachingPlan(
        for promptID: PromptID,
        context: TodayAIContext
    ) -> CoachTeachingPlan? {
        guard allowsCoachTurn(promptID),
              let turn = context.coachTurnState else {
            return nil
        }
        return CoachTeachingPolicy().makePlan(
            turn: turn,
            prescription: context.trainingPrescription
        )
    }

    func lensFeedback(
        for promptID: PromptID,
        context: TodayAIContext
    ) -> [PromptContextPayload.LensFeedbackContext] {
        guard allowsLensFeedback(promptID) else { return [] }
        let finalLensId = context.trainingPrescription?.finalLensId
            ?? context.selectedLensItem?.lensId
            ?? context.draft.selectedLens?.rawValue
        guard let finalLensId else { return [] }

        return Array(
            context.lensFeedback
                .filter { $0.lensId == finalLensId }
                .prefix(lensFeedbackLimit)
        )
    }

    private func allowsCoachMemory(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .mentorRespond, .mentorDraftUnderstanding, .lifeGuidanceReview, .lifeGuidanceShortlist:
            return false
        case .generateQuestions, .generateQuests, .extractPrinciple:
            return true
        case .organizeCards, .recommendLenses, .verifyQuest, .suggestProjectLinks,
             .generateProjectInsights, .suggestProjectMerges, .generateSideQuest, .weeklyCalibration, .monthlyGrowth,
             .recommendGuidance, .evaluateGuidanceEvidence, .diagnoseTrainingCase, .reviewCoachAnswer, .digestCaptures, .singleNudge:
            return false
        }
    }

    private func allowsPrincipleReferences(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .mentorRespond, .mentorDraftUnderstanding, .lifeGuidanceReview, .lifeGuidanceShortlist:
            return false
        case .generateQuestions, .generateQuests:
            return true
        case .extractPrinciple, .organizeCards, .recommendLenses, .verifyQuest,
             .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges, .generateSideQuest,
             .weeklyCalibration, .monthlyGrowth, .recommendGuidance, .evaluateGuidanceEvidence, .diagnoseTrainingCase, .reviewCoachAnswer, .digestCaptures, .singleNudge:
            return false
        }
    }

    private func allowsLensFeedback(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .mentorRespond, .mentorDraftUnderstanding, .lifeGuidanceReview, .lifeGuidanceShortlist:
            return false
        case .generateQuestions, .generateQuests:
            return true
        case .organizeCards, .recommendLenses, .verifyQuest, .extractPrinciple,
             .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges, .generateSideQuest,
             .weeklyCalibration, .monthlyGrowth, .recommendGuidance, .evaluateGuidanceEvidence, .diagnoseTrainingCase, .reviewCoachAnswer, .digestCaptures, .singleNudge:
            return false
        }
    }

    private func allowsTrainingPrescription(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .mentorRespond, .mentorDraftUnderstanding, .lifeGuidanceReview, .lifeGuidanceShortlist:
            return false
        case .generateQuests, .extractPrinciple:
            return true
        case .generateQuestions:
            // Question generation decides whether the user's current material
            // needs one useful next move. A stored training prescription is a
            // prior, not an instruction for this turn.
            return false
        case .organizeCards, .recommendLenses, .verifyQuest, .suggestProjectLinks,
             .generateProjectInsights, .suggestProjectMerges, .generateSideQuest, .weeklyCalibration, .monthlyGrowth,
             .recommendGuidance, .evaluateGuidanceEvidence, .diagnoseTrainingCase, .reviewCoachAnswer, .digestCaptures, .singleNudge:
            return false
        }
    }

    private func allowsCoachTurn(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .mentorRespond, .mentorDraftUnderstanding, .lifeGuidanceReview, .lifeGuidanceShortlist:
            return false
        case .generateQuests:
            return true
        case .generateQuestions:
            // The current question turn must interpret today's evidence before
            // any stateful coach plan can influence the wording.
            return false
        case .organizeCards, .recommendLenses, .verifyQuest, .extractPrinciple,
             .suggestProjectLinks, .generateProjectInsights, .suggestProjectMerges, .generateSideQuest,
             .weeklyCalibration, .monthlyGrowth, .recommendGuidance, .evaluateGuidanceEvidence, .diagnoseTrainingCase, .reviewCoachAnswer, .digestCaptures, .singleNudge:
            return false
        }
    }

    private func allowsCoachObservation(_ promptID: PromptID) -> Bool {
        switch promptID {
        case .mentorRespond, .mentorDraftUnderstanding, .lifeGuidanceReview, .lifeGuidanceShortlist:
            return false
        case .generateQuestions, .organizeCards, .recommendLenses, .generateQuests, .verifyQuest,
             .extractPrinciple, .suggestProjectLinks, .generateProjectInsights,
             .suggestProjectMerges, .generateSideQuest, .weeklyCalibration, .monthlyGrowth,
             .recommendGuidance, .evaluateGuidanceEvidence, .diagnoseTrainingCase, .reviewCoachAnswer, .digestCaptures, .singleNudge:
            return false
        }
    }

    private func allowsCoachPatternSummary(_ promptID: PromptID) -> Bool {
        // Old local diagnoses mixed raw material and assistant-authored text.
        // Keep decoding support, but never send them as evidence or a prior.
        false
    }

}

struct DefaultContextAssembler: ContextAssembler {
    private let principleRetriever: PrincipleRetriever
    private let memoryPolicy: CoachContextMemoryPolicy

    init(
        principleRetriever: PrincipleRetriever = LocalPrincipleRetriever(),
        memoryPolicy: CoachContextMemoryPolicy = CoachContextMemoryPolicy()
    ) {
        self.principleRetriever = principleRetriever
        self.memoryPolicy = memoryPolicy
    }

    func assemble(promptID: PromptID, context: TodayAIContext) -> PromptContext {
        let memory = memoryPolicy.selectMemory(
            promptID: promptID,
            context: context,
            principleRetriever: principleRetriever
        )
        let relevantPrinciples = memory.relevantPrinciples
        let contextPayload = structuredPayload(
            for: context,
            memory: memory,
            directives: .init(
                principleUsageRule: !relevantPrinciples.isEmpty
                    ? "Use accepted principles as experience replay: ask whether today's case should reproduce, adapt, or reject the prior behavior. Do not force today's situation to fit them."
                    : nil,
                principleSelectionRule: !relevantPrinciples.isEmpty
                    ? "The principles supplied here are bounded candidate material, not a local conclusion. You are the final decision maker: select only a candidate that is materially relevant to the current matter, and ignore all candidates that do not fit today's evidence. Never claim a principle was applied unless the current evidence supports that claim."
                    : nil,
                // The versioned action-design template governs these optional
                // plans. Legacy directives required another repair question and
                // contradicted the user's explicit choice to carry an open gap.
                coachDiagnosisRule: nil,
                coachTurnRule: nil,
                coachTeachingRule: nil,
                coachObservationRule: memory.coachObservation != nil
                    ? "Use coachObservation before wording questions: cite what was observed, the primary gap, the training ability, the repair ask, and the experience replay prompt. Treat coachObservation as the coach's interpretation of confirmed material, not as new source evidence. Create one primary training contract from trainingAbility, primaryGap, and feedback.ask. The first question must ask the user to produce missing material; it must not provide the missing material or solve the case. why_now must name the observed gap, expected_update must name the user-owned training output, and proceed_when must name a self-checkable standard. If experienceReplayPrompt is relevant, ask whether prior experience should reproduce, adapt, or reject today's move before applying it."
                    : nil,
                coachPatternSummaryRule: nil
            )
        )

        return PromptContext(
            version: 1,
            inputSummary: inputSummary(for: context, relevantPrinciples: relevantPrinciples),
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs(for: context),
            contextRecordIDs: contextRecordIDs(
                for: context,
                relevantPrinciples: relevantPrinciples,
                existingPrinciples: memory.existingPrinciples,
                coachPatternSummary: memory.coachPatternSummary,
                lensFeedback: memory.lensFeedback
            )
        )
    }

    private func structuredPayload(
        for context: TodayAIContext,
        memory: CoachContextMemorySelection,
        directives: PromptContextPayload.PromptDirectives
    ) -> PromptContextPayload {
        PromptContextPayload(
            currentInput: .init(
                dailyEntryId: context.draft.id.uuidString,
                rawText: caseScopedRawText(for: context)
            ),
            currentCase: context.currentTrainingCase.map { trainingCase in
                .init(
                    id: trainingCase.id.uuidString,
                    title: trainingCase.title,
                    status: trainingCase.status.rawValue,
                    evidenceRefs: context.confirmedCards.map { $0.id.uuidString }
                )
            },
            userChoice: .init(
                sessionMode: context.draft.sessionMode.rawValue,
                selectedLens: selectedLensId(for: context),
                lensCatalog: selectedLensItem(for: context).map { item in
                    return .init(
                        localId: item.lensId,
                        promptId: item.promptId,
                        version: item.version,
                        title: item.title,
                        methodLine: item.methodLine,
                        promptGuidance: item.promptGuidance,
                        purpose: item.purpose,
                        questionStrategy: item.questionStrategy,
                        taskSelectionRule: item.taskSelectionRule,
                        applicability: item.applicability,
                        disableConditions: item.disableConditions,
                        uiMetadata: .init(
                            symbolName: item.uiMetadata.symbolName,
                            accentRole: item.uiMetadata.accentRole,
                            methodIndex: item.uiMetadata.methodIndex
                        ),
                        sourceKind: item.sourceKind,
                        packId: item.packId,
                        packVersion: item.packVersion,
                        packDisplayName: item.packDisplayName
                    )
                }
            ),
            cards: context.confirmedCards.map { card in
                .init(
                    id: card.id.uuidString,
                    type: card.type.rawValue,
                    title: card.title,
                    body: card.body,
                    priority: card.priority.rawValue,
                    sensitivity: card.sensitivity.rawValue,
                    isExcludedFromModel: card.isExcludedFromModel
                )
            },
            answers: context.questions.map { question in
                .init(
                    id: question.id.uuidString,
                    question: question.question,
                    answer: question.answer,
                    calibrationTarget: question.calibrationTarget
                )
            },
            quests: context.quests.map { quest in
                .init(
                    id: quest.id.uuidString,
                    type: quest.type.rawValue,
                    title: quest.title,
                    completionCriteria: quest.completionCriteria,
                    calibrationTarget: quest.calibrationTarget
                )
            },
            principles: memory.retrievedPrinciples.map { retrieved in
                let principle = retrieved.principle
                return PromptContextPayload.PrincipleContext(
                    id: principle.id.uuidString,
                    title: principle.title,
                    summary: principle.summary,
                    triggerContext: principle.triggerContext,
                    successCriteria: principle.successCriteria,
                    exceptions: principle.exceptions,
                    status: principle.status,
                    retrievalReason: retrieved.retrievalReason,
                    retrievalPolicyVersion: retrieved.policyVersion,
                    retrievalSignal: retrieved.retrievalSignal
                )
            },
            existingPrinciples: memory.existingPrinciples.map { principle in
                .init(
                    id: principle.id.uuidString,
                    title: principle.title,
                    summary: principle.summary,
                    triggerContext: principle.triggerContext,
                    successCriteria: principle.successCriteria,
                    exceptions: principle.exceptions,
                    status: principle.status
                )
            },
            directives: directives,
            lensFeedback: memory.lensFeedback,
            trainingPrescription: memory.trainingPrescription.map(PromptContextPayload.TrainingPrescriptionContext.init),
            coachDiagnosis: memory.coachDiagnosis.map(PromptContextPayload.CoachDiagnosisContext.init),
            coachTurnState: memory.coachTurnState.map(PromptContextPayload.CoachTurnStateContext.init),
            coachTeachingPlan: memory.coachTeachingPlan.map(PromptContextPayload.CoachTeachingPlanContext.init),
            coachObservation: memory.coachObservation.map(PromptContextPayload.CoachObservationContext.init),
            coachPatternSummary: memory.coachPatternSummary.map(PromptContextPayload.CoachPatternSummaryContext.init)
        )
    }

    private func sourceRecordIDs(for context: TodayAIContext) -> [String] {
        var ids = [context.draft.id.uuidString]
        if let currentTrainingCase = context.currentTrainingCase {
            ids.append(currentTrainingCase.id.uuidString)
        }
        ids.append(contentsOf: context.confirmedCards.map { $0.id.uuidString })
        ids.append(contentsOf: context.questions.map { $0.id.uuidString })
        ids.append(contentsOf: context.quests.map { $0.id.uuidString })
        return Array(Set(ids)).sorted()
    }

    private func contextRecordIDs(
        for context: TodayAIContext,
        relevantPrinciples: [PrincipleAsset],
        existingPrinciples: [PrincipleAsset],
        coachPatternSummary: CoachPatternSummary?,
        lensFeedback: [PromptContextPayload.LensFeedbackContext]
    ) -> [String] {
        var ids = sourceRecordIDs(for: context)
        ids.append(contentsOf: relevantPrinciples.map { $0.id.uuidString })
        ids.append(contentsOf: existingPrinciples.map { $0.id.uuidString })
        ids.append(contentsOf: coachPatternSummary?.sourceDailyEntryIds ?? [])
        ids.append(contentsOf: lensFeedback.flatMap { [$0.verificationId, $0.trainingCaseId].compactMap { $0 } })
        return Array(Set(ids)).sorted()
    }

    private func inputSummary(for context: TodayAIContext, relevantPrinciples: [PrincipleAsset]) -> String {
        let rawText = caseScopedRawText(for: context).trimmingCharacters(in: .whitespacesAndNewlines)
        let lens = selectedLensItem(for: context)?.promptId ?? "none"
        let cardTitles = context.confirmedCards.map(\.title).joined(separator: ", ")
        let principleTitles = relevantPrinciples.map(\.title).joined(separator: ", ")
        return "mode=\(context.draft.sessionMode.rawValue); lens=\(lens); rawText=\(rawText); cards=\(cardTitles); principles=\(principleTitles)"
    }

    private func caseScopedRawText(for context: TodayAIContext) -> String {
        guard context.currentTrainingCase != nil else { return context.draft.rawText }
        return context.confirmedCards
            .filter { !$0.isExcludedFromModel }
            .map { "\($0.title)：\($0.body)" }
            .joined(separator: "\n")
    }

    private func selectedLensId(for context: TodayAIContext) -> String? {
        if let finalLensId = context.trainingPrescription?.finalLensId {
            return finalLensId
        }
        return selectedLensItem(for: context)?.lensId
    }

    private func selectedLensItem(for context: TodayAIContext) -> LensCatalogItem? {
        if let finalLensId = context.trainingPrescription?.finalLensId {
            if let runtimeItem = context.selectedLensItem, runtimeItem.lensId == finalLensId {
                return runtimeItem
            }
            if let builtinItem = BuiltinLensCatalog.item(localId: finalLensId) {
                return builtinItem
            }
        }
        return context.selectedLensItem ?? context.draft.selectedLens?.catalogItem
    }
}
