# Claude Code Current Status

Last updated: 2026-06-04

## Current Worker

Status: no active Claude Code worker is running.

Current prepared slice:

- Subtask: `033-claude-code-conclusion-log-smoke`
- Owner: Claude Code read-only smoke candidate.
- PRD file: `docs/subtasks/033-claude-code-conclusion-log-smoke-prd.md`
- Progress file: `docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md`
- Claude prompt file: `docs/subtasks/033-claude-code-conclusion-log-smoke-claude-prompt.md`
- Event log: `docs/subtasks/logs/033-claude-code-conclusion-log-smoke-events.jsonl`
- Raw log: `docs/subtasks/logs/033-claude-code-conclusion-log-smoke-claude-run.jsonl`
- Launch state: completed and Codex-accepted; no active worker is running.

Latest utilization smoke:

- Subtask: `033-claude-code-conclusion-log-smoke`
- Result: `DONE`, Codex-accepted.
- Evidence: default print fallback no longer streams raw JSONL to the manager terminal; raw/event flow logs are retained on disk, while `status` and `wait` consume worker progress as the conclusion source.
- Worker evidence: `scripts/claude_delegate.sh` and `scripts/claude_event_bridge.sh` were present inside the isolated worker worktree and inspected there; worker progress reached `HANDOFF`; no product source files were modified.
- Remaining note: normal `git worktree add` setup output can still appear before Claude starts. It is not model raw flow output.

Prior utilization smoke:

- Subtask: `032-claude-code-worker-fallback-smoke`
- Result: worker reached `HANDOFF` with final token `DONE`; Codex accepted with follow-up.
- Evidence: wrapper launched print fallback from the isolated worker worktree, worker progress became the active conclusion source, and default `status` / `wait` consumed progress rather than flow-log tails.
- Limitation found: the first 032 launch still streamed raw JSONL to the manager terminal through `tee`, and untracked `scripts/` files were not present in the worker worktree. The wrapper has been patched and Subtask 033 is prepared to verify the repaired behavior.

Earlier utilization smoke:

- Subtask: `031-claude-code-utilization-smoke`
- Result: `DONE_WITH_CONCERNS`, Codex-reconciled.
- Evidence: wrapper command path launched and fell back to print mode; hook events and raw stream usage were recorded.
- Limitation: old print fallback ran from the manager worktree, so worker-side progress writing was not proven.
- Follow-up: Subtask 032 will verify the patched print fallback runs from the isolated worker worktree.

Current delegation infrastructure:

- Subtask: `030-claude-code-pipeline-hardening`
- Owner: Codex direct implementation; Claude Code was not delegated.
- PRD file: `docs/subtasks/030-claude-code-pipeline-hardening-prd.md`
- Progress file: `docs/subtasks/030-claude-code-pipeline-hardening-progress.md`
- Wrapper: `scripts/claude_delegate.sh`
- Event bridge: `scripts/claude_event_bridge.sh`
- Task-local settings example: `.claude/delegation/030-claude-code-pipeline-hardening-settings.json`
- Event log: `docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl`
- Current state: wrapper verified for help, prepare, status, strict wait handoff detection, worker-progress handoff detection, manual event bridge append, and a 031 print-fallback launch with real model usage.
- Launch behavior: wrapper creates/reuses `.claude/worktrees/subtask-<id-topic>`, syncs matching `docs/subtasks/<id-topic>*` files into the worker worktree, and then launches Claude with `--worktree --tmux --agent` when interactive. In non-interactive shells, it falls back to `claude -p` from the isolated worker worktree.
- Monitoring behavior: `status` and `wait` prefer a worker progress file with real `HANDOFF`, can fall back to a manager progress file with real `HANDOFF` for legacy print-fallback runs, and otherwise prefer the worker copy.

Current MVP slice needing acceptance:

