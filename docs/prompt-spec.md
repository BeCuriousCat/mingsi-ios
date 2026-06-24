# 明思 Prompt Specification

## Prompt Architecture

Prompt 与上下文工程的完整产品规格见 `docs/prompt-context-engineering-prd.md`。本文档保留具体 Prompt schema 和模板要求；上下文选择、原则资产检索、上下文预算和 eval 规则以该 PRD 为准。

Prompt 不允许和 SwiftUI 页面耦合。业务层只能通过 `PromptProvider` 获取模板。

MVP 使用：

```text
LocalPromptProvider
```

未来可切换为：

```text
RemotePromptProvider
```

每次模型调用必须记录：

- promptId。
- promptVersion。
- inputSchemaVersion。
- outputSchemaVersion。
- modelProvider。
- modelName。
- sessionMode。

## Common System Behavior

```text
You are a thinking coach for a busy knowledge worker.
Your role is to help the user clarify problems, challenge assumptions, choose high-value actions, and calibrate judgment.
Do not decide for the user.
Do not replace the user's thinking.
Separate facts, interpretations, assumptions, risks, and validation needs.
Do not encourage the user to share confidential company information, code, customer data, or internal documents.
Be concise, concrete, and non-performative.
Return valid JSON matching the requested schema.
```

## Session Modes

```text
quick:
  shortest path, fewer questions, one main quest.

standard:
  default full loop, cards, lens, 3 questions, quests, principle candidate.

deep:
  higher depth, more questions, stronger opposing view, better suited for important events.
```

Mode affects prompt depth, not the underlying data model.

## GLM Response Contract

- Preferred transport: OpenAI-compatible Chat Completions with `response_format: {"type":"json_object"}`.
- Compatibility fallback: if a GLM-compatible endpoint rejects `response_format`, the client retries once without that field.
- All prompts must therefore still say “return valid JSON only” and include an explicit output shape; the parser must not depend solely on transport-level JSON mode.
- Fallback does not change schema versions or parser expectations.
- A successful connection test does not guarantee successful production prompts; production calls can still fail on quota, model permission, malformed JSON, empty content, schema mismatch, or transport errors.
- If a production prompt fails, UI must show the concrete error, keep or create an editable local fallback, and allow retry with the same local input.
- Retry prompts must be idempotent: re-running the same prompt against the same DailyEntry should replace only that prompt's draft output, not duplicate cards, quests, or principles.

## Data Shapes

### Thinking Card

```json
{
  "type": "fact | problem | decision | risk | idea | communication | task",
  "title": "string",
  "body": "string",
  "importance": "low | medium | high",
  "sensitivity": "normal | possibly_sensitive | sensitive",
  "confidence": "low | medium | high",
  "reason": "string"
}
```

### Thinking Lens

```json
{
  "id": "first_principles | occams_razor | opposing_view | opportunity_cost | leverage_analysis | evidence_check | execution_bias_check",
  "name": "string",
  "why_recommended": "string"
}
```

### Reflection Question

```json
{
  "question": "string",
  "why_this_matters": "string",
  "why_now": "why this question is the right next move in the current coach turn",
  "expected_update": "what judgment, action, evidence plan, or calibration signal the answer is expected to change",
  "proceed_when": "what kind of answer is sufficient to move toward action",
  "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
  "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
  "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
  "source_card_titles": ["string"],
  "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this question will calibrate",
  "expected_answer_type": "fact | judgment | tradeoff | validation"
}
```

`why_now`, `expected_update`, and `proceed_when` are user-visible teaching fields, not hidden parser metadata. Together they must explain why this question now, what the answer will change, and what is sufficient to proceed. Today may render them directly inside question teaching cues, so they must be concrete, short, and grounded in the current coach turn.

### Lens Feedback

```json
{
  "lensId": "string",
  "lensTitle": "string",
  "signal": "reinforce | adjust | avoid",
  "completion": "done | partial | missed",
  "valueRating": "high | medium | low | uncertain",
  "calibrationNote": "short verified outcome summary",
  "recommendation": "short next calibration recommendation",
  "questionTargets": ["specific prior calibration target"],
  "evidenceGapTypes": ["missing_calibration_signal"],
  "lensMoves": ["prediction_calibration"]
}
```

