# Claude Code Prompt: Subtask 016 Growth Report Trigger Review

You are an implementation/review worker in the MingSi iOS repo. Codex owns architecture and final verification.

## Task

Review and, if appropriate, implement only the Growth report trigger slice described in:

- `docs/subtasks/016-growth-report-trigger-prd.md`
- `docs/subtasks/016-growth-report-trigger-progress.md`

## Ownership

Preferred write scope if implementing:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/016-growth-report-trigger-progress.md`

Do not edit persistence migrations, prompt specs, project files, or unrelated UI.

## Rules

- You are not alone in the codebase. Do not revert other changes.
- Use TDD: write failing tests before production code.
- Growth is an attribution ledger, not a personality test.
- Do not show Growth scores when evidence is insufficient.
- Do not create MetricContribution without source evidence.
- Keep UI quiet: no purple gradients, no fake dashboards, no large decorative cards.

## Progress Protocol

Update `docs/subtasks/016-growth-report-trigger-progress.md` at start and after each checklist step.

## Expected Final Response

Report:

- Files changed.
- Tests run and exact results.
- Any unresolved concerns.
