# Subtask 032: Claude Code Worker Fallback Smoke

Date: 2026-06-04

## Problem

Subtask 031 proved that Claude Code can execute through the wrapper command path in non-interactive print fallback, but the old fallback ran from the manager worktree. That made Claude update the manager progress file while `status` and `wait` preferred a stale worker progress file.

The wrapper has now been patched so print fallback runs inside the isolated worker worktree.

## Goal

Run one very small read-only Claude Code smoke through `scripts/claude_delegate.sh` and verify:

- The wrapper launches Claude Code.
- Non-interactive fallback uses `mode_effective=print`.
- The worker runs from `.claude/worktrees/subtask-032-claude-code-worker-fallback-smoke`.
- The worker writes progress checkpoints in the worker worktree copy.
- The manager can observe `HANDOFF` through `scripts/claude_delegate.sh wait`.

## Scope

Read only:

- `scripts/claude_delegate.sh`
- `docs/subtasks/032-claude-code-worker-fallback-smoke-prd.md`
- `docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md`

Allowed worker writes:

- `docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md` in the worker worktree only.

## Acceptance Criteria

- Event log records `manager_launch` with `mode_effective=print`.
- Event log contains at least `session_start`, one `post_tool_use`, and `stop`.
- Worker progress file reaches `HANDOFF` with a final status token.
- Manager progress may remain prepared; worker progress is the accepted truth source.
- No product source files are modified by the worker.

## Non-Goals

- No production source changes.
- No UI changes.
- No persistence, prompt, parser, Keychain, AppStore, or migration changes.
- No tmux path proof; this subtask only proves safe print fallback utilization in the current non-interactive Codex environment.
