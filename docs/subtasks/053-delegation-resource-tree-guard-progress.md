# Subtask 053 Progress: Delegation Resource Tree Guard

Status: CODEX_ACCEPTED
Timestamp: 2026-06-06

Owner: Codex direct framework fix.
Claude Code worker: not delegated.

## Scope

- Harden resource guard accounting for Codex process-tree zombie buildup.
- Add wrapper health diagnostics.
- Make print-mode launch lifecycle explicit.
- Keep conclusion-first monitoring and flow-log separation.
- Do not change MingSi product behavior.

## Checkpoints

- START: Codex started direct framework fix after the user reported that the delegation skill model can accumulate stale/zombie threads under Codex and exhaust macOS user-level process resources.
- RED: current wrapper health check counts direct Codex zombies only; current post-restart process inventory shows Codex direct zombies below threshold but does not prove descendant-tree coverage.
- IMPLEMENTED: wrapper now counts Codex process-tree zombies, exposes `health`, records print-mode launch exit, and returns `75` when print mode exits without a final handoff token.
- TARGETED_VERIFIED: syntax, health output, threshold blocking, status compatibility, fake print-mode no-handoff regression, worktree cleanup, and `git diff --check` passed.
- HANDOFF: not applicable; no Claude Code worker will be delegated for this framework self-fix.

## Initial Evidence

Current post-restart process evidence:

```text
total_zombies=10
Codex direct zombies=8
DoubaoIme zombies=2
Codex main PID=77268
```

`top` currently reports about 4,375 total threads and `kernel_task` at 783 threads. This is high but expected for macOS kernel accounting and is not the same class of evidence as unreaped `<defunct>` children under Codex.

## Root Cause Hypothesis

The wrapper reduced new leaks in Subtasks 051 and 052, but it still treats Codex as a single direct parent PID. Codex-managed shell commands actually run through descendants such as `codex app-server`, `node_repl`, and `zsh`, so zombie pressure must be measured against the Codex process tree.

Print mode is still useful as an escape hatch when tmux cannot run from a non-TTY host, but it must be treated as a synchronous high-risk path: if the Claude process exits without a real final handoff token, the wrapper should classify the launch as non-delivery immediately.

## Manager Notes

- This is a reusable delegation-framework fix, not a MingSi business slice.
- No Claude Code worker is launched because the bug is in the delegation control plane itself.
- Flow logs remain diagnostic-only.

## Changed Files

- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- local installed skill: `/Users/chenzewei/.codex/skills/claude-code-managed-delegation/SKILL.md`
- `docs/subtasks/053-delegation-resource-tree-guard-prd.md`
- `docs/subtasks/053-delegation-resource-tree-guard-progress.md`

## Verification

Commands:

```bash
bash -n scripts/claude_delegate.sh
scripts/claude_delegate.sh health
CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0 scripts/claude_delegate.sh prepare 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
scripts/claude_delegate.sh status 050-project-detail-visual-qa-launch-fixture docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md
PATH="$tmpdir:$PATH" CLAUDE_DELEGATE_MODE=print CLAUDE_DELEGATE_LOG_DIR="$tmpdir/logs" scripts/claude_delegate.sh launch 053-delegation-resource-tree-guard docs/subtasks/053-delegation-resource-tree-guard-prd.md docs/subtasks/053-delegation-resource-tree-guard-progress.md
git worktree list --porcelain | rg -n "subtask-053|worker-subtask-053" || true
git branch --list worker-subtask-053-delegation-resource-tree-guard
git diff --check
```

Results:

- Syntax check passed.
- `health` reports direct Codex zombies, Codex process-tree zombies, Codex tree process count, total zombies, and task liveness without requiring a progress file.
- With `CLAUDE_DELEGATE_MAX_CODEX_ZOMBIES=0`, `prepare` exits `75`, proving guard blocking uses current Codex tree pressure.
- Existing 050 accepted status still surfaces normally.
- Fake print-mode Claude exited `0` without handoff; wrapper returned `75` and reported `claude print launch exited without HANDOFF`.
- Temporary 053 fake worker worktree and branch were removed after the regression.
- `git diff --check` passed.

## Residual Risk

- Current post-restart health still shows Codex-owned zombies below threshold, not zero. A shell wrapper cannot reap zombies if the Codex parent process does not reap them.
- `kernel_task` has a high thread count in `top`, but that is OS kernel accounting and is not the same root-cause signal as `<defunct>` Codex children.
- Real tmux-mode Claude launch remains constrained by the current non-TTY Codex host; print mode is still an explicit escape hatch, now with stricter failure classification.