Rules:

- `lensFeedback` contains only verified outcomes from previous completed loops with both a lens session and next-day verification.
- `reinforce` means the lens move produced high-value calibration evidence.
- `adjust` means the move produced partial, medium, or uncertain evidence and should be made more concrete.
- `avoid` means the move led to missed, low-value, or uncalibratable work.
- Use `lensMoves` to tune specific reasoning moves; do not discard an entire lens because one move performed poorly.
- Use at most a small recent sample; do not insert full history or raw daily text into lens feedback.

### Training Dimension

Coach-led training uses `TrainingPrescription` as a plan, not just a selected lens. Prompt context carries:

```json
{
  "primaryTrainingDimension": "evidence_discipline",
  "secondaryTrainingDimensions": ["fact_interpretation_separation", "counterexample_seeking"],
  "baselineTrainingDimensions": [
    "fact_interpretation_separation",
    "evidence_discipline",
    "counterexample_seeking",
    "assumption_testing",
    "testable_action_design",
    "system_feedback_awareness",
    "judgment_calibration"
  ]
}
```

Supported `ThinkingTrainingDimension` values:

- `fact_interpretation_separation`: separate what happened from the user's interpretation.
- `evidence_discipline`: name missing evidence, weak evidence, and what observation would close the gap.
- `counterexample_seeking`: ask what would make the user's current view wrong or incomplete.
- `assumption_testing`: expose inherited assumptions and test the smallest necessary premise.
- `system_feedback_awareness`: look for feedback loops, delays, constraints, and second-order effects.
- `judgment_calibration`: compare prediction, confidence, actual evidence, and judgment update.
- `testable_action_design`: turn thinking into one action with observable completion or calibration evidence.

Rules:

- The generateQuestions prompt must apply this plan before output generation.
- Do not rely on the deterministic quality gate as the first place where training-dimension alignment happens.
- Every question must serve either the primary training dimension or one baseline training dimension.
- The first question should usually train `primaryTrainingDimension`; later questions may cover `secondaryTrainingDimensions` or unresolved baseline gaps.
- Baseline dimensions are checks, not permission to generate a broad questionnaire. Keep one main coaching focus per loop.
- Do not treat a user's override lens as proof that the coach diagnosis was wrong. Keep `primaryTrainingDimension` tied to the coach recommendation and use `finalTrainingLens` for the generated lens move.

### Coach Turn State

Coach Turn State v1 turns the coach from a one-shot lens recommender into a Today-local stateful coach loop. Prompt context may carry:

```json
{
  "coachTurnState": {
    "phase": "explore_problem | clarify_judgment | fill_evidence_gap | form_action",
    "readiness": "not_ready | ready",
    "recommendedMove": "ask_clarifying_question | surface_evidence_gap | slow_down_convergence | recommend_training_lens | generate_quest",
    "reason": "short coach rationale",
    "openEvidenceGaps": ["missing_observation", "missing_baseline"],
    "baselineChecks": ["fact_interpretation_separation", "evidence_gap", "testable_action"],
    "decisionSource": "coachRecommended | coachAccepted | userSlowDown | userOverrideProgress",
    "policyVersion": "coach-turn.local-v1",
    "turnSummary": "short summary of where this coach turn currently stands"
  }
}
```

The prompt directive key is `coachTurnRule`.

Rules:

- organizeCards must not receive `coachTurnState`. It also must not receive `coachDiagnosis`, historical principles, or training history. It only cleans current raw input into reviewable cards.
- `generateQuestions` must use `coachTurnState` before choosing question style. If readiness is `not_ready`, ask clarification or evidence-gap questions before converging.
- `generateQuests` may form a verifiable action when readiness is `ready`.
- If readiness is `not_ready`, `generateQuests` should not produce a quest unless `decisionSource` is `userOverrideProgress`.
- A user override is permission to proceed, not proof that the coach was wrong.
- `openEvidenceGaps` should guide the next question before the model invents broader advice.
- `baselineChecks` are quiet guardrails; they should prevent premature convergence without turning the loop into a broad questionnaire.
- `turnSummary` is an audit summary for the current coach turn, not source evidence.

