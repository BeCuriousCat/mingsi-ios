# Subtask 052 Progress: Delegation Tmux Flag Compatibility

Status: CODEX_ACCEPTED
Timestamp: 2026-06-06

Owner: Codex direct framework fix.
Claude Code worker: not delegated.

## Scope

- Correct wrapper tmux flag generation for the current local Claude CLI.
- Preserve conclusion-first monitoring.
- Preserve 050 flow logs before relaunch attempts.
- Do not change MingSi product behavior.

## Checkpoints

- START: Codex diagnosed 050 relaunch failure under the fixed lifecycle wrapper.
- RED: `--tmux=classic` produced `open terminal failed: not a terminal` while exiting `0`; `--tmux=native` failed with `unknown option '--tmux=native'`.
- IMPLEMENTED: wrapper defaults to native bare `--tmux`, keeps explicit classic as `--tmux=classic`, and classifies non-TTY classic output as failure.
- TARGETED_VERIFIED: syntax, static tmux flag regression, wrapper help, preserved flow-log evidence, and `git diff --check` passed.
- HANDOFF: not applicable; no Claude Code worker was delegated.

## Evidence So Far

- `claude --help` confirms native tmux is bare `--tmux`; classic is `--tmux=classic`.
- `bash -n scripts/claude_delegate.sh` passed after the wrapper edit.
- Static native flag regression passed: no `--tmux=native` invocation remains.
- `scripts/claude_delegate.sh --help` now shows `CLAUDE_DELEGATE_TMUX_STYLE=native`.
- `git diff --check` passed.
- Preserved 050 failed relaunch flow logs:
  - `docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-after-051-classic-*.jsonl`
  - `docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-after-051-native-invalid-*.jsonl`

## 050 State

Subtask 050 still has no accepted worker output. It can now be relaunched under the corrected native tmux flag behavior.
