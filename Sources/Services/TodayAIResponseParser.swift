import Foundation

enum TodayAIParsingError: Error, Equatable {
    case missingResponseContent
    case invalidJSON
    case emptyResult
    case qualityGateFailed([String])
}

struct GrowthReportResult: Hashable {
    let snapshot: MetricSnapshot
    let contributions: [MetricContribution]
}

struct TodayAIResponseParser {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func parseCards(from data: Data) throws -> [ThinkingCard] {
        try parseOrganizedCapture(from: data).cards
    }

    func parseOrganizedCapture(from data: Data) throws -> OrganizedCaptureResult {
        let response = try decoder.decode(OrganizeCardsResponseDTO.self, from: normalizedPayloadData(from: data))
        var grouped: [(card: ThinkingCard, caseKey: String, caseTitle: String)] = []
        for dto in response.cards {
            let title = dto.title.trimmed
            let body = dto.body.trimmed
            guard !title.isEmpty || !body.isEmpty else { continue }

            let card = ThinkingCard(
                type: ThinkingCardType(aiRawValue: dto.type.value),
                title: title.isEmpty ? "未命名卡片" : title,
                body: body.isEmpty ? dto.reason.trimmed : body,
                priority: PriorityLevel(aiRawValue: dto.importance.value),
                sensitivity: SensitivityLevel(aiRawValue: dto.sensitivity.value),
                confidence: ConfidenceMapper.score(from: dto.confidence.value),
                isConfirmed: false
            )
            grouped.append((card, dto.caseKey.trimmed, dto.caseTitle.trimmed))
        }
        let cards = grouped.map(\.card)

        guard !cards.isEmpty else { throw TodayAIParsingError.emptyResult }
        return OrganizedCaptureResult(
            cards: cards,
            caseSuggestions: Self.caseSuggestions(
                grouped.map { ($0.card.id, $0.caseKey, $0.caseTitle, $0.card.title) }
            )
        )
    }

    private static func caseSuggestions(
        _ values: [(cardId: UUID, key: String, title: String, fallbackTitle: String)]
    ) -> [TrainingCaseSuggestion] {
        var order: [String] = []
        var groups: [String: (title: String, ids: [UUID])] = [:]
        for value in values {
            let key = value.key.isEmpty ? "default" : String(value.key.prefix(64))
            if groups[key] == nil { order.append(key) }
            let title = value.title.isEmpty ? value.fallbackTitle : value.title
            groups[key, default: (title, [])].ids.append(value.cardId)
        }
        return order.compactMap { key in
            guard let group = groups[key] else { return nil }
            return TrainingCaseSuggestion(key: key, title: group.title.ifEmpty("今天要想清楚的事"), cardIds: group.ids)
        }
    }

    func parseQuestions(from data: Data) throws -> [ReflectionQuestion] {
        let response = try decoder.decode(QuestionsResponseDTO.self, from: normalizedPayloadData(from: data))
        let questions = response.questions.compactMap { dto -> ReflectionQuestion? in
            let question = dto.question.trimmed
            guard !question.isEmpty else { return nil }

            return ReflectionQuestion(
                question: question,
                whyItMatters: dto.whyThisMatters.trimmed.ifEmpty("帮助把今天的判断转成可验证行动。"),
                whyNow: dto.whyNow.trimmed.ifEmpty(nil),
                expectedUpdate: dto.expectedUpdate.trimmed.ifEmpty(nil),
                proceedWhen: dto.proceedWhen.trimmed.ifEmpty(nil),
                evidenceGapType: EvidenceGapType(aiRawValue: dto.evidenceGapType),
                answerUse: QuestionAnswerUse(aiRawValue: dto.answerUse),
                lensMove: QuestionLensMove(aiRawValue: dto.lensMove),
                sourceCardTitles: Self.normalizedTitles(dto.sourceCardTitles),
                calibrationTarget: dto.calibrationTarget.trimmed.ifEmpty(nil)
            )
        }

        guard !questions.isEmpty else { throw TodayAIParsingError.emptyResult }
        return questions
    }

    fileprivate static func normalizedTitles(_ titles: [String]) -> [String] {
        titles.reduce(into: [String]()) { result, title in
            let trimmed = title.trimmed
            guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
            result.append(trimmed)
        }
    }

    func parseQuests(from data: Data) throws -> [Quest] {
        let response = try decoder.decode(QuestsResponseDTO.self, from: normalizedPayloadData(from: data))
        guard let mainQuest = response.mainQuest?.domainQuest(defaultType: .main) else {
            throw TodayAIParsingError.emptyResult
        }

        var quests = [mainQuest]
        quests.append(contentsOf: response.sideQuests.compactMap { $0.domainQuest(defaultType: .side) })
        if let observationQuest = response.observationQuest?.domainQuest(defaultType: .observation) {
            quests.append(observationQuest)
        }

        return quests
    }

    func parsePrinciples(from data: Data) throws -> [PrincipleAsset] {
        let response = try decoder.decode(PrincipleResponseDTO.self, from: normalizedPayloadData(from: data))
        guard let candidate = response.principleCandidate else { return [] }
        guard let principle = candidate.domainPrinciple else { return [] }
        return [principle]
    }