### Coach Teaching Plan

Coach Teaching Plan turns the current coach turn into a teaching frame. It tells
the model what the user has not thought through yet, why MingSi is training that
move instead of giving an AI answer, and what is enough to proceed. Prompt
context may carry:

```json
{
  "coachTeachingPlan": {
    "policyVersion": "coach-teaching.local-v1",
    "missingMoveTitle": "the missing thinking move the user has not handled yet",
    "trainingTargetTitle": "localized primary training target",
    "whyNotAnswer": "why this is not an AI answer or direct advice moment",
    "proceedStandard": "what answer or evidence is sufficient to continue",
    "routeSteps": ["first teaching step", "second teaching step", "third teaching step"],
    "auditNote": "optional override or boundary note"
  }
}
```

The prompt directive key is `coachTeachingRule`.

Rules:

- `generateQuestions` must use `coachTeachingPlan` before wording questions:
  start from the missing thinking move, train the named target, and keep
  `whyNotAnswer` visible in `why_this_matters` or `why_now`.
- `generateQuests` may use `coachTeachingPlan` to preserve the proceed standard
  when forming an action after the coach turn is ready or explicitly overridden.
- organizeCards must not receive `coachTeachingPlan`; it only cleans current raw
  input into reviewable cards.
- `coachTeachingPlan` is not source evidence. It is the coach's operational
  teaching frame for the current turn.
- `routeSteps` are training route cues, not a command to add extra workflow
  steps or a broad questionnaire.
- A user override may proceed, but `auditNote` and `proceedStandard` must keep
  the unresolved gap visible.

### Quest

```json
{
  "type": "main | side | observation",
  "title": "string",
  "why_it_matters": "string",
  "completion_criteria": "string",
  "expected_resistance": "string",
  "reflection_question": "string",
  "calibration_target": "specific judgment, assumption, prediction, causal explanation, or tradeoff this quest will calibrate",
  "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
  "linked_cards": ["string"]
}
```

Rules:

- Quest must carry the calibration target into tomorrow's verification.
- Quest must carry the selected lens's reasoning move into `lens_move`; this is parsed into `Quest.lensMove` and persisted with the quest's calibration payload.
- Quest must cite confirmed card titles in `linked_cards`; these are parsed into `Quest.sourceCardTitles` and persisted with the quest's calibration payload.
- Use the reflection answer's `calibrationTarget` when present; otherwise derive a concrete target from confirmed cards and the user's answer.
- Do not switch the task into a different lens move just because it sounds useful; the quest is the action form of the selected thinking lens.
- Do not invent `linked_cards`; use only confirmed card titles from the current context.
- Do not use vague targets such as "user thinking" or "this situation".

## Deterministic Coaching Quality Gate

`PromptCoachingQualityPolicy` is a local, deterministic quality gate for obvious coaching regressions. It does not call the LLM and does not replace deeper human or LLM review. It protects the core coaching loop from accepting outputs that are syntactically valid but not useful as thinking training.

Question output can be flagged with:

