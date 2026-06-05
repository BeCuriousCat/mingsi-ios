# Subtask 051 Progress: Delegation Lifecycle Cleanup

Status: CODEX_ACCEPTED
Timestamp: 2026-06-06

Owner: Codex direct framework fix.
Claude Code worker: not delegated.

## Scope

- Fix worker launch lifecycle observability.
- Add task-scoped cleanup.
- Keep conclusion-first monitoring and flow-log separation.
- Do not change MingSi product behavior.

## Checkpoints

- START: Codex started direct framework fix after user reported delegation skill zombie accumulation.
- RED: static regression check failed because tmux launch still backgrounded `claude`.
- IMPLEMENTED: wrapper now observes tmux launch exit, reports liveness, exits wait early on launch-before-START failure, and supports task-scoped cleanup.
- TARGETED_VERIFIED: wrapper syntax, static regression, 050 liveness/status/cleanup/wait, resource count, and `git diff --check` passed.
- HANDOFF: not applicable; no Claude Code worker was delegated.

## Evidence

RED command:

```bash
if rg -q '> "\$raw_log" 2>&1 &' scripts/claude_delegate.sh; then echo 'RED: tmux launch still backgrounds claude and cannot observe launch exit'; exit 1; fi
```

Observed failure before the fix:

```text
RED: tmux launch still backgrounds claude and cannot observe launch exit
```

Post-implementation checks already observed:

- `bash -n scripts/claude_delegate.sh`: passed.
- Static tmux-background regression: passed.
- `status` on Subtask 050 reports `active_processes=0` and warns that launch likely failed before `START`.
- `cleanup` on Subtask 050 is a no-op when no active worker process remains.
- `wait 0 1` on Subtask 050 exits `75` immediately with launch-before-START classification.
- `git diff --check` passed.
- Resource count after verification: Codex-owned zombies 5, total zombies 7; still below wrapper thresholds.

## Accepted Scope

Codex accepts this as a framework/control-plane fix. It does not accept Subtask 050 implementation output.

## Current 050 Impact

Subtask 050 remains unaccepted and not started:

- Progress is still `PREPARED`.
- No `START` checkpoint exists.
- No worker handoff exists.
- Existing 050 raw/event logs are treated as diagnostic flow logs only.

After this wrapper fix is accepted, 050 can be relaunched under the new observed-launch lifecycle if it is still the next product priority.
