# Coach Teaching UX Alpha Design

Date: 2026-06-25

## Goal

Coach Teaching UX Alpha upgrades MingSi from "the coach can decide the next
move" to "the user can feel that MingSi is training their thinking."

The goal is not to add more features, tabs, lenses, or chat. The goal is to make
the existing Today loop show:

- what the user has not thought through yet;
- why that gap matters before action;
- which thinking move is being trained now;
- how past experience or principles should be replayed, challenged, or rejected.

The product promise remains:

> MingSi does not think for the user. MingSi trains the user to see the missing
> part of their own thinking, answer the next useful question, and turn the
> result into verifiable action.

## Current Baseline

The current main branch already has the necessary coaching substrate:

- `CoachTurnState` records phase, readiness, recommended move, evidence gaps,
  baseline checks, decision source, policy version, and turn summary.
- `CoachDecisionPolicyV2` scores evidence readiness, convergence risk,
  calibration opportunity, system feedback, action testability, and historical
  learning signals.
- `TrainingPrescription` records the coach recommendation, final lens, primary
  training dimension, baseline checks, confidence, and override boundary.
- `ReflectionQuestion` carries `whyNow`, `expectedUpdate`, `proceedWhen`,
  `evidenceGapType`, `answerUse`, `lensMove`, source grounding, and calibration
  target.
- `ReferencedPrinciplesView` already shows recalled active principles and lets
  the user mark recall feedback.

The gap is not lack of data. The gap is expression. Much of the teaching logic is
currently internal, while the user mostly sees cards, questions, and actions.
Alpha should make the training route visible without turning Today into a
general AI chat surface.

## Product Principles

### 1. Training Before Answers

MingSi should not sound like it is giving advice. It should say what thinking
move is missing and why the user should practice it now.

Good:

```text
本轮漏想点：你已经有行动倾向，但还没有说明可观察证据。
```

Bad:

```text
AI 建议你明天先找负责人沟通。
```

### 2. Diagnose The Missing Move

Every coach-facing surface should answer:

- What part of the user's thinking is currently underdeveloped?
- What evidence, counterexample, baseline, constraint, feedback loop, or
  calibration signal is missing?
- What answer would let the loop safely proceed?

### 3. One Primary Lesson, Quiet Baseline Checks

Each Today loop has one primary teaching focus. Baseline checks remain visible
only as supporting context. The UI must not become a list of competencies.

### 4. Experience Replay, Not Source Citation

When past principles are recalled, the user should experience them as practice:

```text
这次是否要复现这条经验？
```

not as passive context:

```text
AI 参考了这条原则。
```

The user must be able to say the principle applies, does not apply, was
misrecalled, or needs adjustment.

### 5. Calm Working Surface

This is a native thinking workspace, not a chatbot. UI changes should be dense,
quiet, and legible:

- no chat bubbles;
- no new tab;
- no nested card stacks;
- no decorative hero or marketing copy;
- no broad redesign of Today.

## Recommended Slice

Implement the narrow B + A slice:

1. **B: Training route in Select Lens / training prescription.**
   The user sees the coach diagnosis before answering questions.
2. **A: Teaching cue inside each question card.**
   Each question shows what it trains, what gap it closes, and what answer is
   enough to continue.

This slice gives the user an immediate sense that MingSi is coaching a thinking
process, while reusing existing state and prompt contracts.

## UX Design

### Teaching Diagnosis

In the training prescription area, show a user-readable diagnosis derived from
the current coach state.

Required content:

- `本轮漏想点`: the missing thinking move or evidence gap.
- `训练目标`: the primary thinking dimension.
- `为什么不是直接给答案`: why the coach is slowing down or routing through a
  lens.
- `推进标准`: what kind of answer or evidence makes it safe to proceed.

Example for not-ready evidence state:

```text
本轮漏想点：你已经有行动倾向，但还没有说明可观察证据。
训练目标：证据意识。
为什么不是直接生成任务：现在行动会把未经验证的解释当成事实。
推进标准：先说清一个可观察事实和一个验收基线。
```

Example for ready action state:

```text
本轮漏想点：不是继续分析，而是把判断转成明天能留下证据的行动。
训练目标：可验证行动设计。
为什么不是继续追问：当前证据已经足够形成小实验。
推进标准：明日行动能留下负责人、验收标准和可观察结果。
```

Example for user override:

```text
本轮漏想点：证据缺口仍然存在，但你选择先推进。
训练目标：带着审计边界行动。
为什么保留提示：override 是推进许可，不是缺口已经消失。
推进标准：任务必须留下可回看证据，方便明天校准。
```

### Training Route

The existing training prescription card should read more like a route than a
recommendation.

Route examples:

- Not ready:
  1. 补上一个可观察事实
  2. 回答校准问题
  3. 再形成明日验证行动
- Ready:
  1. 固定当前判断
  2. 设计一个明日小实验
  3. 明天用结果校准判断
- Override:
  1. 记录用户主动推进
  2. 保留未关闭缺口
  3. 明天重点验证这个缺口是否造成偏差

The route should be compact. It should not add a new state-machine step.

### Question Teaching Cue

Each question card should show a compact teaching cue before or below the
answer field.

Required content:

- `训练动作`: localized `lensMove`.
- `补的缺口`: localized `evidenceGapType`, or "取舍/框架问题" when none.
- `为什么现在问`: `whyNow`.
- `答案会改变`: `expectedUpdate`.
- `推进标准`: `proceedWhen`.