    func parseVerification(from data: Data) throws -> VerifyQuestResult {
        let dto = try decoder.decode(VerificationResponseDTO.self, from: normalizedPayloadData(from: data))
        let note = dto.calibrationNote.trimmed
        guard !note.isEmpty else {
            throw TodayAIParsingError.emptyResult
        }
        return VerifyQuestResult(
            calibrationNote: note,
            likelyIssue: dto.likelyIssue.trimmed.ifEmpty(nil),
            recommendation: dto.recommendation.trimmed.ifEmpty(nil),
            expectedPrinciplePracticeAssessment: dto.expectedPrinciplePracticeAssessment.trimmed.ifEmpty(nil),
            growthEvidenceItems: try growthEvidenceItems(
                dto.growthEvidenceItems,
                allowedSourceRefs: []
            )
        )
    }

    func parseVerification(
        from data: Data,
        allowedGrowthEvidenceRefs: Set<String>
    ) throws -> VerifyQuestResult {
        let dto = try decoder.decode(VerificationResponseDTO.self, from: normalizedPayloadData(from: data))
        let note = dto.calibrationNote.trimmed
        guard !note.isEmpty else { throw TodayAIParsingError.emptyResult }
        return VerifyQuestResult(
            calibrationNote: note,
            likelyIssue: dto.likelyIssue.trimmed.ifEmpty(nil),
            recommendation: dto.recommendation.trimmed.ifEmpty(nil),
            expectedPrinciplePracticeAssessment: dto.expectedPrinciplePracticeAssessment.trimmed.ifEmpty(nil),
            growthEvidenceItems: try growthEvidenceItems(
                dto.growthEvidenceItems,
                allowedSourceRefs: allowedGrowthEvidenceRefs
            )
        )
    }

    private func growthEvidenceItems(
        _ items: [GrowthSettlementEvidenceDTO],
        allowedSourceRefs: Set<String>
    ) throws -> [GrowthSettlementEvidenceItem] {
        guard items.count <= 3 else {
            throw TodayAIParsingError.qualityGateFailed(["成长结算证据不得超过三条。"])
        }
        return try items.map { item in
            guard let category = GrowthSettlementCategory(rawValue: item.category),
                  let metric = GrowthMetric(rawValue: item.metric) else {
                throw TodayAIParsingError.qualityGateFailed(["成长结算证据使用了未允许的分类或指标。"])
            }
            let title = item.title.trimmed
            let refs = Array(Set(item.sourceRefs.map { $0.trimmed }.filter { !$0.isEmpty })).sorted()
            guard !title.isEmpty, title.count <= 80, !refs.isEmpty else {
                throw TodayAIParsingError.qualityGateFailed(["成长结算证据必须有简短标题和来源。"])
            }
            if !allowedSourceRefs.isEmpty,
               !Set(refs).isSubset(of: allowedSourceRefs) {
                throw TodayAIParsingError.qualityGateFailed(["成长结算证据只能引用当前行动和验证材料。"])
            }
            return GrowthSettlementEvidenceItem(
                category: category,
                metric: metric,
                title: title,
                sourceRefs: refs
            )
        }
    }

    func parseMetricContributions(from data: Data, snapshotId: UUID) throws -> [MetricContribution] {
        let response = try decoder.decode(MetricContributionsResponseDTO.self, from: normalizedPayloadData(from: data))
        let contributions = response.metricContributions.compactMap { $0.domainContribution(snapshotId: snapshotId) }

        guard !contributions.isEmpty else { throw TodayAIParsingError.emptyResult }
        return contributions
    }

