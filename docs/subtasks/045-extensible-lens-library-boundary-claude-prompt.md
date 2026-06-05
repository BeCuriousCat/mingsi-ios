# Claude Prompt: Subtask 045 Extensible Lens Library Boundary

You are a bounded implementation worker for Codex. Codex owns product judgment, architecture acceptance, and final verification.

Invoke and follow the Claude skill `codex-delegated-worker` if it is available.

## Workspace

You are running in the isolated worker worktree created by `scripts/claude_delegate.sh`.

## Read Before Editing

Read these files first:

- `docs/subtasks/045-extensible-lens-library-boundary-prd.md`
- `docs/subtasks/045-extensible-lens-library-boundary-progress.md`
- `docs/subtasks/039-first-principles-lens-catalog-prd.md`
- `docs/subtasks/042-lens-prompt-context-wiring-prd.md`
- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`

Use `rg` and narrow `sed` ranges. Do not read large files in full unless a narrow search cannot locate the relevant section.

## Hard Constraints

- Use TDD for behavior changes.
- Update `docs/subtasks/045-extensible-lens-library-boundary-progress.md` at exactly these checkpoints:
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

- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/045-extensible-lens-library-boundary-progress.md`

Do not edit:

- SwiftUI views
- `Sources/App/AppStore.swift`
- persistence, migrations, repositories, GRDB code
- PromptProvider or prompt text
- parser code
- LLM clients
- Keychain
- History / Projects / Growth / Settings
- assets, screenshots, unrelated docs

## Implementation Requirements

Implement the PRD narrowly:

1. Add a compact reusable catalog/provider boundary in Domain. Acceptable names include `LensCatalogProviding`, `BuiltInLensLibrary`, or a similarly clear equivalent.
2. The boundary must support:
   - listing all items;
   - lookup by durable local id;
   - lookup by prompt-facing id;
   - lookup by `ThinkingLens`.
3. Keep `BuiltinLensCatalog.items` compatible unless there is a strong reason to change it.
4. Keep `ThinkingLens.catalogItem`, `title`, and `subtitle` compatible.
5. Keep first principles as normal catalog data:
   - local id `firstPrinciples`
   - prompt id `first_principles`
   - title `第一性原理`
   - version `builtin.v1`
6. Do not add custom lens creation, remote loading, persistence, migrations, prompt rewrites, parser changes, UI changes, or AppStore state.

## Required Tests

Add focused tests near the existing `// MARK: - ThinkingLens Catalog` tests in `Tests/App/AppStoreStateMachineTests.swift`:

- The built-in library lists one item per `ThinkingLens.allCases`.
- Lookup by local id `firstPrinciples` returns the first-principles item.
- Lookup by prompt id `first_principles` returns the first-principles item.
- `ThinkingLens.firstPrinciples.catalogItem` resolves through the same metadata.
- Existing raw values and prompt ids remain stable.

## Required Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

If `xcodebuild` fails in the isolated worker worktree because of the known vendored GRDB custom path issue, record the exact failure in `HANDOFF`, still run `git diff --check`, and use final status `DONE_WITH_CONCERNS`.

## Final Handoff Format

End the progress file `## HANDOFF` section with exactly one status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

Also summarize:

- files changed
- implementation summary
- tests run and result
- concerns or follow-ups
