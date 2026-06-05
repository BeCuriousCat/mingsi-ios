# Claude Code Prompt: Subtask 039 First Principles Lens Catalog

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns product judgment, architecture, final review, and final verification. You own only this scoped implementation slice.

## Read First

First read:

- `docs/subtasks/039-first-principles-lens-catalog-prd.md`
- `docs/subtasks/039-first-principles-lens-catalog-progress.md`
- `docs/architecture-decisions.md`
- `docs/prompt-spec.md` sections for Thinking Lens and future lens packs

Then update `docs/subtasks/039-first-principles-lens-catalog-progress.md` with `START` before broad source inspection.

For source files, avoid whole-file reads up front. Use targeted ranges first:

- `Sources/Domain/Models.swift` lines 95-145
- `Sources/Features/Today/TodayView.swift` lines 720-835
- `Sources/Features/Today/TodayView.swift` lines 1035-1075
- `Tests/App/AppStoreStateMachineTests.swift` lines 1-70

Only inspect additional narrow ranges after `rg` identifies a relevant line.

## Progress Contract

Update `docs/subtasks/039-first-principles-lens-catalog-progress.md` at exactly:

- `START`: after reading PRD/progress and before broad source inspection;
- `RED`: after adding failing tests;
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

- `Sources/Domain/Models.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Allowed documentation file:

- `docs/subtasks/039-first-principles-lens-catalog-progress.md`

Do not edit any other file. If another file appears necessary, write `NEEDS_CONTEXT`.

## Required Behavior

- Add `firstPrinciples` as an MVP built-in `ThinkingLens`.
- Do not change existing lens raw values:
  - `ThinkingLens.evidenceCheck.rawValue == "evidenceCheck"`
  - `ThinkingLens.opposingView.rawValue == "opposingView"`
  - `ThinkingLens.leverageAnalysis.rawValue == "leverageAnalysis"`
- Add a lightweight built-in catalog boundary near `ThinkingLens`.
- Catalog metadata must include:
  - durable local lens id;
  - prompt-facing id;
  - version;
  - title;
  - subtitle;
  - short label;
  - method line;
  - SF Symbol name.
- `firstPrinciples` metadata:
  - title: `第一性原理`
  - short label: `本质`
  - subtitle: `拆掉默认前提，只保留不可再拆的事实和约束。`
  - method line: `先问：如果从零开始，这件事必须成立的条件是什么？`
  - prompt-facing id: `first_principles`
  - version: `builtin.v1`
  - symbol: `square.stack.3d.down.right`
- Update Today lens card display so title, short label, subtitle, method line, and symbol name read from catalog metadata rather than separate UI-only switch statements.
- Keep tint/color mapping in `TodayView.swift`; domain model must not import SwiftUI.

## Tests

Use TDD. Add focused tests before implementation in one existing test file.

Required test coverage:

- `ThinkingLens.allCases` contains `.firstPrinciples`.
- Existing three lens raw values remain stable.
- Built-in catalog contains one item per `ThinkingLens.allCases`.
- `firstPrinciples` catalog metadata has title `第一性原理`, prompt id `first_principles`, version `builtin.v1`, and a non-empty symbol name.
- Existing lens titles remain unchanged.

## Explicit Non-Goals

Do not change:

- persistence schema or migrations;
- repositories;
- parser behavior;
- PromptProvider or prompt text;
- LLM clients;
- Keychain;
- AppStore orchestration;
- History / Project / Growth / Settings behavior;
- Today loop state transitions;
- dynamic/custom lens UI.

## Architecture Rules

- SwiftUI views must not import GRDB.
- SwiftUI views must not call `LLMClient`.
- Domain model must not import SwiftUI.
- No fake data, fake history, or unsupported growth/project claims.
- Preserve existing DS styling and dark-mode readability.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

If you put tests in `HistoryFeatureTests`, run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If xcodebuild fails due missing local infrastructure or simulator availability, report `DONE_WITH_CONCERNS` or `NEEDS_CONTEXT` with the exact error. Do not modify dependencies.

## Handoff Format

At the end, update the progress file with `HANDOFF` and include:

- final status token;
- changed files;
- root cause / product gap;
- implementation summary;
- verification commands and results;
- any remaining risk for Codex review.
