import XCTest
@testable import MingSi

final class PromptEvalFixtureTests: XCTestCase {
    private var parser: TodayAIResponseParser!

    override func setUp() {
        super.setUp()
        parser = TodayAIResponseParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testOrganizeCards_messyDailyInputProducesTypedSensitiveCards() throws {
        let data = fixtureData(
            """
            {
              "cards": [
                {
                  "type": "communication",
                  "title": "会前没有明确要确认的决策",
                  "body": "会议推进时先讨论细节，最后才发现负责人和验收标准没有写清。",
                  "importance": "high",
                  "sensitivity": "normal",
                  "confidence": "high",
                  "reason": "这是可复用的沟通流程问题。"
                },
                {
                  "type": "risk",
                  "title": "内部项目名需要抽象化",
                  "body": "用户提到具体内部项目和客户语境，后续模型调用应避免重复细节。",
                  "importance": "medium",
                  "sensitivity": "possibly_sensitive",
                  "confidence": "medium",
                  "reason": "符合隐私边界要求。"
                },
                {
                  "type": "task",
                  "title": "下次会议前写出决策清单",
                  "body": "列出本次会议要确认的事项、负责人和完成标准。",
                  "importance": "high",
                  "sensitivity": "normal",
                  "confidence": "high",
                  "reason": "可转化为明日任务。"
                }
              ]
            }
            """
        )

        let cards = try parser.parseCards(from: data)

        XCTAssertEqual(cards.map(\.type), [.communication, .risk, .task])
        XCTAssertTrue(cards.contains { $0.sensitivity == .possiblySensitive })
        XCTAssertTrue(cards.allSatisfy { !$0.title.isEmpty && !$0.body.isEmpty })
    }

    func testQuestionsEval_requiresConcreteLensSpecificQuestions() throws {
        let data = fixtureData(
            """
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
        )

        let questions = try parser.parseQuestions(from: data)

        XCTAssertEqual(questions.count, 3)
        XCTAssertTrue(questions.contains { $0.question.contains("事实") && $0.question.contains("判断") })
        XCTAssertTrue(questions.contains { $0.question.contains("最可能") && $0.question.contains("推翻") })
        XCTAssertTrue(questions.contains { $0.question.contains("明天") || $0.question.contains("一件事") })
    }

    func testQuestsEval_requiresSingleMainQuestWithVerifiableCriteria() throws {
        let data = fixtureData(
            """
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
        )

        let quests = try parser.parseQuests(from: data)

        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests[0].type, .main)
        XCTAssertTrue(quests[0].completionCriteria.contains("包含"))
        XCTAssertTrue(quests[0].completionCriteria.contains("负责人"))
        XCTAssertTrue(quests[0].completionCriteria.count > quests[0].title.count)
    }

