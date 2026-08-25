import Foundation

struct GrowthReportContext: Hashable {
    var period: String
    var startDate: Date?
    var endDate: Date?
    var completeLoopCount: Int
    var historyRecords: [GrowthRecordSummary]
    var previousSnapshot: MetricSnapshot?
    var dismissedContributionTitles: [String]
}

struct GrowthRecordSummary: Hashable {
    var dailyEntryId: UUID
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

struct GrowthAIService {
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

    func generateWeeklyReport(context: GrowthReportContext) async throws -> GrowthReportResult {
        guard context.completeLoopCount >= 3 else {
            return insufficientResult(period: context.period, completeLoopCount: context.completeLoopCount)
        }

        let promptID: PromptID = .weeklyCalibration
        let template = promptProvider.template(for: promptID, mode: .standard)
        let contextPayload = buildContextPayload(from: context)

        let sourceRecordIDs = Array(Set(context.historyRecords.map { $0.dailyEntryId.uuidString })).sorted()
        let request = LLMRequest(
            prompt: template,
            inputSummary: "period=\(context.period); loops=\(context.completeLoopCount); records=\(context.historyRecords.count)",
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: sourceRecordIDs
        )

        let data = try await llmClient.complete(request)
        return try parser.parseGrowthReport(
            from: data,
            period: context.period,
            completeLoopCount: context.completeLoopCount
        )
    }

    func generateMonthlyReport(context: GrowthReportContext) async throws -> GrowthReportResult {
        guard context.completeLoopCount >= 3 else {
            return insufficientResult(period: context.period, completeLoopCount: context.completeLoopCount)
        }

        let promptID: PromptID = .monthlyGrowth
        let template = promptProvider.template(for: promptID, mode: .standard)
        let contextPayload = buildContextPayload(from: context)

        let sourceRecordIDs = Array(Set(context.historyRecords.map { $0.dailyEntryId.uuidString })).sorted()
        let request = LLMRequest(
            prompt: template,
            inputSummary: "period=\(context.period); loops=\(context.completeLoopCount); records=\(context.historyRecords.count)",
            contextPayload: contextPayload,
            sourceRecordIDs: sourceRecordIDs,
            contextVersion: 1,
            contextRecordIDs: sourceRecordIDs
        )

        let data = try await llmClient.complete(request)
        return try parser.parseGrowthReport(
            from: data,
            period: context.period,
            completeLoopCount: context.completeLoopCount
        )
    }

    func generateWeeklyGuidanceReview(
        verifications: [Verification],
        catalog: [GuidanceCatalogItem] = BuiltinGuidanceCatalog.items,
        now: Date = .now
    ) async throws -> WeeklyGuidanceReviewSelection? {
        let policy = WeeklyGuidanceReviewPolicy()
        guard policy.isEligible(verifications: verifications, now: now) else { return nil }
        let recent = verifications.filter { $0.createdAt >= Calendar.current.date(byAdding: .day, value: -7, to: now)! }
        let refs = Set(recent.map { $0.id.uuidString })
        let base = promptProvider.template(for: .weeklyCalibration, mode: .standard)
        let template = PromptTemplate(
            id: base.id, version: base.version,
            systemPolicyVersion: base.systemPolicyVersion, contextPolicyVersion: base.contextPolicyVersion,
            evalSuiteVersion: base.evalSuiteVersion, rollbackTargetVersion: base.rollbackTargetVersion,
            systemText: base.systemText,
            userText: """
            Review only the supplied verification evidence. Return JSON only:
            {"training_focus":"one concrete next-week focus","hint_ids":["existing hint id"],"evidence_refs":["verification id"]}
            You may select only from these existing hint IDs: \(catalog.map(\.hintId).joined(separator: ", ")).
            Do not create UI copy, scores, metric contributions, personality claims, or new hint IDs.
            """,
            outputSchemaVersion: 1
        )
        let payload = PromptContextPayload(
            currentInput: .init(dailyEntryId: nil, rawText: recent.map { "\($0.id.uuidString): \($0.evidenceText) \($0.calibrationNote)" }.joined(separator: "\n")),
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            privacy: .init(rules: "Use only supplied verification evidence."),
            growth: .init(
                period: "weekly_guidance",
                completeLoopCount: recent.count,
                records: [],
                dismissedContributionTitles: []
            )
        )
        let data = try await llmClient.complete(LLMRequest(
            prompt: template, inputSummary: "verification_count=\(recent.count)", contextPayload: payload,
            sourceRecordIDs: refs.sorted(), contextVersion: 1, contextRecordIDs: refs.sorted()
        ))
        let selection = try Self.parseWeeklyGuidanceSelection(data)
        guard policy.validate(selection, catalog: catalog, allowedEvidenceRefs: refs) else {
            throw TodayAIParsingError.qualityGateFailed(["周复盘必须只选择已有提示和真实验证证据。"])
        }
        return selection
    }