- Subtask: `029-safe-area-floating-tab`
- Owner: Codex direct implementation after Claude Code non-delivery; Codex manager owns final simulator verification.
- Reason: this is a bounded SwiftUI layout implementation slice with fixed acceptance criteria and no prompt/persistence/product-semantics changes.
- PRD file: `docs/subtasks/029-safe-area-floating-tab-prd.md`
- Progress file: `docs/subtasks/029-safe-area-floating-tab-progress.md`
- Claude prompt file: `docs/subtasks/029-safe-area-floating-tab-claude-prompt.md`
- Latest raw log: `docs/subtasks/logs/029-claude-run-focused.jsonl`
- Failed first launch log: `docs/subtasks/logs/029-claude-run-failed-args.jsonl`
- Stopped no-checkpoint launch log: `docs/subtasks/logs/029-claude-run-no-start.jsonl`
- Worker path: `.claude/worktrees/subtask-029-safe-area-floating-tab`
- Current launch state: paused after worker non-delivery
- Failed launch session id: `61459`
- Stopped no-checkpoint session id: `32727`
- Stopped focused session id: `20801`
- Current acceptance state: no Subtask 029 worker code accepted. Codex source changes are build-verified and partially screenshot-verified, but full light/dark visual acceptance remains pending.

Current wrapper commands:

```bash
scripts/claude_delegate.sh prepare <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh launch <id-topic> docs/subtasks/<id-topic>-claude-prompt.md docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh status <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh wait <id-topic> docs/subtasks/<id-topic>-progress.md 300 5
```

Default print-mode budget guard:

- `CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00` for ordinary bounded Claude Code coding tasks.
- For large delegated tasks, explicitly raise to `60.00` or higher.

Do not run another broad `claude -p` implementation attempt for Subtask 029.

Previous MVP slice:

- Subtask: `028-real-simulator-visual-qa`
- Owner: Codex manager
- Result: findings recorded; next slice chosen as safe-area and floating-tab layout fix.
- Progress file: `docs/subtasks/028-real-simulator-visual-qa-progress.md`
- Findings file: `docs/subtasks/028-real-simulator-visual-qa-findings.md`
- Screenshot directory: `docs/subtasks/screenshots/028-real-simulator-visual-qa/`

## Latest Claude Code Worker

Subtask: `027-history-repair-ui`

- Final status: `DONE`, accepted by Codex after one manager-side TDD correction.
- Worker path: `.claude/worktrees/subtask-027-history-repair-ui`
- Main progress file: `docs/subtasks/027-history-repair-ui-progress.md`
- Worker progress file: `.claude/worktrees/subtask-027-history-repair-ui/docs/subtasks/027-history-repair-ui-progress.md`
- First failed launch log: `docs/subtasks/logs/027-claude-run.jsonl`
- Successful escalated launch log: `docs/subtasks/logs/027-claude-run-escalated.jsonl`
- Manager acceptance record: `docs/agent-delegation-log.md`

## Where To Review

Use these files in order:

1. `docs/subtasks/claude-code-current-status.md`
   - One-screen answer for whether a Claude task is currently running and where the files are.
2. `docs/agent-delegation-log.md`
   - Manager-level decision record: why delegated, what was accepted or rejected, and verification result.
3. `docs/subtasks/<id>-<topic>-progress.md`
   - Checkpoint record for the delegated task.
4. `docs/subtasks/logs/<id>-*.jsonl`
   - Raw Claude Code stream output when a Claude process was actually launched.

## Required Contract For Future Delegations

Before launching Claude Code, Codex must create and update these artifacts:

- PRD: `docs/subtasks/<id>-<topic>-prd.md`
- Progress: `docs/subtasks/<id>-<topic>-progress.md`
- Claude prompt: `docs/subtasks/<id>-<topic>-claude-prompt.md`
- Raw log: `docs/subtasks/logs/<id>-claude-run*.jsonl`
- Current status pointer: `docs/subtasks/claude-code-current-status.md`
- Manager record: `docs/agent-delegation-log.md`

If a slice is not delegated, the current status file must say `no active Claude Code worker is running` and explain why no Claude log is expected.