- `genericQuestion`: question invites generic reflection, opinion, venting, or mood description.
- `missingFunctionalCoachField`: question does not state why it is the right next move now, what its answer will update, or what answer is sufficient to proceed.
- `missingEvidenceGapType`: question does not classify the evidence gap.
- `missingAnswerUse`: question does not state how the answer will update judgment, action, evidence, assumption testing, or calibration.
- `missingLensMove`: question does not state the trained reasoning move.
- `missingSourceGrounding`: question cites no confirmed source card.
- `vagueCalibrationTarget`: question names an abstract target such as "the user's thinking" or "this situation" instead of a concrete belief, prediction, causal explanation, or tradeoff.
- `missingSelectedLensMove`: question batch does not include the reasoning move required by the selected built-in lens.
- `missingTrainingDimensionAlignment`: question does not serve the primary training dimension or any baseline training dimension.
- `missingPrimaryTrainingDimensionFocus`: first question does not serve the primary training dimension, so the coach-led main focus is being diluted by baseline checks.
- `missingCoachTurnAlignment`: question ignores the current coach turn phase, readiness, or recommended move. For example, a `not_ready` turn that recommends evidence gathering should not accept a generic action-choice question.
- `repeatedAvoidedLensMove`: question repeats a `lensMove` that recent verified `lensFeedback` marked as `avoid`.
- `unadjustedLensMove`: question repeats a `lensMove` and calibration target that recent verified `lensFeedback` marked as `adjust`, instead of making the move smaller or more observable.
- `missingReinforcedLensMove`: question batch ignores a `lensMove` that recent verified `lensFeedback` marked as `reinforce`.
- `missingSystemThinkingLensMove`: question batch ignores `feedback_loop`, `delayed_effect`, and `second_order_consequence` when the selected lens is `system_thinking`.

Selected built-in lens move mapping:

- `evidence_check`: requires `fact_interpretation_split`.
- `opposing_view`: requires `alternative_explanation`.
- `leverage_analysis`: requires `leverage_tradeoff`.
- `first_principles`: requires `constraint_decomposition`.
- `system_thinking`: requires `feedback_loop`, `delayed_effect`, or `second_order_consequence`.
- `judgment_calibration`: requires `prediction_calibration`.

Quest output can be flagged with:

- `busyworkQuest`: quest looks productive but does not reduce uncertainty, test a judgment, or create a calibration signal.
- `weakCompletionCriteria`: quest completion criteria are too short or not observable enough.
- `vagueCalibrationTarget`: quest calibration target is too abstract to verify tomorrow.
- `missingSourceGrounding`: quest cites no linked confirmed card, so tomorrow's action cannot be traced back to today's evidence.
- `missingSelectedLensMove`: quest output does not include the reasoning move required by the selected built-in lens.
- `missingCoachTurnAlignment`: quest is generated while the coach turn is not ready and the user has not explicitly chosen `userOverrideProgress`.
- `missingSystemThinkingLensMove`: quest output ignores `feedback_loop`, `delayed_effect`, and `second_order_consequence` when the selected lens is `system_thinking`.

Verification output can be flagged with:

- `weakVerificationCalibrationNote`: verification has a `targetJudgment` but the calibration note does not cover the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
- `weakVerificationRecommendation`: verification has a `targetJudgment` but the recommendation does not name a next calibration action, test, or observable signal to watch.
- `missingExpectedPrinciplePracticeAssessment`: verification has a `trainingPrinciple` context but the parsed output omits the separate `expected_principle_practice_assessment` audit field.

Principle output can be flagged with:

- `missingPrincipleSourceGrounding`: principle candidate cites no confirmed source card, so the reusable rule cannot be traced back to today's evidence.
- `weakPrincipleActionability`: principle candidate is grounded but still too slogan-like, lacks at least two concrete next-time actions, or has no observable success criteria.

The gate should stay conservative: it catches low-cost, high-confidence failures. Passing the gate means "not obviously bad"; it does not mean the prompt is high quality.

At runtime, `TodayAIService.generateQuestions`, `TodayAIService.generateQuests`, `TodayAIService.verifyQuest`, and `TodayAIService.extractPrinciple` run this gate after JSON parsing and before returning output to the app state machine. If the gate finds issues, the service throws `TodayAIParsingError.qualityGateFailed` with issue reason codes only. The app should treat this like a parse-quality failure and use the existing fallback and retry path rather than showing low-quality AI output to the user.

### Principle Candidate

```json
{
  "title": "string",
  "summary": "string",
  "trigger_context": "string",
  "actions": ["string"],
  "success_criteria": "string",
  "exceptions": "string",
  "source_card_titles": ["string"]
}
```

Rules:

