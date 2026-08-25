# Coach Turn State v1 Audit

Date: 2026-06-23

Scope: audit the milestone that upgrades `coachDiagnosis` from a one-shot recommendation into a Today-local stateful coach turn.

## Result

Coach Turn State v1 is the active milestone for the next MingSi slice. The intended product behavior is:

- MingSi maintains the coach turn across confirmed cards, follow-up answers, and quest generation.
- The coach can decide that the user is `not_ready` and should clarify or close evidence gaps before converging.
- A user override means permission to proceed, not proof that the coach was wrong.
- State transitions remain local, deterministic, auditable, and testable. The current vNext product contract routes meaningful diagnosis and recommendation through `CentralLLMDecisionCenter`; local state policy is not the authority for model-quality decisions. This audit does not introduce a general chat agent, LangChain/LangGraph, subscription/sync/market expansion, or a database migration.

## Stop Conditions

### 1. Domain State

Status: implemented in current worktree.

Evidence:

- `Sources/Domain/Models.swift` defines `CoachTurnState`.
- `CoachTurnPolicy.policyVersion` is `coach-turn.local-v1`.
- The state records phase, readiness, recommended move, reason, open evidence gaps, baseline checks, decision source, policy version, and turn summary.

### 2. AppStore State Flow

Status: implemented in current worktree.

Evidence:

- `AppStore.prepareTrainingPrescriptionForCurrentCards()` creates the initial coach turn after confirmed cards.
- `AppStore.syncCoachTurnState(with:)` records accept, slow-down, and override decisions.
- `AppStore.refreshCoachTurnStateAfterAnswers()` updates the turn after answers and before quest generation.
- `TodayAIContext` receives `coachTurnState` for question and quest generation.

### 3. Prompt Context Boundary

Status: implemented in current worktree.

Evidence:

- `PromptContextPayload.CoachTurnStateContext` carries the state.
- Legacy compatibility keys include `coachTurnPhase`, `coachTurnReadiness`, `coachTurnRecommendedMove`, `coachTurnOpenEvidenceGaps`, `coachTurnBaselineChecks`, `coachTurnDecisionSource`, `coachTurnPolicyVersion`, and `coachTurnSummary`.
- `TodayAIService` keeps `organizeCards` free of coach turn state.

### 4. Prompt Directives

Status: implemented and documented.

Evidence:

- `PromptDirectives.coachTurnRule` tells the model to clarify or close evidence gaps before converging when the turn is not ready, and to form a verifiable action when ready.
- `docs/prompt-spec.md` documents the same rule and the override boundary.

### 5. Quality Gate

Status: implemented and documented.

Evidence:

- `PromptCoachingQualityIssueReason.missingCoachTurnAlignment` covers questions or quests that ignore coach readiness and recommended move.
- Question evaluation rejects obvious mismatch with not-ready coach turns.
- Quest evaluation rejects quest generation when the coach turn is not ready and the user has not explicitly chosen `userOverrideProgress`.

### 6. Tests

Status: implemented for the critical state paths.

Evidence:

- `AppStoreStateMachineTests` covers insufficient cards, answer-updated readiness, and override audit boundaries.
- `TodayAIServiceContextTests` covers prompt context inclusion and `organizeCards` exclusion.
- `PromptEvalFixtureTests` covers the deterministic quality gate for not-ready coach turns.
- `PromptSpecificationDocumentTests` keeps the prompt spec aligned with the stateful coach design.

### 7. UI Scope

Status: minimal UI only.

Evidence:

- `TodayView` renders the coach reason, evidence gaps, and turn summary inside the existing coach diagnosis / training prescription surface.
- No general chat interface was added.

### 8. Preserved Boundaries

Status: preserved.

Evidence:

- `TrainingPrescription` remains present.
- Growth evidence authority still stays local and auditable.
- Principle recall remains bounded to prompt stages where principles are allowed.
- PromptRun audit boundaries remain in place.
- No CoachTurn database migration is introduced.

### 9. Verification

Status: passed for this milestone specification and current implementation evidence.

Fresh commands:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptSpecificationDocumentTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayTrainingPrescriptionShowsPrimaryFocusAndBaselineChecks
git diff --check
```

Result:

- `PromptSpecificationDocumentTests` focused Coach Turn State coverage passed.
- Full `MingSiTests` passed with 711 executed, 1 skipped, and 0 failures.
- Focused Today UI test passed with 1 executed and 0 failures.
- `git diff --check` passed.

## Next Slice After This Milestone

After Coach Turn State v1, the next design slice should be Coach Context Memory v1: decide which historical principles, lens feedback, and previous coach outcomes should enter a turn, under strict token-cost and evidence-authority limits.
