# Subtask 044 Progress: Project Status Filter

Status: CODEX_ACCEPTED
Timestamp: 2026-06-05

Owner: Codex manager
Delegated implementer: Claude Code worker

Required PRD: `docs/subtasks/044-project-status-filter-prd.md`
Worker prompt: `docs/subtasks/044-project-status-filter-claude-prompt.md`

## Scope

- Add a local display-only Project status filter in `ProjectsView`.
- Add focused helper tests.
- No AppStore, persistence, migration, prompt, parser, LLM, Keychain, Today, History, Growth, or Settings behavior changes.

## Manager Readiness

- `docs/mvp-stage-progress.md` lists Project top-level status filtering as a recommended next slice.
- The slice is bounded to existing `ProjectStatus` display and local filtering.
- The worker has explicit allowed files and acceptance tests.
- Codex will not inspect partial worker diffs before `HANDOFF`.

## START

Timestamp: 2026-06-05

Planned files:
- `Sources/Features/FeatureTabs.swift` — add filter state, filter control UI, helper functions
- `Tests/Features/HistoryFeatureTests.swift` — add 4 focused helper tests

Assumptions:
- `ProjectEvidenceBoardItem` is `private` to FeatureTabs.swift; helper functions will be file-private or internal for testability
- `projectsById` is `[UUID: Project]` on `AppStore`
- `ProjectStatus` has `.allCases` (active, watching, paused, archived) via `CaseIterable`
- Filter labels will use Chinese titles (活跃, 关注中, 暂停, 已归档)
- `议题治理` section must keep using unfiltered `projectItems` for its count check

## RED

Timestamp: 2026-06-05

Tests written:
- `testProjectStatusFilteredItems_nilStatusReturnsAllItems`
- `testProjectStatusFilteredItems_activeFilterReturnsOnlyActive`
- `testProjectStatusFilteredItems_missingProjectPreservedForNil_excludedForConcrete`
- `testProjectBoardCountText_concreteFilterDistinguishesFilteredFromTotal`

Expected failure: `ProjectEvidenceBoardItem` is `private` and helper functions `projectStatusFilteredItems` / `projectBoardCountText` do not exist yet — compilation will fail.

## IMPLEMENTED

Timestamp: 2026-06-05

Changed files:
- `Sources/Features/FeatureTabs.swift`:
  - `ProjectEvidenceBoardItem` changed from `private` to internal
  - Added `projectStatusFilteredItems(_:projectsById:status:)` helper
  - Added `projectBoardCountText(filteredCount:totalCount:filterStatus:)` helper
  - Added `chineseTitle` to private `ProjectStatus` extension
  - Added `@State private var statusFilter: ProjectStatus?` to `ProjectsView`
  - `projectBoard` now filters via helper, shows filter chips, shows status-specific empty state
  - Added `statusFilterChip` private view builder
  - `议题治理` unchanged (still uses unfiltered `projectItems`)
- `Tests/Features/HistoryFeatureTests.swift`:
  - Added `makeBoardItem` helper
  - Added 4 acceptance tests for filter helpers

## TARGETED_VERIFIED

Timestamp: 2026-06-05

- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`: **FAILED** due to known GRDB custom path issue: `invalid custom path 'Tests' for target 'GRDBTests'`. This is the expected failure in the isolated worker worktree.
- `git diff --check`: **PASSED** (no whitespace or merge conflict markers)

## HANDOFF

Status: DONE_WITH_CONCERNS

Changed files:
- `Sources/Features/FeatureTabs.swift` — filter state, filter control UI, helper functions, chineseTitle
- `Tests/Features/HistoryFeatureTests.swift` — 4 acceptance tests

Implementation summary:
- Added `@State private var statusFilter: ProjectStatus?` to `ProjectsView`
- Filter chip row with `全部` + one chip per `ProjectStatus.allCases` (Chinese labels: 活跃, 关注中, 暂停, 已归档)
- `projectStatusFilteredItems` helper: nil returns all, concrete status filters by `store.projectsById[item.id]?.status`, missing projects excluded from concrete filters
- `projectBoardCountText` helper: nil shows `N 个证据项目`, concrete shows `filtered / total 个<status>项目`
- Empty filtered state: `没有匹配「<status>」状态的项目。`
- `议题治理` / merge review section unchanged — still uses unfiltered `projectItems` for count checks
- `ProjectEvidenceBoardItem` changed from `private` to internal for testability

Verification:
- `xcodebuild` test: FAILED — known GRDB custom path issue (`invalid custom path 'Tests' for target 'GRDBTests'`). Cannot run tests in worker worktree.
- `git diff --check`: PASSED

Handoff notes:
- Codex must rerun `xcodebuild -only-testing:MingSiTests/HistoryFeatureTests` in the manager checkout to verify the 4 new tests pass
- `ProjectEvidenceBoardItem` visibility changed from `private` to internal — acceptable per PRD's "Add small helper functions or structs near existing Project display helpers if that makes tests straightforward"
- No other files edited, no persistence or schema changes

## CODEX REVIEW

Status: ACCEPTED

Codex accepted:

- Display-only Projects top-level status filter using local `@State`.
- `全部` plus one chip per existing `ProjectStatus.allCases`.
- Helper behavior that preserves missing `Project` metadata under `全部` and excludes it for concrete status filters.
- Count copy that distinguishes filtered count from total count.
- Keeping `议题治理` / merge review based on unfiltered `projectItems`.
- `ProjectEvidenceBoardItem` internal visibility for focused helper tests.

Codex rejected / did not take:

- No AppStore state.
- No Project status semantics changes.
- No persistence, migration, repository, prompt, parser, LLM, Keychain, Growth, Settings, or Today changes.

Manager verification:

- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test`: passed, 65 tests, 0 failures.
- `git diff --check`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.

Manager note:

- During monitoring, `scripts/claude_delegate.sh status` showed an `active handoff summary` for the template `## HANDOFF` placeholder before real handoff. Codex did not accept that as completion. This should be handled as a separate delegation-wrapper strictness follow-up, not as part of the 044 product slice.
