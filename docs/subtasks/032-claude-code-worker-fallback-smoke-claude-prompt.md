# Claude Prompt: Subtask 032 Worker Fallback Smoke

Use the Claude skill `codex-delegated-worker` if available.

Read the PRD first:

- `docs/subtasks/032-claude-code-worker-fallback-smoke-prd.md`

Then execute this read-only smoke exactly:

1. Write `START` to the progress file before broad inspection.
2. Confirm the current working directory with `pwd`.
3. Run `git status --short`.
4. Inspect only these files:
   - `scripts/claude_delegate.sh`
   - `docs/subtasks/032-claude-code-worker-fallback-smoke-prd.md`
   - `docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md`
5. Write `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, and `HANDOFF` in the progress file.
6. Do not edit product source code.
7. Do not commit.

Hand off with a short summary that answers:

- What was the current working directory?
- Did the worker progress file reach `HANDOFF`?
- Were any product source files modified?
