# Subtask 043 Progress: Delegation Status Handoff Summary

Status: CODEX_ACCEPTED
Timestamp: 2026-06-05

Owner: Codex manager
Delegated implementer: none

Required PRD: `docs/subtasks/043-delegation-status-handoff-summary-prd.md`

## Scope

- Delegation wrapper status display fix.
- No MingSi product source changes.
- No Claude Code worker launch; this is a direct manager fix because the bug is in the delegation pipeline itself.

## Root Cause

`scripts/claude_delegate.sh status` selected the correct active progress file, and `handoff_reached` could detect `## HANDOFF`.

The apparent stale status came from display truncation: `status` printed only the first 80 lines of active progress. In Subtask 042, `## HANDOFF` was below line 100, so the manager-visible status looked stuck at `RED` even though the worker had completed.

There was a second presentation issue after Codex acceptance: the worker progress copy still had `Status: PREPARED` at the top, while the manager progress copy had `Status: CODEX_ACCEPTED`. Routine status should prefer the manager-side accepted conclusion once it exists.

## RED

Regression command failed before the fix:

```bash
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'Status: DONE_WITH_CONCERNS'
```

Result:

- Exit code `1`.
- `status` pointed at a progress file but did not show the final handoff token.

## IMPLEMENTED

Changed:

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/delegation-framework-boundary.md`

Implementation:

1. Added `codex_accepted` helper.
2. Updated `current_progress_path` to prefer manager progress when it has `Status: CODEX_ACCEPTED`.
3. Added `print_handoff_summary`.
4. Updated `status` to print `active handoff summary` when the active progress has reached handoff.
5. Updated framework docs so conclusion-first monitoring requires status to surface handoff summaries without raw/event log inspection.

## TARGETED_VERIFIED

Commands:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'Status: DONE_WITH_CONCERNS'
scripts/claude_delegate.sh status 042-lens-prompt-context-wiring docs/subtasks/042-lens-prompt-context-wiring-progress.md | rg -q 'active progress: .*/docs/subtasks/042-lens-prompt-context-wiring-progress.md'
scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1
git diff --check
```

Result:

- Syntax check passed.
- `status` now exposes `Status: DONE_WITH_CONCERNS` from the handoff summary.
- `status` prefers the manager-side 042 progress after Codex acceptance.
- Pending handoff check still exits `75` for Subtask 029.
- `git diff --check` passed.

## HANDOFF

Status: DONE

Codex accepted the direct wrapper fix.

No Claude Code delegation was used because the bug was inside the delegation manager wrapper itself.
