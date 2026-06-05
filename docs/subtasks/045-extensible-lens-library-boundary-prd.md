# Subtask 045 PRD: Extensible Lens Library Boundary

Date: 2026-06-05

## Goal

Turn the current built-in lens catalog into a small extensible lens library boundary, while keeping `第一性原理` as an MVP first-party built-in lens.

Subtasks 039 and 042 already added:

- `ThinkingLens.firstPrinciples`
- `LensCatalogItem`
- `BuiltinLensCatalog`
- Today lens card metadata reads from catalog fields
- Today AI prompt payloads use prompt-facing lens ids such as `first_principles`

This slice should not redo that work. It should make the architecture clearer: built-in lenses are provided through a catalog/provider boundary so future custom lenses, lens packs, or remote/versioned prompt assets can plug into the same lookup model instead of adding UI/prompt smoke stacks.

## Product Principle

A lens is a thinking-method asset, not a UI enum label.

MVP ships only first-party built-in lenses, including `第一性原理`. The extensibility boundary should make these future paths natural without implementing them now:

- multiple first-party lens packs;
- user-created custom lenses;
- remote/versioned lens metadata;
- prompt assets that evolve independently from local persistence ids.

## Scope

Allowed source files:

- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`

Allowed documentation file:

- `docs/subtasks/045-extensible-lens-library-boundary-progress.md`

Do not edit:

- SwiftUI views
- AppStore orchestration
- persistence, migrations, repositories, GRDB code
- PromptProvider or prompt text
- parser code
- LLM clients
- Keychain
- History / Projects / Growth / Settings
- assets, screenshots, unrelated docs

## Required Behavior

1. Keep existing local ids stable:
   - `ThinkingLens.evidenceCheck.rawValue == "evidenceCheck"`
   - `ThinkingLens.opposingView.rawValue == "opposingView"`
   - `ThinkingLens.leverageAnalysis.rawValue == "leverageAnalysis"`
   - `ThinkingLens.firstPrinciples.rawValue == "firstPrinciples"`

2. Keep existing prompt ids stable:
   - `evidence_check`
   - `opposing_view`
   - `leverage_analysis`
   - `first_principles`

3. Introduce a small reusable catalog/provider boundary, for example:
   - `LensCatalogProviding`
   - `BuiltInLensLibrary`
   - or an equivalent compact API.

4. The boundary must support at least:
   - listing catalog items;
   - lookup by durable local id;
   - lookup by prompt-facing id;
   - lookup by `ThinkingLens`.

5. Preserve compatibility:
   - `BuiltinLensCatalog.items` should continue to work for existing callers/tests unless there is a strong reason to rename.
   - `ThinkingLens.catalogItem`, `title`, and `subtitle` should continue to work.
   - Today AI prompt wiring from Subtask 042 should not require source changes in this slice.

6. The first-party built-in library must contain `第一性原理` as an ordinary built-in catalog item, not a special-case branch.

## Tests

Add focused tests in `Tests/App/AppStoreStateMachineTests.swift` near the existing ThinkingLens catalog tests:

1. The library lists one item per `ThinkingLens.allCases`.
2. Lookup by local id returns `第一性原理` for `firstPrinciples`.
3. Lookup by prompt id returns `firstPrinciples` for `first_principles`.
4. `ThinkingLens.firstPrinciples.catalogItem` resolves through the same library metadata.
5. Existing raw values and prompt ids remain stable.

## Non-Goals

- No custom lens editor.
- No remote lens loading.
- No persistence migration or new database table.
- No prompt text rewrite.
- No parser changes.
- No AppStore state-machine changes.
- No UI redesign.
- No fake lens data beyond the current MVP built-ins.

## Architecture Requirements

- Domain must not import SwiftUI.
- Catalog metadata must remain presentation-neutral; symbols/copy are acceptable, colors are not.
- The boundary should be small enough to keep MVP maintainable.
- Avoid a large abstraction hierarchy. The goal is a clean extension point, not a full plugin system.
- Keep `ThinkingLens.rawValue` as durable local persistence identity.
- Keep `LensCatalogItem.promptId` as the model-facing identity.

## Verification

Worker should run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

If worker worktree `xcodebuild` is blocked by the known GRDB custom path issue, report `DONE_WITH_CONCERNS` with the exact error and still run `git diff --check`.

Codex will rerun focused tests and the iPhone 17 simulator build in the manager checkout before acceptance.
