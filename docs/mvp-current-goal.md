# MingSi MVP Current Goal

Date: 2026-06-29

## Active Codex Pursuit Goal

MingSi MVP acceptance is complete. The current product work is Coach Training Loop v2: make MingSi feel less like an AI answer surface and more like a coach that observes how the user describes, judges, recalls experience, and turns judgment into action.

This repo is also dogfooding a second, separate framework project: Codex-to-Claude Code managed delegation. The framework is a tooling project, not a MingSi feature. It should remain generic enough to extract later and must not bake MingSi business semantics into its skill or wrapper contract.

Current Codex goal:

> Coach Training Loop v2: strengthen MingSi's core coach logic, teaching logic, and Today UX so the user clearly experiences "MingSi is training me" instead of "AI gave me an answer." The coach should focus on what the user skipped while describing the situation, guide more complete thinking, and help the user reproduce, adapt, or reject past experience.

This is not a feature expansion milestone. It is a training-quality milestone:

- MingSi should train foundational ability, not narrow industry tricks.
- Communication training means helping the user make an event replayable by another person.
- Thinking training means separating facts, feelings, interpretations, judgments, assumptions, goals, constraints, counterexamples, and calibration signals.
- Execution training means turning one reviewed judgment into an action with owner, standard, resistance plan, evidence, and tomorrow's calibration signal.
- The coach may be respectful, but must not appease. It should name weak thinking moves and repair them without attacking the person.
- User lens choice remains a downstream override. MingSi should carry the primary diagnostic burden for choosing the training focus.

Coach Turn State v1 is no longer the active stop condition. It has a completion audit in `docs/coach-turn-state-v1-audit.md`, and `docs/mvp-stage-progress.md` records the product as being in Post-MVP follow-up. Future coach work should build on that stateful turn instead of reimplementing it.

## Current Stop Condition

The next milestone can stop only when Coach Training Loop v2 is coherent:

- `CoachObservationPolicy`, `CoachDecisionPolicyV2`, `CoachTeachingPolicy`, prompt directives, and Today UI all use the same training vocabulary: observed material, primary gap, baseline checks, ability trained, repair ask, and proceed condition.
- Today makes the two loops visible and hard to confuse: `今天内容 -> 今日复盘` and `明日验证 -> 结果校准`.
- The coach selects one primary training focus, while quietly checking baseline thinking foundations so the user is not trapped in a single lens.
- User answers get actionable coach feedback: what improved, what is still missing, whether the turn is ready, the next repair sentence, and the experience-replay decision.
- Generated tomorrow actions are explicitly tied to a reviewed judgment and calibration target, not generic todos.
- Prompt quality gates reject appeasing outputs, generic advice, and questions or quests that do not connect observation -> gap -> training -> ask.
- Tests cover deterministic policy, prompt specs, prompt quality gates, persistence boundaries where affected, and rendered Today UX for the user-facing training cues.
- The milestone does not add a general chat agent, LangChain/LangGraph, subscription, sync, marketplace, or remote distribution behavior.

Alpha guardrails still apply: local app prerequisites must remain runnable through `scripts/check_alpha_prerequisites.sh`, rendered UI automation should remain repeatable through `scripts/run_ui_automation.sh`, and the full Alpha acceptance runner remains `scripts/run_alpha_acceptance.sh --summary-json <path>`. Do not claim full external Alpha acceptance until the live BYOK GLM path has been run with a real key and recorded evidence.

## Current Stage Priority

1. Make the coach's observation visible before the user experiences a prompt or task.
2. Improve the teaching route after user answers: the coach should explain the thinking repair, not only decide pass/fail.
3. Strengthen experience replay as a decision drill: reproduce, adapt, or reject past experience before applying it.
4. Keep the accepted alpha loop stable and runnable while improving the coach-led loop.
5. Preserve structured Prompt/Context asset versioning, eval, rollback, and PromptRun audit.
6. Keep coach-led training evidence local, deterministic, auditable, and testable; LLM may explain but must not authoritatively create long-term practice evidence.

## Recommended Next Slices

Choose based on the user's newest report or highest current coach-quality risk:

- **Coach observation v2**: broaden deterministic observation fixtures and prompt-eval cases for narrative, object/user, goal, constraint, causal, counterexample, judgment, execution, calibration, and experience gaps.
- **Teaching feedback v2**: make answer feedback consistently show `你刚补上 / 当前仍缺 / 能否进入明日验证 / 下一句修补 / 过往经验复现`.
- **Experience replay capture**: ensure recalled principles or patterns require a user-visible reproduce/adapt/reject classification before becoming useful practice material.
- **Review sustainability**: use repeated local gap history to surface a lightweight next training recommendation without letting LLM observations become high-confidence long-term evidence.
- **Rendered Today UX proof**: keep using `scripts/run_ui_automation.sh` or focused `MingSiUITests` when user-facing training copy, stage boundaries, or input behavior changes.
- **Live GLM Alpha acceptance**: run only when a real BYOK key and approved network window are available; this is an external Alpha proof gate, not the current coach-quality slice.

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
