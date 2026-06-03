# Subtask 033: Claude Code Conclusion-First Log Smoke

Date: 2026-06-04

## Problem

Subtask 032 proved that print fallback can run in the isolated worker worktree and write `HANDOFF`, but it also exposed two pipeline issues:

- `launch` streamed raw JSONL to the manager terminal through `tee`, which made the manager consume flow logs during normal execution.
- Untracked manager scripts were not synced into the worker worktree, so the worker could not inspect `scripts/claude_delegate.sh` from its own isolated checkout.

User requirement:

- Delegation records must have two layers.
- Flow logs are append-only storage for diagnosis and are not consumed routinely.
- Conclusion logs are the manager-facing layer: worker progress, findings, concerns, and recommendations.
- The manager should inspect flow logs only after a problem, failed acceptance, or a hard-to-fix discrepancy.

## Goal

Run one small read-only Claude Code smoke after the wrapper patch and verify:

- Default `launch` output does not print raw stream JSONL to the manager terminal.
- Worker progress remains the conclusion source.
- `scripts/claude_delegate.sh` and `scripts/claude_event_bridge.sh` are present in the worker worktree.
- The worker reaches `HANDOFF` without modifying product source files.

## Scope

Read only:

- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`
- `docs/subtasks/033-claude-code-conclusion-log-smoke-prd.md`
- `docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md`

Allowed worker writes:

- `docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md` in the worker worktree only.

## Acceptance Criteria

- Manager launch output stays quiet by default; raw stream is retained only in `docs/subtasks/logs/033-claude-code-conclusion-log-smoke-claude-run.jsonl`.
- `scripts/claude_delegate.sh wait` finds `HANDOFF` through the worker progress file.
- `scripts/claude_delegate.sh status` shows progress plus retained flow-log paths, without tailing flow logs unless `CLAUDE_DELEGATE_SHOW_FLOW_LOGS=1`.
- Worker confirms both scripts exist inside `.claude/worktrees/subtask-033-claude-code-conclusion-log-smoke`.
- Worker progress reaches `HANDOFF` with final status token `DONE` or `DONE_WITH_CONCERNS`.
- Worker git status contains no modified product source files.

## Non-Goals

- No product source changes.
- No UI changes.
- No persistence, prompt, parser, Keychain, AppStore, or migration changes.
- No tmux proof; this smoke verifies default print fallback behavior in the current non-interactive Codex environment.
