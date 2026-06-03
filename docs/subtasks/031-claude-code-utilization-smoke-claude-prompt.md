# Claude Prompt: Subtask 031 Utilization Smoke Audit

Use the Claude skill `codex-delegated-worker` if available.

Read the PRD first:

- `docs/subtasks/031-claude-code-utilization-smoke-prd.md`

Then execute this read-only audit exactly:

1. Write `START` to the progress file before broad inspection.
2. Inspect only these files:
   - `scripts/claude_delegate.sh`
   - `scripts/claude_event_bridge.sh`
   - `docs/subtasks/030-claude-code-pipeline-hardening-progress.md`
   - `docs/subtasks/claude-code-current-status.md`
3. Identify whether the wrapper now looks safe for the next real bounded implementation slice.
4. Identify any remaining blocking gap in launch, progress tracking, or monitoring.
5. Write `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, and `HANDOFF` in the progress file.
6. Do not edit source code.

Hand off with a short summary that answers:

- Did the worker actually run through the wrapper?
- Is the wrapper good enough to use for the next bounded implementation slice?
- If not, what is the single remaining blocking gap?
