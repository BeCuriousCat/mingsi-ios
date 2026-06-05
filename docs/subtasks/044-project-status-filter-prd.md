# Subtask 044 PRD: Project Status Filter

Date: 2026-06-05

## Goal

Add a local status filter to the Projects top-level board so the alpha user can scan active, watching, paused, and archived long-running topics without changing Project semantics or persistence.

This is a bounded MVP hardening slice. The feature must stay display-only: it exposes existing `ProjectStatus` values already stored on `Project`, and it does not create, update, infer, or migrate any Project data.

## Background

`docs/mvp-stage-progress.md` lists Project top-level status filtering as a current recommended next slice if project count/scanning becomes user-facing.

`Sources/Features/FeatureTabs.swift` currently builds `ProjectsView.projectItems` from `store.historyRecords` project links and displays every evidence-backed item together. Project Detail already shows `project?.status.title`, and `ProjectEditorSheet` can archive/restore projects, but the top-level Projects board does not let the user filter by status.

## Scope

Allowed source files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/044-project-status-filter-progress.md`

Do not edit:

- `Sources/App/AppStore.swift`
- persistence, migrations, repositories, GRDB code
- prompt/provider/client/parser code
- Today, History, Growth, Settings behavior outside the focused helper/test needs
- assets, screenshots, unrelated docs

## Product Requirements

1. Add a compact status filter control near the Projects `项目工作台` header.
2. The control must include:
   - `全部`
   - one option for each `ProjectStatus.allCases`
3. Selecting `全部` shows all current `projectItems`.
4. Selecting a concrete status shows only `ProjectEvidenceBoardItem` values whose corresponding `store.projectsById[item.id]?.status` equals that status.
5. Evidence-backed items whose `Project` object is missing from `store.projectsById` must:
   - show under `全部`;
   - not be included under any concrete status filter.
6. The board count text should make the filter state clear:
   - no filter: current count behavior is acceptable;
   - concrete filter: show filtered count and total count.
7. If a concrete filter has no matching items, show an empty state that explains no item matches the selected status, without implying there is no project evidence at all.
8. `议题治理` / merge review behavior must not be narrowed by the current display filter. The merge button availability should still be based on the unfiltered evidence-backed project count.

## Architecture Requirements

- Keep filter state local to `ProjectsView` with `@State`.
- Keep status filtering as view/helper logic; do not add AppStore state.
- Do not change `ProjectStatus` raw values.
- Add small helper functions or structs near existing Project display helpers if that makes tests straightforward.
- Existing `ProjectStatus.title` may be reused, but user-facing filter labels should be readable in Chinese if changed or exposed.

## Acceptance Tests

Add focused tests in `Tests/Features/HistoryFeatureTests.swift` for helper behavior:

1. `projectStatusFilteredItems` with `nil` status returns all items.
2. Filtering by `.active` returns only items whose project status is `.active`.
3. Items missing from the `projectsById` dictionary are preserved for `nil` filter and excluded from concrete status filters.
4. Project board count copy for a concrete filter distinguishes filtered count from total count.

Use lightweight domain objects; do not require database setup for these helper tests.

## Required Verification

Worker should run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If the isolated worker worktree cannot run `xcodebuild` due the known GRDB custom path issue, worker must still run `git diff --check`, record the exact `xcodebuild` failure in `HANDOFF`, and leave manager verification to Codex.

Codex will rerun targeted tests and an iPhone 17 simulator build in the manager checkout before accepting.

## Non-Goals

- No persistence changes.
- No Project status semantics changes.
- No Project creation, archive, restore, merge, or insight behavior changes.
- No saved filter persistence.
- No visual screenshot claim in this slice unless Codex chooses to run later visual smoke.