    func testPrincipleEval_acceptsBehaviorRuleAndRejectsSlogan() throws {
        let valid = fixtureData(
            """
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
        )
        let slogan = fixtureData(
            """
            {
              "principle_candidate": {
                "title": "要更主动",
                "summary": "主动一点就会更好。",
                "trigger_context": "",
                "actions": [],
                "success_criteria": "",
                "exceptions": ""
              }
            }
            """
        )

        let principles = try parser.parsePrinciples(from: valid)
        let rejected = try parser.parsePrinciples(from: slogan)

        XCTAssertEqual(principles.count, 1)
        XCTAssertEqual(principles[0].actions.count, 4)
        XCTAssertTrue(principles[0].successCriteria.contains("负责人"))
        XCTAssertTrue(rejected.isEmpty)
    }

    func testGrowthContributionEval_requiresEvidenceRefsAndClampsDelta() throws {
        let sourceDailyEntryId = UUID()
        let snapshotId = UUID()
        let data = fixtureData(
            """
            {
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.45,
                  "title": "会议目标更清晰",
                  "reason": "用户在任务中明确要求会前写出决策、负责人和验收标准。",
                  "source_type": "quest",
                  "source_id": "quest-001",
                  "source_daily_entry_id": "\(sourceDailyEntryId.uuidString)"
                },
                {
                  "metric": "reflection_depth",
                  "direction": "negative",
                  "delta": 0.08,
                  "title": "缺少反方验证",
                  "reason": "复盘没有记录什么证据会推翻当前判断。",
                  "source_type": "thinking_card",
                  "source_id": "card-002",
                  "source_daily_entry_id": "\(sourceDailyEntryId.uuidString)"
                }
              ]
            }
            """
        )

        let contributions = try parser.parseMetricContributions(from: data, snapshotId: snapshotId)

        XCTAssertEqual(contributions.count, 2)
        XCTAssertEqual(contributions[0].snapshotId, snapshotId)
        XCTAssertEqual(contributions[0].metric, .clarity)
        XCTAssertEqual(contributions[0].direction, .positive)
        XCTAssertEqual(contributions[0].delta, 0.30, accuracy: 0.001)
        XCTAssertEqual(contributions[0].sourceDailyEntryId, sourceDailyEntryId)
        XCTAssertEqual(contributions[1].direction, .negative)
    }

    func testGrowthContributionEval_rejectsItemsWithoutSourceEvidence() {
        let snapshotId = UUID()
        let data = fixtureData(
            """
            {
              "metric_contributions": [
                {
                  "metric": "clarity",
                  "direction": "positive",
                  "delta": 0.10,
                  "title": "更清晰",
                  "reason": "看起来更清楚。",
                  "source_type": "quest",
                  "source_id": "",
                  "source_daily_entry_id": ""
                }
              ]
            }
            """
        )

        XCTAssertThrowsError(try parser.parseMetricContributions(from: data, snapshotId: snapshotId)) { error in
            XCTAssertEqual(error as? TodayAIParsingError, .emptyResult)
        }
    }

    func testPromptEvalRunner_recordsSuiteMetadataAndCaseResults() throws {
        let provider = LocalPromptProvider()
        let runner = PromptEvalRunner(promptProvider: provider, parser: parser)

        let runs = runner.runFixedSuite()

        XCTAssertFalse(runs.isEmpty)
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.organizeCards.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.generateQuestions.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.generateQuests.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.extractPrinciple.rawValue })
        XCTAssertTrue(runs.contains { $0.promptId == PromptID.weeklyCalibration.rawValue })
        XCTAssertTrue(runs.allSatisfy { !$0.promptVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.systemPolicyVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.contextPolicyVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.evalSuiteVersion.isEmpty })
        XCTAssertTrue(runs.allSatisfy { !$0.caseResults.isEmpty })
        XCTAssertTrue(runs.allSatisfy { $0.status == .passed })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.inputSummary.isEmpty })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.expectedBehavior.isEmpty })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.actualObservation.isEmpty })
        XCTAssertTrue(runs.flatMap(\.caseResults).allSatisfy { !$0.diagnosticReason.isEmpty })

        let questionsRun = runs.first { $0.promptId == PromptID.generateQuestions.rawValue }
        XCTAssertEqual(questionsRun?.evalSuiteVersion, provider.template(for: .generateQuestions, mode: .standard).evalSuiteVersion)
        XCTAssertTrue(questionsRun?.caseResults.contains { $0.caseId == "questions.concrete_lens_specific" } ?? false)
        let questionsCase = try XCTUnwrap(questionsRun?.caseResults.first { $0.caseId == "questions.concrete_lens_specific" })
        XCTAssertTrue(questionsCase.inputSummary.contains("meeting"))
        XCTAssertTrue(questionsCase.expectedBehavior.contains("lens-specific"))
        XCTAssertTrue(questionsCase.actualObservation.contains("passed"))
        XCTAssertTrue(questionsCase.diagnosticReason.contains("fixed-suite"))
    }

    func testPromptEvalReleaseGate_blocksMissingStaleAndFailedRuns() throws {
        let provider = LocalPromptProvider()
        let runner = PromptEvalRunner(promptProvider: provider, parser: parser)
        let passingRuns = runner.runFixedSuite(createdAt: Date(timeIntervalSince1970: 200))

        let passingGate = PromptEvalReleaseGate.evaluate(
            runs: passingRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(passingGate.status, .passed)
        XCTAssertTrue(passingGate.canShipPromptAssets)
        XCTAssertEqual(passingGate.totalPromptCount, PromptID.allCases.count)
        XCTAssertEqual(passingGate.passedPromptCount, PromptID.allCases.count)
        XCTAssertEqual(passingGate.failedPromptCount, 0)
        XCTAssertEqual(passingGate.missingPromptCount, 0)
        XCTAssertEqual(passingGate.stalePromptCount, 0)
        XCTAssertEqual(passingGate.runnerMismatchCount, 0)
        XCTAssertTrue(passingGate.blockingIssues.isEmpty)

        let missingRun = passingRuns.filter { $0.promptId != PromptID.generateQuestions.rawValue }
        let missingGate = PromptEvalReleaseGate.evaluate(
            runs: missingRun,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(missingGate.status, .blocked)
        XCTAssertFalse(missingGate.canShipPromptAssets)
        XCTAssertEqual(missingGate.missingPromptCount, 1)
        XCTAssertTrue(missingGate.blockingIssues.contains { $0.promptId == PromptID.generateQuestions.rawValue && $0.reason == .missingRun })

        var staleRuns = passingRuns
        let staleIndex = try XCTUnwrap(staleRuns.firstIndex { $0.promptId == PromptID.generateQuests.rawValue })
        staleRuns[staleIndex].promptVersion = "quests.old"
        let staleGate = PromptEvalReleaseGate.evaluate(
            runs: staleRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(staleGate.status, .blocked)
        XCTAssertEqual(staleGate.stalePromptCount, 1)
        XCTAssertTrue(staleGate.blockingIssues.contains { $0.promptId == PromptID.generateQuests.rawValue && $0.reason == .staleVersion })

        var failedRuns = passingRuns
        let failedIndex = try XCTUnwrap(failedRuns.firstIndex { $0.promptId == PromptID.extractPrinciple.rawValue })
        failedRuns[failedIndex].caseResults = [
            PromptEvalCaseResult(
                caseId: "principle.behavior_rule_not_slogan",
                name: "Principle is a behavior rule rather than a slogan",
                status: .failed,
                failureReason: "Expected concrete actions."
            )
        ]
        let failedGate = PromptEvalReleaseGate.evaluate(
            runs: failedRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(failedGate.status, .blocked)
        XCTAssertEqual(failedGate.failedPromptCount, 1)
        XCTAssertTrue(failedGate.blockingIssues.contains { $0.promptId == PromptID.extractPrinciple.rawValue && $0.reason == .failedCases })

        var runnerMismatchRuns = passingRuns
        let mismatchIndex = try XCTUnwrap(runnerMismatchRuns.firstIndex { $0.promptId == PromptID.weeklyCalibration.rawValue })
        runnerMismatchRuns[mismatchIndex].runnerVersion = "prompt-eval-runner.old"
        let runnerMismatchGate = PromptEvalReleaseGate.evaluate(
            runs: runnerMismatchRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )
        XCTAssertEqual(runnerMismatchGate.status, .blocked)
        XCTAssertEqual(runnerMismatchGate.runnerMismatchCount, 1)
        XCTAssertTrue(runnerMismatchGate.blockingIssues.contains { $0.promptId == PromptID.weeklyCalibration.rawValue && $0.reason == .runnerMismatch })
    }

    func testPromptEvalReleaseGate_findsRollbackCandidatesFromPassingHistory() throws {
        let provider = RollbackFixturePromptProvider()
        let template = provider.template(for: .generateQuestions, mode: .standard)
        let currentFailedRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: template.version,
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(
                    caseId: "questions.current_failure",
                    name: "Current prompt version failed",
                    status: .failed,
                    failureReason: "Regression in current questions prompt."
                )
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let rollbackPassingRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "0.9.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(
                    caseId: "questions.previous_pass",
                    name: "Previous prompt version passed",
                    status: .passed
                )
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let gate = PromptEvalReleaseGate.evaluate(
            runs: [currentFailedRun, rollbackPassingRun],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )

        XCTAssertEqual(gate.status, .blocked)
        XCTAssertEqual(gate.failedPromptCount, 1)
        XCTAssertEqual(gate.rollbackReadyCount, 1)
        XCTAssertEqual(gate.manualReviewCount, PromptID.allCases.count - 1)
        let candidate = try XCTUnwrap(gate.rollbackCandidates.first)
        XCTAssertEqual(candidate.promptId, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(candidate.currentVersion, "1.0.0")
        XCTAssertEqual(candidate.rollbackTargetVersion, "0.9.0")
        XCTAssertEqual(candidate.lastPassingRunId, rollbackPassingRun.id)
        XCTAssertEqual(candidate.reason, .failedCases)
        XCTAssertTrue(gate.blockingIssues.contains {
            $0.promptId == PromptID.generateQuestions.rawValue &&
            $0.reason == .failedCases &&
                $0.rollbackCandidate?.rollbackTargetVersion == "0.9.0"
        })
    }

    func testPromptAssetQualityGate_flagsHighOperationalFailureSignalsAfterMinimumSample() throws {
        let runs = [
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 100)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "upstream failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 101)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "empty result",
                error: "TodayAIParsingError.emptyResult",
                createdAt: Date(timeIntervalSince1970: 102)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: "1.0.0",
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "denied result",
                responseJSON: "{}",
                userFeedback: .denied,
                createdAt: Date(timeIntervalSince1970: 103)
            )
        ]
        let summaries = PromptAssetRunQualitySummary.summaries(for: runs)

        let gate = PromptAssetQualityGate.evaluate(
            summaries: summaries,
            policy: PromptAssetQualityGatePolicy(
                minimumSampleCount: 4,
                failureRateThreshold: 0.5,
                emptyResultRateThreshold: 0.25,
                userDenialRateThreshold: 0.25
            )
        )

        XCTAssertEqual(gate.status, .needsReview)
        XCTAssertEqual(gate.needsReviewAssetCount, 1)
        XCTAssertEqual(gate.issueCount, 3)
        XCTAssertEqual(Set(gate.issues.map(\.reason)), [
            .highFailureRate,
            .highEmptyResultRate,
            .highUserDenialRate
        ])
        XCTAssertTrue(gate.issues.allSatisfy {
            $0.promptId == PromptID.generateQuestions.rawValue &&
                $0.promptVersion == "1.0.0" &&
                $0.sampleCount == 4
        })

        let underSampledGate = PromptAssetQualityGate.evaluate(
            summaries: summaries,
            policy: PromptAssetQualityGatePolicy(minimumSampleCount: 5)
        )
        XCTAssertEqual(underSampledGate.status, .passed)
        XCTAssertTrue(underSampledGate.issues.isEmpty)
    }

    func testPromptAssetQualityGate_marksImportedPackRollbackReadyFromPassingEvalHistory() throws {
        let provider = ImportedPromptPackRollbackFixtureProvider()
        let currentTemplate = provider.template(for: .generateQuestions, mode: .standard)
        let currentRuns = [
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 100)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "second success",
                responseJSON: "{}",
                createdAt: Date(timeIntervalSince1970: 101)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "upstream failure",
                error: "HTTP 500",
                createdAt: Date(timeIntervalSince1970: 102)
            ),
            PromptRun(
                promptId: PromptID.generateQuestions.rawValue,
                promptVersion: currentTemplate.version,
                promptSourceKind: currentTemplate.sourceKind,
                promptPackId: currentTemplate.packId,
                promptPackVersion: currentTemplate.packVersion,
                promptPackDisplayName: currentTemplate.packDisplayName,
                systemPolicyVersion: currentTemplate.systemPolicyVersion,
                contextPolicyVersion: currentTemplate.contextPolicyVersion,
                outputSchemaVersion: currentTemplate.outputSchemaVersion,
                evalSuiteVersion: currentTemplate.evalSuiteVersion,
                rollbackTargetVersion: currentTemplate.rollbackTargetVersion,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                requestSummary: "second upstream failure",
                error: "HTTP 502",
                createdAt: Date(timeIntervalSince1970: 103)
            )
        ]
        let summaries = PromptAssetRunQualitySummary.summaries(for: currentRuns)
        let rollbackTemplate = try XCTUnwrap(provider.template(for: .generateQuestions, mode: .standard, version: "1.0.0"))
        let passingRollbackRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: rollbackTemplate.version,
            promptSourceKind: rollbackTemplate.sourceKind,
            promptPackId: rollbackTemplate.packId,
            promptPackVersion: rollbackTemplate.packVersion,
            promptPackDisplayName: rollbackTemplate.packDisplayName,
            systemPolicyVersion: currentTemplate.systemPolicyVersion,
            contextPolicyVersion: currentTemplate.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: currentTemplate.outputSchemaVersion,
            evalSuiteVersion: currentTemplate.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "imported.questions.pass", name: "Imported previous prompt passed", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 90)
        )

        let gate = PromptAssetQualityGate.evaluate(
            summaries: summaries,
            policy: PromptAssetQualityGatePolicy(
                minimumSampleCount: 4,
                failureRateThreshold: 0.5,
                emptyResultRateThreshold: 0.25,
                userDenialRateThreshold: 0.25
            ),
            evalRuns: [passingRollbackRun],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )

        XCTAssertEqual(gate.status, .needsReview)
        XCTAssertEqual(gate.needsReviewAssetCount, 1)
        XCTAssertEqual(gate.rollbackReadyAssetCount, 1)
        XCTAssertEqual(gate.manualReviewAssetCount, 0)
        let issue = try XCTUnwrap(gate.issues.first)
        XCTAssertEqual(issue.reason, .highFailureRate)
        let candidate = try XCTUnwrap(issue.rollbackCandidate)
        XCTAssertEqual(candidate.promptId, PromptID.generateQuestions.rawValue)
        XCTAssertEqual(candidate.currentVersion, "1.1.0")
        XCTAssertEqual(candidate.rollbackTargetVersion, "1.0.0")
        XCTAssertEqual(candidate.promptPackId, "marketplace.prompts.coach")
        XCTAssertEqual(candidate.currentPromptPackVersion, "2026.06")
        XCTAssertEqual(candidate.rollbackPromptPackVersion, "2026.05")
        XCTAssertEqual(candidate.lastPassingRunId, passingRollbackRun.id)
    }

    func testPromptEvalReleaseGate_passesAfterPromptAssetRollbackUsesTargetVersionHistory() throws {
        let provider = AppliedRollbackFixturePromptProvider()
        let template = provider.template(for: .generateQuestions, mode: .standard)
        XCTAssertEqual(template.version, "0.9.0")

        let priorPassingRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "0.9.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.previous_pass", name: "Previous pass", status: .passed)
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let supersededFailedRun = PromptEvalRun(
            promptId: PromptID.generateQuestions.rawValue,
            promptVersion: "1.0.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            inputSchemaVersion: 1,
            outputSchemaVersion: template.outputSchemaVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            caseResults: [
                PromptEvalCaseResult(caseId: "questions.current_failure", name: "Current failure", status: .failed)
            ],
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let otherRuns = PromptID.allCases
            .filter { $0 != .generateQuestions }
            .map { promptID -> PromptEvalRun in
                let prompt = provider.template(for: promptID, mode: .standard)
                return PromptEvalRun(
                    promptId: promptID.rawValue,
                    promptVersion: prompt.version,
                    systemPolicyVersion: prompt.systemPolicyVersion,
                    contextPolicyVersion: prompt.contextPolicyVersion,
                    inputSchemaVersion: 1,
                    outputSchemaVersion: prompt.outputSchemaVersion,
                    evalSuiteVersion: prompt.evalSuiteVersion,
                    runnerVersion: PromptEvalRunner.currentRunnerVersion,
                    caseResults: [
                        PromptEvalCaseResult(caseId: "\(promptID.rawValue).pass", name: "\(promptID.displayName) pass", status: .passed)
                    ],
                    createdAt: Date(timeIntervalSince1970: 250)
                )
            }

        let gate = PromptEvalReleaseGate.evaluate(
            runs: otherRuns + [priorPassingRun, supersededFailedRun],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion
        )

        XCTAssertEqual(gate.status, .passed)
        XCTAssertEqual(gate.passedPromptCount, PromptID.allCases.count)
        XCTAssertEqual(gate.failedPromptCount, 0)
        XCTAssertEqual(gate.rollbackReadyCount, 0)
    }

    func testPromptEvalSchedulePolicy_runsForMissingOrExpiredHistoryAndSkipsFreshPassingHistory() {
        let provider = LocalPromptProvider()
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = PromptEvalSchedulePolicy(minimumRunInterval: 60)

        let missingDecision = policy.decision(
            runs: [],
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            now: now
        )

        XCTAssertTrue(missingDecision.shouldRun)
        XCTAssertEqual(missingDecision.reason, .missingRequiredRun)

        let freshRuns = PromptEvalRunner(promptProvider: provider)
            .runFixedSuite(mode: .standard, createdAt: now.addingTimeInterval(-30))
        let freshDecision = policy.decision(
            runs: freshRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            now: now
        )

        XCTAssertFalse(freshDecision.shouldRun)
        XCTAssertNil(freshDecision.reason)

        let expiredRuns = PromptEvalRunner(promptProvider: provider)
            .runFixedSuite(mode: .standard, createdAt: now.addingTimeInterval(-61))
        let expiredDecision = policy.decision(
            runs: expiredRuns,
            promptProvider: provider,
            mode: .standard,
            runnerVersion: PromptEvalRunner.currentRunnerVersion,
            now: now
        )

        XCTAssertTrue(expiredDecision.shouldRun)
        XCTAssertEqual(expiredDecision.reason, .minimumIntervalElapsed)
    }

    private func fixtureData(_ json: String) -> Data {
        Data(json.utf8)
    }
}

private struct RollbackFixturePromptProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        var template = base.template(for: id, mode: mode)
        if id == .generateQuestions {
            template.rollbackTargetVersion = "0.9.0"
        }
        return template
    }
}

private struct AppliedRollbackFixturePromptProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        if id == .generateQuestions {
            return template(for: id, mode: mode, version: "0.9.0")!
        }
        return base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        let template = base.template(for: id, mode: mode)
        guard id == .generateQuestions, version == "0.9.0" else {
            return template.version == version ? template : nil
        }
        return PromptTemplate(
            id: template.id,
            version: "0.9.0",
            systemPolicyVersion: template.systemPolicyVersion,
            contextPolicyVersion: template.contextPolicyVersion,
            evalSuiteVersion: template.evalSuiteVersion,
            rollbackTargetVersion: nil,
            systemText: template.systemText,
            userText: template.userText,
            outputSchemaVersion: template.outputSchemaVersion
        )
    }
}

private struct ImportedPromptPackRollbackFixtureProvider: PromptProvider {
    private let base = LocalPromptProvider()

    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        if id == .generateQuestions {
            return importedTemplate(version: "1.1.0", packVersion: "2026.06", rollbackTargetVersion: "1.0.0")
        }
        return base.template(for: id, mode: mode)
    }

    func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
        guard id == .generateQuestions else {
            let template = base.template(for: id, mode: mode)
            return template.version == version ? template : nil
        }
        switch version {
        case "1.1.0":
            return importedTemplate(version: "1.1.0", packVersion: "2026.06", rollbackTargetVersion: "1.0.0")
        case "1.0.0":
            return importedTemplate(version: "1.0.0", packVersion: "2026.05", rollbackTargetVersion: nil)
        default:
            return nil
        }
    }

    private func importedTemplate(
        version: String,
        packVersion: String,
        rollbackTargetVersion: String?
    ) -> PromptTemplate {
        let baseTemplate = base.template(for: .generateQuestions, mode: .standard)
        return PromptTemplate(
            id: .generateQuestions,
            version: version,
            systemPolicyVersion: baseTemplate.systemPolicyVersion,
            contextPolicyVersion: baseTemplate.contextPolicyVersion,
            evalSuiteVersion: baseTemplate.evalSuiteVersion,
            rollbackTargetVersion: rollbackTargetVersion,
            sourceKind: .marketplace,
            packId: "marketplace.prompts.coach",
            packVersion: packVersion,
            packDisplayName: "Coach Prompt Pack",
            systemText: baseTemplate.systemText,
            userText: "Imported questions prompt \(version).",
            outputSchemaVersion: baseTemplate.outputSchemaVersion
        )
    }
}
