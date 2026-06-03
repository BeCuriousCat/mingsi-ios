# Subtask 030 Progress: Claude Code Pipeline Hardening

Status: CODEX_VERIFIED
Final status token: DONE

## Checkpoints

- START: done
- ROOT_CAUSE: done
- IMPLEMENTED: done
- VERIFIED: done
- HANDOFF: Codex direct handoff done

## Root Cause

Subtask 029 showed that a worker can appear launched while producing little manager-verifiable work:

- `claude -p` is a weak fit for long implementation slices.
- Variadic `--allowedTools` needs an explicit `--` prompt separator.
- Stream `usage` fields were not reliable for GLM-backed worker usefulness.
- Manual polling looked at logs/progress too often while still missing an event-driven wake signal.
- Searches over `.claude/worktrees` and vendored dependencies can explode context and hide the relevant signal.
- A naive wait check for the text `HANDOFF` can misclassify `HANDOFF: pending` as success.
- macOS `/bin/date` does not support `date -Is`, so audit timestamps need a portable format.
- `--worktree` means the worker may update progress inside `.claude/worktrees/...`, while the manager worktree progress file remains unchanged.
- New, untracked PRD/prompt/progress files may not exist in a fresh worker worktree unless the wrapper syncs them before launch.
- `--tmux` without `=classic` can fail in this non-interactive shell with `open terminal failed: not a terminal`.

## Implementation Notes

Added repo-owned wrapper scripts:

- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`

The wrapper now pre-creates or reuses the task worker worktree on launch, syncs matching `docs/subtasks/<id-topic>*` files into that worktree, and lets `status` / `wait` prefer worker progress before falling back to manager progress.
The wrapper defaults to `--tmux=classic` to avoid the native-pane terminal failure in this environment.

Supported manager commands:

```bash
scripts/claude_delegate.sh prepare <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh launch <id-topic> docs/subtasks/<id-topic>-claude-prompt.md docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh status <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh wait <id-topic> docs/subtasks/<id-topic>-progress.md 300 5
```

Default implementation launch path now targets:

```bash
scripts/claude_delegate.sh launch <id-topic> docs/subtasks/<id-topic>-claude-prompt.md docs/subtasks/<id-topic>-progress.md
```

Expected follow-up monitoring:

```bash
scripts/claude_delegate.sh status <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh wait <id-topic> docs/subtasks/<id-topic>-progress.md 300 5
```

## Verification

- `scripts/claude_delegate.sh --help`: passed.
- `scripts/claude_delegate.sh prepare 030-claude-code-pipeline-hardening docs/subtasks/030-claude-code-pipeline-hardening-progress.md`: passed and generated `.claude/delegation/030-claude-code-pipeline-hardening-settings.json`.
- `scripts/claude_delegate.sh status 030-claude-code-pipeline-hardening docs/subtasks/030-claude-code-pipeline-hardening-progress.md`: passed and showed one idle interactive Claude agent; no implementation worker was launched.
- `scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1`: correctly exited 75 because `HANDOFF: pending` is not a real handoff.
- `scripts/claude_delegate.sh wait 027-history-repair-ui docs/subtasks/027-history-repair-ui-progress.md 0 1`: correctly exited 0 by reading the worker worktree progress file that contains the real handoff.
- `printf '{"probe":"bridge"}' | scripts/claude_event_bridge.sh docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl manual_probe`: passed and appended an event with base64 payload.
- `bash -n scripts/claude_delegate.sh`: passed.
- `bash -n scripts/claude_event_bridge.sh`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed after the Settings audit flicker fix and safe-area code changes.
- `git diff --check`: passed after final source/script/documentation updates.

## Handoff

Codex direct implementation is ready for manager use. Future Claude Code implementation attempts should use the wrapper instead of broad `claude -p`.

No Claude Code worker was delegated for Subtask 030.
