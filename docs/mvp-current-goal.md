# MingSi MVP Current Goal

Date: 2026-06-23

## Active Codex Pursuit Goal

MingSi is being upgraded from a user-selected thinking-lens toolbox into a stateful coach-led training system. The current product direction is not "pick a lens and ask a prompt"; it is "let the coach maintain the current thinking turn, decide whether the user is ready to converge, and guide the next move."

This repo is also dogfooding a second, separate framework project: Codex-to-Claude Code managed delegation. The framework is a tooling project, not a MingSi feature. It should be generic enough to extract later and must not bake MingSi business semantics into its skill or wrapper contract.

Current Codex goal:

> Coach Turn State v1: upgrade the `coachDiagnosis` already entering LLM context into a Today-local stateful coach turn. MingSi should maintain a testable state across confirmed cards, follow-up answers, and quest generation: current phase, readiness, recommended move, open evidence gaps, baseline checks, user decision or override, policy version, and a turn summary.

This means the product is not trying to maximize the number of lenses or prompts. It is trying to maximize high-quality thinking calibration:

- MingSi, not the user, should carry the primary diagnostic burden for deciding what thinking ability to train next.
- The user's role is to confirm, override, or reject the recommendation, not to self-diagnose from a menu before the coach has spoken.
- A single loop should keep one primary training focus, but every loop must still check the baseline thinking foundation: fact/interpretation separation, evidence gaps, counterexamples, assumptions, testable action, feedback signal, and judgment update.
- The coach must be allowed to slow the user down. If the current turn is `not_ready`, the next move should be clarification or evidence collection before action generation.
- User override means "I choose to proceed anyway"; it does not prove the coach diagnosis was wrong.
- Growth absorption must distinguish `targetedPractice`, `secondaryPractice`, and `possibleSignal`; LLM observations alone cannot become high-confidence practice evidence.
- Recommendation rules, confidence, versions, and user overrides must be auditable and testable before they affect prompts or long-term growth summaries.

## Current Stop Condition

The next milestone can stop only when MingSi has a coherent Coach Turn State v1:

- A `CoachTurnState` or equivalent pure domain model records coach phase, readiness, recommended move, open evidence gaps, baseline checks, user decision or override, policy version, and turn summary.
- `AppStore` creates or refreshes the coach turn after confirmed cards, updates it after follow-up answers, and passes the latest state into `generateQuestions` and `generateQuests`.
- `PromptContextPayload` / `TodayAIContext` carry the latest coach turn state, while `organizeCards` remains clean and receives no coach state or historical principles.
- Prompt directives use coach turn state: `not_ready` means clarify or close evidence gaps first; `ready` means form a verifiable action; override is permission to proceed, not proof that the coach was wrong.
- Prompt quality gates reject obvious outputs that ignore coach phase, readiness, or recommended move.
- Tests cover insufficient cards -> clarification, evidence gap -> evidence question, answer closes gap -> action readiness, user override -> audit boundary, and `organizeCards` -> no coach state.
- UI remains minimal: show why MingSi is slowing down or moving forward, without building a general chat agent.
- Existing boundaries remain intact: `TrainingPrescription`, Growth evidence authority, principle recall boundary, PromptRun audit, and no database migration unless resume-state tests prove it is required.
- Verification passes focused tests, full `MingSiTests`, and relevant `MingSiUITests` when UI copy changes.

## Current Stage Priority

The repo is past raw skeleton work and past the first prompt/context assetization slices. Current priority is coach-led training design:

1. Keep the Today coach loop stateful before adding a general chat surface.
2. Implement local, deterministic coach-turn rules before relying on LLM diagnosis.
3. Keep the user in control through accept/override/slow-down/proceed, but make the coach recommendation the default path.
4. Preserve structured Prompt/Context asset versioning, eval, rollback, and PromptRun audit.
5. Keep PrinciplePracticeEvidence writes local and auditable; LLM may explain, not authoritatively confirm evidence.
6. Defer marketplace, subscription, sync, and broad lens-pack expansion until the coach-led loop is coherent.

## Current Implementation Bias

- Prefer small, testable slices.
- Use TDD for behavior changes and keep prompt/context schema changes versioned.
- Start with deterministic local recommendation policy so the coach's reasoning is inspectable.
- Treat manual user lens choice as override feedback that may improve future recommendations.
- Treat `CoachTurnState` as Today orchestration state first; do not persist it unless resume tests prove durable state is required.
- Keep baseline thinking checks quiet in the UI and explicit in prompt/context.
- Do not write secondary or possible growth signals as high-confidence evidence without local policy and user-auditable support.

## Active Constraints

- Dirty worktree is expected. Do not revert unrelated Codex, Claude Code, GLM, or user changes.
- SwiftUI views must not directly import GRDB or call `LLMClient`.
- No fake data may stand in for missing Project or Growth evidence.
- Prompt outputs that affect Projects or Growth must carry source ids.
- History remains the source evidence archive for Project and Growth drilldown.
- User-selected lenses must not become the only training authority; coach recommendation and final user choice should both be recorded.
- LLM output must not directly create or confirm `PrinciplePracticeEvidence`, targeted practice, secondary practice, or long-term growth claims.
- Do not introduce LangChain/LangGraph for this milestone. The state machine should stay local, deterministic, auditable, and testable.

## Repo Document Authority

Use these documents as the current source of truth:

- `docs/prd.md`
- `docs/implementation-gap-audit.md`
- `docs/mvp-task-breakdown.md`
- `docs/technical-architecture.md`
- `docs/data-architecture.md`
- `docs/ux-flow.md`
- `docs/coach-observation-model.md`
- `docs/prompt-spec.md`
- `docs/prompt-context-engineering-prd.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/architecture-decisions.md`
- `docs/agent-delegation-log.md`
