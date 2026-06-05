# Subtask 051 PRD: Delegation Lifecycle Cleanup

Date: 2026-06-06

## Purpose

Fix the reusable Codex-to-Claude Code delegation wrapper so worker launch and cleanup do not accumulate unmanaged child processes under Codex.

This is a framework/control-plane slice, not a MingSi product feature.

## Problem

Recent delegation attempts showed this failure mode:

- `launch` recorded a background launcher PID.
- The worker progress stayed at `PREPARED`.
- The raw log could be empty.
- No `START` checkpoint appeared.
- Codex-owned `<defunct>` child processes accumulated across attempts.

The previous resource guard blocked new launches after zombie thresholds, but it did not make worker lifecycle observable or cleanup task-scoped stale processes.

## Acceptance Criteria

- Tmux/session launch observes the Claude CLI launch exit code instead of backgrounding the launcher by default.
- `status` reports task-scoped worker liveness.
- `wait` exits early when there is no active worker process and no conclusion checkpoint.
- A `cleanup` command terminates only processes tied to the current subtask worker worktree or `--worktree` target.
- Prelaunch cleanup is enabled for the same subtask by default.
- Flow logs remain diagnostic-only.
- The generic skill and installed local skill document the lifecycle rule.

## Allowed Files

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `/Users/chenzewei/.codex/skills/claude-code-managed-delegation/SKILL.md`
- process docs and verification docs under `docs/`

## Forbidden Files

- MingSi Swift product source
- Persistence, migrations, PromptProvider, parsers, LLM clients, Keychain
- Product tests unrelated to the wrapper

## Verification

Required:

```bash
bash -n scripts/claude_delegate.sh
if rg -q '> "\$raw_log" 2>&1 &' scripts/claude_delegate.sh; then exit 1; fi
scripts/claude_delegate.sh status 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh cleanup 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh wait 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md 0 1
git diff --check
```
