# Subtask 017 Progress: History Search and Evidence Filter

Status: verified

## Todo

- [x] Define bounded PRD.
- [x] Add failing domain tests.
- [x] Implement `HistoryEvidenceFilter` and local search query.
- [x] Add History UI search/filter controls.
- [x] Run targeted tests.
- [x] Run full test suite.
- [x] Update delegation log.

## Notes

- This slice is intentionally local-only and does not change database schema.
- It is the next MVP slice because History is the evidence archive for both Projects and Growth.

## Verification

RED:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

Result:

- Failed before implementation because `HistorySearchQuery` did not exist.

Targeted GREEN:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

Result:

- Passed: 18 tests, 0 failures.

Related suite:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/HistoryFeatureTests \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/PersistenceCoreTests \
  test
```

Result:

- Passed: 137 tests, 0 failures.

Full suite:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Result:

- Passed: 214 tests, 0 failures.

Diff check:

```bash
git diff --check -- Sources/Domain/Models.swift Sources/Features/FeatureTabs.swift Tests/Features/HistoryFeatureTests.swift docs/subtasks/017-history-search-filter-prd.md docs/subtasks/017-history-search-filter-progress.md docs/ux-flow.md docs/implementation-gap-audit.md docs/agent-delegation-log.md
```

Result:

- Passed with no whitespace errors.