    func parseGrowthReport(
        from data: Data,
        period: String,
        completeLoopCount: Int
    ) throws -> GrowthReportResult {
        let payload = try normalizedPayloadData(from: data)
        let dto = try decoder.decode(GrowthReportResponseDTO.self, from: payload)

        let isInsufficient = dto.insufficientEvidence
        let summary = dto.summary.trimmed.ifEmpty("成长报告生成中。")
        let focus = dto.nextTrainingFocus.trimmed.ifEmpty(nil)

        let clarity = dto.metrics.clarity?.value ?? 3.0
        let valueJudgment = dto.metrics.valueJudgment?.value ?? 3.0
        let executionReliability = dto.metrics.executionReliability?.value ?? 3.0
        let calibration = dto.metrics.calibration?.value ?? 3.0
        let reflectionDepth = dto.metrics.reflectionDepth?.value ?? 3.0

        let clarityDelta = dto.metrics.clarity?.delta
        let valueJudgmentDelta = dto.metrics.valueJudgment?.delta
        let executionReliabilityDelta = dto.metrics.executionReliability?.delta
        let calibrationDelta = dto.metrics.calibration?.delta
        let reflectionDepthDelta = dto.metrics.reflectionDepth?.delta

        var metricReasons: [String: String] = [:]
        if let reason = dto.metrics.clarity?.reason, !reason.trimmed.isEmpty {
            metricReasons[GrowthMetric.clarity.rawValue] = reason.trimmed
        }
        if let reason = dto.metrics.valueJudgment?.reason, !reason.trimmed.isEmpty {
            metricReasons[GrowthMetric.valueJudgment.rawValue] = reason.trimmed
        }
        if let reason = dto.metrics.executionReliability?.reason, !reason.trimmed.isEmpty {
            metricReasons[GrowthMetric.executionReliability.rawValue] = reason.trimmed
        }
        if let reason = dto.metrics.calibration?.reason, !reason.trimmed.isEmpty {
            metricReasons[GrowthMetric.calibration.rawValue] = reason.trimmed
        }
        if let reason = dto.metrics.reflectionDepth?.reason, !reason.trimmed.isEmpty {
            metricReasons[GrowthMetric.reflectionDepth.rawValue] = reason.trimmed
        }

        let snapshotId = UUID()
        let contributions = dto.metricContributions.compactMap { $0.domainContribution(snapshotId: snapshotId) }

        let positiveRefs = contributions
            .filter { $0.direction == .positive }
            .map { $0.id.uuidString }
        let negativeRefs = contributions
            .filter { $0.direction == .negative }
            .map { $0.id.uuidString }

        let snapshot = MetricSnapshot(
            id: snapshotId,
            period: period,
            clarity: clarity,
            valueJudgment: valueJudgment,
            executionReliability: executionReliability,
            calibration: calibration,
            reflectionDepth: reflectionDepth,
            clarityDelta: clarityDelta,
            valueJudgmentDelta: valueJudgmentDelta,
            executionReliabilityDelta: executionReliabilityDelta,
            calibrationDelta: calibrationDelta,
            reflectionDepthDelta: reflectionDepthDelta,
            summary: summary,
            metricReasons: metricReasons,
            positiveContributionRefs: positiveRefs,
            negativeContributionRefs: negativeRefs,
            status: isInsufficient ? .insufficientEvidence : .draftReview,
            completeLoopCount: completeLoopCount,
            nextTrainingFocus: focus
        )

        return GrowthReportResult(snapshot: snapshot, contributions: contributions)
    }

    func parseProjectSuggestions(from data: Data) throws -> ProjectSuggestionResult {
        let response = try decoder.decode(ProjectSuggestionsResponseDTO.self, from: normalizedPayloadData(from: data))
        return ProjectSuggestionResult(
            linkCandidates: response.projectLinkCandidates.compactMap(\.domainCandidate),
            newProjectCandidates: response.newProjectCandidates.compactMap(\.domainCandidate)
        )
    }

    func parseProjectInsights(from data: Data) throws -> ProjectInsightsResult {
        let response = try decoder.decode(ProjectInsightsResponseDTO.self, from: normalizedPayloadData(from: data))
        let insights = response.projectInsights.compactMap(\.domainInsight)
        let reason = response.insufficientEvidenceReason.trimmed.ifEmpty(nil)
        guard !insights.isEmpty || reason != nil else { throw TodayAIParsingError.emptyResult }
        return ProjectInsightsResult(insights: insights, insufficientEvidenceReason: reason)
    }

    func parseProjectMergeCandidates(from data: Data) throws -> [ProjectMergeCandidate] {
        let response = try decoder.decode(ProjectMergeCandidatesResponseDTO.self, from: normalizedPayloadData(from: data))
        let candidates = response.mergeCandidates.compactMap(\.domainCandidate)
        guard !candidates.isEmpty else { throw TodayAIParsingError.emptyResult }
        return candidates
    }

    private func normalizedPayloadData(from data: Data) throws -> Data {
        if let envelope = try? decoder.decode(LLMChatEnvelopeDTO.self, from: data),
           let content = envelope.choices.compactMap(\.message?.content).first?.trimmed,
           !content.isEmpty {
            return try jsonObjectData(from: content)
        }

        return try jsonObjectData(from: String(decoding: data, as: UTF8.self))
    }

    private func jsonObjectData(from text: String) throws -> Data {
        let stripped = text
            .trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmed

        guard
            let start = stripped.firstIndex(of: "{"),
            let end = stripped.lastIndex(of: "}"),
            start <= end
        else {
            throw TodayAIParsingError.invalidJSON
        }

        let jsonText = String(stripped[start...end])
        guard let data = jsonText.data(using: .utf8) else {
            throw TodayAIParsingError.invalidJSON
        }
        return data
    }
}

private struct LLMChatEnvelopeDTO: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message?
    }

    struct Message: Decodable {
        let content: String?
    }
}

private struct OrganizeCardsResponseDTO: Decodable {
    let cards: [CardDTO]
}

private struct CardDTO: Decodable {
    let type: FlexibleString
    let title: String
    let body: String
    let importance: FlexibleString
    let sensitivity: FlexibleString
    let confidence: FlexibleString
    let reason: String
    let caseKey: String
    let caseTitle: String

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case body
        case importance
        case sensitivity
        case confidence
        case reason
        case caseKey
        case caseTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(FlexibleString.self, forKey: .type) ?? FlexibleString("")
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        importance = try container.decodeIfPresent(FlexibleString.self, forKey: .importance) ?? FlexibleString("")
        sensitivity = try container.decodeIfPresent(FlexibleString.self, forKey: .sensitivity) ?? FlexibleString("")
        confidence = try container.decodeIfPresent(FlexibleString.self, forKey: .confidence) ?? FlexibleString("")
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        caseKey = try container.decodeIfPresent(String.self, forKey: .caseKey) ?? ""
        caseTitle = try container.decodeIfPresent(String.self, forKey: .caseTitle) ?? ""
    }
}

