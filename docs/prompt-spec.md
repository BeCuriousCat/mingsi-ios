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
  "expected_answer_type": "fact | judgment | tradeoff | validation"
}
```

### Quest

```json
{
  "type": "main | side | observation",
  "title": "string",
  "why_it_matters": "string",
  "completion_criteria": "string",
  "expected_resistance": "string",
  "reflection_question": "string",
  "linked_cards": ["string"]
}
```

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
Identify whether the task was well-chosen, too vague, too large, blocked, avoided, or lower-value than expected.
Do not blame the user.
Return a concise calibration note and one recommendation for today's quest design.
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

Context payload (passed via jsonPayload):

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