- Principle candidate must cite confirmed card titles in `source_card_titles`; these are parsed into `PrincipleAsset.sourceCardTitles` and persisted with the principle raw payload.
- Principle candidate must include at least two concrete actions the user can do next time.
- `success_criteria` must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
- Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
- Do not invent `source_card_titles`; use exact titles from `confirmedCards`.
- If no confirmed card supports the reusable rule, return `principle_candidate: null`.

### Project Link Candidate

```json
{
  "project_id": "string | null",
  "candidate_project_name": "string | null",
  "link_type": "evidence | blocker | decision | task | principle | risk",
  "source_type": "daily_entry | thinking_card | quest | verification | principle",
  "source_id": "string",
  "reason": "string",
  "confidence": "low | medium | high",
  "requires_user_confirmation": true
}
```

### Project Candidate

```json
{
  "candidate_project_name": "string",
  "goal": "string",
  "current_bottleneck": "string",
  "success_criteria": "string",
  "why_this_is_long_running": "string",
  "source_refs": [
    {
      "source_type": "daily_entry | thinking_card | quest | verification | principle",
      "source_id": "string"
    }
  ],
  "privacy_safe_name_required": true,
  "confidence": "low | medium | high"
}
```

Rules:

- A candidate requires at least one source ref.
- The model must explain why the issue is recurring or strategically important.
- The model must not use company-sensitive names as the candidate name.
- The client must require user confirmation before creating a Project.
- Client validator: `TodayAIResponseParser.parseProjectSuggestions(from:)` only accepts project links with user confirmation required and explicit source evidence, and only accepts new project candidates with source refs.

### Project Merge Candidate

```json
{
  "source_project_id": "string",
  "target_project_id": "string",
  "reason": "string",
  "overlapping_evidence_refs": ["string"],
  "risks_if_merged": ["string"],
  "risks_if_kept_separate": ["string"],
  "confidence": "low | medium | high"
}
```

### Project Insight

```json
{
  "project_id": "string",
  "insight_type": "progress | blocker_change | thinking_change | open_question_closed | principle_practiced | next_bet",
  "title": "string",
  "summary": "string",
  "before": {
    "text": "string",
    "source_type": "daily_entry | thinking_card | quest | verification | principle",
    "source_id": "string"
  },
  "after": {
    "text": "string",
    "source_type": "daily_entry | thinking_card | quest | verification | principle",
    "source_id": "string"
  },
  "source_refs": ["string"],
  "confidence": "low | medium | high"
}
```

Rules:

- `thinking_change` and `blocker_change` require both `before` and `after`.
- Other insight types require at least one `source_ref`.
- The model must not infer project progress from unconfirmed cards.
- Client validator: `TodayAIResponseParser.parseProjectInsights(from:)` filters invalid insights; an empty insight list is only valid when `insufficient_evidence_reason` explains what evidence is missing.

### Metric Contribution

```json
{
  "metric": "clarity | value_judgment | execution_reliability | calibration | reflection_depth",
  "direction": "positive | negative",
  "delta": 0.0,
  "title": "string",
  "reason": "string",
  "source_type": "daily_entry | thinking_card | quest | verification | principle | project",
  "source_id": "string",
  "source_daily_entry_id": "string"
}
```

Rules:

- `source_id` and `source_daily_entry_id` are required.
- `delta` must be small and explainable; suggested range is 0.05-0.30.
- Positive and negative contributions are both allowed in the same period.
- If evidence is weak or contradictory, return a candidate with a low confidence reason rather than forcing a score.

## Prompt 1: Organize Raw Input Into Cards

Purpose:

- Convert messy daily input into editable thinking cards.
- Preserve uncertainty.
- Flag possible sensitivity.
- Stream candidate cards progressively so the user can see real generation progress.

Input:

- rawText。
- sessionMode。
- optional project context。
- privacy rules。

Instruction:

