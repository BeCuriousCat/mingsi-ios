# Subtask 031 Progress: Claude Code Utilization Smoke Audit

Status: CODEX_RECONCILED_DONE_WITH_CONCERNS
Final status token: DONE_WITH_CONCERNS

## Checkpoints

- START: 2026-06-04T00:47:10+0800, wrapper launch recorded `mode_requested=tmux` and `mode_effective=print`.
- RED: N/A, read-only audit slice.
- IMPLEMENTED: N/A, no source code implementation was expected.
- TARGETED_VERIFIED: Claude read the target files and updated this manager progress file.
- HANDOFF: 2026-06-04T00:48:41+0800, Claude stopped with final status `DONE_WITH_CONCERNS`.

## Codex Reconciliation

Claude's handoff text said the worker did not run through the wrapper. Codex rejects that exact statement after checking the event and raw logs.

What actually happened:

- `scripts/claude_delegate.sh launch 031-claude-code-utilization-smoke ...` was used.
- The wrapper created/reused the worker worktree and synced task docs.
- Because the Codex shell was non-interactive, the wrapper downgraded from tmux to print mode.
- The old print fallback ran from the manager worktree, so Claude saw and edited the manager progress file.
- Hook events fired: `session_start`, multiple `post_tool_use`, and `stop`.
- Raw stream usage was nonzero: `input_tokens=44757`, `cache_read_input_tokens=391552`, `output_tokens=1912`, `costUSD=0.46736099999999997`.

Accepted 031 evidence:

- Claude Code did execute useful work through the wrapper command path.
- GLM usage counters inside intermediate stream chunks can still be misleading, but the final result line recorded real model usage.
- Task-local hook events and raw stream logging worked in print fallback.
- The worker reached `HANDOFF` in the manager progress file.

Rejected 031 evidence:

- 031 does not prove the tmux/worktree implementation lifecycle.
- 031 does not prove worker-side progress writing, because the old print fallback wrote to the manager worktree.
- 031 is not sufficient evidence for accepting future implementation diffs without another wrapper smoke.

## Follow-Up Fix

Codex patched `scripts/claude_delegate.sh` after this run:

- Non-interactive print fallback now runs from the isolated worker worktree.
- The launch prompt explicitly states the worker worktree path.
- `status` and `wait` can fall back to a manager progress file that has a real handoff when the worker copy is stale.

Subtask 032 will verify the repaired print fallback with a new small read-only worker run.

## Worker Instructions

- Read the PRD first.
- Use `codex-delegated-worker` if available.
- Keep the slice read-only.
- Update this file at each checkpoint using exactly:
  - `START`
  - `RED`
  - `IMPLEMENTED`
  - `TARGETED_VERIFIED`
  - `HANDOFF`
- At `HANDOFF`, include one final status token:
  - `DONE`
  - `DONE_WITH_CONCERNS`
  - `NEEDS_CONTEXT`
  - `BLOCKED`

## Manager Constraints

- Do not modify product source files.
- Do not modify persistence, prompt, parser, Keychain, or AppStore orchestration code.
- Do not invent a success state without progress-file evidence.
- Do not treat manager-side wrapper fixes as proof until a worker run reaches `HANDOFF`.

## Evidence

- Event log: `docs/subtasks/logs/031-claude-code-utilization-smoke-events.jsonl`
- Raw stream log: `docs/subtasks/logs/031-claude-code-utilization-smoke-claude-run.jsonl`
- Stale worker progress file: `.claude/worktrees/subtask-031-claude-code-utilization-smoke/docs/subtasks/031-claude-code-utilization-smoke-progress.md`
