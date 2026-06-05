# Subtask 053 PRD: Delegation Resource Tree Guard

Date: 2026-06-06

## Problem

The delegation framework can still undercount process pressure after Codex restarts or repeated Claude Code launches.

Subtasks 051 and 052 fixed launch exit observation, task-scoped cleanup, and tmux flag compatibility. The remaining gap is that `scripts/claude_delegate.sh` counts only zombie children whose direct parent is the Codex app process. In practice, Codex launches manager shell commands through a process tree such as:

```text
Codex.app
  -> codex app-server
    -> zsh
      -> claude / xcodebuild / simctl / worker helper
```

Zombies can accumulate under any Codex-managed descendant, not only under the direct Codex app PID. A direct-child-only guard can therefore report a healthy state while the Codex process tree is already leaking unreaped child processes.

Foreground print-mode Claude runs are also riskier than tmux/session runs because their child processes are attached to Codex-managed shells. If print mode exits without an explicit handoff, the wrapper should classify that as non-delivery instead of returning a quiet success.

## Goal

Make the reusable delegation wrapper safer under repeated launches by:

- counting zombie children across the Codex process tree, not only direct Codex children;
- exposing a lightweight health command for diagnostics;
- making print-mode launch exit and no-handoff behavior explicit;
- preserving conclusion-first monitoring and flow-log separation.

## Non-Goals

- Do not change MingSi product behavior.
- Do not modify Swift source, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, or tests.
- Do not attempt to reap zombies that only the Codex parent process can reap.
- Do not make raw/event flow logs routine manager input.
- Do not relaunch Claude Code for this framework fix.

## Allowed Files

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `/Users/chenzewei/.codex/skills/claude-code-managed-delegation/SKILL.md`
- `docs/subtasks/053-delegation-resource-tree-guard-progress.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`
- `docs/mvp-stage-progress.md`

## Acceptance Criteria

- `resource guard` output reports both direct Codex zombies and Codex process-tree zombies.
- Guard blocking uses Codex tree zombie count.
- `scripts/claude_delegate.sh health` can run without a subtask-specific progress file.
- Print-mode launch records a launch-exit event and exits non-zero if Claude exits without a final handoff token.
- `bash -n scripts/claude_delegate.sh` passes.
- Targeted shell regressions pass.
- `git diff --check` passes.