private struct QuestionsResponseDTO: Decodable {
    let questions: [QuestionDTO]
}

private struct QuestionDTO: Decodable {
    let question: String
    let whyThisMatters: String
    let whyNow: String
    let expectedUpdate: String
    let proceedWhen: String
    let evidenceGapType: String
    let answerUse: String
    let lensMove: String
    let sourceCardTitles: [String]
    let calibrationTarget: String

    private enum CodingKeys: String, CodingKey {
        case question
        case whyThisMatters
        case whyNow
        case expectedUpdate
        case proceedWhen
        case evidenceGapType
        case answerUse
        case lensMove
        case sourceCardTitles
        case calibrationTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        whyThisMatters = try container.decodeIfPresent(String.self, forKey: .whyThisMatters) ?? ""
        whyNow = try container.decodeIfPresent(String.self, forKey: .whyNow) ?? ""
        expectedUpdate = try container.decodeIfPresent(String.self, forKey: .expectedUpdate) ?? ""
        proceedWhen = try container.decodeIfPresent(String.self, forKey: .proceedWhen) ?? ""
        evidenceGapType = try container.decodeIfPresent(String.self, forKey: .evidenceGapType) ?? ""
        answerUse = try container.decodeIfPresent(String.self, forKey: .answerUse) ?? ""
        lensMove = try container.decodeIfPresent(String.self, forKey: .lensMove) ?? ""
        sourceCardTitles = try container.decodeIfPresent([String].self, forKey: .sourceCardTitles) ?? []
        calibrationTarget = try container.decodeIfPresent(String.self, forKey: .calibrationTarget) ?? ""
    }
}

private struct QuestsResponseDTO: Decodable {
    let mainQuest: QuestDTO?
    let sideQuests: [QuestDTO]
    let observationQuest: QuestDTO?

    private enum CodingKeys: String, CodingKey {
        case mainQuest
        case sideQuests
        case observationQuest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainQuest = try container.decodeIfPresent(QuestDTO.self, forKey: .mainQuest)
        sideQuests = try container.decodeIfPresent([QuestDTO].self, forKey: .sideQuests) ?? []
        observationQuest = try container.decodeIfPresent(QuestDTO.self, forKey: .observationQuest)
    }
}

private struct QuestDTO: Decodable {
    let type: FlexibleString
    let title: String
    let whyItMatters: String
    let completionCriteria: String
    let expectedResistance: String
    let reflectionQuestion: String
    let calibrationTarget: String
    let lensMove: String
    let linkedCards: [String]

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case whyItMatters
        case completionCriteria
        case expectedResistance
        case reflectionQuestion
        case calibrationTarget
        case lensMove
        case linkedCards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(FlexibleString.self, forKey: .type) ?? FlexibleString("")
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        whyItMatters = try container.decodeIfPresent(String.self, forKey: .whyItMatters) ?? ""
        completionCriteria = try container.decodeIfPresent(String.self, forKey: .completionCriteria) ?? ""
        expectedResistance = try container.decodeIfPresent(String.self, forKey: .expectedResistance) ?? ""
        reflectionQuestion = try container.decodeIfPresent(String.self, forKey: .reflectionQuestion) ?? ""
        calibrationTarget = try container.decodeIfPresent(String.self, forKey: .calibrationTarget) ?? ""
        lensMove = try container.decodeIfPresent(String.self, forKey: .lensMove) ?? ""
        linkedCards = try container.decodeIfPresent([String].self, forKey: .linkedCards) ?? []
    }

    func domainQuest(defaultType: QuestType) -> Quest? {
        let title = title.trimmed
        let completionCriteria = completionCriteria.trimmed
        guard !title.isEmpty, !completionCriteria.isEmpty else { return nil }

        return Quest(
            type: QuestType(aiRawValue: type.value) ?? defaultType,
            title: title,
            whyItMatters: whyItMatters.trimmed.ifEmpty("来自今日复盘的高价值行动。"),
            completionCriteria: completionCriteria,
            expectedResistance: expectedResistance.trimmed.ifEmpty("容易被临时事务打断。"),
            reflectionQuestion: reflectionQuestion.trimmed.ifEmpty("完成后，哪个关键判断被验证了？"),
            calibrationTarget: calibrationTarget.trimmed.ifEmpty(nil),
            lensMove: QuestionLensMove(aiRawValue: lensMove),
            sourceCardTitles: TodayAIResponseParser.normalizedTitles(linkedCards),
            status: .draft
        )
    }
}

private struct PrincipleResponseDTO: Decodable {
    let principleCandidate: PrincipleDTO?
}

