# Claude Prompt: Subtask 044 Project Status Filter

You are a bounded implementation worker for Codex. Codex owns architecture, product judgment, and final review.

Invoke and follow the Claude skill `codex-delegated-worker` if it is available.

## Workspace

You are running in the isolated worker worktree created by `scripts/claude_delegate.sh`.

## Read Before Editing

Read these files first:

- `docs/subtasks/044-project-status-filter-prd.md`
- `docs/subtasks/044-project-status-filter-progress.md`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Use `rg` and narrow `sed` ranges. Do not read the whole large SwiftUI file at once.

## Hard Constraints

- Use TDD for behavior changes.
- Update `docs/subtasks/044-project-status-filter-progress.md` at exactly these checkpoints:
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

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/044-project-status-filter-progress.md`

Do not edit:

- `Sources/App/AppStore.swift`
- persistence, migrations, repositories, GRDB code
- prompt/provider/client/parser/LLM/Keychain code
- Today, History, Growth, Settings behavior outside focused helper/test needs
- assets, screenshots, unrelated docs

## Implementation Requirements

Implement exactly the PRD:

1. Add local `@State` in `ProjectsView` for an optional `ProjectStatus` filter.
2. Add a compact filter control near the `项目工作台` header with `全部` plus every `ProjectStatus.allCases` option.
3. Filter the displayed board items only; keep `议题治理` / merge review behavior based on unfiltered `projectItems`.
4. Items missing from `store.projectsById` must remain visible under `全部` and disappear under concrete status filters.
5. Count copy must distinguish filtered count from total count for concrete filters.
6. Empty filtered states must say no item matches the selected status, not that there is no project evidence.
7. Keep UI restrained and consistent with existing DS patterns.

Add focused helper tests in `Tests/Features/HistoryFeatureTests.swift`:

1. `projectStatusFilteredItems` with `nil` status returns all items.
2. Filtering by `.active` returns only active projects.
3. Missing project metadata is preserved for `nil` filter and excluded from concrete status filters.
4. Project board count copy for a concrete filter distinguishes filtered count from total count.

## Required Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
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
