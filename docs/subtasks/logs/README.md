# Claude Code Logs

This directory contains raw Claude Code output logs that were launched by Codex for delegated subtasks.

Current archived logs:

- `027-claude-run.jsonl`: failed Subtask 027 launch; ended before `START` because Claude Code could not connect to the API.
- `027-claude-run-escalated.jsonl`: successful Subtask 027 escalated launch; reached `HANDOFF` and final status `DONE`.
- `029-claude-run-failed-args.jsonl`: failed Subtask 029 launch; prompt argument was swallowed by CLI argument parsing before `START`.
- `029-claude-run-no-start.jsonl`: stopped Subtask 029 launch; worker produced log output but never updated `START`.
- `029-claude-run-focused.jsonl`: stopped Subtask 029 focused launch; worker reached `START` but did not reach `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, or `HANDOFF`.

Older zero-byte `.log` files are historical failed attempts where no useful stream output was captured.

For the current delegation status, start with `docs/subtasks/claude-code-current-status.md`.
