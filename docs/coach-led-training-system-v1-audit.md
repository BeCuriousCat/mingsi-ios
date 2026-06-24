# Coach-Led Training System v1 Completion Audit

Date: 2026-06-22

Scope: audit the active milestone that upgrades MingSi from a single Coach Training Prescription into a coach-led systematic thinking training system v1.

## Result

The v1 milestone is complete for the current local MVP scope.

The implementation now has:

- A typed thinking-competency model through `ThinkingTrainingDimension` and `BaselineThinkingCheck`.
- A `TrainingPrescription` plan that records coach recommendation, primary/secondary/baseline dimensions, confidence, policy version, alternatives, final lens, source, and override boundary.
- Structured prompt context carrying the coach-led plan to question, quest, and verification generation.
- Deterministic prompt quality gates for evidence gaps, answer use, lens moves, calibration targets, source grounding, selected-lens moves, training-dimension alignment, primary-focus dilution, weak verification notes, weak recommendations, and expected principle-practice assessment.
- Growth/practice attribution roles that distinguish `targetedPractice`, `secondaryPractice`, and `possibleSignal`, with possible signals preserved for review but excluded from local score reinforcement.
- Today UI that presents the coach prescription as the default path, shows primary focus and baseline checks, supports accept/override/skip, and renders override audit copy when the user changes the lens.

This audit does not claim a production-scale adaptive curriculum, remote sync, subscription, marketplace distribution, or live BYOK GLM network acceptance. Those are outside this milestone.

## Stop Condition Evidence

### 1. Thinking Competency / Training Dimension

Status: complete.

Evidence:

- `Sources/Domain/Models.swift` defines `ThinkingTrainingDimension` with fact/interpretation separation, evidence discipline, counterexample seeking, assumption testing, system feedback awareness, judgment calibration, and testable action design.
- `ThinkingLens.primaryTrainingDimension` maps each built-in lens to a primary training dimension.
- `BaselineThinkingCheck.trainingDimension` maps baseline checks back to dimensions.
- `docs/prompt-spec.md` documents `primaryTrainingDimension`, `secondaryTrainingDimensions`, `baselineTrainingDimensions`, and the supported dimension values.
- `Tests/Services/PromptSpecificationDocumentTests.swift` verifies the prompt spec documents these dimensions.

Residual risk:

- The model is rule-based and bounded to the current built-in lens catalog. Future imported lens packs will need explicit training-dimension metadata before they can participate fully in coach-led planning.

### 2. Coach-Led Training Plan

Status: complete.

Evidence:

- `TrainingPrescription` records recommended lens/prompt, reason, confidence, policy version, alternatives, baseline checks, primary dimension, secondary dimensions, baseline dimensions, user-selected lens, final lens, source, and override boundary.
- `LocalTrainingPrescriptionPolicy.prescribe` creates a deterministic local plan from confirmed cards and session mode.
- `PromptContextPayload.TrainingPrescriptionContext` carries the same plan into prompt context and legacy compatibility keys.
- `Tests/Services/TodayAIServiceContextTests.testLocalTrainingPrescription_recommendsCoachLensWithAuditMetadata` verifies recommendation metadata, baseline checks, primary dimension, secondary dimensions, and baseline dimensions.
- `Tests/Services/TodayAIServiceContextTests.testStructuredContext_includesCoachTrainingPrescriptionAndFinalLens` verifies structured prompt context preserves coach recommendation and final lens.
- `Tests/App/AppStoreStateMachineTests.testSelectLens_createsCoachTrainingPrescriptionForConfirmedCards` and related accept/override/skip tests verify app-state behavior.

Residual risk:

- Recommendation policy is intentionally deterministic and conservative. It is not yet an adaptive longitudinal coach that reweights training focus from a full historical curriculum.

### 3. Prompt And Lens Quality

Status: complete.

Evidence:

- `PromptCoachingQualityPolicy` flags weak outputs for missing evidence gap, missing answer use, missing lens move, vague calibration target, missing selected lens move, missing training dimension alignment, missing primary training focus, busywork quests, weak verification calibration notes, weak recommendations, and missing expected-principle practice assessment.
- `TodayAIService` applies training-prescription dimensions during question generation quality checks.
- `docs/prompt-spec.md` documents output fields and quality gate reasons.
- `docs/product-risks-and-design-language.md` defines good question, quest, verification, and principle criteria around evidence gaps, hidden assumptions, disconfirming signals, calibration signals, source grounding, and observable action evidence.
- `Tests/Services/PromptEvalFixtureTests` covers fixed eval cases for evidence gap taxonomy, answer use, lens moves, source grounding, calibration target, selected-lens move, training-dimension alignment, primary-training focus, busywork quests, source grounding, verification calibration note, and verification recommendation.
- `Tests/Services/TodayAIServiceContextTests.testGenerateQuestions_usesTrainingPrescriptionDimensionsForQualityGate` verifies runtime rejection when final-lens output ignores the coach's training dimensions.

