# Subtask 052 PRD: Delegation Tmux Flag Compatibility

Date: 2026-06-06

## Purpose

Fix the wrapper's Claude CLI tmux flag handling so Codex can relaunch delegated workers from a non-interactive host without false success.

This is a reusable delegation-framework slice, not a MingSi product feature.

## Problem

Subtask 050 relaunch after Subtask 051 exposed two CLI compatibility issues:

- `--tmux=classic` can print `open terminal failed: not a terminal` in the Codex non-interactive shell while exiting `0`.
- `--tmux=native` is not accepted by the current Claude CLI; native mode is the bare `--tmux` flag.

The wrapper must not treat either condition as a successful worker launch.

## Acceptance Criteria

- Default tmux style uses native mode and emits bare `--tmux`.
- Classic mode remains available as explicit `--tmux=classic`.
- The wrapper does not emit `--tmux=native`.
- If raw launch output contains `open terminal failed: not a terminal`, the wrapper converts the launch to failure even if the CLI exits `0`.
- Generic and installed skills document the flag behavior.

## Allowed Files

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `/Users/chenzewei/.codex/skills/claude-code-managed-delegation/SKILL.md`
- process docs and flow logs under `docs/`

## Verification

```bash
bash -n scripts/claude_delegate.sh
if rg -q -- '--tmux="\$tmux_style"|--tmux=native' scripts/claude_delegate.sh; then exit 1; fi
git diff --check
```