```text
Organize the user's raw daily input into thinking cards.
Do not summarize into one article.
Extract concrete facts, problems, decisions, risks, ideas, communications, and tasks.
If the transcript is messy, infer likely boundaries but mark low-confidence cards.
If content may contain confidential company details, mark it as possibly_sensitive or sensitive and avoid repeating unnecessary specifics.
Return concise editable cards.
```

MVP streaming output:

`organizeCards` is the only MVP prompt that returns XML-like streaming text instead of JSON. The model must output only the following controlled tags:

- `<MINGSI_STREAM version="1">`
- `<CARD>`
- `<TYPE>`
- `<TITLE>`
- `<BODY>`
- `<IMPORTANCE>`
- `<SENSITIVITY>`
- `<CONFIDENCE>`
- `<REASON>`
- matching closing tags

Allowed values:

- `TYPE`: `fact | problem | decision | risk | idea | communication | task`
- `IMPORTANCE`: `low | medium | high`
- `SENSITIVITY`: `normal | possibly_sensitive | sensitive`
- `CONFIDENCE`: `low | medium | high`

Rules:

- Output no markdown and no explanatory text outside the tags.
- Start each candidate as soon as it is clear enough; do not wait to plan all cards before outputting the first `<CARD>`.
- Every `<CARD>` must be closed with `</CARD>`.
- Body text must not contain XML control tags. If the user's text contains angle brackets, rewrite them as plain words.
- If uncertain, still output the card with `CONFIDENCE` set to `low`.
- Prefer 2-6 cards for standard mode, 1-3 for quick mode, and 3-8 for deep mode.

Few-shot:

Input:

```text
今天开会讨论接口归属，但会前没有列清楚要确认哪些问题。会后也没有发总结。
```

Output:

```xml
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
<CARD>
<TYPE>task</TYPE>
<TITLE>会后总结没有形成闭环</TITLE>
<BODY>会议结束后没有把关键结论、行动项和负责人发出，后续可能继续不清楚。</BODY>
<IMPORTANCE>medium</IMPORTANCE>
<SENSITIVITY>normal</SENSITIVITY>
<CONFIDENCE>medium</CONFIDENCE>
<REASON>这是可以在下一次会议中验证和改进的行动习惯。</REASON>
</CARD>
</MINGSI_STREAM>
```

Non-streaming compatibility:

- Tests and fallback parsers may still support the old JSON `cards` shape.
- Production MVP should prefer XML-like SSE for `organizeCards`.

## Prompt 2: Recommend Thinking Lenses

Purpose:

- Recommend one or two lenses based on confirmed cards.

Instruction:

```text
Review the confirmed cards and recommend up to two thinking lenses.
Choose lenses that improve the user's thinking quality today.
Prefer lenses that expose unclear goals, weak evidence, opportunity cost, hidden assumptions, or low-leverage execution.
Explain briefly why each lens is useful.
```

Output:

```json
{
  "recommended_lenses": [],
  "default_lens": "string"
}
```

## Prompt 3: Generate Lens Questions

Purpose:

- Ask high-quality questions under one lens.

Instruction:

```text
Generate lens-specific questions from the confirmed cards.
Questions must be specific to the user's content.
Do not ask generic self-help questions.
At least one question should challenge a hidden assumption.
At least one question should connect to tomorrow's action.
Use lensFeedback verified outcomes and lensMoves when present: reinforce moves marked reinforce, make moves marked adjust more concrete, and avoid moves marked avoid.
Do not repeat a lens move that produced low-value or uncalibratable work.
Use the session mode to control depth.
```

Mode rules:

- quick: 1-2 questions。
- standard: 3 questions。
- deep: 4-5 questions, including a stronger opposing-view question。

Output:

```json
{
  "questions": []
}
```

## Prompt 4: Generate Tomorrow Quests

Purpose:

- Generate a small set of high-value tasks for tomorrow.

Instruction:

