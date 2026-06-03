# Subtask 030: Claude Code Delegation Pipeline Hardening

Date: 2026-06-04

## Problem

Recent Claude Code delegation attempts were too easy to launch and too hard to prove useful.

Observed failure modes:

- `claude -p` argument parsing swallowed the prompt after variadic `--allowedTools`.
- A worker could produce stream/log output without reaching `START`.
- The focused worker reached `START` but spent time reading and deliberating without reaching `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, or `HANDOFF`.
- GLM usage fields in stream logs showed `0`, so manager-visible token accounting did not prove useful work happened.
- Codex had to poll manually, which spends manager attention and does not improve worker throughput.
- A progress file can contain `HANDOFF: pending`, so a plain text search for `HANDOFF` can falsely report completion.
- macOS `/bin/date` does not support `date -Is`, so wrapper timestamps must use a portable format.
- A `--worktree` worker can update the worker copy of the progress file while the manager worktree copy stays unchanged.
- New subtask docs are often untracked during active work, so a fresh worker worktree may not contain the PRD, progress, and Claude prompt unless the wrapper syncs them.
- `--tmux` without `=classic` can fail in this non-interactive shell with `open terminal failed: not a terminal`.

## Goal

Make Claude Code delegation observable enough that Codex can answer four questions cheaply:

- Did a worker actually start?
- Did it use tools against the expected worktree?
- Did it reach the progress checkpoints?
- Did delegation save work, stay neutral, or add cost?

## Required Behavior

- Prefer `claude --worktree --tmux --agent` for implementation slices.
- Keep `claude -p` only for read-only audits or short one-shot checks.
- Always pass `--` before the prompt when `--allowedTools` is used.
- Generate a task-local settings file with file-bridge hooks.
- Append lifecycle/tool events to `docs/subtasks/logs/<id>-events.jsonl`.
- Keep raw Claude output in `docs/subtasks/logs/<id>-claude-run.jsonl`.
- Use the progress file as the source of truth; event logs are wake signals only.
- Add a wrapper command so future launches are reproducible.
- Default searches and audits should exclude `.claude/worktrees/*/Vendor`, `Vendor`, and `.git`.

## Implementation

Added:

- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`

The launcher supports:

- `prepare`: preflight CLI/tmux/agent state and generate task-local hook settings without starting a worker.
- `launch`: preflight CLI/tmux/agent state, generate hook settings, create/reuse the worker worktree, sync task docs, start a worker, and create raw/event logs.
- `status`: read active progress, manager progress, worker progress, recent events, active agents, and worker git status.
- `wait`: shell-level low-frequency checkpoint wait without spending model turns; it must prefer worker progress and must not treat `HANDOFF: pending` as success.
- Launches should default to `--tmux=classic` in this environment unless an interactive terminal is explicitly available.

## Acceptance Criteria

- The wrapper has a help page and validates missing prompt/progress files.
- The wrapper can inspect current agent state through `claude agents --json`.
- The wrapper generates task-local hook settings without modifying global Claude settings.
- The wrapper uses `--worktree`, `--tmux`, `--agent`, `--settings`, `--allowedTools`, and an explicit `--` separator in implementation mode.
- The wrapper uses portable timestamps on macOS.
- The wrapper can positively distinguish a real handoff from pending checklist text.
- The wrapper syncs untracked subtask docs into the worker worktree before launch.
- The wrapper monitors the worker worktree progress file when present.
- The wrapper defaults to `--tmux=classic` for launch safety in non-interactive shells.
- The wrapper leaves enough filesystem evidence for Codex to classify non-delivery before inspecting partial code.

## Non-Goals

- Do not launch a new implementation worker until the current dirty worktree and active task are clarified.
- Do not clean old Claude processes or worktrees automatically.
- Do not change global `~/.claude/settings.json`.
- Do not accept partial worker diffs without `HANDOFF`.