The cue should be scannable, not a wall of text. It can use short rows or a
quiet grouped surface inside the question card.

### Experience Replay Cue

When active principles are recalled, the section should be reframed from
reference material to experience replay.

Current semantic direction:

```text
本次参考的原则
```

Target semantic direction:

```text
过往经验复现
这次先判断：这条经验是否应该复现？
```

Feedback copy should map to the current stored feedback values without requiring
a migration in v1:

- `.helpful` -> `适用，今天要复现`
- `.notApplicable` -> `场景不同，不复现`
- `.misrecalled` -> `召回错了`

If adding an explicit "needs adjustment" value requires a model or persistence
migration, defer it. v1 can use the existing note field to capture adjustment
text.

## Domain And Data Design

### Teaching Diagnosis Policy

Add a pure domain helper rather than putting teaching copy directly in SwiftUI.
The helper can be named `CoachTeachingPolicy` or equivalent.

Inputs:

- `CoachTurnState`
- `TrainingPrescription?`
- `CoachDecisionAssessment?` when available later

Output:

- `missingMoveTitle`
- `trainingTargetTitle`
- `whyNotAnswer`
- `proceedStandard`
- `routeSteps`
- `auditNote?`
- `policyVersion`

The first implementation can derive from `CoachTurnState` and
`TrainingPrescription` only. It should not call the LLM, SwiftUI, persistence,
or networking.

### Question Teaching Cue

No new model is required in v1. `ReflectionQuestion` already has the fields.
The UI can render from:

- `lensMove`
- `evidenceGapType`
- `whyNow`
- `expectedUpdate`
- `proceedWhen`

If a legacy persisted question lacks one of these fields, show the row only when
data exists. Prompt quality gates already protect new generated questions.

### Experience Replay

No persistence migration is required in v1. Reuse current principle recall
feedback values and note text.

Future work may introduce a dedicated `needsAdjustment` feedback value, but this
slice should not block on it.

## Prompt And Quality Design

The current prompt already requires functional question fields. This slice should
not broaden the prompt surface unless implementation discovers a mismatch.

Required prompt/document alignment:

- `docs/prompt-spec.md` should describe that `why_now`, `expected_update`, and
  `proceed_when` are user-visible teaching fields, not only parser fields.
- `docs/product-risks-and-design-language.md` should state that recalled
  principles are experience replay cues, not passive references.

Quality gate behavior should remain deterministic:

- missing functional question fields remain invalid;
- question teaching UI should not weaken parser or quality gate requirements;
- no LLM output may directly confirm principle practice evidence.

## UI Boundary

Allowed:

- Update training prescription/coach diagnosis copy and layout inside Today.
- Add a compact teaching diagnosis/route block.
- Add compact teaching rows inside `QuestionCardView`.
- Rename/reframe recalled principles section as experience replay.
- Add accessibility identifiers only when tests need stable handles.

Not allowed:

- New Today state.
- New tab.
- General chat UI.
- Broad visual redesign.
- New lens catalog expansion.
- Growth score redesign.
- Remote sync, subscription, marketplace work.

## Tests And Acceptance Criteria

### Domain Tests

Add focused tests for the teaching policy:

- Evidence-not-ready state produces a missing evidence diagnosis and route that
  starts with evidence collection.
- Ready/actionable state produces a route that forms a verifiable tomorrow
  action.
- User override state preserves an audit note that says override is permission
  to proceed, not proof that gaps disappeared.

### UI Tests

Add or update Today UI tests so rendered UI proves:

- `SelectLens` shows the training route and missing-move diagnosis.
- `AnswerQuestions` shows at least one teaching cue row sourced from
  `whyNow`, `expectedUpdate`, and `proceedWhen`.
- Recalled principles section uses "过往经验复现" or equivalent experience replay
  language.

### Service / Prompt Tests

Add or update tests so docs and prompt templates remain aligned:

- Prompt spec documents question fields as teaching fields.
- Product risk/design language documents experience replay.

### Non-Regression

Before accepting implementation:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
```

If UI test target is unavailable in a given environment, run the closest focused
rendered Today tests and document the gap in `docs/verification-log.md`.

## Milestones

### Milestone 1: Teaching Policy Contract

Create a pure domain teaching policy that maps coach turn and training
prescription into a user-visible teaching diagnosis and route.

Stop when domain tests prove evidence-not-ready, ready/actionable, and override
states.

### Milestone 2: Today Teaching Surfaces

Render the teaching diagnosis/route in the training prescription area and render
question teaching cues in question cards.

Stop when focused UI or state-machine tests prove the text appears in the
expected Today steps.

### Milestone 3: Experience Replay Reframe

Reframe recalled principle UI copy as experience replay and keep existing
feedback values wired.

Stop when tests prove recalled principles no longer look like passive AI
references.

### Milestone 4: Documentation And Verification

Align prompt/product docs and record verification evidence.

Stop when focused tests, full unit tests, UI tests when available, and
`git diff --check` pass.

## Out Of Scope Follow-Ups

- Adaptive curriculum across many days.
- Dedicated teaching dashboard.
- Principle adjustment feedback enum/migration.
- Rich visual skill tree or ability map.
- Remote prompt/lens delivery.
- Open-source packaging.

These may be useful later, but they are not required to make the next Today loop
feel like coaching.