private struct VerificationResponseDTO: Decodable {
    let calibrationNote: String
    let likelyIssue: String
    let recommendation: String
    let expectedPrinciplePracticeAssessment: String
    let growthEvidenceItems: [GrowthSettlementEvidenceDTO]

    private enum CodingKeys: String, CodingKey {
        case calibrationNote
        case likelyIssue
        case recommendation
        case expectedPrinciplePracticeAssessment
        case growthEvidenceItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calibrationNote = try container.decodeIfPresent(String.self, forKey: .calibrationNote) ?? ""
        likelyIssue = try container.decodeIfPresent(String.self, forKey: .likelyIssue) ?? ""
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation) ?? ""
        expectedPrinciplePracticeAssessment = try container.decodeIfPresent(
            String.self,
            forKey: .expectedPrinciplePracticeAssessment
        ) ?? ""
        growthEvidenceItems = try container.decodeIfPresent(
            [GrowthSettlementEvidenceDTO].self,
            forKey: .growthEvidenceItems
        ) ?? []
    }
}

private struct GrowthSettlementEvidenceDTO: Decodable {
    var category: String
    var metric: String
    var title: String
    var sourceRefs: [String]

    private enum CodingKeys: String, CodingKey {
        case category, metric, title, sourceRefs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        metric = try container.decodeIfPresent(String.self, forKey: .metric) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        sourceRefs = try container.decodeIfPresent([String].self, forKey: .sourceRefs) ?? []
    }
}

private struct MetricContributionsResponseDTO: Decodable {
    let metricContributions: [MetricContributionDTO]

    private enum CodingKeys: String, CodingKey {
        case metricContributions
        case contributions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metricContributions = try container.decodeIfPresent([MetricContributionDTO].self, forKey: .metricContributions)
            ?? container.decodeIfPresent([MetricContributionDTO].self, forKey: .contributions)
            ?? []
    }
}

private struct GrowthReportResponseDTO: Decodable {
    let insufficientEvidence: Bool
    let summary: String
    let metrics: GrowthMetricsDTO
    let metricContributions: [MetricContributionDTO]
    let nextTrainingFocus: String

    private enum CodingKeys: String, CodingKey {
        case insufficientEvidence
        case summary
        case metrics
        case metricContributions
        case contributions
        case nextTrainingFocus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        insufficientEvidence = try container.decodeIfPresent(Bool.self, forKey: .insufficientEvidence) ?? false
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        metrics = try container.decodeIfPresent(GrowthMetricsDTO.self, forKey: .metrics) ?? GrowthMetricsDTO()
        metricContributions = try container.decodeIfPresent([MetricContributionDTO].self, forKey: .metricContributions)
            ?? container.decodeIfPresent([MetricContributionDTO].self, forKey: .contributions)
            ?? []
        nextTrainingFocus = try container.decodeIfPresent(String.self, forKey: .nextTrainingFocus) ?? ""
    }
}

private struct GrowthMetricsDTO: Decodable {
    let clarity: GrowthMetricValueDTO?
    let valueJudgment: GrowthMetricValueDTO?
    let executionReliability: GrowthMetricValueDTO?
    let calibration: GrowthMetricValueDTO?
    let reflectionDepth: GrowthMetricValueDTO?

    init(
        clarity: GrowthMetricValueDTO? = nil,
        valueJudgment: GrowthMetricValueDTO? = nil,
        executionReliability: GrowthMetricValueDTO? = nil,
        calibration: GrowthMetricValueDTO? = nil,
        reflectionDepth: GrowthMetricValueDTO? = nil
    ) {
        self.clarity = clarity
        self.valueJudgment = valueJudgment
        self.executionReliability = executionReliability
        self.calibration = calibration
        self.reflectionDepth = reflectionDepth
    }
}

private struct GrowthMetricValueDTO: Decodable {
    let value: Double
    let delta: Double?
    let reason: String?

    private enum CodingKeys: String, CodingKey {
        case value
        case delta
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(Double.self, forKey: .value) ?? 3.0
        delta = try container.decodeIfPresent(Double.self, forKey: .delta)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
    }
}

private struct MetricContributionDTO: Decodable {
    let metric: String
    let direction: String
    let delta: Double
    let title: String
    let reason: String
    let sourceType: String
    let sourceId: String
    let sourceDailyEntryId: String

    private enum CodingKeys: String, CodingKey {
        case metric
        case direction
        case delta
        case title
        case reason
        case sourceType
        case sourceId
        case sourceDailyEntryId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metric = try container.decodeIfPresent(String.self, forKey: .metric) ?? ""
        direction = try container.decodeIfPresent(String.self, forKey: .direction) ?? ""
        delta = try container.decodeIfPresent(Double.self, forKey: .delta) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? ""
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId) ?? ""
        sourceDailyEntryId = try container.decodeIfPresent(String.self, forKey: .sourceDailyEntryId) ?? ""
    }

    func domainContribution(snapshotId: UUID) -> MetricContribution? {
        guard
            let metric = GrowthMetric(aiRawValue: metric),
            let direction = MetricContributionDirection(aiRawValue: direction),
            let sourceType = MetricContributionSourceType(aiRawValue: sourceType),
            let sourceDailyEntryId = UUID(uuidString: sourceDailyEntryId)
        else {
            return nil
        }

        let title = title.trimmed
        let reason = reason.trimmed
        let sourceId = sourceId.trimmed
        guard !title.isEmpty, !reason.isEmpty, !sourceId.isEmpty else { return nil }

        return MetricContribution(
            snapshotId: snapshotId,
            metric: metric,
            direction: direction,
            delta: min(max(abs(delta), 0.01), 0.30),
            title: title,
            reason: reason,
            sourceType: sourceType,
            sourceId: sourceId,
            sourceDailyEntryId: sourceDailyEntryId,
            candidateStatus: .candidate
        )
    }
}