    private static func parseWeeklyGuidanceSelection(_ data: Data) throws -> WeeklyGuidanceReviewSelection {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = String(decoding: data, as: UTF8.self)
        let text: String
        if let envelope = try? decoder.decode(WeeklyEnvelope.self, from: data), let content = envelope.choices.first?.message?.content {
            text = content
        } else { text = raw }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { throw TodayAIParsingError.invalidJSON }
        let dto = try decoder.decode(WeeklyGuidanceReviewSelection.self, from: Data(text[start...end].utf8))
        return dto
    }

    private struct WeeklyEnvelope: Decodable {
        struct Choice: Decodable { struct Message: Decodable { var content: String? }; var message: Message? }
        var choices: [Choice]
    }

    private func insufficientResult(period: String, completeLoopCount: Int) -> GrowthReportResult {
        let snapshot = MetricSnapshot(
            period: period,
            clarity: 3.0,
            valueJudgment: 3.0,
            executionReliability: 3.0,
            calibration: 3.0,
            reflectionDepth: 3.0,
            summary: "完成 \(completeLoopCount) 次完整复盘，需要至少 3 次才能生成可解释的成长趋势。",
            status: .insufficientEvidence,
            completeLoopCount: completeLoopCount,
            nextTrainingFocus: "先稳定完成输入、卡片确认、明日验证和次日结果校准。"
        )
        return GrowthReportResult(snapshot: snapshot, contributions: [])
    }

    private func buildContextPayload(from context: GrowthReportContext) -> PromptContextPayload {
        PromptContextPayload(
            userChoice: .init(sessionMode: SessionMode.standard.rawValue),
            privacy: .init(
                rules: "Use only user-confirmed local evidence. Do not infer personality traits or expose sensitive company details."
            ),
            growth: .init(
                period: context.period,
                startDate: context.startDate,
                endDate: context.endDate,
                completeLoopCount: context.completeLoopCount,
                records: context.historyRecords.map { record in
                    PromptContextPayload.GrowthRecordContext(
                        dailyEntryId: record.dailyEntryId.uuidString,
                        date: record.date,
                        confirmedCardCount: record.confirmedCardCount,
                        hasMainQuest: record.hasMainQuest,
                        mainQuestTitle: record.mainQuestTitle,
                        mainQuestCompletionCriteria: record.mainQuestCompletionCriteria,
                        verificationCompletion: record.verificationCompletion,
                        verificationValueRating: record.verificationValueRating,
                        calibrationNote: record.calibrationNote,
                        hasLensSessionAnswers: record.hasLensSessionAnswers,
                        principleTitles: record.principleTitles
                    )
                },
                previousSnapshot: context.previousSnapshot?.canDisplayScores == true ? context.previousSnapshot.map { snapshot in
                    PromptContextPayload.GrowthSnapshotContext(
                        clarity: snapshot.clarity,
                        valueJudgment: snapshot.valueJudgment,
                        executionReliability: snapshot.executionReliability,
                        calibration: snapshot.calibration,
                        reflectionDepth: snapshot.reflectionDepth
                    )
                } : nil,
                dismissedContributionTitles: context.dismissedContributionTitles
            )
        )
    }
}
