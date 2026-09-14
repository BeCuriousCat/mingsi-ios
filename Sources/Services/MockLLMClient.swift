import Foundation

final class MockLLMClient: LLMClient {
    private let encoder: JSONEncoder

    init() {
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        switch request.prompt.id {
        case .mentorRespond:
            return try encode(["schema_version": "1.0.0", "action": "explain", "material_status": "not_needed",
                "body": "可以先区分完成的动作和它带来的效果。例如，提交一个改动是动作，使用者的问题是否减少是效果。两者可能需要分别观察。",
                "question": NSNull(), "question_purpose": NSNull(), "source_refs": [],
                "lesson_ref": NSNull(), "suggested_actions": ["finish"]])
        case .mentorDraftUnderstanding:
            let context = try JSONDecoder().decode(MentorContextPayload.self, from: Data(request.inputSummary.utf8))
            guard let source = context.sources.last(where: { $0.role == .user && $0.isCurrent }) else {
                throw MentorContextError.invalidUnderstanding
            }
            return try encode(["schema_version": "1.0.0", "text": source.content, "source_refs": [source.ref.value]])
        case .organizeCards:
            return try encode([
                "cards": [
                    [
                        "type": "problem",
                        "title": "Meeting goal was unclear",
                        "body": "The discussion moved across several topics before the decision that mattered most was named.",
                        "importance": "high",
                        "sensitivity": "normal",
                        "confidence": "high",
                        "reason": "The input points to unclear alignment and likely rework."
                    ],
                    [
                        "type": "task",
                        "title": "Clarify interface ownership",
                        "body": "Confirm owner, inputs, outputs, and acceptance criteria before the next implementation step.",
                        "importance": "high",
                        "sensitivity": "normal",
                        "confidence": "high",
                        "reason": "This is the most concrete next action implied by the notes."
                    ]
                ],
                "recommended_next_step": "Confirm which card is most important before choosing a thinking lens.",
                "sensitivity_notes": [],
                "transcript_quality": "medium"
            ])

        case .recommendLenses:
            return try encode([
                "default_lens": "leverage_analysis",
                "recommended_lenses": [
                    [
                        "id": "leverage_analysis",
                        "name": "Leverage Analysis",
                        "why_recommended": "It separates the highest-value unblock from lower-value follow-up work."
                    ],
                    [
                        "id": "evidence_check",
                        "name": "Evidence Check",
                        "why_recommended": "It tests whether the assumed root cause is supported by concrete signals."
                    ]
                ]
            ])

        case .generateQuestions:
            return try encode([
                "questions": [
                    [
                        "evidence_gap_type": "none",
                        "answer_use": "choose_action",
                        "lens_move": "leverage_tradeoff",
                        "source_card_titles": ["Clarify interface ownership"],
                        "calibration_target": "Clarifying ownership is the highest-leverage way to reduce rework",
                        "expected_answer_type": "tradeoff",
                        "question": "If tomorrow can only reduce one source of rework, which decision must become explicit?",
                        "why_this_matters": "It forces prioritization by downstream value instead of task convenience.",
                        "why_now": "The coach turn is ready to compare possible actions after ownership evidence was named.",
                        "expected_update": "The answer chooses the judgment that should drive tomorrow's main action.",
                        "proceed_when": "Proceed when one decision is named with a clear reason it reduces rework."
                    ],
                    [
                        "evidence_gap_type": "missing_observation",
                        "answer_use": "collect_evidence",
                        "lens_move": "fact_interpretation_split",
                        "source_card_titles": ["Meeting goal was unclear"],
                        "calibration_target": "Unclear ownership is the real blocker behind rework",
                        "expected_answer_type": "validation",
                        "question": "What evidence would show that unclear ownership is the real blocker?",
                        "why_this_matters": "It checks the hidden assumption behind the proposed action.",
                        "why_now": "The coach turn still needs observable evidence before treating ownership as the root cause.",
                        "expected_update": "The answer updates the evidence plan for validating the blocker.",
                        "proceed_when": "Proceed when one observable signal can confirm or weaken the ownership explanation."
                    ],
                    [
                        "evidence_gap_type": "none",
                        "answer_use": "choose_action",
                        "lens_move": "leverage_tradeoff",
                        "source_card_titles": ["Clarify interface ownership", "Meeting goal was unclear"],
                        "calibration_target": "Postponing a smaller task will protect the main unblock",
                        "expected_answer_type": "judgment",
                        "question": "Which smaller task should be deliberately postponed so the main unblock happens?",
                        "why_this_matters": "It protects the highest-value action from being crowded out.",
                        "why_now": "The coach turn is moving from diagnosis into a focused tradeoff.",
                        "expected_update": "The answer updates the action boundary for tomorrow's quest.",
                        "proceed_when": "Proceed when one lower-value task is explicitly postponed in favor of the main unblock."
                    ]
                ]
            ])

        case .generateQuests:
            return try encode([
                "main_quest": [
                    "completion_criteria": "Owner, inputs, outputs, and acceptance criteria are written down and acknowledged by the relevant people.",
                    "expected_resistance": "Cross-role ownership may feel awkward to make explicit.",
                    "linked_cards": ["Clarify interface ownership", "Meeting goal was unclear"],
                    "lens_move": "leverage_tradeoff",
                    "reflection_question": "After the confirmation, which rework risk is measurably lower?",
                    "title": "Confirm interface ownership",
                    "type": "main",
                    "why_it_matters": "It reduces the chance that implementation proceeds with different assumptions."
                ],
                "observation_quest": [
                    "completion_criteria": "Write one note about where ownership became ambiguous during the day.",
                    "expected_resistance": "It is easy to notice only after friction appears.",
                    "linked_cards": ["Meeting goal was unclear"],
                    "lens_move": "fact_interpretation_split",
                    "reflection_question": "What early signal would have revealed the ambiguity sooner?",
                    "title": "Watch for ownership ambiguity",
                    "type": "observation",
                    "why_it_matters": "It trains earlier detection of the repeated pattern."
                ],
                "rejected_low_value_tasks": ["Polish the full meeting summary before the critical owner is confirmed."],
                "side_quests": [
                    [
                        "completion_criteria": "Send a short summary with decision, action, owner, and due date.",
                        "expected_resistance": "The summary can expand into too much context.",
                        "linked_cards": ["Meeting goal was unclear"],
                        "lens_move": "leverage_tradeoff",
                        "reflection_question": "Did the summary make the next action easier to execute?",
                        "title": "Send concise decision summary",
                        "type": "side",
                        "why_it_matters": "It keeps the decision visible after the discussion."
                    ]
                ]
            ])

        case .verifyQuest:
            let refs = request.sourceRecordIDs.filter { UUID(uuidString: $0) != nil }
            return try encode([
                "calibration_note": "Original prediction: a visible artifact or response would clarify ownership. Actual evidence: the completed quest produced a concrete response but criteria were still a little broad. Evidence gained: ownership signals are easier to verify when tied to one artifact. Observable signal: the owner replied on the artifact. Completion criteria met: one visible artifact received a concrete response. Judgment update: keep tomorrow's quest anchored to a single observable artifact.",
                "likely_issue": "unclear_criteria",
                "recommendation": "Define tomorrow's quest so completion can be verified by one visible artifact or response.",
                "growth_evidence_items": [[
                    "category": "action",
                    "metric": "execution_reliability",
                    "title": "用可见产物留下了可核对的结果",
                    "source_refs": Array(refs.prefix(2))
                ]]
            ])

        case .extractPrinciple:
            return try encode([
                "principle_candidate": [
                    "actions": [
                        "Name the decision before the discussion expands.",
                        "Write owner, input, output, and acceptance criteria.",
                        "Send the smallest useful summary after alignment."
                    ],
                    "exceptions": "Skip the full format for low-stakes status updates.",
                    "source_card_titles": ["Meeting goal was unclear", "Clarify interface ownership"],
                    "success_criteria": "Owner and acceptance criteria are visible before execution.",
                    "summary": "Before implementation work continues, make ownership and done criteria explicit.",
                    "title": "Clarify ownership before execution",
                    "trigger_context": "Cross-functional work where implementation depends on shared assumptions."
                ]
            ])

        case .generateSideQuest:
            return try encode([
                "decision": "offer",
                "reason": "最近的记录以工作事项为主；一件不要求产出的轻松遇见，可能比再增加一个计划更合适。",
                "grounding_refs": ["current_day"],
                "offer": [
                    "category": "making",
                    "title": "给一件旧物换个角度",
                    "invitation": "从手边一件平时不会多看的东西开始，随手挪到一个不同的位置看看；不需要整理，也不用留下它。",
                    "evidence_prompt": "它换了位置之后，有没有一点不同的感觉？",
                    "minimum_minutes": 5,
                    "maximum_minutes": 15,
                    "prerequisite_ids": [],
                    "completion_experience": 20,
                    "reflection_bonus_experience": 5,
                    "notification_title": "今天留了一个小岔口",
                    "notification_body": "路过时，看看会不会遇见一点新东西。"
                ]
            ])

        case .recommendGuidance:
            return try encode([
                "decision": "show",
                "hint_id": "action.completion_criteria",
                "reason": "当前行动缺少可核对的完成信号。"
            ])

        case .evaluateGuidanceEvidence:
            return try encode([
                "result": "supports",
                "hint_id": "verification.result_not_completion",
                "reason": "验证中记录了实际结果，而不是只报告完成。"
            ])

        case .diagnoseTrainingCase:
            return try encode([
                "phase": "fill_evidence_gap",
                "readiness": "not_ready",
                "recommended_move": "surface_evidence_gap",
                "training_dimension": "evidence_discipline",
                "recommended_lens_id": "evidenceCheck",
                "reason": "当前卡片有判断，但还缺少能支持或推翻它的可观察证据。",
                "confidence": 0.78
            ])

        case .reviewCoachAnswer:
            let refs = Array(request.sourceRecordIDs.prefix(2))
            return try encode([
                "readiness": "not_ready",
                "recommended_move": "surface_evidence_gap",
                "open_evidence_gaps": ["missing_observation"],
                "reason": "回答提出了判断，但还没有给出能支持或推翻它的可观察结果。",
                "turn_summary": "已记录判断，仍需补一个可观察信号。",
                "coach_critique": "我听到你的判断，但当前材料还不能区分事实与解释。",
                "repaired_material": "你明确了暂时的判断。",
                "missing_material": "还缺一条可观察事实或结果信号。",
                "proceed_line": "可以先补这个信号，也可以由你决定带着缺口继续。",
                "ability_gap": "让判断有可观察依据。",
                "training_output": "说清哪条事实会支持或削弱判断。",
                "self_check": "别人能否指出你引用的事实，而不是只复述结论？",
                "training_target": "练习把判断和证据分开。",
                "next_repair_question": "哪一个已经发生的事实最能支持或削弱这个判断？",
                "experience_replay_decision": "比较这次和旧经验的条件，再决定复现、调整或否定。",
                "experience_replay_prompt": "过去类似情况中的哪个条件这次不同？",
                "judgment_sentence_prompt": "基于什么事实，我暂时相信什么；什么结果会让我更新它？",
                "reference_suggestion": "先写事实，再写暂时判断，最后写校准信号。",
                "reference_example": "基于「可观察事实」，我暂时判断「……」；如果「相反信号」出现，我会更新判断。",
                "source_refs": refs
            ])

        case .weeklyCalibration:
            if request.prompt.userText.contains("existing hint IDs") {
                return try encode([
                    "training_focus": "Make each action's completion evidence explicit.",
                    "hint_ids": ["action.completion_criteria"],
                    "evidence_refs": Array(request.sourceRecordIDs.prefix(2))
                ] as [String: Any])
            }
            return try encode([
                "evidence": ["Repeated meetings improved when decisions were written as owner/action/date."],
                "highest_value_action": "Clarifying ownership before implementation",
                "lowest_value_time_sink": "Polishing summaries before decisions were clear",
                "next_week_focus": "Define completion evidence before starting the main quest",
                "repeated_blocker": "Ambiguous responsibility",
                "thinking_pattern": "Moving to execution before verifying alignment"
            ])

        case .monthlyGrowth:
            return try encode([
                "before_after_examples": [
                    "Before: broad meeting notes. After: explicit owner/action/criteria records."
                ],
                "calibration": ["trend": "improving"],
                "clarity": ["trend": "improving"],
                "execution_reliability": ["trend": "steady"],
                "reflection_depth": ["trend": "improving"],
                "next_month_focus": "Improve verification of quest value after completion.",
                "value_judgment": ["trend": "improving"]
            ])

        case .suggestProjectLinks:
            return try encode([
                "project_link_candidates": [],
                "new_project_candidates": []
            ] as [String: [Any]])

        case .generateProjectInsights:
            if request.prompt.userText.contains("principle_candidates") {
                let refs = Array(request.sourceRecordIDs.prefix(2))
                return try encode([
                    "summary": "Confirmed evidence shows the project closed with a testable handoff rule.",
                    "principle_candidates": [[
                        "title": "Confirm ownership before handoff",
                        "summary": "Use an explicit owner before cross-team work starts.",
                        "trigger_context": "Before a cross-team handoff",
                        "actions": ["Name the owner", "Record the acceptance check"],
                        "success_criteria": "The owner confirms the handoff in writing.",
                        "exceptions": "Immediate incident response",
                        "evidence_refs": refs
                    ]]
                ] as [String: Any])
            }
            return try encode([
                "insights": [],
                "insufficient_evidence_reason": "Mock client requires real AI for insights."
            ] as [String: Any])

        case .suggestProjectMerges:
            return try encode([
                "merge_candidates": []
            ] as [String: [Any]])
        }
    }

    private func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
}