private struct ProjectSuggestionsResponseDTO: Decodable {
    let projectLinkCandidates: [ProjectLinkCandidateDTO]
    let newProjectCandidates: [ProjectCandidateDTO]

    private enum CodingKeys: String, CodingKey {
        case projectLinkCandidates
        case linkCandidates
        case newProjectCandidates
        case projectCandidates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectLinkCandidates = try container.decodeIfPresent([ProjectLinkCandidateDTO].self, forKey: .projectLinkCandidates)
            ?? container.decodeIfPresent([ProjectLinkCandidateDTO].self, forKey: .linkCandidates)
            ?? []
        newProjectCandidates = try container.decodeIfPresent([ProjectCandidateDTO].self, forKey: .newProjectCandidates)
            ?? container.decodeIfPresent([ProjectCandidateDTO].self, forKey: .projectCandidates)
            ?? []
    }
}

private struct ProjectLinkCandidateDTO: Decodable {
    let projectId: String?
    let candidateProjectName: String?
    let linkType: String
    let sourceType: String
    let sourceId: String
    let reason: String
    let confidence: FlexibleString
    let requiresUserConfirmation: Bool

    private enum CodingKeys: String, CodingKey {
        case projectId
        case candidateProjectName
        case linkType
        case sourceType
        case sourceId
        case reason
        case confidence
        case requiresUserConfirmation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try container.decodeIfPresent(String.self, forKey: .projectId)
        candidateProjectName = try container.decodeIfPresent(String.self, forKey: .candidateProjectName)
        linkType = try container.decodeIfPresent(String.self, forKey: .linkType) ?? ""
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? ""
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        confidence = try container.decodeIfPresent(FlexibleString.self, forKey: .confidence) ?? FlexibleString("")
        requiresUserConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresUserConfirmation) ?? false
    }

    var domainCandidate: ProjectLinkCandidate? {
        guard
            requiresUserConfirmation,
            let sourceType = ProjectSourceType(aiRawValue: sourceType),
            let linkType = ProjectLinkType(aiRawValue: linkType)
        else {
            return nil
        }

        let sourceId = sourceId.trimmed
        let reason = reason.trimmed
        let candidateProjectName = candidateProjectName?.trimmed.ifEmpty(nil)
        let projectId = projectId?.trimmed.ifEmpty(nil).flatMap(UUID.init(uuidString:))
        guard !sourceId.isEmpty, !reason.isEmpty, projectId != nil || candidateProjectName != nil else { return nil }

        return ProjectLinkCandidate(
            projectId: projectId,
            candidateProjectName: candidateProjectName,
            sourceType: sourceType,
            sourceId: sourceId,
            linkType: linkType,
            reason: reason,
            confidence: ConfidenceMapper.score(from: confidence.value),
            requiresUserConfirmation: true
        )
    }
}

private struct ProjectCandidateDTO: Decodable {
    let candidateProjectName: String
    let name: String
    let goal: String
    let currentBottleneck: String
    let successCriteria: String
    let whyThisIsLongRunning: String
    let reason: String
    let sourceRefs: [ProjectSourceRefDTO]
    let sourceIds: [String]
    let privacySafeNameRequired: Bool
    let confidence: FlexibleString

    private enum CodingKeys: String, CodingKey {
        case candidateProjectName
        case name
        case goal
        case currentBottleneck
        case successCriteria
        case whyThisIsLongRunning
        case reason
        case sourceRefs
        case sourceIds
        case privacySafeNameRequired
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        candidateProjectName = try container.decodeIfPresent(String.self, forKey: .candidateProjectName) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        currentBottleneck = try container.decodeIfPresent(String.self, forKey: .currentBottleneck) ?? ""
        successCriteria = try container.decodeIfPresent(String.self, forKey: .successCriteria) ?? ""
        whyThisIsLongRunning = try container.decodeIfPresent(String.self, forKey: .whyThisIsLongRunning) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        sourceRefs = try container.decodeIfPresent([ProjectSourceRefDTO].self, forKey: .sourceRefs) ?? []
        sourceIds = try container.decodeIfPresent([String].self, forKey: .sourceIds) ?? []
        privacySafeNameRequired = try container.decodeIfPresent(Bool.self, forKey: .privacySafeNameRequired) ?? false
        confidence = try container.decodeIfPresent(FlexibleString.self, forKey: .confidence) ?? FlexibleString("")
    }

