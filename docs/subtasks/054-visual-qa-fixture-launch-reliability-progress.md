# Subtask 054 Progress: Visual QA Fixture Launch Reliability

Status: CODEX_ACCEPTED
Timestamp: 2026-06-06

Owner: Codex manager
Delegated implementer: Claude Code worker

PRD: `docs/subtasks/054-visual-qa-fixture-launch-reliability-prd.md`
Worker prompt: `docs/subtasks/054-visual-qa-fixture-launch-reliability-claude-prompt.md`
Expected event log: `docs/subtasks/logs/054-visual-qa-fixture-launch-reliability-events.jsonl`
Expected raw log: `docs/subtasks/logs/054-visual-qa-fixture-launch-reliability-claude-run.jsonl`

## Scope

- Debug-only visual QA fixture launch reliability.
- Narrow source/test change.
- No production persistence or product semantic change.

## Delegation Rationale

This is suitable for Claude Code because it has named write files, clear tests, and no product judgment beyond preserving production behavior.

Codex remains final verifier and simulator screenshot owner.

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
- Current Subtask 049 evidence shows `MINGSI_VISUAL_QA_PROJECT_DETAIL` simulator launch still displays live Projects empty state.

## START

Timestamp: 2026-06-06

Worker progress was recorded in the raw/follow-up logs but this manager progress file was stale at restart. Codex accepted only after reading the worker handoff evidence and rerunning verification in the manager checkout.

## IMPLEMENTED

Worker changed:

- `Sources/App/AppStore.swift` — added Debug-only `loadsPersistedStateOnLaunch`, environment activation support, and fixture opt-out from launch persisted loading.
- `Sources/App/MingSiApp.swift` — guarded app startup persisted loading behind the Debug fixture opt-out.
- `Tests/App/AppStoreStateMachineTests.swift` — added fixture launch/environment/persisted-load tests.

## TARGETED_VERIFIED

Worker verification:

- `git diff --check`: passed.
- `xcodebuild -only-testing:MingSiTests/AppStoreStateMachineTests test`: blocked by the known worker-worktree GRDB package path issue.

Codex verification:

- `git diff --check`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`: passed with 128 tests and 0 failures after the manager acceptance fix.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.

## HANDOFF

Status: DONE_WITH_CONCERNS

Codex acceptance:

- Accepted the worker direction for Debug-only launch reliability and persisted-load opt-out.
- Added a manager acceptance fix after real screenshots still showed live empty Projects state: Debug fixture stores now make `loadHistoryRecords()` a no-op, so the Projects tab reload task cannot overwrite fixture evidence.
- Added regression coverage: `testVisualQAFixture_loadHistoryRecordsKeepsFixtureProjectEvidence`.
- Final real iPhone 17 screenshot evidence: `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/15-projects-fixture-top-light-load-guard.png`.

Residual risk:

- This accepts fixture activation reliability and restores Project Detail visual QA readiness. It does not complete the full Project Detail screenshot matrix from Subtask 048.
