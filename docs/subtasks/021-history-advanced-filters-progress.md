# Subtask 021 Progress: History Advanced Filters

Owner: Codex

Delegated implementer: Claude Code via `/opt/homebrew/bin/claude`

Required PRD: `docs/subtasks/021-history-advanced-filters-prd.md`

## Status

- [x] PRD created
- [x] Claude Code started
- [x] RED tests observed
- [x] Implementation completed
- [x] Codex diff review completed
- [x] Targeted verification completed
- [x] Related regression completed
- [x] Docs updated

## Progress Log

### 2026-06-02 04:50

Codex created the subtask PRD and progress file.

Scope constraints:

- No migration.
- No saved filter persistence.
- No AI search.
- Advanced filters are derived from loaded `HistoryRecord` values.
- Codex remains responsible for review and verification.

### 2026-06-02 04:49

Claude Code was started with PID `38764`, but did not write to its log or update this progress file. Codex treated that delegation as a non-delivery and took over implementation directly.

RED observed:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

Result:

- Failed to compile because `HistorySearchQuery` did not accept `projectId`, `lens`, `cardType`, or `questStatus`.

### 2026-06-02 04:52

Codex implemented:

- Advanced `HistorySearchQuery` filters for project, lens, card type, and quest status.
- Intersection semantics with existing keyword and evidence-type filters.
- Compact History advanced filter menus derived from loaded records.
- Local UI display names for quest status.

Targeted verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

Result:

- Passed: 23 tests, 0 failures.

Related regression:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/PersistenceCoreTests test
```

Result:

- Passed: 157 tests, 0 failures.

Full verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
git diff --check
```

Result:

- Full test suite passed: 240 tests, 0 failures.
- Diff whitespace check passed.
