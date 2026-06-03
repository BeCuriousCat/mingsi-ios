# Codex To Claude Code Delegation Framework Boundary

Date: 2026-06-04

## Purpose

This document separates two active projects that currently share one repository:

1. MingSi product hardening.
2. A reusable Codex-to-Claude Code delegation framework.

MingSi remains the business main thread. The delegation framework is a tooling project that should eventually be extractable and open-sourceable. It must not depend on MingSi product semantics, SwiftUI, iOS, or the current `docs/subtasks` folder shape.

## Business Project: MingSi

MingSi's goal is a usable personal alpha:

- Today daily reflection loop.
- History evidence archive.
- Projects backed by evidence.
- Growth attribution ledger.
- Settings BYOK GLM and PromptRun audit.
- AI failures visible, retryable, and auditable.
- Simulator build, tests, and screenshots.

MingSi subtasks may still use delegation, but MingSi docs must not become the delegation framework's public API.

## Framework Project: Managed Delegation

The framework goal is:

> Let a stronger manager model specify, dispatch, and accept bounded coding work from a cheaper worker agent without turning the manager into a process babysitter.

Success is measured by accepted, verified worker output per manager token, not by raw token usage alone.

The framework should provide:

- A task contract with inputs, allowed files, acceptance commands, and stop policy.
- A worker lifecycle with `START`, `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, and `HANDOFF`.
- Two-layer logging:
  - Conclusion layer: progress, findings, concerns, handoff, and suggested next actions. This is the default manager consumption path.
  - Flow layer: raw stream and hook JSONL logs. These are retained for diagnosis and opened only after a problem or failed acceptance.
- Isolated worktrees for worker changes.
- Configurable task root and log root, not hard-coded MingSi paths.
- Templates that can generate routine PRD/progress/prompt artifacts from a compact manifest.
- Acceptance rules that require worker handoff, targeted verification, manager rerun, and an explicit accept/reject decision.

## Current Prototype

Current repo-owned prototype:

- Wrapper: `scripts/claude_delegate.sh`
- Event bridge: `scripts/claude_event_bridge.sh`
- Skill prototype: `delegation-framework/claude-code-managed-delegation/SKILL.md`

Current generalized wrapper knobs:

- `CLAUDE_DELEGATE_TASK_ROOT`
- `CLAUDE_DELEGATE_LOG_DIR`
- `CLAUDE_DELEGATE_MODEL`
- `CLAUDE_DELEGATE_AGENT`
- `CLAUDE_DELEGATE_EFFORT`
- `CLAUDE_DELEGATE_MODE`
- `CLAUDE_DELEGATE_MAX_BUDGET_USD`
- `CLAUDE_DELEGATE_SHOW_FLOW_LOGS`

MingSi uses the defaults:

```bash
CLAUDE_DELEGATE_TASK_ROOT=docs/subtasks
CLAUDE_DELEGATE_LOG_DIR=docs/subtasks/logs
```

Other projects should be able to use their own task root without changing the wrapper.

## Manager Cost Guardrail

The framework should reduce manager work, not add ceremony.

Default manager interaction should be:

1. Write a compact task intent or manifest.
2. Generate or reuse standard artifacts.
3. Launch the worker.
4. Wait on conclusion-layer progress.
5. Accept or reject after handoff with fresh verification.

The manager should not routinely:

- Hand-write long boilerplate for every task.
- Poll raw stream logs.
- Inspect partial diffs before handoff.
- Rescue half-finished worker code as the normal path.

## Dogfood Plan

The next MingSi business slice, manual Principle creation, should be used as a dogfood task:

- The framework remains generic.
- The business subtask supplies only MingSi-specific requirements, write targets, and test commands.
- Claude Code does the bounded coding work in an isolated worktree.
- Codex consumes conclusion-layer progress first.
- Raw flow logs are opened only if the worker stalls or acceptance fails.

