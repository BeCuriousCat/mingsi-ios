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
        let payload = buildPayload(from: context)

        let request = LLMRequest(
            prompt: template,
            inputSummary: "period=\(context.period); loops=\(context.completeLoopCount); records=\(context.historyRecords.count)",
            jsonPayload: payload,
            contextPayload: buildContextPayload(from: context, legacyPayload: payload),
            sourceRecordIDs: context.historyRecords.map { $0.dailyEntryId.uuidString },
            contextVersion: 1,
            contextRecordIDs: context.historyRecords.map { $0.dailyEntryId.uuidString }
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
        let payload = buildPayload(from: context)

        let request = LLMRequest(
            prompt: template,
            inputSummary: "period=\(context.period); loops=\(context.completeLoopCount); records=\(context.historyRecords.count)",
            jsonPayload: payload,
            contextPayload: buildContextPayload(from: context, legacyPayload: payload),
            sourceRecordIDs: context.historyRecords.map { $0.dailyEntryId.uuidString },
            contextVersion: 1,
            contextRecordIDs: context.historyRecords.map { $0.dailyEntryId.uuidString }
        )

        let data = try await llmClient.complete(request)
        return try parser.parseGrowthReport(
            from: data,
            period: context.period,
            completeLoopCount: context.completeLoopCount
        )
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
            nextTrainingFocus: "先稳定完成输入、卡片确认、明日任务和次日验证。"
        )
        return GrowthReportResult(snapshot: snapshot, contributions: [])
    }

    private func buildPayload(from context: GrowthReportContext) -> [String: String] {
        var payload: [String: String] = [:]
        payload["period"] = context.period
        payload["complete_loop_count"] = String(context.completeLoopCount)
        payload["record_count"] = String(context.historyRecords.count)

        let summaries = context.historyRecords.map { record -> String in
            var parts = ["entry=\(record.dailyEntryId.uuidString)"]
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
        payload["evidence_summaries"] = summaries.joined(separator: "\n")

        if let previous = context.previousSnapshot, previous.canDisplayScores {
            payload["previous_clarity"] = String(format: "%.1f", previous.clarity)
            payload["previous_value_judgment"] = String(format: "%.1f", previous.valueJudgment)
            payload["previous_execution_reliability"] = String(format: "%.1f", previous.executionReliability)
            payload["previous_calibration"] = String(format: "%.1f", previous.calibration)
            payload["previous_reflection_depth"] = String(format: "%.1f", previous.reflectionDepth)
        }

        if !context.dismissedContributionTitles.isEmpty {
            payload["dismissed_contributions"] = context.dismissedContributionTitles.joined(separator: "; ")
        }

        return payload
    }

    private func buildContextPayload(
        from context: GrowthReportContext,
        legacyPayload: [String: String]
    ) -> PromptContextPayload {
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
                previousSnapshot: context.previousSnapshot.map { snapshot in
                    PromptContextPayload.GrowthSnapshotContext(
                        clarity: snapshot.clarity,
                        valueJudgment: snapshot.valueJudgment,
                        executionReliability: snapshot.executionReliability,
                        calibration: snapshot.calibration,
                        reflectionDepth: snapshot.reflectionDepth
                    )
                },
                dismissedContributionTitles: context.dismissedContributionTitles
            ),
            extra: legacyPayload
        )
    }
}
