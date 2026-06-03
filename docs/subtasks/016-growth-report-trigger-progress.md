# Subtask 016 Progress: Growth Report Trigger and Evidence Gate

Status: verified

## Todo

- [x] Define bounded PRD.
- [x] Prepare Claude Code delegation prompt.
- [x] Add failing AppStore tests.
- [x] Implement AppStore report status state.
- [x] Add Growth UI report actions.
- [x] Run targeted tests.
- [x] Run full test suite.
- [x] Update delegation log.

## Notes

- `ralph-loop` was not found in PATH during setup.
- `/opt/homebrew/bin/claude` is available; this subtask keeps a prompt file so Claude Code can be used for a bounded review or implementation slice if needed.
- Claude Code was not executed for this slice before implementation because the bounded behavior was already covered by failing AppStore tests and touched a narrow AppStore/UI path.
- Durable data remains `MetricSnapshot` and `MetricContribution`.
- Weekly/monthly report actions are visible from Growth and guarded by a shared generation state.
- Insufficient evidence saves a snapshot and no contributions.
- Successful report contributions are saved as accepted because Growth UI only displays accepted contribution evidence.

## Verification

Targeted tests run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/AppStoreStateMachineTests/testGenerateWeeklyGrowthReport_withEnoughEvidencePersistsAISnapshotAndContributions \
  -only-testing:MingSiTests/AppStoreStateMachineTests/testGenerateMonthlyGrowthReport_withInsufficientEvidenceSavesNoContributions \
  test
```

Result:

- Passed: 2 tests, 0 failures.

Broader related suite:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/TodayAIServiceContextTests \
  -only-testing:MingSiTests/TodayAIResponseParserTests \
  -only-testing:MingSiTests/PromptEvalFixtureTests \
  test
```

Result:

- Passed: 129 tests, 0 failures.

Full suite:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Result:

- Passed: 209 tests, 0 failures.

Diff check:

```bash
git diff --check -- Sources/App/AppStore.swift Sources/Features/FeatureTabs.swift Tests/App/AppStoreStateMachineTests.swift docs/subtasks/016-growth-report-trigger-prd.md docs/subtasks/016-growth-report-trigger-progress.md docs/subtasks/016-growth-report-trigger-claude-prompt.md docs/agent-delegation-log.md
```

Result:

- Passed with no whitespace errors.
