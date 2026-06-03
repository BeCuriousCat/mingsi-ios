# Claude Prompt: Subtask 033 Conclusion-First Log Smoke

Use the Claude skill `codex-delegated-worker` if available.

Read the PRD first:

- `docs/subtasks/033-claude-code-conclusion-log-smoke-prd.md`

Then execute this read-only smoke exactly:

1. Write `START` to the progress file before broad inspection.
2. Confirm the current working directory with `pwd`.
3. Run `git status --short`.
4. Confirm these files exist in the worker worktree:
   - `scripts/claude_delegate.sh`
   - `scripts/claude_event_bridge.sh`
5. Inspect only these files:
   - `scripts/claude_delegate.sh`
   - `scripts/claude_event_bridge.sh`
   - `docs/subtasks/033-claude-code-conclusion-log-smoke-prd.md`
   - `docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md`
6. Write `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, and `HANDOFF` in the progress file.
7. Do not edit product source code.
8. Do not commit.

At handoff, answer:

- What was the current working directory?
- Were both scripts present in the worker worktree?
- Did the worker progress file reach `HANDOFF`?
- Were any product source files modified?