Residual risk:

- The deterministic gate is intentionally a local guardrail for obvious regressions. It does not replace human review or model-quality evaluation for nuanced coaching quality.

### 4. Growth Absorption And Non-Over-Attribution

Status: complete.

Evidence:

- `MetricContributionPracticeRole` distinguishes `targetedPractice`, `secondaryPractice`, and `possibleSignal`.
- `PrinciplePracticeEvidence` stores `matchSignal`, `attributionPolicyVersion`, and `practiceRole`.
- `AppStore.recordPrinciplePracticeEvidenceIfNeeded` writes principle practice evidence only from local verification-backed attribution, using `targetedPractice` for user-selected training principles and `secondaryPractice` for local text matches.
- `AppStore.makeLocalGrowthContributions` marks quest/verification evidence as secondary practice, lens answers with a matching stored training prescription as targeted practice, and lens answers without a prescription as possible signal.
- Local Growth snapshot calculation now excludes `possibleSignal` from score reinforcement and positive/negative contribution refs while still saving the contribution for review.
- `Tests/App/AppStoreStateMachineTests.testLoadPersistedState_generatesLocalGrowthSnapshotFromCompletedVerifiedLoops` verifies targeted practice participates in positive refs, verification evidence remains secondary, possible signals are preserved, possible signals do not enter positive refs, and reflection depth is not inflated by possible signals.
- `Tests/App/AppStoreStateMachineTests` also verifies selected training-principle evidence is targeted, automatic matches are secondary, duplicate verification evidence is not written, and disputed practice evidence is excluded from active summaries.
- `docs/product-risks-and-design-language.md` states that only targeted or locally verified secondary practice should reinforce training state while possible signals remain review material.

Residual risk:

- The Growth surface can still be improved to explain possible signals as review material more explicitly, but the core evidence-authority boundary is implemented and tested.

### 5. Coach Authority UI And Override Boundary

Status: complete.

Evidence:

- Today Select Lens is now labeled as `训练处方`, with copy saying MingSi first diagnoses the training focus and then the user can accept, override, or skip.
- `trainingPrescriptionCard` shows coach confidence, recommendation reason, primary training dimension, baseline checks, accept action, and skip action.
- When the user overrides the recommendation, Today renders `改选审计` with the user-facing final lens title and retained coach recommendation title.
- `Tests/UI/MingSiUITests.testTodayTrainingPrescriptionShowsPrimaryFocusAndBaselineChecks` verifies `主练：证据意识`, `底盘检查`, and `证据缺口` render in the real UI.
- `Tests/UI/MingSiUITests.testTodayTrainingPrescriptionOverrideShowsCoachAuditBoundary` verifies the rendered override audit after selecting `反方视角`.

Residual risk:

- Custom/imported lenses can still be selected through the broader lens library. Their coach-led semantics should be improved when imported lens assets carry training dimensions.

### 6. Minimal Eval / Test Set

Status: complete.

Evidence:

- Fixed prompt eval cases cover high-quality questions, evidence gap taxonomy, answer use, lens moves, source-card grounding, calibration target, selected-lens move, training-dimension alignment, primary-focus requirement, quest calibration signals, busywork rejection, quest source grounding, verification judgment update, weak verification note rejection, weak recommendation rejection, principle source grounding, and principle actionability.
- Service/runtime tests cover training prescription context, training-dimension quality gate usage, selected/final lens usage, quest quality gates, verification quality gates, and expected-principle practice assessment.
- State-machine tests cover coach prescription creation, accept/override/skip, prompt context wiring, local Growth role attribution, and possible-signal non-reinforcement.
- UI tests cover rendered primary focus, baseline checks, accept path, and override audit boundary.
- Current verification commands are recorded in `docs/verification-log.md`.

Residual risk:

- The eval suite is deterministic and fixture-based. Live GLM acceptance remains an external Alpha prerequisite, not a blocker for this local MVP milestone.

## Verification Commands

Fresh verification for this audit:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_generatesLocalGrowthSnapshotFromCompletedVerifiedLoops
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
git diff --check
```

Result:

- Focused Growth boundary test passed with 1 test, 0 failures.
- Full `MingSiUITests` passed with 19 tests, 0 failures.
- Full `MingSiTests` passed with 697 tests, 1 skipped, and 0 failures.
- `git diff --check` passed.
