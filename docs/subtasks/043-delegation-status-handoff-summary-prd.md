# Subtask 043 PRD: Delegation Status Handoff Summary

Date: 2026-06-05

## Goal

Fix the delegation wrapper `status` command so the manager can see the active conclusion state without opening raw/event flow logs.

Subtask 042 exposed a confusing status view: the worker had reached `HANDOFF/DONE_WITH_CONCERNS`, but `scripts/claude_delegate.sh status` printed only the first 80 lines of the active progress file. Since `## HANDOFF` was below that cutoff, the manager view looked stale and forced raw/event log diagnosis.

## Scope

Allowed source files:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/delegation-framework-boundary.md`

Allowed documentation files:

- `docs/subtasks/043-delegation-status-handoff-summary-prd.md`
- `docs/subtasks/043-delegation-status-handoff-summary-progress.md`
- process docs that record verification and delegation state

Do not edit:

- MingSi product source files
- tests for app features
- persistence / migrations / PromptProvider / parser / LLM clients
- existing worker raw logs

## Required Behavior

1. If manager progress has `Status: CODEX_ACCEPTED`, `status` should prefer that manager-side conclusion over an older worker progress copy.
2. If the active progress file has reached `HANDOFF`, `status` must print a handoff summary that includes the final status token.
3. Flow logs remain hidden by default. The fix must not make raw/event logs part of routine status consumption.
4. `wait` handoff detection must remain strict and must not treat `HANDOFF: pending` as success.

## Acceptance Evidence

Use Subtask 042's real progress files as the regression fixture.

Required checks:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'Status: DONE_WITH_CONCERNS'
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'active progress: .*/docs/subtasks/042-lens-prompt-context-wiring-progress.md'
scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1
git diff --check
```

Expected:

- First three commands pass.
- The 029 wait command exits `75`, proving pending handoff text is still not accepted as a real handoff.
- `git diff --check` passes.

## Non-Goals

- No new Claude worker launch.
- No rewrite of launch mode, hook bridge, or wait cadence.
- No raw/event log parsing in normal status output.
- No changes to MingSi product behavior.
