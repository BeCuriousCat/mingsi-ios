# 明思 Prompt Specification

## Prompt Architecture

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

## Prompt 1: Organize Raw Input Into Cards

Purpose:

- Convert messy daily input into editable thinking cards.
- Preserve uncertainty.
- Flag possible sensitivity.

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

Output:

```json
{
  "cards": [],
  "sensitivity_notes": [],
  "transcript_quality": "low | medium | high",
  "recommended_next_step": "string"
}
```

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

## Prompt 7: Weekly Calibration

Purpose:

- Detect weekly patterns in thinking and execution.

Instruction:

```text
Analyze confirmed daily records and quest verifications for the week.
Identify highest-value action, lowest-value time sink, repeated blocker, repeated thinking pattern, and recommended training focus for next week.
Use evidence snippets from confirmed cards, quests, or verifications.
Avoid vague praise.
```

Output:

```json
{
  "highest_value_action": "string",
  "lowest_value_time_sink": "string",
  "repeated_blocker": "string",
  "thinking_pattern": "string",
  "next_week_focus": "string",
  "evidence": []
}
```

## Prompt 8: Monthly Growth Report

Purpose:

- Show visible changes in the user's thinking and execution.

Instruction:

```text
Compare this month's records against baseline and early-month examples.
Show changes in clarity, value judgment, execution reliability, calibration, and reflection depth.
Use before/after evidence.
Do not present scores as objective intelligence measures.
Present them as personal trend indicators.
```

Output:

```json
{
  "clarity": {},
  "value_judgment": {},
  "execution_reliability": {},
  "calibration": {},
  "reflection_depth": {},
  "before_after_examples": [],
  "next_month_focus": "string"
}
```