```text
Generate tomorrow's quests from confirmed cards and user answers.
Create exactly one main quest unless information is insufficient.
Create at most two side quests and at most one observation quest.
The main quest should target the highest-value action, not the easiest task.
Each quest must include why it matters, concrete completion criteria, expected resistance, and one reflection question.
Each quest must include calibration_target: the specific judgment, assumption, prediction, causal explanation, or tradeoff it will calibrate.
Each quest must include linked_cards with confirmed card titles from today's context; do not invent linked card titles.
Quest must carry the calibration target into tomorrow's verification.
Use lensFeedback as verified lens outcomes from previous days.
Reinforce lensMoves that produced high-value calibration evidence.
When lensFeedback says adjust, make the same lensMoves smaller, more observable, and more explicit about completion evidence.
When lensFeedback says avoid, avoid repeating quest patterns and lensMoves that were low-value, missed, or did not produce a usable calibration signal.
If information is insufficient, ask for clarification rather than inventing a task.
```

Output:

```json
{
  "main_quest": {},
  "side_quests": [],
  "observation_quest": null,
  "rejected_low_value_tasks": []
}
```

## Prompt 5: Verify Yesterday's Quest

Purpose:

- Calibrate expected value against actual execution.

Instruction:

```text
Review yesterday's quest, completion status, and actual value.
Verify Quest input includes targetJudgment when yesterday's quest had a calibration target.
Compare targetJudgment with actual evidence when targetJudgment is present.
Name the observable evidence or signal that proves what actually happened.
Compare completion criteria or acceptance criteria with the evidence before judging completion quality.
Identify whether the task was well-chosen, too vague, too large, blocked, avoided, or lower-value than expected.
Do not blame the user.
Return a concise calibration note and one recommendation for today's quest design.
The calibration note must include the original prediction, actual evidence, evidence gained, judgment update, observable evidence or signal, and completion criteria or acceptance criteria evidence.
The recommendation must name the next calibration action, test, or observable signal to watch; do not return generic encouragement.
```

Output:

```json
{
  "calibration_note": "string",
  "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
  "recommendation": "string"
}
```

## Prompt 6: Extract Principle Candidate

Purpose:

- Identify whether today's reflection contains one reusable action rule.

Instruction:

```text
From the confirmed cards, answers, and quest, identify at most one reusable principle.
Do not create a principle if the lesson is too situational.
The principle must be concrete enough to apply later.
Frame it as a behavior rule, not a slogan.
The principle must include at least two concrete actions the user can do next time.
The success_criteria must name observable evidence, a visible artifact, owner confirmation, acceptance criteria, or another verifiable signal.
Do not return vague slogans such as "keep clear", "be better", or "improve efficiency".
The principle must cite source_card_titles using exact titles from confirmedCards.
Do not invent source_card_titles. If no confirmed card supports the rule, return principle_candidate: null.
```

Output:

```json
{
  "principle_candidate": null
}
```

or:

```json
{
  "principle_candidate": {}
}
```

## Prompt 7: Suggest Project Links

Purpose:

- Suggest project associations from confirmed daily evidence.
- Detect when a new abstract project candidate may be useful.

Instruction:

```text
Review confirmed cards, quests, verifications, principles, and existing active projects.
Suggest at most two project links.
If no existing project fits and the evidence suggests a recurring long-running topic, propose one candidate project name.
Do not use company-sensitive names.
Only link confirmed evidence.
Do not create or merge projects automatically.
Return candidates that require user confirmation.
Do not treat repeated keywords as a project unless there is a recurring goal, blocker, decision pattern, or action standard.
```

Output:

```json
{
  "project_link_candidates": [],
  "new_project_candidates": [
    {
      "name": "string",
      "goal": "string",
      "success_criteria": "string",
      "current_bottleneck": "string",
      "source_ids": ["string"],
      "reason": "string"
    }
  ]
}
```

## Prompt 8: Generate Project Insights

Purpose:

- Produce evidence-backed project progress and thinking-change signals.
- Help Project Detail explain why a project exists and what changed.

Instruction:

```text
Review one project, its confirmed ProjectLinks, related quests, verifications, and principles.
Generate concise progress signals only when there is source evidence.
For thinking_change and blocker_change, compare an earlier source and a later source.
If evidence is insufficient, return an empty list and explain what evidence is missing.
Do not use percentages.
Do not use company-sensitive names.
```

