# Subtask 031: Claude Code Utilization Smoke Audit

Date: 2026-06-04

## Problem

The delegation wrapper was fixed to create/reuse worker worktrees, sync task docs, and monitor worker progress. That is necessary, but it is still only infrastructure evidence.

We need one real worker run to prove that:

- Claude Code can start through the wrapper.
- The worker can write the expected progress checkpoints.
- The manager can observe worker progress in the worker worktree.
- The worker can hand off without Codex rescuing the slice.

## Goal

Run one very small, read-only Claude Code audit slice through `scripts/claude_delegate.sh` and verify the full lifecycle:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

The worker must not change product source code.

## Scope

Read only:

- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`
- `docs/subtasks/030-claude-code-pipeline-hardening-progress.md`
- `docs/subtasks/claude-code-current-status.md`

The worker should answer two questions:

1. Does the wrapper now look safe to use for future bounded implementation slices?
2. Are there any remaining launch/monitoring gaps that should block the next real delegated implementation?

## Acceptance Criteria

- The worker reaches `HANDOFF` and writes a final status token.
- The worker reports at least one concrete audit result about the wrapper.
- No source files are modified outside the designated progress/log artifacts.
- The manager can verify the run from raw logs plus progress files.

## Non-Goals

- No production code changes.
- No UI changes.
- No persistence, prompt, parser, or migration changes.
- No new product decisions.
