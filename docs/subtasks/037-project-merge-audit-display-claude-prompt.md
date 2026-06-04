# Claude Code Prompt: Subtask 037 Project Merge Audit Display

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns product judgment, architecture, final review, and final verification. You own only this scoped implementation slice.

## Read First

First read:

- `docs/subtasks/037-project-merge-audit-display-prd.md`
- `docs/subtasks/037-project-merge-audit-display-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`

Then update `docs/subtasks/037-project-merge-audit-display-progress.md` with `START` before broad source inspection.

For source files, avoid whole-file reads up front. Use targeted ranges first:

- `Sources/Features/FeatureTabs.swift` lines 1230-1455
- `Sources/Features/FeatureTabs.swift` lines 3279-3525
- `Sources/Features/FeatureTabs.swift` lines 4990-5075
- `Tests/Features/HistoryFeatureTests.swift` lines 468-590

Only inspect additional narrow ranges after a search identifies a relevant line.

## Progress Contract

Update `docs/subtasks/037-project-merge-audit-display-progress.md` at exactly:

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

- `docs/subtasks/037-project-merge-audit-display-progress.md`

Do not edit any other file. If another file appears necessary, write `NEEDS_CONTEXT`.

## Required Behavior

- Add small display helpers for Project merge audit copy.
- Pending merge candidate row should explain:
  - target project remains active;
  - source project is archived;
  - existing evidence links are retained, not moved.
- Pending merge candidate row should show evidence count and compact evidence ref preview when refs exist.
- Project detail should show a `合并审计` section only when `project.mergeHistory` has non-empty trimmed lines.
- The `合并审计` section should display retained audit lines as stored, after trimming surrounding whitespace.
- Do not invent evidence titles, dates, claims, or source details.

## Tests

Use TDD. Add focused tests before implementation in `Tests/Features/HistoryFeatureTests.swift`.

Required test coverage:

- empty merge history produces no audit display lines;
- whitespace-only merge history is ignored;
- non-empty merge history is trimmed and preserved;
- candidate evidence summary includes count and compact refs;
- candidate consequence copy does not claim links are moved or source is deleted.

## Explicit Non-Goals

Do not change:

- AppStore merge actions;
- Project repositories;
- migrations;
- parser;
- PromptProvider or prompt text;
- LLM clients;
- Keychain;
- Today workflow;
- History repair behavior;
- Growth semantics.

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
