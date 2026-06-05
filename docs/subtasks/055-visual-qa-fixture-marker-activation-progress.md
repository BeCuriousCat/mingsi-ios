# Subtask 055 Progress: Visual QA Fixture Marker Activation

Status: CODEX_ACCEPTED
Timestamp: 2026-06-06

Owner: Codex manager
Delegated implementer: Claude Code worker

PRD: `docs/subtasks/055-visual-qa-fixture-marker-activation-prd.md`
Worker prompt: `docs/subtasks/055-visual-qa-fixture-marker-activation-claude-prompt.md`
Expected event log: `docs/subtasks/logs/055-visual-qa-fixture-marker-activation-events.jsonl`
Expected raw log: `docs/subtasks/logs/055-visual-qa-fixture-marker-activation-claude-run.jsonl`

## Scope

- Debug-only visual QA fixture marker activation.
- Narrow source/test change.
- No production persistence or product semantic change.

## Delegation Rationale

This is suitable for Claude Code because 054 has a verified runtime failure and the follow-up fix is a bounded Debug-only launch detection slice with named source/test files.

Codex remains final simulator screenshot owner.

## Required Checkpoints

Claude Code must update this file at:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At final handoff, add exactly one final status token:

- `Status: DONE`
- `Status: DONE_WITH_CONCERNS`
- `Status: NEEDS_CONTEXT`
- `Status: BLOCKED`

## Manager Notes

- Consume worker progress first.
- Do not inspect partial diff before `HANDOFF`.
- Flow logs are diagnostic-only.
- Current Subtask 054 code passes unit tests but fails real simulator activation.

---

## START

Timestamp: 2026-06-06T01:40Z
Worker: Claude Code

Planned files:
- `Sources/App/AppStore.swift` — add `markerFileExists` parameter to `isVisualQAProjectDetailLaunch`
- `Tests/App/AppStoreStateMachineTests.swift` — add marker-file activation tests
- `docs/subtasks/055-visual-qa-fixture-marker-activation-progress.md` — this file

Assumptions:
- `isVisualQAProjectDetailLaunch` already accepts `arguments`, `environment`, `defaults` for testability; we add `markerFileExists: () -> Bool` with a default that checks the real marker path in the app documents directory.
- Marker file name: `.visual_qa_project_detail` in the app's Documents directory (accessible via `xcrun simctl get_app_container`).
- The default closure uses `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first` and appends the marker filename — this resolves correctly in-simulator.
- No changes needed in `MingSiApp.swift` since it already calls `isVisualQAProjectDetailLaunch()` with no args, which will pick up the new default parameter.

## RED

Timestamp: 2026-06-06T01:42Z
Added tests:
- `testVisualQAProjectDetailLaunch_withMarkerFile_returnsTrue` — marker closure returning true activates fixture
- `testVisualQAProjectDetailLaunch_withoutMarkerFile_returnsFalse` — marker closure returning false does not activate (no other flags)
- `testVisualQAProjectDetailLaunch_markerFile_doesNotOverrideOtherActivation` — argument path still works without marker
- `testVisualQAProjectDetailLaunch_markerFileName_isDocumented` — marker filename constant is documented

Expected failure: `isVisualQAProjectDetailLaunch` does not yet accept `markerFileExists` parameter; `visualQAMarkerFileName` constant does not yet exist.

## IMPLEMENTED

Timestamp: 2026-06-06T01:44Z

Changed files:
- `Sources/App/AppStore.swift` — added `visualQAMarkerFileName` constant and `markerFileExists` parameter to `isVisualQAProjectDetailLaunch`
- `Tests/App/AppStoreStateMachineTests.swift` — added 4 marker-file activation tests
- `docs/subtasks/055-visual-qa-fixture-marker-activation-progress.md` — this file

Implementation summary:
- `isVisualQAProjectDetailLaunch` now accepts a `markerFileExists: () -> Bool` parameter with a default that checks `FileManager.default` for `.visual_qa_project_detail` in the app Documents directory.
- The default closure is injected so tests can override it without needing a real filesystem.
- Marker filename exposed as `visualQAMarkerFileName` constant for documentation and Codex reference.
- All existing activation paths (argument, env, simctl env, UserDefaults) are preserved unchanged.
- `MingSiApp.swift` needs no changes — it calls `isVisualQAProjectDetailLaunch()` with no args, picking up the new default parameter.

## TARGETED_VERIFIED

Timestamp: 2026-06-06T01:49Z

- `git diff --check`: passed (no output).
- `xcodebuild -only-testing:MingSiTests/AppStoreStateMachineTests test`: **FAILED** — known GRDB worktree issue: `Could not resolve package dependencies: invalid custom path 'Tests' for target 'GRDBTests'`. This is the same SPM resolution failure seen in other worker worktrees. Codex must rerun in the manager checkout.

## HANDOFF

Status: DONE_WITH_CONCERNS

Changed files:
- `Sources/App/AppStore.swift` — added `visualQAMarkerFileName` constant and `markerFileExists` closure parameter to `isVisualQAProjectDetailLaunch`
- `Tests/App/AppStoreStateMachineTests.swift` — added 4 marker-file activation tests
- `docs/subtasks/055-visual-qa-fixture-marker-activation-progress.md` — progress tracking

Verification:
- `git diff --check`: passed
- `xcodebuild test`: blocked by GRDB worktree SPM issue, Codex must rerun

Marker file path for Codex:
```bash
# Get the app data container
CONTAINER=$(xcrun simctl get_app_container booted com.codex.mingsi data)
# Create marker file
touch "$CONTAINER/Documents/.visual_qa_project_detail"
# Launch app
xcrun simctl launch --terminate-running-process booted com.codex.mingsi
```

The marker file `.visual_qa_project_detail` lives in the app's Documents directory. The default `markerFileExists` closure checks `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first` appended with the marker filename.

Concerns:
- xcodebuild cannot resolve GRDB in the worker worktree. Codex must rerun focused tests in the manager checkout: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
- Real simulator activation requires Codex to create the marker file before launch and verify via screenshot.

## CODEX_ACCEPTANCE

Timestamp: 2026-06-06

Codex accepted the marker-file activation only after fresh manager verification and real simulator evidence.

Manager acceptance fix:

- Real iPhone 17 screenshots still failed after marker and argument launches because `ProjectsView.task` called `store.loadHistoryRecords()` and replaced the fixture evidence with live empty history.
- Codex added a Debug fixture guard in `AppStore.loadHistoryRecords()` so fixture stores that opt out of persisted launch loading are not overwritten by Projects tab reload tasks.
- Codex added `testVisualQAFixture_loadHistoryRecordsKeepsFixtureProjectEvidence`, first observed it fail, then verified it passed after the fix.

Verification:

- `git diff --check`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`: passed with 128 tests and 0 failures.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.

Screenshot evidence:

- Failed before manager guard: `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/13-projects-fixture-top-light-task-activation.png`
- Failed argument control before manager guard: `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/14-projects-fixture-top-light-argument-after-task-activation.png`
- Accepted marker launch after manager guard: `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/15-projects-fixture-top-light-load-guard.png`

Outcome:

- Accepted for Debug-only visual QA fixture activation.
- This does not create production fake data and does not complete Project Detail visual matrix screenshots.
