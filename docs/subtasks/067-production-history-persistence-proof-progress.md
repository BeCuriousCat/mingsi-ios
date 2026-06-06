# Subtask 067 Progress: Production History Persistence Proof

Status: CODEX_ACCEPTED

Owner: Codex manager
Delegated implementer: not delegated

PRD: `docs/subtasks/067-production-history-persistence-proof-prd.md`
Claude prompt: none
Event log: none
Raw log: none

## Manager Setup

- Timestamp: 2026-06-07
- Source state: Subtask 066 committed in `4ed9d5b Add debug today completion history seed`.
- Reason: Subtask 066 proved deterministic rendered Today completion and History archive screenshots through a Debug-only in-memory seed. The remaining product evidence gap was production SQLite persistence from the real Today completion path into History.
- Implementation path: direct Codex TDD/proof test plus a scoped production persistence-ordering fix after the proof test exposed a real AppStore race.

## Checkpoints

- RED: initial 067 test exposed the production evidence condition as unproven, then the full suite exposed a real AppStore local persistence ordering race: rapid Today writes could let older snapshots finish after newer confirmed evidence.
- GREEN: Codex queued Today local persistence writes behind a single AppStore persistence chain, waited for pending persistence before SessionComplete growth/history refresh, and the focused 067 test passed against a fresh `AppStore.loadHistoryRecords()` over SQLite repositories.
- TARGETED_VERIFIED: focused 067 test passed; full `AppStoreStateMachineTests` passed with 174 tests and 0 failures; `git diff --check` passed; iPhone 17 simulator build passed.
- HANDOFF: not applicable; no Claude Code worker was launched.

## Planned Verification

Commands:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testProductionTodayCompletion_persistsHistoryEvidenceThroughSQLiteReload test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Current Results

- Focused 067 test passed after the AppStore persistence ordering fix: 1 test, 0 failures.
- Full `AppStoreStateMachineTests` passed after the final cleanup patch: 174 tests, 0 failures.
- `git diff --check` passed with no output.
- iPhone 17 simulator build passed with `BUILD SUCCEEDED`.

## Acceptance Notes

- The proof test uses the real Today state machine and SQLite repositories.
- Production source changes were needed: `AppStore` now queues Today local persistence writes so older snapshots cannot overwrite newer confirmed cards, quests, principles, lens sessions, or the final completed draft state.
- The test intentionally verifies the user-facing History archive reload surface, not just individual repository rows.
- The full-suite failure was a useful production bug signal, not merely a test timing issue. The accepted path must prove a fresh `AppStore` loading History from the same SQLite repositories sees the completed evidence after rapid local writes.

## Residual Risk

- This is not live GLM proof; the path uses local fallback because no BYOK GLM key is configured in the simulator/test environment.
- This does not add new simulator screenshots; Subtask 066 already covered rendered Today/History first-viewport evidence using Debug-only visual QA.
