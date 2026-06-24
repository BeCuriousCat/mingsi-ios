# Coach Core Alpha Design

Date: 2026-06-24

## Purpose

Coach Core Alpha moves MingSi from a prompt-assisted reflection app into a
stateful thinking coach. The next stage should not optimize for more tabs,
more lenses, sync, marketplace, or subscription. It should optimize for one
product capability:

> MingSi can judge whether the user is ready to converge, ask the next useful
> question, turn the result into a verifiable action, and learn from the next
> verification loop.

This document is the design contract for the next implementation slice.

## Current Baseline

The current app already has the first coach-led scaffolding:

- `CoachEngine` diagnoses the current cards into a thinking phase, readiness,
  and next move.
- `TrainingPrescription` records the coach-recommended lens, final lens,
  primary training dimension, baseline checks, confidence, and override
  boundary.
- `CoachTurnState` keeps Today-local coach state across confirmed cards,
  answers, and quest generation.
- `PromptCoachingQualityPolicy` rejects obvious non-coaching outputs such as
  generic questions, missing evidence gaps, missing lens moves, missing source
  grounding, weak quest criteria, weak verification notes, and outputs that
  ignore coach readiness.
- Verified lens outcomes can enter prompt context as bounded `lensFeedback`.

The baseline is correct but still coarse. The current policy depends heavily on
card type counts, keyword signals, and fixed guardrails. Alpha should make the
coach decision itself more explicit and more inspectable.

## Product Principles

### 1. Diagnose Before Advising

The coach must decide what kind of thinking state the user is in before asking
or recommending anything. It should not skip from raw input to advice.

The diagnosis must answer:

- Is the problem defined?
- Is there enough evidence to converge?
- Is the user prematurely converging?
- Which thinking ability should be trained now?
- What answer would make it safe to proceed?

### 2. One Primary Training Focus

Each loop has one main training focus. Baseline checks remain active, but they
must not turn the session into a broad questionnaire.

The user should feel a clear training arc:

```text
today's material -> coach diagnosis -> one primary question -> verifiable action -> next-day calibration
```

### 3. Questions Must Be Functional

A MingSi question is valid only if its answer can change the next state. A good
question must carry three fields:

- `why_now`: why this question is the right next move in this coach turn.
- `expected_update`: what judgment, action, evidence plan, or calibration signal
  the answer is expected to change.
- `proceed_when`: what kind of answer is sufficient to move toward action.

These fields complement the existing `why_this_matters`, `answer_use`,
`evidence_gap_type`, `lens_move`, source grounding, and calibration target.

### 4. Quests Are Calibration Instruments

A quest is not a generic task. It should test one judgment, close one evidence
gap, or produce one observable signal. Completion criteria must define what
evidence will exist tomorrow.

### 5. Verification Teaches The Coach

Next-day verification should update future coaching. It should not only archive
whether the user finished. It should identify:

- which `lens_move` produced useful evidence and should be reinforced;
- which `lens_move` was low-value or uncalibratable and should be avoided;
- which move needs adjustment because it was partially useful;
- whether the user frequently overrides the coach recommendation for a specific
  dimension or lens.

### 6. Growth Absorbs Evidence Conservatively

Growth must distinguish actual practice from possible signals:

- `targetedPractice`: the user intentionally practiced the prescribed focus.
- `secondaryPractice`: local evidence supports a related practice signal.
- `possibleSignal`: useful review material, but not score reinforcement.

LLM output may explain verification, but local policy remains the authority for
training evidence and reinforcement.

## Coach Decision Matrix

`CoachDecisionPolicyV2` should be a pure domain policy. It does not call the
LLM, does not import SwiftUI, and does not write persistence. It evaluates cards,
answers, selected/final lens, current turn state, and bounded lens feedback.

The policy should score these axes:

