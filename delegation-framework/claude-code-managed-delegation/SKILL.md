---
name: claude-code-managed-delegation
description: Use when a strong manager model delegates bounded coding work to Claude Code or a similar worker agent while preserving isolation, conclusion-first monitoring, and manager-side acceptance.
---

# Claude Code Managed Delegation

Use this skill when the user wants Codex to direct a cheaper worker agent for implementation, audit, or test repair without turning Codex into a line-by-line babysitter.

## Core Contract

Codex owns task shape, architecture, acceptance, and final verification.

The worker owns bounded implementation, test-first execution, progress reporting, and handoff evidence.

No worker output is accepted without:

- isolated worker worktree
- exact allowed write set
- known verification commands
- progress checkpoint `HANDOFF`
- manager-side rerun of relevant checks

## Dispatch Gate

Delegate only when all are true:

- The task has one concrete outcome.
- The allowed files can be named before launch.
- The worker does not need new product judgment mid-task.
- Acceptance commands are known.
- Partial output is disposable.
- The coordination cost is likely lower than direct manager implementation.

Do not delegate product strategy, prompt strategy, migrations, broad refactors, or final visual taste.

## Lifecycle

Each task uses these conclusion checkpoints:

```text
START
RED
IMPLEMENTED
TARGETED_VERIFIED
HANDOFF
```

`HANDOFF` must include one status token:

```text
DONE
DONE_WITH_CONCERNS
NEEDS_CONTEXT
BLOCKED
```

The manager reads conclusion progress first. Raw flow logs are only for diagnosis after stalls, contradictions, or failed acceptance.

## Two-Layer Logs

Conclusion layer:

- progress file
- handoff summary
- changed files
- tests run
- concerns and suggested next actions

Flow layer:

- raw model stream JSONL
- hook events JSONL
- tool traces

The conclusion layer is routine manager input. The flow layer is append-only evidence, not daily reading material.

## Wrapper Assumptions

A compatible wrapper should support:

- configurable task root
- configurable log root
- isolated worktree per task
- worker progress copied or available inside the worktree
- `status` and `wait` commands that prefer conclusion progress
- relaunch-safe progress sync: once worker progress contains checkpoints, do not overwrite it with a stale manager-side progress file unless an explicit reset flag is set
- dynamic wait backoff, defaulting to 3/6/9 minute checks before manager intervention
- explicit no-progress classification: after the scheduled checks, intervention is allowed only when no `HANDOFF` arrived and the conclusion progress did not move
- an opt-in flag to inspect flow logs

For this repo prototype, use:

```bash
scripts/claude_delegate.sh prepare <task-id> <progress-file>
scripts/claude_delegate.sh launch <task-id> <prompt-file> <progress-file>
scripts/claude_delegate.sh status <task-id> <progress-file>
scripts/claude_delegate.sh wait <task-id> <progress-file>
```

Set these for non-default projects:

```bash
CLAUDE_DELEGATE_TASK_ROOT=<path>
CLAUDE_DELEGATE_LOG_DIR=<path>
CLAUDE_DELEGATE_WAIT_SCHEDULE=180,360,540
CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS=0
```

Use `status` for immediate inspection after launch. Use `wait` for low-frequency monitoring; it prints the active conclusion source and keeps flow logs hidden unless diagnostics are explicitly enabled.

Do not reset worker progress during a relaunch just because the manager edited the prompt or PRD. The worker progress file is the conclusion source; overwriting it can erase `START`, `RED`, `IMPLEMENTED`, or `TARGETED_VERIFIED` evidence and force the manager back into flow-log diagnosis. Reset only when the manager intentionally wants to discard the current worker attempt.

## Manager Workflow

1. Write a compact task contract: purpose, allowed files, forbidden files, tests, and acceptance criteria.
2. Generate or update the PRD/progress/prompt artifacts from that contract.
3. Launch the worker.
4. Wait at low frequency on conclusion progress.
5. If `HANDOFF` arrives, inspect diff and rerun checks.
6. If the 3/6/9 checks finish with no conclusion progress, classify the stall before opening flow logs or taking over.
7. Accept, reject, or request a new worker attempt.
8. Capture generalized lessons in the skill; keep project-specific lessons in the project docs.

## Worker Prompt Rules

The worker prompt must say:

- read the PRD and progress first
- update `START` before broad inspection
- use TDD for behavior changes
- keep the diff inside the allowed write set
- run named verification commands
- do not commit unless explicitly allowed
- end with exactly one handoff status token

## References

- `references/task-contract.md`
- `references/conclusion-first-monitoring.md`