    var domainCandidate: ProjectCandidate? {
        let suggestedName = candidateProjectName.trimmed.ifEmpty(name.trimmed)
        let sourceRefs = (sourceRefs.compactMap(\.validSourceId) + sourceIds)
            .map(\.trimmed)
            .filter { !$0.isEmpty }
        let reason = whyThisIsLongRunning.trimmed.ifEmpty(reason.trimmed)

        guard !suggestedName.isEmpty, !sourceRefs.isEmpty, !reason.isEmpty else { return nil }

        return ProjectCandidate(
            suggestedName: suggestedName,
            suggestedGoal: goal.trimmed.ifEmpty(nil),
            suggestedBottleneck: currentBottleneck.trimmed.ifEmpty(nil),
            suggestedSuccessCriteria: successCriteria.trimmed.ifEmpty(nil),
            reason: reason,
            sourceRefs: Array(Set(sourceRefs)).sorted(),
            privacyReviewNote: privacySafeNameRequired ? "需要用户确认抽象命名，避免泄露敏感名称。" : nil,
            confidence: ConfidenceMapper.score(from: confidence.value)
        )
    }
}

private struct ProjectInsightsResponseDTO: Decodable {
    let projectInsights: [ProjectInsightDTO]
    let insufficientEvidenceReason: String

    private enum CodingKeys: String, CodingKey {
        case projectInsights
        case insights
        case insufficientEvidenceReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectInsights = try container.decodeIfPresent([ProjectInsightDTO].self, forKey: .projectInsights)
            ?? container.decodeIfPresent([ProjectInsightDTO].self, forKey: .insights)
            ?? []
        insufficientEvidenceReason = try container.decodeIfPresent(String.self, forKey: .insufficientEvidenceReason) ?? ""
    }
}

private struct ProjectInsightDTO: Decodable {
    let projectId: String
    let insightType: String
    let title: String
    let summary: String
    let before: ProjectEvidenceTextDTO?
    let after: ProjectEvidenceTextDTO?
    let sourceRefs: [String]
    let confidence: FlexibleString

    private enum CodingKeys: String, CodingKey {
        case projectId
        case insightType
        case title
        case summary
        case before
        case after
        case sourceRefs
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try container.decodeIfPresent(String.self, forKey: .projectId) ?? ""
        insightType = try container.decodeIfPresent(String.self, forKey: .insightType) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        before = try container.decodeIfPresent(ProjectEvidenceTextDTO.self, forKey: .before)
        after = try container.decodeIfPresent(ProjectEvidenceTextDTO.self, forKey: .after)
        sourceRefs = try container.decodeIfPresent([String].self, forKey: .sourceRefs) ?? []
        confidence = try container.decodeIfPresent(FlexibleString.self, forKey: .confidence) ?? FlexibleString("")
    }

    var domainInsight: ProjectInsight? {
        guard
            let projectId = UUID(uuidString: projectId.trimmed),
            let insightType = ProjectInsightType(aiRawValue: insightType)
        else {
            return nil
        }

        let title = title.trimmed
        let summary = summary.trimmed
        var refs = sourceRefs.map(\.trimmed).filter { !$0.isEmpty }
        let beforeEvidence = before?.validEvidence
        let afterEvidence = after?.validEvidence

        if insightType.requiresBeforeAfterEvidence {
            guard let beforeEvidence, let afterEvidence else { return nil }
            refs.append(beforeEvidence.sourceId)
            refs.append(afterEvidence.sourceId)
        } else if refs.isEmpty {
            return nil
        }

        guard !title.isEmpty, !summary.isEmpty, !refs.isEmpty else { return nil }

        return ProjectInsight(
            projectId: projectId,
            insightType: insightType,
            title: title,
            summary: summary,
            beforeText: beforeEvidence?.text,
            afterText: afterEvidence?.text,
            sourceRefs: Array(Set(refs)).sorted(),
            confidence: ConfidenceMapper.score(from: confidence.value)
        )
    }
}

private struct ProjectEvidenceTextDTO: Decodable {
    let text: String
    let sourceType: String
    let sourceId: String

    private enum CodingKeys: String, CodingKey {
        case text
        case sourceType
        case sourceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? ""
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId) ?? ""
    }

    var validEvidence: (text: String, sourceId: String)? {
        guard ProjectSourceType(aiRawValue: sourceType) != nil else { return nil }
        let text = text.trimmed
        let sourceId = sourceId.trimmed
        guard !text.isEmpty, !sourceId.isEmpty else { return nil }
        return (text, sourceId)
    }
}

private struct ProjectMergeCandidatesResponseDTO: Decodable {
    let mergeCandidates: [ProjectMergeCandidateDTO]

    private enum CodingKeys: String, CodingKey {
        case mergeCandidates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mergeCandidates = try container.decodeIfPresent([ProjectMergeCandidateDTO].self, forKey: .mergeCandidates) ?? []
    }
}

private struct ProjectMergeCandidateDTO: Decodable {
    let sourceProjectId: String
    let targetProjectId: String
    let reason: String
    let overlappingEvidenceRefs: [String]

