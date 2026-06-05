# Subtask 046 PRD: Delegation Strict Handoff Detection

Date: 2026-06-05

## Goal

Tighten `scripts/claude_delegate.sh` so `status` and `wait` treat a progress file as complete only when the handoff section contains a real final status token.

Subtask 044 exposed the bug: `status` displayed an `active handoff summary` for the progress-template placeholder `## HANDOFF` before the worker had actually delivered. Codex correctly ignored that placeholder, but the wrapper should not present it as an active handoff.

## Product / Framework Principle

This is a delegation-framework slice, not a MingSi product feature.

The manager-facing conclusion source is the progress file. The wrapper must distinguish:

- conclusion progress: checkpoints, findings, concerns, final handoff;
- flow logs: retained raw/event logs used only for diagnosis;
- placeholder text: instructions or templates that must not be treated as delivery.

False-positive handoff detection wastes manager attention and can cause premature acceptance of unfinished worker output.

## Scope

Allowed source files:

- `scripts/claude_delegate.sh`

Allowed documentation files:

- `docs/subtasks/046-delegation-strict-handoff-detection-progress.md`

Do not edit:

- MingSi product source files
- Swift tests or app feature tests
- persistence / migrations / repositories
- PromptProvider, prompt text, parser, LLM clients, Keychain
- existing raw/event logs
- unrelated process docs during worker implementation

Codex may update process docs after acceptance.

## Required Behavior

1. Bare `## HANDOFF` must not count as a completed handoff.
2. A handoff counts only when the progress file has at least one real final token:
   - `Status: DONE`
   - `Status: DONE_WITH_CONCERNS`
   - `Status: NEEDS_CONTEXT`
   - `Status: BLOCKED`
   - `Final status token: DONE`
   - `Final status token: DONE_WITH_CONCERNS`
   - `Final status token: NEEDS_CONTEXT`
   - `Final status token: BLOCKED`
   - a bullet checkpoint such as `- HANDOFF: DONE`
   - a `## HANDOFF` section containing one of the final token forms above.
3. `Status: CODEX_ACCEPTED` remains a manager-side accepted conclusion and must still be preferred by `current_progress_path`.
4. `status` should print `active handoff summary` only when strict final-token detection succeeds.
5. `wait` should exit `0` only when strict final-token detection succeeds.
6. `HANDOFF: pending`, `Pending worker update.`, or a template `## HANDOFF` section with no final token must still cause `wait` to exit `75`.
7. Flow logs remain hidden by default.

## Acceptance Evidence

Use real repo fixtures plus one temporary negative fixture.

Required checks:

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

Expected:

- Syntax check passes.
- 044 real handoff still surfaces `Status: DONE_WITH_CONCERNS`.
- Placeholder progress file does not print active handoff summary.
- Placeholder progress file `wait` exits `75`.
- 029 pending/non-worker handoff still exits `75`.
- `git diff --check` passes.

## Non-Goals

- No rewrite of launch mode.
- No change to check cadence.
- No raw/event log parsing in normal status.
- No MingSi product behavior changes.
- No new Swift/Xcode tests.
- No broad delegation-framework refactor.

