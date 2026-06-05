# Claude Prompt: Subtask 046 Delegation Strict Handoff Detection

You are a bounded implementation worker for Codex. Codex owns architecture, process rules, acceptance, and final verification.

Invoke and follow the Claude skill `codex-delegated-worker` if it is available.

## Workspace

You are running in the isolated worker worktree created by `scripts/claude_delegate.sh`.

## Read Before Editing

Read these files first:

- `docs/subtasks/046-delegation-strict-handoff-detection-prd.md`
- `docs/subtasks/046-delegation-strict-handoff-detection-progress.md`
- `scripts/claude_delegate.sh`
- `docs/subtasks/044-project-status-filter-progress.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`

Use `rg` and narrow `sed` ranges. Do not read unrelated large files.

## Hard Constraints

- Use test-first shell regression checks.
- Update `docs/subtasks/046-delegation-strict-handoff-detection-progress.md` at exactly these checkpoints:
  - `START`
  - `RED`
  - `IMPLEMENTED`
  - `TARGETED_VERIFIED`
  - `HANDOFF`
- Mark `START` before broad source inspection.
- Keep the diff scoped to this subtask.
- Do not commit.
- Do not run destructive git commands.
- Leave unrelated dirty changes alone and report them.

Allowed write files:

- `scripts/claude_delegate.sh`
- `docs/subtasks/046-delegation-strict-handoff-detection-progress.md`

Do not edit:

- MingSi product source files
- Swift tests or app feature tests
- persistence / migrations / repositories
- PromptProvider, prompt text, parser, LLM clients, Keychain
- existing raw/event logs
- unrelated docs

## Implementation Requirements

Implement the PRD narrowly:

1. Make `handoff_reached` strict enough that bare `## HANDOFF` is not success.
2. Add a helper if useful, for example `final_handoff_token_reached`.
3. Treat these final tokens as real handoff:
   - top-level `Status: DONE`
   - top-level `Status: DONE_WITH_CONCERNS`
   - top-level `Status: NEEDS_CONTEXT`
   - top-level `Status: BLOCKED`
   - `Final status token: ...` with one of those four values
   - `- HANDOFF: DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
   - final token lines inside a `## HANDOFF` section.
4. Keep `Status: CODEX_ACCEPTED` as a manager-side accepted conclusion.
5. Make `status` print `active handoff summary` only when strict detection succeeds.
6. Make `wait` exit `0` only when strict detection succeeds.
7. Do not add raw/event log parsing to normal status.

## Required Verification

Run:

```bash
bash -n scripts/claude_delegate.sh

scripts/claude_delegate.sh status 044-project-status-filter docs/subtasks/044-project-status-filter-progress.md | rg -q 'Status: DONE_WITH_CONCERNS'

tmp_progress="$(mktemp)"
cat > "$tmp_progress" <<'EOF'
# Placeholder Progress

Status: PREPARED

## HANDOFF

Pending worker update.
EOF
scripts/claude_delegate.sh status 046-placeholder "$tmp_progress" | rg -q 'active handoff summary' && exit 1 || true
scripts/claude_delegate.sh wait 046-placeholder "$tmp_progress" 0 1; code=$?; test "$code" -eq 75
rm -f "$tmp_progress"

scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1; code=$?; test "$code" -eq 75

git diff --check
```

If a verification command fails, record the exact command, exit code, and output in the progress file and use `BLOCKED` or `DONE_WITH_CONCERNS` as appropriate.

## Final Handoff Format

At final handoff, append a new `## HANDOFF` section to the progress file with exactly one status token:

- `Status: DONE`
- `Status: DONE_WITH_CONCERNS`
- `Status: NEEDS_CONTEXT`
- `Status: BLOCKED`

Also summarize:

- files changed
- implementation summary
- verification commands and results
- concerns or follow-ups