    private enum CodingKeys: String, CodingKey {
        case sourceProjectId
        case targetProjectId
        case reason
        case overlappingEvidenceRefs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceProjectId = try container.decodeIfPresent(String.self, forKey: .sourceProjectId) ?? ""
        targetProjectId = try container.decodeIfPresent(String.self, forKey: .targetProjectId) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        overlappingEvidenceRefs = try container.decodeIfPresent([String].self, forKey: .overlappingEvidenceRefs) ?? []
    }

    var domainCandidate: ProjectMergeCandidate? {
        let refs = overlappingEvidenceRefs.map(\.trimmed).filter { !$0.isEmpty }
        guard
            let sourceProjectId = UUID(uuidString: sourceProjectId.trimmed),
            let targetProjectId = UUID(uuidString: targetProjectId.trimmed),
            sourceProjectId != targetProjectId,
            !reason.trimmed.isEmpty,
            !refs.isEmpty
        else {
            return nil
        }

        return ProjectMergeCandidate(
            sourceProjectId: sourceProjectId,
            targetProjectId: targetProjectId,
            reason: reason.trimmed,
            overlappingEvidenceRefs: Array(Set(refs)).sorted()
        )
    }
}

private struct ProjectSourceRefDTO: Decodable {
    let sourceType: String
    let sourceId: String

    private enum CodingKeys: String, CodingKey {
        case sourceType
        case sourceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType) ?? ""
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId) ?? ""
    }

    var validSourceId: String? {
        guard ProjectSourceType(aiRawValue: sourceType) != nil else { return nil }
        return sourceId.trimmed.ifEmpty(nil)
    }
}

private struct PrincipleDTO: Decodable {
    let title: String
    let summary: String
    let triggerContext: String
    let actions: [String]
    let successCriteria: String
    let exceptions: String
    let sourceCardTitles: [String]

    private enum CodingKeys: String, CodingKey {
        case title
        case summary
        case triggerContext
        case actions
        case successCriteria
        case exceptions
        case sourceCardTitles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        triggerContext = try container.decodeIfPresent(String.self, forKey: .triggerContext) ?? ""
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        successCriteria = try container.decodeIfPresent(String.self, forKey: .successCriteria) ?? ""
        exceptions = try container.decodeIfPresent(String.self, forKey: .exceptions) ?? ""
        sourceCardTitles = try container.decodeIfPresent([String].self, forKey: .sourceCardTitles) ?? []
    }

    var domainPrinciple: PrincipleAsset? {
        let cleanActions = actions.map(\.trimmed).filter { !$0.isEmpty }
        guard !title.trimmed.isEmpty, !summary.trimmed.isEmpty, !cleanActions.isEmpty else { return nil }

        return PrincipleAsset(
            title: title.trimmed,
            summary: summary.trimmed,
            triggerContext: triggerContext.trimmed.ifEmpty("适用于类似的复盘场景。"),
            actions: cleanActions,
            successCriteria: successCriteria.trimmed.ifEmpty("行动结果可被检查。"),
            exceptions: exceptions.trimmed.ifEmpty("低风险场景可简化。"),
            sourceCardTitles: TodayAIResponseParser.normalizedTitles(sourceCardTitles)
        )
    }
}

private struct FlexibleString: Decodable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            value = ""
        }
    }
}

private enum ConfidenceMapper {
    static func score(from rawValue: String) -> Double {
        switch rawValue.lowercased().trimmed {
        case "high":
            return 0.86
        case "medium":
            return 0.72
        case "low":
            return 0.48
        default:
            if let number = Double(rawValue) {
                if number > 1 {
                    return min(max(number / 100, 0), 1)
                }
                return min(max(number, 0), 1)
            }
            return 0.64
        }
    }
}

private extension ThinkingCardType {
    init(aiRawValue: String) {
        self = ThinkingCardType(rawValue: aiRawValue.normalizedAIRawValue) ?? .idea
    }
}

private extension PriorityLevel {
    init(aiRawValue: String) {
        self = PriorityLevel(rawValue: aiRawValue.normalizedAIRawValue) ?? .medium
    }
}

private extension SensitivityLevel {
    init(aiRawValue: String) {
        switch aiRawValue.normalizedAIRawValue {
        case "sensitive":
            self = .sensitive
        case "possibly_sensitive", "possiblysensitive":
            self = .possiblySensitive
        default:
            self = .normal
        }
    }
}

private extension GrowthMetric {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension MetricContributionDirection {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension MetricContributionSourceType {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension ProjectSourceType {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension ProjectLinkType {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension ProjectInsightType {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }

    var requiresBeforeAfterEvidence: Bool {
        switch self {
        case .thinkingChange, .blockerChange:
            return true
        case .progress, .openQuestionClosed, .principlePracticed, .nextBet:
            return false
        }
    }
}

private extension QuestType {
    init?(aiRawValue: String) {
        self.init(rawValue: aiRawValue.normalizedAIRawValue)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedAIRawValue: String {
        trimmed
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    func ifEmpty(_ fallback: String?) -> String? {
        isEmpty ? fallback : self
    }
}
