# Coach Training Feedback v2 Design

Date: 2026-06-29

## Goal

Make the Today review loop feel more like coaching and less like an AI answer.
The first Coach Training Loop v2 implementation slice focuses on the moment
after the user answers a coach question.

The user should see:

1. What they just repaired.
2. What thinking material is still missing.
3. Whether the turn can move into tomorrow validation.
4. The exact next sentence or material to add if it cannot move forward.
5. Whether recalled past experience should be reproduced, adapted, or rejected.

This is not a new feature surface, not a chat agent, and not a new lens pack.
It is a tightening of the existing Today coaching loop.

## Context

Current code already has:

- `CoachObservationPolicy` for local material/gap diagnosis.
- `CoachTurnPolicy` and `CoachTeachingPolicy` for turn readiness and route copy.
- `CoachAnswerTrainingFeedback` surfaced in Today after answers.
- Prompt quality gates for non-appeasement and training language.
- Rendered UI tests proving Today stage boundaries, question teaching cues,
  answer input, coach gap preview, quest calibration target, and result
  calibration copy.

The current weakness is consistency. The docs define the desired feedback shape,
but the implementation still risks expressing it as scattered labels instead of
one stable teaching contract.

## Considered Approaches

### Approach A: UI copy polish only

Add more explanatory text to `TodayView`.

Trade-off: fastest, but it leaves the actual teaching contract implicit and
fragile. Future prompt or policy changes could drift away from the desired
coach shape without failing tests.

### Approach B: Domain feedback contract first

Make `CoachAnswerTrainingFeedback` carry explicit fields for repaired material,
remaining gap, readiness decision, next repair sentence, and experience replay
classification prompt. Then render those fields in Today and cover them with
domain, prompt spec, and UI tests.

Trade-off: slightly more code, but it keeps the coaching logic testable and
prevents UI-only training language from becoming decorative.

### Approach C: LLM-authored feedback

Ask the model to produce the whole answer-feedback frame.

Trade-off: expressive, but too early. It would make the core training decision
less deterministic and could reintroduce appeasement or generic coaching unless
we add a stricter local contract first.

## Recommended Design

Use Approach B.

The implementation should create a stable local feedback contract and use LLM
only downstream. The coach's teaching logic remains local, inspectable, and
auditable. Prompt assets may refer to the same shape, but they do not become the
source of truth for whether the user is ready to proceed.

## Scope

In scope:

- Extend or normalize `CoachAnswerTrainingFeedback` so it exposes these fields:
  - `repairedMaterialLine`
  - `remainingGapLine`
  - `readinessLine`
  - `nextRepairSentence`
  - `experienceReplayDecisionPrompt`
- Update `CoachTeachingPolicy` or the existing answer-feedback builder to fill
  those fields from `CoachTurnState`, `TrainingPrescription`, `CoachObservation`,
  and current answers.
- Render the fields together in Today after the answer input.
- Keep copy framed as training, not approval:
  - `你刚补上`
  - `当前仍缺`
  - `能否进入明日验证`
  - `下一句修补`
  - `过往经验复现`
- Keep one primary gap per turn while allowing baseline checks to remain visible.
- Add focused tests before production changes.

Out of scope:

- No general chat UI.
- No LangChain/LangGraph.
- No new persistence unless an existing resume-state test fails.
- No subscription, sync, marketplace, or remote registry work.
- No LLM-created long-term practice evidence.
- No broad visual redesign.

## Data Flow

```text
confirmed cards
  -> CoachObservationPolicy
  -> CoachTurnPolicy / CoachTeachingPolicy
  -> CoachAnswerTrainingFeedback v2
  -> Today answer feedback section
  -> generateQuests context only if readiness allows or user overrides
```

The feedback contract should not be a raw prompt dictionary. It should remain a
typed Swift value that can be asserted in unit tests and reused by prompt context
assembly.

## UX Contract

After the user types an answer, Today should show one compact feedback frame:

```text
你刚补上：A
当前仍缺：B
能否进入明日验证：可以 / 不能，因为 C
下一句修补：D
过往经验复现：复现 / 调整 / 否定，先判断旧经验是否适用
```

The copy may be more polished in the UI, but the five parts must remain visible.
The purpose is to make the user feel:

> MingSi is not judging whether my answer is pleasing. It is showing which
> thinking material moved, which gap remains, and what exact repair move trains
> the ability.

## Testing Plan

Follow TDD.

1. Add a failing `AppStoreStateMachineTests` case where a thin answer partially
   repairs the gap but is not ready. Expected feedback includes all five fields
   and blocks progression.
2. Add a failing domain test where a stronger answer closes the current gap.
   Expected feedback says the turn can proceed and names the tomorrow validation
   handoff.
3. Add a failing test for experience replay copy. A recalled principle or
   experience signal must ask for reproduce/adapt/reject rather than treating
   the old experience as authority.
4. Update implementation minimally until the tests pass.
5. Run focused tests:
   - `xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests`
6. If rendered copy changes in Today, run the focused UI test that covers answer
   teaching cues or add one narrow UI assertion if needed.

## Acceptance Criteria

- The five-part answer feedback contract exists in typed code.
- The user-facing Today screen renders the five parts together after an answer.
- The coach still refuses to proceed when the answer lacks required evidence.
- Experience replay is framed as reproduce/adapt/reject, not passive recall.
- Focused tests fail before implementation and pass after implementation.
- The worktree remains clean after commit.

## Self-Review Notes

- No placeholder requirements remain.
- The slice is intentionally narrower than the full Coach Training Loop v2 goal.
- The design does not introduce a new surface or external dependency.
- The design keeps deterministic local policy as the authority and LLM output as
  downstream explanation.