Output:

```json
{
  "project_insights": [],
  "insufficient_evidence_reason": "string | null"
}
```

## Prompt 9: Suggest Project Merge Candidates

Purpose:

- Detect projects that may represent the same long-running topic.

Instruction:

```text
Review active projects and their evidence links.
Suggest merge candidates only when goal, current bottleneck, success criteria, or repeated evidence strongly overlaps.
Name similarity alone is not sufficient.
Explain why merging helps and what may be lost.
Never merge automatically.
```

Output:

```json
{
  "merge_candidates": []
}
```

Client validator:

- `TodayAIResponseParser.parseProjectMergeCandidates(from:)` requires valid source/target project UUIDs, distinct projects, a non-empty reason, and non-empty overlapping evidence refs.

## Prompt 10: Weekly Calibration

Purpose:

- Generate a weekly Growth attribution report with strict evidence traceability.

Instruction:

```text
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
```

Context payload (rendered from typed `PromptContextPayload.growth`):

| Key | Type | Description |
|-----|------|-------------|
| period | string | "weekly" |
| complete_loop_count | int | number of completed daily loops |
| record_count | int | number of daily records in scope |
| evidence_summaries | string | newline-separated summaries per daily entry (entry id, card count, quest, verification) |
| previous_clarity etc. | string | previous metric scores if available |
| dismissed_contributions | string | semicolon-separated titles of previously dismissed contributions |

Output schema:

```json
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
```

Insufficient evidence output:

```json
{
  "insufficient_evidence": true,
  "summary": "string: explain what is missing",
  "metrics": {},
  "metric_contributions": [],
  "next_training_focus": "string"
}
```

Client validator:

- `TodayAIResponseParser.parseGrowthReport(from:period:completeLoopCount:)` parses report into `GrowthReportResult` containing a `MetricSnapshot` and `[MetricContribution]`.
- Contributions without valid `source_type`, `source_id`, or `source_daily_entry_id` UUID are rejected.
- Delta values are clamped to [0.01, 0.30].
- `insufficient_evidence=true` produces `MetricSnapshot(status: .insufficientEvidence)` with no numeric score display.

## Prompt 11: Monthly Growth Report

Purpose:

- Generate a monthly Growth attribution report comparing current period against baseline.

Instruction:

```text
Compare this month's records against baseline and early-month examples.
Produce a strict Growth attribution report.

Rules:
- Growth is an attribution ledger, not a personality test.
- Fewer than 3 complete loops: return insufficient_evidence=true.
- Every score delta must be explained by positive or negative metric_contributions.
- Every contribution MUST include source_type, source_id, and source_daily_entry_id.
- A contribution without source evidence must be omitted.
- Delta per contribution must be between 0.01 and 0.30.
- Use before/after evidence.
- Do not present scores as objective intelligence measures; present them as personal trend indicators.
```

Context payload: same as weekly calibration with period="monthly".

Output schema: identical to weekly calibration.

Client validator: same `parseGrowthReport` parser.

## Future Extension: Custom Lens Packs

MVP ships with fixed first-party lenses. The long-term design should treat lenses as versioned prompt assets, not hardcoded UI choices.

Lens pack fields:

```json
{
  "id": "string",
  "name": "string",
  "author": "user | official | community",
  "version": "string",
  "description": "string",
  "use_cases": ["string"],
  "system_prompt": "string",
  "question_style": "socratic | first_principles | contrarian | checklist | custom",
  "safety_notes": ["string"],
  "visibility": "private | shared_link | marketplace",
  "created_at": "date",
  "updated_at": "date"
}
```

Rules:

- Custom lenses may guide questions, but cannot silently override privacy boundaries.
- Community/marketplace lenses must be copied into the user's local library before use, so later marketplace edits do not mutate past records.
- Daily records should store the lens id and version used for that session.
- First-party examples can include Socratic questioning, first principles, inversion, pre-mortem, opportunity cost, and decision journal review.
