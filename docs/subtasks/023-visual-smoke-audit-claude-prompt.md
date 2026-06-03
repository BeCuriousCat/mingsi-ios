# Claude Prompt: Subtask 023 Visual Smoke Audit

You are Claude Code working as a bounded read-only worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if it is available.

## Manager Contract

Codex remains product owner, architect, reviewer, and final verifier. You are responsible only for this read-only audit slice.

## Required First Steps

1. Read `docs/subtasks/023-visual-smoke-audit-prd.md`.
2. Read:
   - `docs/mvp-current-goal.md`
   - `docs/mvp-stage-progress.md`
   - `docs/implementation-gap-audit.md`
   - `docs/architecture-decisions.md`
   - `docs/ux-flow.md`
   - `docs/verification-log.md`
3. Update `docs/subtasks/023-visual-smoke-audit-progress.md` with `START`.

## Strict Write Boundary

You may only write:

- `docs/subtasks/023-visual-smoke-audit-progress.md`
- `docs/subtasks/023-visual-smoke-audit-findings.md`

Do not edit source code, tests, assets, Xcode project files, or other docs.

## Task

Perform a visual and interaction smoke audit for the current MingSi app across:

- Today
- History
- Projects
- Growth
- Settings

Prefer actual iPhone 17 simulator inspection if available. If simulator launch or visual inspection is blocked, do a code-informed audit and clearly label every finding as `code-inferred`.

Focus on:

- dark-mode readability
- tab bar/safe-area overlap
- page gutters and clipped controls
- History advanced filter/calendar/dropdown behavior
- Projects evidence hierarchy and merge audit display
- Growth report and metric explanation clarity
- Settings GLM configuration and AI audit list scalability
- whether the UI feels like a calm native thinking coach rather than an AI wrapper

## Required Output

Create `docs/subtasks/023-visual-smoke-audit-findings.md` with:

- Audit environment and commands attempted.
- Per-tab status: `PASS`, `CONCERN`, or `BLOCKED`.
- Severity-ranked findings.
- Reproduction steps.
- Evidence type: `visually-confirmed` or `code-inferred`.
- Suggested owner decision: `fix now`, `backlog`, `needs product decision`, or `unable to verify`.
- Top 3 recommended next fixes for Codex.

Then update progress:

- `TARGETED_VERIFIED`: after findings are written.
- `HANDOFF`: final token plus short summary.

Final status token must be one of:

- DONE
- DONE_WITH_CONCERNS
- NEEDS_CONTEXT
- BLOCKED
