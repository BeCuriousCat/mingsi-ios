# MingSi MVP Current Goal

Date: 2026-06-29

## Active Codex Pursuit Goal

MingSi MVP acceptance is complete. The current product work is Post-MVP Alpha hardening: keep the accepted personal-alpha loop runnable, preserve the coach-led training direction, and close external or operational gaps without reopening the MVP stop condition.

This repo is also dogfooding a second, separate framework project: Codex-to-Claude Code managed delegation. The framework is a tooling project, not a MingSi feature. It should remain generic enough to extract later and must not bake MingSi business semantics into its skill or wrapper contract.

Current Codex goal:

> Keep MingSi alpha-ready while improving the coach-led loop and its operating reliability: use Claude Code for bounded implementation or audit slices when resource health allows, keep Codex in manager/reviewer/final-verifier mode, and keep every accepted claim backed by tests, screenshots, logs, PromptRun audit, or repository evidence.

Coach Turn State v1 is no longer the active stop condition. It has a completion audit in `docs/coach-turn-state-v1-audit.md`, and `docs/mvp-stage-progress.md` records the product as being in Post-MVP follow-up. Future coach work should build on that stateful turn instead of reimplementing it.

## Current Stop Condition

The MVP stop condition is already accepted. The active Post-MVP Alpha gate is narrower:

- Local app prerequisites pass through `scripts/check_alpha_prerequisites.sh`.
- Rendered UI automation can be repeated through `scripts/run_ui_automation.sh` when a UI change or user-facing flow needs proof.
- The full Alpha acceptance runner remains `scripts/run_alpha_acceptance.sh --summary-json <path>`.
- The only known external Alpha prerequisite is a real BYOK GLM network call with a user-provided key and an approved external network-call window.
- Product changes must preserve the accepted MVP loop: Today completion, History evidence archive, Project/Growth evidence chains, Settings BYOK/audit visibility, PromptProvider / LLMClient boundaries, AI failure visibility, and local-first persistence.

Do not claim full external Alpha acceptance until the live BYOK GLM path has been run with a real key and recorded evidence. A missing key is a documented external blocker, not a reason to reopen accepted local MVP work.

## Current Stage Priority

1. Keep the accepted alpha loop stable and runnable.
2. Prefer bounded, testable Post-MVP slices from `docs/mvp-stage-progress.md`.
3. Use Claude Code aggressively for suitable local implementation or read-only audit tasks when `scripts/claude_delegate.sh health` is healthy.
4. Keep framework/delegation reliability separate from MingSi business semantics, but dogfood it on safe slices.
5. Preserve structured Prompt/Context asset versioning, eval, rollback, and PromptRun audit.
6. Keep coach-led training evidence local, deterministic, auditable, and testable; LLM may explain but must not authoritatively create long-term practice evidence.

## Recommended Next Slices

Choose based on the user's newest report or highest current risk:

- **Live GLM Alpha acceptance**: if a real BYOK key and network window are available, run `scripts/check_alpha_prerequisites.sh`, then `scripts/run_live_glm_acceptance.sh`, or the full `scripts/run_alpha_acceptance.sh --summary-json /tmp/mingsi-alpha-acceptance.json`.
- **UI automation follow-up**: use `scripts/run_ui_automation.sh` and extend `MingSiUITests` only when new rendered Today, Settings, History repair, or Growth/Project action surfaces need proof.
- **Prompt / Context assetization follow-up**: preserve typed `PromptContextPayload` and `PromptProvider` boundaries while improving publisher onboarding, external key distribution, remote prompt registry rollout, install/distribution UX, or registry refresh behavior.
- **Lens Asset follow-up**: build on the pack-aware local registry, trust metadata, Settings import/manage surface, and runtime enabled-pack catalog without adding prompt- or UI-specific branches to Today state.
- **Principle retrieval / PromptRun audit follow-up**: improve recall feedback policy, structured localized recall signals, and not-applicable/misrecalled weighting instead of adding another hand-maintained denial counter.
- **Delegation framework follow-up**: if the user redirects to framework work, improve worker launch reliability, conclusion-first monitoring, worktree setup, process cleanup, and experience capture without tying the framework to MingSi.

## Current Implementation Bias

- Prefer small, testable slices with clear allowed files.
- Delegate implementation/audit slices to Claude Code when the task has a narrow write set, known verification, and no mid-task product judgment.
- Do not delegate prompt strategy, migrations, cross-tab product semantics, broad refactors, or final visual taste.
- If docs conflict, fix docs first.
- If no real BYOK GLM key is available, stop at the documented missing-key gate and do not fake live success.
- Keep new service/test call sites on typed `PromptContextPayload`; do not reintroduce stored request dictionaries or arbitrary prompt payload maps.
- Do not write secondary or possible growth signals as high-confidence evidence without local policy and user-auditable support.

## Active Constraints

- Dirty worktree is expected. Do not revert unrelated Codex, Claude Code, GLM, or user changes.
- SwiftUI views must not directly import GRDB or call `LLMClient`.
- No fake data may stand in for missing Project or Growth evidence.
- Prompt outputs that affect Projects or Growth must carry source ids.
- History remains the source evidence archive for Project and Growth drilldown.
- User-selected lenses must not become the only training authority; coach recommendation and final user choice should both be recorded where relevant.
- LLM output must not directly create or confirm `PrinciplePracticeEvidence`, targeted practice, secondary practice, or long-term growth claims.
- Do not introduce LangChain/LangGraph for the local coach loop.
- Do not add subscription, sync, marketplace, or distribution behavior unless the current Post-MVP slice explicitly calls for it.

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
- `docs/coach-turn-state-v1-audit.md`
