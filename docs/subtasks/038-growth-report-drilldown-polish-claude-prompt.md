# Claude Code Prompt: Subtask 038 Growth Report Drilldown Polish

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns product judgment, architecture, final review, and final verification. You own only this scoped implementation slice.

## Read First

First read:

- `docs/subtasks/038-growth-report-drilldown-polish-prd.md`
- `docs/subtasks/038-growth-report-drilldown-polish-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`

Then update `docs/subtasks/038-growth-report-drilldown-polish-progress.md` with `START` before broad source inspection.

For source files, avoid whole-file reads up front. Use targeted ranges first:

- `Sources/Features/FeatureTabs.swift` lines 1440-1868
- `Sources/Features/FeatureTabs.swift` lines 4070-4425
- `Tests/Features/HistoryFeatureTests.swift` lines 731-790

Only inspect additional narrow ranges after `rg` identifies a relevant line.

## Progress Contract

Update `docs/subtasks/038-growth-report-drilldown-polish-progress.md` at exactly:

- `START`: after reading PRD/progress and before broad source inspection;
- `RED`: after adding failing helper tests;
- `IMPLEMENTED`: after source changes are applied;
- `TARGETED_VERIFIED`: after required verification commands;
- `HANDOFF`: final report with one status token.

Do not use extra checkpoint names.

At `HANDOFF`, include one of:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Scope

Allowed source files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Allowed documentation file:

- `docs/subtasks/038-growth-report-drilldown-polish-progress.md`

Do not edit any other file. If another file appears necessary, write `NEEDS_CONTEXT`.

## Required Behavior

- Add small testable display helpers for Growth report review and metric detail copy.
- Helper behavior must cover:
  - metric display title;
  - positive/negative accepted contribution count summary;
  - leading contribution by largest absolute `delta`;
  - trimmed metric reason;
  - conservative fallback reason when reason is missing but accepted contributions exist.
- Use helpers in `GrowthReportReviewPanel`, `GrowthReportMetricEvidenceRow`, and/or `MetricDetailSheet`.
- Keep existing source navigation from contribution rows unchanged.
- Keep insufficient-evidence and empty-review states conservative.
- Do not invent dates, source titles, claims, or longitudinal conclusions.

## Tests

Use TDD. Add focused tests before implementation in `Tests/Features/HistoryFeatureTests.swift`.

Required test coverage:

- positive/negative count summary;
- leading contribution chooses largest absolute delta;
- metric reason trims whitespace;
- fallback reason appears only when reason is missing and contributions exist;
- no fallback reason appears when there is no reason and no contributions.

## Explicit Non-Goals

Do not change:

- AppStore Growth actions;
- Growth score computation;
- repositories;
- migrations;
- parser;
- PromptProvider or prompt text;
- LLM clients;
- Keychain;
- Today workflow;
- History repair behavior;
- Project semantics.

## Architecture Rules

- SwiftUI views must not import GRDB.
- SwiftUI views must not call `LLMClient`.
- No fake data, fake history, or fake evidence.
- Preserve existing DS styling and dark-mode readability.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If xcodebuild fails due missing local infrastructure or simulator availability, report `NEEDS_CONTEXT` with the exact error. Do not modify dependencies.

## Handoff Format

At the end, update the progress file with `HANDOFF` and include:

- final status token;
- changed files;
- root cause / display gap;
- implementation summary;
- verification commands and results;
- any remaining risk for Codex review.

## Relaunch Guard

If this prompt is relaunched and the progress file already contains `IMPLEMENTED` and `TARGETED_VERIFIED` but no `HANDOFF`, do not continue feature expansion.

On relaunch:

1. Read the current progress file.
2. Inspect only the already touched files enough to confirm the summary is still accurate.
3. If verification evidence is already present and no blocker remains, append `## HANDOFF` with status `DONE` or `DONE_WITH_CONCERNS`.
4. If verification evidence is insufficient, run only the required verification commands, then append `## HANDOFF`.
5. If you cannot complete the handoff, append `## HANDOFF` with `NEEDS_CONTEXT` or `BLOCKED` and explain why.
