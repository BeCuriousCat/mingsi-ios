# Subtask 039 PRD: First Principles Lens Catalog

## Goal

Add `第一性原理` as an MVP built-in thinking lens while establishing a lightweight lens catalog boundary.

The user should see `第一性原理` in Today `SelectLens` as a normal first-party lens card, but the implementation should not be another UI-only chimney. The lens should be represented as an item in a local built-in catalog so future lens packs, custom lenses, or versioned prompt assets can build on the same boundary.

## Product Principle

MingSi is a personal thinking operating system. A lens is not just a button label; it is a thinking method asset with:

- a durable local id;
- a prompt-facing id;
- a version;
- display copy;
- method guidance;
- UI symbol metadata.

MVP ships only built-in first-party lenses. It does not add custom lens creation, marketplace packs, remote lens fetch, persistence migrations, or dynamic prompt asset storage.

## Scope

Allowed source files:

- `Sources/Domain/Models.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift` or `Tests/Features/HistoryFeatureTests.swift`

Allowed documentation file:

- `docs/subtasks/039-first-principles-lens-catalog-progress.md`

Expected implementation:

1. Add a lightweight local catalog boundary for built-in lenses.
2. Add `firstPrinciples` as a `ThinkingLens` case without changing existing raw values.
3. Keep existing persisted ids stable:
   - `evidenceCheck`
   - `opposingView`
   - `leverageAnalysis`
4. Add catalog metadata for all current lenses:
   - title;
   - subtitle;
   - short label;
   - method line;
   - SF Symbol name;
   - prompt-facing id;
   - version.
5. Update Today lens card display to read from the catalog metadata, not from separate UI-only switch statements.
6. Add tests that prove:
   - `firstPrinciples` is included in the built-in catalog;
   - existing raw values remain unchanged;
   - prompt-facing ids are snake_case where applicable;
   - the Today UI metadata for `firstPrinciples` is present through the shared catalog;
   - `ThinkingLens.allCases` includes `firstPrinciples` so the lens card appears in the existing `ForEach`.

## Copy Requirements

Use this product copy unless a small grammar adjustment is necessary:

- Title: `第一性原理`
- Short label: `本质`
- Subtitle: `拆掉默认前提，只保留不可再拆的事实和约束。`
- Method line: `先问：如果从零开始，这件事必须成立的条件是什么？`
- Prompt-facing id: `first_principles`
- Version: `builtin.v1`
- Suggested SF Symbol: `square.stack.3d.down.right`

Existing lens copy should remain visually consistent and semantically unchanged.

## Non-Goals

- No persistence migration.
- No new database table.
- No custom lens editor.
- No remote lens catalog.
- No prompt text rewrite.
- No parser rewrite.
- No AppStore state-machine behavior change.
- No changes to History, Projects, Growth, Settings, Keychain, LLM clients, or repositories.
- No fake data.

## Architecture Requirements

- `ThinkingLens.rawValue` remains the durable local id used by existing persistence.
- Prompt-facing id must be a separate catalog field, not a forced rewrite of `rawValue`.
- The built-in catalog can live near `ThinkingLens` in `Sources/Domain/Models.swift`.
- SwiftUI styling that requires `Color` should remain in `TodayView.swift`, but copy/symbol/version/prompt ids should come from catalog metadata where practical.
- The implementation should leave an obvious future extension point for a `LensCard` / lens-pack system without implementing that system now.

## Acceptance Criteria

- Today lens picker includes `第一性原理`.
- Existing three lens raw values are unchanged.
- Existing three lens titles/subtitles remain unchanged.
- `firstPrinciples` has prompt id `first_principles` and version `builtin.v1`.
- Today lens card uses catalog metadata for title, short label, subtitle, method line, and symbol name.
- Focused tests pass.
- `git diff --check` passes.
- iPhone 17 simulator build passes.

## Verification

Worker should run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

If the selected focused test target is not appropriate after inspection, worker may instead run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If xcodebuild cannot run due worker worktree infrastructure or simulator availability, report `DONE_WITH_CONCERNS` or `NEEDS_CONTEXT` with the exact error and do not modify dependencies.
