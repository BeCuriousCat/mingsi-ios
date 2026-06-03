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

    private func fixtureData(_ json: String) -> Data {
        Data(json.utf8)
    }
}