| Axis | What It Measures | Example Signals | Product Effect |
| --- | --- | --- | --- |
| Evidence readiness | Whether there is enough observable evidence to proceed | fact cards, baseline, source titles, explicit evidence, answer closes gap | ready vs not ready |
| Convergence risk | Whether the user is acting before the judgment is grounded | high-risk/problem cards, weak evidence, unsupported decision | slow down or surface gap |
| Calibration opportunity | Whether there is a prediction/confidence/outcome mismatch to learn from | prediction, confidence, expected/actual result, judgment update | judgment calibration focus |
| System feedback | Whether the case involves loops, delays, downstream effects, or repeated rework | feedback loop, delay, second-order consequence, repeated rework | system thinking focus |
| Action testability | Whether the next step can create tomorrow's evidence | owner, acceptance criteria, observable signal, small experiment | generate quest |
| Historical learning signal | Whether previous lens moves should be reinforced, adjusted, or avoided | verified `lensFeedback`, value rating, completion, user overrides | tune next question |

The output should include:

- `policyVersion`
- `phase`
- `readiness`
- `recommendedMove`
- `primaryTrainingDimension`
- `openEvidenceGaps`
- `convergenceRisk`
- `decisionScores`
- `reason`
- `whyNow`
- `expectedUpdate`
- `proceedWhen`
- `learningSignals`

## Question Quality Standard

The generate-questions prompt and quality gate should require every question to
answer:

```json
{
  "question": "string",
  "why_this_matters": "string",
  "why_now": "string",
  "expected_update": "string",
  "proceed_when": "string",
  "evidence_gap_type": "missing_observation | missing_baseline | missing_causal_link | missing_counterexample | missing_constraint | missing_calibration_signal | none",
  "answer_use": "update_judgment | choose_action | test_assumption | collect_evidence | watch_calibration_signal",
  "lens_move": "fact_interpretation_split | alternative_explanation | leverage_tradeoff | constraint_decomposition | feedback_loop | delayed_effect | second_order_consequence | prediction_calibration",
  "source_card_titles": ["string"],
  "calibration_target": "string",
  "expected_answer_type": "fact | judgment | tradeoff | validation"
}
```

Quality gates should reject:

- missing `why_now`;
- missing `expected_update`;
- missing `proceed_when`;
- generic `why_now` that does not reference the coach turn or evidence gap;
- generic `expected_update` that does not say what changes;
- vague `proceed_when` such as "when it feels clear".

## Verification-To-Learning Loop

Verification should produce or support a local learning signal:

```text
quest lens_move + completion + value rating + calibration note
-> lens learning signal
-> capped lensFeedback in the next relevant prompt
```

Recommended mapping:

| Verification Result | Learning Signal | Next Prompt Effect |
| --- | --- | --- |
| done + high value + specific evidence gained | reinforce | reuse this lens move when current cards fit |
| partial/done + medium/uncertain value | adjust | ask a smaller or more observable version next time |
| missed or low value or no evidence gained | avoid | do not repeat the same move/target pattern |
| user override before action | override audit | preserve user choice but do not treat it as coach error |

The learning signal should target a specific `lens_move` and calibration target,
not the entire lens.

## Implementation Milestones

### Milestone 1: Design Contract

Create this document and keep `docs/prompt-spec.md`,
`docs/prompt-context-engineering-prd.md`, and
`docs/product-risks-and-design-language.md` aligned with it.

### Milestone 2: Coach Decision Policy v2

Add pure domain types and policy tests for:

- insufficient evidence;
- premature convergence;
- judgment calibration;
- system feedback;
- actionable state.

The policy should not replace existing `CoachEngine` immediately. It should be
introduced as an inspectable decision kernel that can later back `CoachTurnState`.

### Milestone 3: Question Contract Upgrade

Add `whyNow`, `expectedUpdate`, and `proceedWhen` to `ReflectionQuestion`,
parser DTOs, prompt schema, prompt docs, fixed eval fixtures, and quality gates.

### Milestone 4: Verification Learning Signal

Add a local policy that derives lens-learning signals from verified quest
outcomes and user override audit data. Feed bounded results into existing
`lensFeedback` context instead of adding raw history to prompts.

## Non-Goals

This Alpha slice does not include:

- general chat agent UI;
- LangChain or LangGraph;
- remote prompt or lens marketplace work;
- subscription, sync, or commercial gates;
- Growth score redesign;
- broad UI redesign.

The target is the coach core, not surface expansion.

## Acceptance Criteria

- A repo document defines Coach Core Alpha.
- A pure domain policy classifies the five required states through tests.
- Questions have required functional fields and the parser preserves them.
- Quality gates reject questions missing those fields.
- Verification can create a bounded lens-learning signal for future coaching.
- No UI change is required for this slice.
