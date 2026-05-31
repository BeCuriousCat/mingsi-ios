import Foundation

final class MockLLMClient: LLMClient {
    private let encoder: JSONEncoder

    init() {
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func complete(_ request: LLMRequest) async throws -> Data {
        switch request.prompt.id {
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
                        "expected_answer_type": "tradeoff",
                        "question": "If tomorrow can only reduce one source of rework, which decision must become explicit?",
                        "why_this_matters": "It forces prioritization by downstream value instead of task convenience."
                    ],
                    [
                        "expected_answer_type": "validation",
                        "question": "What evidence would show that unclear ownership is the real blocker?",
                        "why_this_matters": "It checks the hidden assumption behind the proposed action."
                    ],
                    [
                        "expected_answer_type": "judgment",
                        "question": "Which smaller task should be deliberately postponed so the main unblock happens?",
                        "why_this_matters": "It protects the highest-value action from being crowded out."
                    ]
                ]
            ])

        case .generateQuests:
            return try encode([
                "main_quest": [
                    "completion_criteria": "Owner, inputs, outputs, and acceptance criteria are written down and acknowledged by the relevant people.",
                    "expected_resistance": "Cross-role ownership may feel awkward to make explicit.",
                    "linked_cards": ["Clarify interface ownership", "Meeting goal was unclear"],
                    "reflection_question": "After the confirmation, which rework risk is measurably lower?",
                    "title": "Confirm interface ownership",
                    "type": "main",
                    "why_it_matters": "It reduces the chance that implementation proceeds with different assumptions."
                ],
                "observation_quest": [
                    "completion_criteria": "Write one note about where ownership became ambiguous during the day.",
                    "expected_resistance": "It is easy to notice only after friction appears.",
                    "linked_cards": ["Meeting goal was unclear"],
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
                        "reflection_question": "Did the summary make the next action easier to execute?",
                        "title": "Send concise decision summary",
                        "type": "side",
                        "why_it_matters": "It keeps the decision visible after the discussion."
                    ]
                ]
            ])

        case .verifyQuest:
            return try encode([
                "calibration_note": "The quest was valuable, but the completion criteria needed a clearer evidence point.",
                "likely_issue": "unclear_criteria",
                "recommendation": "Define tomorrow's quest so completion can be verified by one visible artifact or response."
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
                    "success_criteria": "People can state who owns the next step and what done means.",
                    "summary": "Before implementation work continues, make ownership and done criteria explicit.",
                    "title": "Clarify ownership before execution",
                    "trigger_context": "Cross-functional work where implementation depends on shared assumptions."
                ]
            ])

        case .weeklyCalibration:
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
        }
    }

    private func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
}
